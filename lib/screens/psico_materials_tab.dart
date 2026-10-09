import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/tracking_service.dart';

/// Pestaña del panel psico con todo lo que suben los docentes.
class PsicoMaterialsTab extends StatefulWidget {
  final Color primaryColor;

  const PsicoMaterialsTab({super.key, required this.primaryColor});

  @override
  State<PsicoMaterialsTab> createState() => _PsicoMaterialsTabState();
}

class _PsicoMaterialsTabState extends State<PsicoMaterialsTab>
    with AutomaticKeepAliveClientMixin {
  static const String _allCourses = 'Todos';

  final _service = TrackingService();
  final _search = TextEditingController();
  List<MaterialEntry> _entries = [];
  String _course = _allCourses;
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await _service.loadAllMaterials();
      if (mounted) setState(() => _entries = entries);
    } catch (e) {
      debugPrint('Error al cargar materiales: $e');
      if (mounted) {
        setState(() => _error = 'No se pudieron cargar los materiales.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(MaterialEntry entry) async {
    final uri = Uri.tryParse(entry.material.fileUrl);
    final opened = uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el archivo.')),
      );
    }
  }

  String _fmt(DateTime d) {
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final primaryColor = widget.primaryColor;

    final courses = [
      _allCourses,
      ...{
        for (final e in _entries)
          if (e.course.isNotEmpty) e.course
      }.toList()
        ..sort(),
    ];

    final q = _search.text.trim().toLowerCase();
    final filtered = _entries.where((e) {
      if (_course != _allCourses && e.course != _course) return false;
      if (q.isEmpty) return true;
      return e.material.title.toLowerCase().contains(q) ||
          (e.subject?.name.toLowerCase().contains(q) ?? false) ||
          e.teacherName.toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Buscar por título, materia o docente',
              prefixIcon: Icon(Icons.search, color: primaryColor),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              isDense: true,
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: courses.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) => Center(
              child: ChoiceChip(
                label: Text(courses[i]),
                selected: _course == courses[i],
                selectedColor: primaryColor.withValues(alpha: 0.25),
                onSelected: (_) => setState(() => _course = courses[i]),
              ),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: filtered.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 80),
                                Center(
                                    child: Text(
                                        'No hay materiales para mostrar.')),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                              itemCount: filtered.length,
                              itemBuilder: (_, i) {
                                final e = filtered[i];
                                final m = e.material;
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                        color: primaryColor.withValues(
                                            alpha: 0.3)),
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          primaryColor.withValues(alpha: 0.15),
                                      child: Icon(
                                          e.subject?.icon ??
                                              Icons.assignment_rounded,
                                          color: primaryColor),
                                    ),
                                    title: Text(m.title,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    subtitle: Text(
                                      '${e.subject?.name ?? 'Materia eliminada'}'
                                      '${e.course.isNotEmpty ? ' · ${e.course}' : ''}\n'
                                      'Prof. ${e.teacherName} · ${_fmt(m.createdAt)}'
                                      '${(m.description ?? '').isNotEmpty ? '\n${m.description}' : ''}',
                                    ),
                                    isThreeLine: true,
                                    trailing: IconButton(
                                      tooltip: 'Abrir archivo',
                                      icon: Icon(Icons.download_rounded,
                                          color: primaryColor),
                                      onPressed: () => _open(e),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
        ),
      ],
    );
  }
}
