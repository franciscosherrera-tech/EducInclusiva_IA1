import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/courses.dart';
import '../models/student_settings.dart';
import '../providers/accessibility_provider.dart';
import '../services/student_settings_service.dart';

/// Pantalla donde la psicopedagoga configura el curso y el perfil de
/// accesibilidad de un alumno. El alumno no puede modificar estos valores.
class PsicoStudentSettingsScreen extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String? year;
  final String? division;
  final StudentSettings? settings;

  const PsicoStudentSettingsScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    this.year,
    this.division,
    this.settings,
  });

  @override
  State<PsicoStudentSettingsScreen> createState() =>
      _PsicoStudentSettingsScreenState();
}

class _PsicoStudentSettingsScreenState
    extends State<PsicoStudentSettingsScreen> {
  final _service = StudentSettingsService();
  late StudentSettings _settings;
  String? _year;
  String? _division;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings ?? StudentSettings(studentId: widget.studentId);
    // Solo aceptamos valores que existan en las listas fijas
    _year = Courses.years.contains(widget.year) ? widget.year : null;
    _division =
        Courses.divisions.contains(widget.division) ? widget.division : null;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _service.saveSettings(
        settings: _settings,
        year: _year,
        division: _division,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil del alumno guardado')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accessibility = Provider.of<AccessibilityProvider>(context);
    final primaryColor = accessibility.activePrimaryColor;
    final onPrimary =
        accessibility.isHighContrast ? Colors.black : Colors.white;

    Widget section(String title, IconData icon, List<Widget> children) {
      return Card(
        margin: const EdgeInsets.only(bottom: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: primaryColor.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: Icon(icon, color: primaryColor),
                title: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
              ...children,
            ],
          ),
        ),
      );
    }

    Widget condition({
      required String title,
      required String description,
      required bool value,
      required ValueChanged<bool> onChanged,
    }) {
      return SwitchListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(description, style: const TextStyle(fontSize: 12)),
        value: value,
        activeThumbColor: primaryColor,
        onChanged: (v) => setState(() => onChanged(v)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor:
            accessibility.isHighContrast ? Colors.black : primaryColor,
        foregroundColor:
            accessibility.isHighContrast ? Colors.yellowAccent : Colors.white,
        title: Text('Perfil de ${widget.studentName}',
            overflow: TextOverflow.ellipsis),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          section('Curso', Icons.groups_rounded, [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _year,
                      decoration: const InputDecoration(
                        labelText: 'Año',
                        border: OutlineInputBorder(),
                      ),
                      items: Courses.years
                          .map(
                              (y) => DropdownMenuItem(value: y, child: Text(y)))
                          .toList(),
                      onChanged: (v) => setState(() => _year = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _division,
                      decoration: const InputDecoration(
                        labelText: 'División',
                        border: OutlineInputBorder(),
                      ),
                      items: Courses.divisions
                          .map(
                              (d) => DropdownMenuItem(value: d, child: Text(d)))
                          .toList(),
                      onChanged: (v) => setState(() => _division = v),
                    ),
                  ),
                ],
              ),
            ),
          ]),
          section('Condiciones y trastornos del aprendizaje',
              Icons.psychology_alt_rounded, [
            condition(
              title: 'TEA (Trastorno del Espectro Autista)',
              description:
                  'Respuestas directas, literales y en pasos numerados.',
              value: _settings.teaMode,
              onChanged: (v) => _settings = _settings.copyWith(teaMode: v),
            ),
            condition(
              title: 'TDAH',
              description:
                  'Modo foco: menos distracciones y tareas en bloques cortos.',
              value: _settings.adhd,
              onChanged: (v) => _settings = _settings.copyWith(adhd: v),
            ),
            condition(
              title: 'Dislexia',
              description:
                  'Dificultad para leer con precisión y fluidez y relacionar letras con sonidos.',
              value: _settings.dyslexia,
              onChanged: (v) => _settings = _settings.copyWith(dyslexia: v),
            ),
            condition(
              title: 'Disgrafía',
              description:
                  'Dificultad para escribir de forma clara y organizada (trazado, tamaño, espaciado).',
              value: _settings.dysgraphia,
              onChanged: (v) => _settings = _settings.copyWith(dysgraphia: v),
            ),
            condition(
              title: 'Disortografía',
              description:
                  'Dificultad para escribir las palabras correctamente y aplicar reglas ortográficas.',
              value: _settings.dysorthography,
              onChanged: (v) =>
                  _settings = _settings.copyWith(dysorthography: v),
            ),
            condition(
              title: 'Discalculia',
              description:
                  'Dificultad para comprender números, cantidades y operaciones.',
              value: _settings.dyscalculia,
              onChanged: (v) => _settings = _settings.copyWith(dyscalculia: v),
            ),
          ]),
          section('Daltonismo', Icons.palette_outlined, [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: DropdownButtonFormField<ColorBlindType>(
                initialValue: _settings.colorBlindness,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Tipo de daltonismo',
                  border: OutlineInputBorder(),
                ),
                items: ColorBlindType.values
                    .map(
                        (t) => DropdownMenuItem(value: t, child: Text(t.label)))
                    .toList(),
                onChanged: (t) => setState(() => _settings = _settings.copyWith(
                    colorBlindness: t ?? ColorBlindType.none)),
              ),
            ),
            if (_settings.colorBlindness != ColorBlindType.none)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  _settings.colorBlindness.description,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
          ]),
          section('Apoyos', Icons.accessibility_new_rounded, [
            condition(
              title: 'Intérprete de Lengua de Señas (LSA)',
              description: 'Muestra el intérprete en las respuestas del tutor.',
              value: _settings.signLanguage,
              onChanged: (v) => _settings = _settings.copyWith(signLanguage: v),
            ),
            condition(
              title: 'Lectura automática en voz alta',
              description: 'El tutor lee sus respuestas en voz alta.',
              value: _settings.autoRead,
              onChanged: (v) => _settings = _settings.copyWith(autoRead: v),
            ),
            condition(
              title: 'Alto contraste',
              description: 'Fondo oscuro y colores brillantes.',
              value: _settings.highContrast,
              onChanged: (v) => _settings = _settings.copyWith(highContrast: v),
            ),
            ListTile(
              title: Text(
                  'Tamaño de letra: ${_settings.fontSize.toStringAsFixed(0)}'),
              subtitle: Slider(
                value: _settings.fontSize.clamp(12.0, 28.0),
                min: 12,
                max: 28,
                divisions: 16,
                activeColor: primaryColor,
                onChanged: (v) =>
                    setState(() => _settings = _settings.copyWith(fontSize: v)),
              ),
            ),
            ListTile(
              title: Text(
                  'Velocidad de lectura: ${_settings.speechRate.toStringAsFixed(1)}'),
              subtitle: Slider(
                value: _settings.speechRate.clamp(0.1, 1.0),
                min: 0.1,
                max: 1.0,
                divisions: 9,
                activeColor: primaryColor,
                onChanged: (v) => setState(
                    () => _settings = _settings.copyWith(speechRate: v)),
              ),
            ),
          ]),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _save,
        backgroundColor: primaryColor,
        foregroundColor: onPrimary,
        icon: _saving
            ? SizedBox(
                width: 20,
                height: 20,
                child:
                    CircularProgressIndicator(strokeWidth: 2, color: onPrimary),
              )
            : const Icon(Icons.save_rounded),
        label: const Text('Guardar perfil'),
      ),
    );
  }
}
