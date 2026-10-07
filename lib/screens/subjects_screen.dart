// lib/screens/subjects_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/subject.dart';
import '../providers/subject_provider.dart';
import '../providers/accessibility_provider.dart';
import '../providers/user_provider.dart';
import '../theme/app_colors.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';

class SubjectsScreen extends StatelessWidget {
  const SubjectsScreen({super.key});

  void _showAddSubjectDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final yearController = TextEditingController();
    final divisionController = TextEditingController();

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
                      child: TextField(
                        controller: yearController,
                        decoration: const InputDecoration(
                          labelText: 'Año',
                          hintText: 'Ej. 1°',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: divisionController,
                        decoration: const InputDecoration(
                          labelText: 'División',
                          hintText: 'Ej. A',
                        ),
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
                if (name.isNotEmpty) {
                  final newSub = Subject(
                    id: '',
                    name: name,
                    year: yearController.text.trim(),
                    division: divisionController.text.trim(),
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
      colorValue: primaryColor.value,
      description: 'Consultas generales libremente con el Tutor IA',
    );

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

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor:
            accessibility.isHighContrast ? Colors.black : primaryColor,
        foregroundColor:
            accessibility.isHighContrast ? Colors.yellowAccent : Colors.white,
        title: Text(
          'Materias de Estudio',
          style: accessibility.getTextStyle(
            overrideSize: accessibility.fontSize * 1.1,
            color: accessibility.isHighContrast
                ? Colors.yellowAccent
                : Colors.white,
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ProfileScreen(),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Builder(
                builder: (_) {
                  final path = userProvider.profileImagePath;
                  ImageProvider? avatarImage;

                  if (path.isNotEmpty) {
                    if (path.startsWith('http')) {
                      avatarImage = NetworkImage(path);
                    } else {
                      final file = File(path);
                      if (file.existsSync()) avatarImage = FileImage(file);
                    }
                  }

                  return avatarImage != null
                      ? CircleAvatar(
                          radius: 18,
                          backgroundImage: avatarImage,
                        )
                      : userProvider.getDefaultAvatar(
                          radius: 18,
                          color: Colors.white,
                        );
                },
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => subjectProvider.fetchSubjects(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿Qué te gustaría estudiar hoy?',
                style: accessibility.getTextStyle(
                  overrideSize: accessibility.fontSize * 1.25,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Selecciona una asignatura o accede al chat libre:',
                style: accessibility.getTextStyle(
                  overrideSize: accessibility.fontSize * 0.85,
                  color: accessibility.isHighContrast
                      ? Colors.white70
                      : textColor.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 14),
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
                        builder: (context) =>
                            ChatScreen(subject: generalSubject),
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
                'Materias Registradas',
                style: accessibility.getTextStyle(
                  overrideSize: accessibility.fontSize * 0.95,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: subjectProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.0,
                        ),
                        itemCount: subjectProvider.subjects.length,
                        itemBuilder: (context, index) {
                          final subject = subjectProvider.subjects[index];
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
                                        ChatScreen(subject: subject),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: LinearGradient(
                                    colors: accessibility.isHighContrast
                                        ? [
                                            Colors.grey.shade900,
                                            Colors.grey.shade900
                                          ]
                                        : [
                                            primaryColor.withValues(
                                                alpha: 0.15),
                                            primaryColor.withValues(
                                                alpha: 0.05),
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
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
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
