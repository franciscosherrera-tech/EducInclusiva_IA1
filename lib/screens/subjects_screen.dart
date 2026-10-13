// lib/screens/subjects_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/courses.dart';
import '../models/subject.dart';
import '../providers/new_content_provider.dart';
import '../providers/subject_provider.dart';
import '../providers/accessibility_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/profile_avatar_button.dart';
import 'chat_screen.dart';
import 'student_subject_screen.dart';

class SubjectsScreen extends StatefulWidget {
  const SubjectsScreen({super.key});

  @override
  State<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends State<SubjectsScreen> {
  final _search = TextEditingController();
  String _lastSignature = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Vuelve a traer el curso asignado, el perfil de accesibilidad y las materias.
  Future<void> _refresh() async {
    await Future.wait([
      context.read<UserProvider>().loadFromSupabase(),
      context.read<AccessibilityProvider>().loadStudentSettings(),
      context.read<SubjectProvider>().fetchSubjects(),
    ]);
  }

  void _showAddSubjectDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String? selectedYear;
    String? selectedDivision;

    Color selectedColor = AppColors.periwinkle;
    IconData selectedIcon = Icons.school;

    final primaryColor =
        Provider.of<AccessibilityProvider>(context, listen: false)
            .activePrimaryColor;

    final availableIcons = [
      Icons.school,
      Icons.music_note,
      Icons.palette,
      Icons.computer,
      Icons.fitness_center,
      Icons.psychology,
      Icons.architecture,
      Icons.biotech,
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: Text(
            'Añadir Nueva Asignatura',
            style: TextStyle(color: primaryColor),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la Materia',
                    hintText: 'Ej. Robótica, Filosofía',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedYear,
                        decoration: const InputDecoration(labelText: 'Año'),
                        items: Courses.years
                            .map((y) =>
                                DropdownMenuItem(value: y, child: Text(y)))
                            .toList(),
                        onChanged: (val) =>
                            setStateModal(() => selectedYear = val),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedDivision,
                        decoration:
                            const InputDecoration(labelText: 'División'),
                        items: Courses.divisions
                            .map((d) =>
                                DropdownMenuItem(value: d, child: Text(d)))
                            .toList(),
                        onChanged: (val) =>
                            setStateModal(() => selectedDivision = val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción corta',
                  ),
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Elige un Ícono:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableIcons.map((icon) {
                    final isSelected = selectedIcon == icon;
                    return InkWell(
                      onTap: () => setStateModal(() => selectedIcon = icon),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? primaryColor.withValues(alpha: 0.2)
                              : Colors.grey.shade200,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: primaryColor, width: 2)
                              : null,
                        ),
                        child: Icon(icon,
                            color: isSelected ? primaryColor : Colors.black87),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty ||
                    selectedYear == null ||
                    selectedDivision == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Completa el nombre, el año y la división'),
                    ),
                  );
                  return;
                }

                final newSub = Subject(
                  id: '',
                  name: name,
                  year: selectedYear!,
                  division: selectedDivision!,
                  iconCode: selectedIcon.codePoint,
                  colorValue: selectedColor.value,
                  description: descController.text.trim(),
                );

                try {
                  await Provider.of<SubjectProvider>(context, listen: false)
                      .addSubject(newSub);
                  if (context.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al guardar materia: $e')),
                    );
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accessibility = Provider.of<AccessibilityProvider>(context);
    final subjectProvider = Provider.of<SubjectProvider>(context);
    final userProvider = Provider.of<UserProvider>(context);

    // Muestra el botón flotante únicamente para profesores o psicopedagogas
    final currentRole = userProvider.role.toLowerCase();
    final isTeacher =
        currentRole == 'docente' || currentRole == 'psicopedagoga';

    final Color primaryColor = accessibility.activePrimaryColor;

    final generalSubject = Subject(
      id: '00000000-0000-0000-0000-000000000000',
      name: 'Chat General',
      iconCode: Icons.forum_rounded.codePoint,
      colorValue: primaryColor.toARGB32(),
      description: 'Consultas generales libremente con el Tutor IA',
    );

    // Solo las materias del curso que le asignó la psicopedagoga
    final query = _search.text.trim().toLowerCase();
    final courseSubjects = subjectProvider.subjects
        .where((s) =>
            s.year == userProvider.year && s.division == userProvider.division)
        .toList();
    final mySubjects = courseSubjects
        .where((s) => query.isEmpty || s.name.toLowerCase().contains(query))
        .toList();

    // Calcula el contenido nuevo cuando cambian las materias del curso
    final signature = courseSubjects.map((s) => s.id).join(',');
    if (signature != _lastSignature) {
      _lastSignature = signature;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !isTeacher) {
          context.read<NewContentProvider>().refresh(courseSubjects);
        }
      });
    }
    final newContent = context.watch<NewContentProvider>();

    final Color bgColor = accessibility.isHighContrast
        ? Colors.black
        : Theme.of(context).scaffoldBackgroundColor;
    final Color cardColor = accessibility.isHighContrast
        ? Colors.grey.shade900
        : primaryColor.withValues(alpha: 0.12);
    final Color textColor = accessibility.isHighContrast
        ? Colors.white
        : (Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : AppColors.darkBlue);
    final Color appBarFg =
        accessibility.isHighContrast ? Colors.yellowAccent : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor:
            accessibility.isHighContrast ? Colors.black : primaryColor,
        foregroundColor: appBarFg,
        leading: IconButton(
          tooltip: 'Inicio',
          icon: const Icon(Icons.home_rounded),
          onPressed: () {
            _search.clear();
            setState(() {});
          },
        ),
        titleSpacing: 0,
        title: Text(
          'Inicio',
          style: accessibility.getTextStyle(
            overrideSize: accessibility.fontSize * 1.1,
            fontWeight: FontWeight.bold,
            color: appBarFg,
          ),
        ),
        actions: [ProfileAvatarButton(onReturn: _refresh)],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Text(
              '¿Qué te gustaría estudiar hoy?',
              style: accessibility.getTextStyle(
                overrideSize: accessibility.fontSize * 1.25,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            if (userProvider.hasCourse) ...[
              const SizedBox(height: 4),
              Text(
                'Tu curso: ${userProvider.year} ${userProvider.division}',
                style: accessibility.getTextStyle(
                  overrideSize: accessibility.fontSize * 0.85,
                  color: accessibility.isHighContrast
                      ? Colors.white70
                      : textColor.withValues(alpha: 0.7),
                ),
              ),
            ],
            if (newContent.totalNew > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: primaryColor.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.notifications_active_rounded,
                        color: primaryColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        newContent.totalNew == 1
                            ? 'Tenés 1 contenido nuevo: ${newContent.newTitles().join(', ')}'
                            : 'Tenés ${newContent.totalNew} contenidos nuevos: ${newContent.newTitles().join(', ')}${newContent.totalNew > 3 ? '…' : ''}',
                        style: accessibility.getTextStyle(
                          overrideSize: accessibility.fontSize * 0.9,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),

            // --- Buscador de materias ---
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              style: accessibility.getTextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Buscar materia...',
                prefixIcon: Icon(Icons.search, color: primaryColor),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Borrar búsqueda',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _search.clear();
                          setState(() {});
                        },
                      ),
                filled: true,
                fillColor: accessibility.isHighContrast
                    ? Colors.grey.shade900
                    : Theme.of(context).cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      BorderSide(color: primaryColor.withValues(alpha: 0.4)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      BorderSide(color: primaryColor.withValues(alpha: 0.4)),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // --- Chat general ---
            Card(
              color: cardColor,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                    color: primaryColor.withValues(alpha: 0.5), width: 1.5),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(subject: generalSubject),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 14.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: primaryColor,
                        child: Icon(
                          Icons.forum_rounded,
                          color: accessibility.isHighContrast
                              ? Colors.black
                              : Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Chat General con Tutor IA',
                              style: accessibility.getTextStyle(
                                overrideSize: accessibility.fontSize * 1.0,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Haz consultas libres sobre cualquier tema.',
                              style: accessibility.getTextStyle(
                                overrideSize: accessibility.fontSize * 0.8,
                                color: accessibility.isHighContrast
                                    ? Colors.white70
                                    : textColor.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: primaryColor,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Mis Materias',
              style: accessibility.getTextStyle(
                overrideSize: accessibility.fontSize * 0.95,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 10),

            // --- Grilla de materias ---
            if (subjectProvider.isLoading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (!userProvider.hasCourse)
              _InfoMessage(
                icon: Icons.groups_rounded,
                text:
                    'Todavía no tenés un curso asignado.\nPedile a tu psicopedagoga que te lo asigne.',
                color: primaryColor,
                textColor: textColor,
                accessibility: accessibility,
              )
            else if (mySubjects.isEmpty)
              _InfoMessage(
                icon: Icons.search_off_rounded,
                text: query.isEmpty
                    ? 'Tu curso todavía no tiene materias cargadas.'
                    : 'No hay materias que coincidan con "${_search.text}".',
                color: primaryColor,
                textColor: textColor,
                accessibility: accessibility,
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.0,
                ),
                itemCount: mySubjects.length,
                itemBuilder: (context, index) {
                  final subject = mySubjects[index];
                  return Card(
                    color: accessibility.isHighContrast
                        ? Colors.grey.shade900
                        : Theme.of(context).cardColor,
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                StudentSubjectScreen(subject: subject),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            colors: accessibility.isHighContrast
                                ? [Colors.grey.shade900, Colors.grey.shade900]
                                : [
                                    primaryColor.withValues(alpha: 0.15),
                                    primaryColor.withValues(alpha: 0.05),
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Stack(
                          children: [
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor:
                                        primaryColor.withValues(alpha: 0.2),
                                    child: Icon(
                                      subject.icon,
                                      color: accessibility.isHighContrast
                                          ? Colors.yellowAccent
                                          : primaryColor,
                                      size: 30,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    subject.name,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: accessibility.getTextStyle(
                                      overrideSize:
                                          accessibility.fontSize * 0.9,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (newContent.newCountFor(subject.id) > 0)
                              Positioned(
                                top: 0,
                                right: 0,
                                child: Semantics(
                                  label:
                                      '${newContent.newCountFor(subject.id)} contenidos nuevos',
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${newContent.newCountFor(subject.id)} nuevo${newContent.newCountFor(subject.id) == 1 ? '' : 's'}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
      floatingActionButton: isTeacher
          ? FloatingActionButton.extended(
              onPressed: () => _showAddSubjectDialog(context),
              backgroundColor: primaryColor,
              icon: Icon(Icons.add,
                  color: accessibility.isHighContrast
                      ? Colors.black
                      : Colors.white),
              label: Text(
                'Nueva Materia',
                style: accessibility.getTextStyle(
                  color: accessibility.isHighContrast
                      ? Colors.black
                      : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }
}

class _InfoMessage extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final Color textColor;
  final AccessibilityProvider accessibility;

  const _InfoMessage({
    required this.icon,
    required this.text,
    required this.color,
    required this.textColor,
    required this.accessibility,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(icon, size: 48, color: color.withValues(alpha: 0.6)),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: accessibility.getTextStyle(
              color: textColor.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
