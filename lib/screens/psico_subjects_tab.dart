import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/courses.dart';
import '../models/subject.dart';
import '../providers/subject_provider.dart';
import '../utils/course_grouping.dart';

/// Pestaña del panel psico: crear materias y asignarlas (o reasignarlas) a
/// un docente, por curso.
class PsicoSubjectsTab extends StatefulWidget {
  final Color primaryColor;

  const PsicoSubjectsTab({super.key, required this.primaryColor});

  @override
  State<PsicoSubjectsTab> createState() => _PsicoSubjectsTabState();
}

class _PsicoSubjectsTabState extends State<PsicoSubjectsTab>
    with AutomaticKeepAliveClientMixin {
  /// id del docente → nombre
  Map<String, String> _teachers = {};
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final rows = List<Map<String, dynamic>>.from(await Supabase
          .instance.client
          .from('profiles')
          .select('id, name, role')
          .order('name'));
      _teachers = {
        for (final r in rows)
          if ((r['role'] ?? '').toString().toLowerCase() == 'docente')
            r['id'].toString(): (r['name'] ?? 'Sin nombre').toString(),
      };
      if (mounted) {
        await context.read<SubjectProvider>().fetchSubjects();
      }
    } catch (e) {
      debugPrint('Error al cargar docentes: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openDialog({Subject? subject}) async {
    final saved = await showDialog<Subject>(
      context: context,
      builder: (_) => _SubjectDialog(
        teachers: _teachers,
        subject: subject,
        primaryColor: widget.primaryColor,
      ),
    );
    if (saved == null || !mounted) return;

    final provider = context.read<SubjectProvider>();
    try {
      if (subject == null) {
        await provider.addSubject(saved);
      } else {
        await provider.updateSubject(saved);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(subject == null
                  ? 'Materia creada y asignada'
                  : 'Materia actualizada')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar la materia: $e')),
        );
      }
    }
  }

  Future<void> _delete(Subject subject) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar materia'),
        content: Text(
            '¿Eliminar "${subject.name}"? También se borran sus contenidos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<SubjectProvider>().deleteSubject(subject.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo eliminar: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final primaryColor = widget.primaryColor;
    final subjects = context.watch<SubjectProvider>().subjects;
    final groups = groupByCourse(subjects);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openDialog(),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nueva materia'),
      ),
      body: _loading && subjects.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: subjects.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 80),
                        Center(child: Text('Todavía no hay materias.')),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                      children: [
                        for (final entry in groups.entries) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
                            child: Row(
                              children: [
                                Icon(Icons.groups_rounded,
                                    size: 18, color: primaryColor),
                                const SizedBox(width: 6),
                                Text(
                                  entry.key,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          for (final s in entry.value)
                            Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                    color: primaryColor.withValues(alpha: 0.3)),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      primaryColor.withValues(alpha: 0.15),
                                  child: Icon(s.icon, color: primaryColor),
                                ),
                                title: Text(s.name,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                subtitle: Text(_teachers[s.teacherId] != null
                                    ? 'Prof. ${_teachers[s.teacherId]}'
                                    : 'Sin docente asignado'),
                                onTap: () => _openDialog(subject: s),
                                trailing: IconButton(
                                  tooltip: 'Eliminar materia',
                                  icon: const Icon(Icons.delete_outline,
                                      color: Colors.red),
                                  onPressed: () => _delete(s),
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
            ),
    );
  }
}

class _SubjectDialog extends StatefulWidget {
  final Map<String, String> teachers;
  final Subject? subject;
  final Color primaryColor;

  const _SubjectDialog({
    required this.teachers,
    required this.subject,
    required this.primaryColor,
  });

  @override
  State<_SubjectDialog> createState() => _SubjectDialogState();
}

class _SubjectDialogState extends State<_SubjectDialog> {
  late final TextEditingController _name;
  String? _year;
  String? _division;
  String? _teacherId;
  String? _error;

  static const _icons = [
    Icons.school,
    Icons.book,
    Icons.calculate,
    Icons.science,
    Icons.palette,
    Icons.computer,
    Icons.fitness_center,
    Icons.biotech,
    Icons.public,
    Icons.history_edu,
  ];
  late IconData _icon;

  @override
  void initState() {
    super.initState();
    final s = widget.subject;
    _name = TextEditingController(text: s?.name ?? '');
    _year = Courses.years.contains(s?.year) ? s?.year : null;
    _division = Courses.divisions.contains(s?.division) ? s?.division : null;
    _teacherId =
        widget.teachers.containsKey(s?.teacherId) ? s?.teacherId : null;
    _icon = _icons.firstWhere((i) => i.codePoint == s?.iconCode,
        orElse: () => Icons.school);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    if (_name.text.trim().isEmpty ||
        _year == null ||
        _division == null ||
        _teacherId == null) {
      setState(() => _error = 'Completá nombre, año, división y docente.');
      return;
    }
    final old = widget.subject;
    Navigator.pop(
      context,
      Subject(
        id: old?.id ?? '',
        teacherId: _teacherId!,
        name: _name.text.trim(),
        description: old?.description ?? '',
        year: _year!,
        division: _division!,
        iconCode: _icon.codePoint,
        colorValue: old?.colorValue ?? widget.primaryColor.toARGB32(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.subject == null ? 'Nueva materia' : 'Editar materia'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration:
                  const InputDecoration(labelText: 'Nombre de la materia'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _year,
                    decoration: const InputDecoration(labelText: 'Año'),
                    items: Courses.years
                        .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                        .toList(),
                    onChanged: (v) => setState(() => _year = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _division,
                    decoration: const InputDecoration(labelText: 'División'),
                    items: Courses.divisions
                        .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                        .toList(),
                    onChanged: (v) => setState(() => _division = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _teacherId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Docente'),
              items: widget.teachers.entries
                  .map((e) =>
                      DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _teacherId = v),
            ),
            if (widget.teachers.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'No hay docentes registrados todavía.',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _icons.map((icon) {
                final selected = icon == _icon;
                return InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => setState(() => _icon = icon),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? widget.primaryColor.withValues(alpha: 0.2)
                          : null,
                      border: selected
                          ? Border.all(color: widget.primaryColor, width: 2)
                          : null,
                    ),
                    child: Icon(icon,
                        color: selected ? widget.primaryColor : null),
                  ),
                );
              }).toList(),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.primaryColor,
            foregroundColor: Colors.white,
          ),
          onPressed: _save,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
