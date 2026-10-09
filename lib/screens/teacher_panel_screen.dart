import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../constants/courses.dart';
import '../models/subject.dart';
import '../providers/accessibility_provider.dart';
import '../providers/subject_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_colors.dart';
import 'teacher_subject_detail_screen.dart';
import '../widgets/profile_avatar_button.dart';

class TeacherPanelScreen extends StatefulWidget {
  const TeacherPanelScreen({super.key});

  @override
  State<TeacherPanelScreen> createState() => _TeacherPanelScreenState();
}

class _TeacherPanelScreenState extends State<TeacherPanelScreen> {
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTeacherData());
  }

  Future<void> _loadTeacherData() async {
    await Future.wait([
      Provider.of<UserProvider>(context, listen: false).loadFromSupabase(),
      Provider.of<SubjectProvider>(context, listen: false).fetchSubjects(),
    ]);
  }

  /// Agrupa las materias del docente por curso ("4° 1ra", "6° 1ra", ...).
  Map<String, List<Subject>> _groupByCourse(List<Subject> subjects) {
    final groups = <String, List<Subject>>{};
    for (final subject in subjects) {
      final key = '${subject.year} ${subject.division}'.trim();
      groups.putIfAbsent(key.isEmpty ? 'Sin curso asignado' : key, () => [])
          .add(subject);
    }

    final sortedKeys = groups.keys.toList()
      ..sort((a, b) {
        final numA = int.tryParse(RegExp(r'\d+').stringMatch(a) ?? '');
        final numB = int.tryParse(RegExp(r'\d+').stringMatch(b) ?? '');
        if (numA != null && numB != null && numA != numB) {
          return numA.compareTo(numB);
        }
        return a.compareTo(b);
      });

    return {for (final key in sortedKeys) key: groups[key]!};
  }

  void _showAddSubjectDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String? selectedYear;
    String? selectedDivision;

    IconData selectedIcon = Icons.school;

    final primaryColor =
        Provider.of<AccessibilityProvider>(context, listen: false)
            .activePrimaryColor;

    final availableIcons = [
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

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) => AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          title: Text(
            'Crear Nueva Materia',
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la Materia',
                    hintText: 'Ej. Matemáticas, Robótica',
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
                    labelText: 'Descripción (opcional)',
                  ),
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Elige un ícono:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
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
                        child: Icon(
                          icon,
                          color: isSelected ? primaryColor : Colors.black87,
                        ),
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
                      content:
                          Text('Completa el nombre, el año y la división'),
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
                  colorValue: primaryColor.toARGB32(),
                  description: descController.text.trim(),
                );

                try {
                  await Provider.of<SubjectProvider>(context, listen: false)
                      .addSubject(newSub);
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Materia creada con éxito')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al crear materia: $e')),
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

    final userId = _supabase.auth.currentUser?.id;
    final mySubjects = subjectProvider.subjects
        .where((s) => s.teacherId == userId)
        .toList();
    final courses = _groupByCourse(mySubjects);

    final Color primaryColor = accessibility.activePrimaryColor;
    final Color bgColor = accessibility.isHighContrast
        ? Colors.black
        : Theme.of(context).scaffoldBackgroundColor;
    final Color textColor = accessibility.isHighContrast
        ? Colors.white
        : (Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : AppColors.darkBlue);
    final Color onPrimary =
        accessibility.isHighContrast ? Colors.black : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor:
            accessibility.isHighContrast ? Colors.black : primaryColor,
        foregroundColor:
            accessibility.isHighContrast ? Colors.yellowAccent : Colors.white,
        title: Text(
          'Mis Cursos',
          style: accessibility.getTextStyle(
            overrideSize: accessibility.fontSize * 1.1,
            color: accessibility.isHighContrast
                ? Colors.yellowAccent
                : Colors.white,
          ),
        ),
        actions: [ProfileAvatarButton(onReturn: _loadTeacherData)],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTeacherData,
        child: subjectProvider.isLoading && mySubjects.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  Text(
                    'Hola, ${userProvider.name} 👋',
                    style: accessibility.getTextStyle(
                      overrideSize: accessibility.fontSize * 1.25,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Selecciona una materia para subir tareas y ver lo publicado:',
                    style: accessibility.getTextStyle(
                      overrideSize: accessibility.fontSize * 0.85,
                      color: accessibility.isHighContrast
                          ? Colors.white70
                          : textColor.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (mySubjects.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: Text(
                        'Todavía no tenés materias asignadas.\n\nUsá el botón "Nueva Materia" para agregar una.',
                        textAlign: TextAlign.center,
                        style: accessibility.getTextStyle(
                          color: textColor.withValues(alpha: 0.6),
                        ),
                      ),
                    )
                  else
                    for (final entry in courses.entries) ...[
                      _CourseHeader(
                        label: entry.key,
                        count: entry.value.length,
                        color: primaryColor,
                        accessibility: accessibility,
                      ),
                      const SizedBox(height: 10),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.0,
                        ),
                        itemCount: entry.value.length,
                        itemBuilder: (context, index) => _SubjectCard(
                          subject: entry.value[index],
                          primaryColor: primaryColor,
                          textColor: textColor,
                          accessibility: accessibility,
                        ),
                      ),
                      const SizedBox(height: 22),
                    ],
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSubjectDialog(context),
        backgroundColor: primaryColor,
        icon: Icon(Icons.add, color: onPrimary),
        label: Text(
          'Nueva Materia',
          style: accessibility.getTextStyle(
            color: onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _CourseHeader extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final AccessibilityProvider accessibility;

  const _CourseHeader({
    required this.label,
    required this.count,
    required this.color,
    required this.accessibility,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.groups_rounded, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: accessibility.getTextStyle(
                  overrideSize: accessibility.fontSize * 0.95,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Divider(color: color.withValues(alpha: 0.3))),
        const SizedBox(width: 10),
        Text(
          count == 1 ? '1 materia' : '$count materias',
          style: accessibility.getTextStyle(
            overrideSize: accessibility.fontSize * 0.75,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final Subject subject;
  final Color primaryColor;
  final Color textColor;
  final AccessibilityProvider accessibility;

  const _SubjectCard({
    required this.subject,
    required this.primaryColor,
    required this.textColor,
    required this.accessibility,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: accessibility.isHighContrast
          ? Colors.grey.shade900
          : Theme.of(context).cardColor,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TeacherSubjectDetailScreen(subject: subject),
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: primaryColor.withValues(alpha: 0.2),
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
                  overrideSize: accessibility.fontSize * 0.9,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
