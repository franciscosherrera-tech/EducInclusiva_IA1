import 'package:eduinclusiva_ia/constants/courses.dart';
import 'package:eduinclusiva_ia/models/student_settings.dart';
import 'package:eduinclusiva_ia/models/subject.dart';
import 'package:eduinclusiva_ia/providers/accessibility_provider.dart';
import 'package:eduinclusiva_ia/services/tracking_service.dart';
import 'package:eduinclusiva_ia/theme/app_colors.dart';
import 'package:eduinclusiva_ia/theme/app_theme.dart';
import 'package:eduinclusiva_ia/utils/course_grouping.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Subject _subject(String name, String year, String division) => Subject(
      id: name,
      name: name,
      year: year,
      division: division,
      iconCode: 0xe318,
      colorValue: 0xFF2C466C,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Cursos', () {
    test('solo hay 1° a 3° y 1ra a 3ra', () {
      expect(Courses.years, ['1°', '2°', '3°']);
      expect(Courses.divisions, ['1ra', '2da', '3ra']);
    });

    test('groupByCourse agrupa y ordena por año y división', () {
      final groups = groupByCourse([
        _subject('Historia', '3°', '1ra'),
        _subject('Matemática', '1°', '2da'),
        _subject('Lengua', '1°', '2da'),
        _subject('Arte', '', ''),
      ]);

      expect(groups.keys.toList(), ['1° 2da', '3° 1ra', 'Sin curso asignado']);
      expect(groups['1° 2da']!.map((s) => s.name), ['Matemática', 'Lengua']);
    });
  });

  group('Subject', () {
    test('fromMap lee los campos de Supabase y usa valores por defecto', () {
      final s = Subject.fromMap({
        'id': 'abc',
        'teacher_id': 't1',
        'name': 'Matemáticas',
        'year': '1°',
        'division': '2da',
      });

      expect(s.id, 'abc');
      expect(s.teacherId, 't1');
      expect(s.description, '');
      expect(s.colorValue, 0xFF2196F3);
      expect(s.toMap()['teacher_id'], 't1');
    });
  });

  group('StudentSettings', () {
    test('ida y vuelta por toMap/fromMap', () {
      const original = StudentSettings(
        studentId: 'u1',
        teaMode: true,
        dyslexia: true,
        colorBlindness: ColorBlindType.deuteranopia,
        fontSize: 22,
      );

      final copy = StudentSettings.fromMap(original.toMap());

      expect(copy.teaMode, isTrue);
      expect(copy.dyslexia, isTrue);
      expect(copy.dysgraphia, isFalse);
      expect(copy.colorBlindness, ColorBlindType.deuteranopia);
      expect(copy.fontSize, 22);
    });

    test('activeConditions lista solo las condiciones activas', () {
      const s = StudentSettings(
        studentId: 'u1',
        adhd: true,
        dyscalculia: true,
        colorBlindness: ColorBlindType.tritanopia,
      );

      expect(s.activeConditions, ['TDAH', 'Discalculia', 'Daltonismo']);
    });

    test('tipos de daltonismo: familia y código desconocido', () {
      expect(ColorBlindType.protanopia.isRedGreen, isTrue);
      expect(ColorBlindType.tritanomaly.isBlueYellow, isTrue);
      expect(ColorBlindType.fromCode('nada'), ColorBlindType.none);
    });
  });

  group('AccessibilityProvider', () {
    test('aplicar el perfil de la psico activa los modos y guía a la IA',
        () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final provider = await _ready();

      await provider.applyStudentSettings(const StudentSettings(
        studentId: 'u1',
        dyslexia: true,
        dyscalculia: true,
        colorBlindness: ColorBlindType.achromatopsia,
      ));

      expect(provider.isDyslexicFriendly, isTrue);
      expect(provider.isColorBlindMode, isTrue);
      // La acromatopsia fuerza alto contraste
      expect(provider.isHighContrast, isTrue);
      expect(provider.aiProfileInstructions, contains('DISLEXIA'));
      expect(provider.aiProfileInstructions, contains('DISCALCULIA'));
      expect(provider.aiProfileInstructions, isNot(contains('TDAH')));
    });

    test('sin perfil, la IA no recibe instrucciones extra', () {
      TestWidgetsFlutterBinding.ensureInitialized();
      expect(AccessibilityProvider().aiProfileInstructions, isEmpty);
    });

    test('con daltonismo solo se ofrece la paleta segura', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final provider = await _ready();

      expect(provider.availableColors, AppColors.themePalette);

      await provider.applyStudentSettings(const StudentSettings(
        studentId: 'u1',
        colorBlindness: ColorBlindType.protanopia,
      ));

      expect(provider.availableColors, AppColors.colorBlindSafePalette);
    });

    test('el color y el tema elegidos se guardan', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final provider = await _ready();

      provider.setCustomColor(AppColors.themePalette[4]);
      provider.setThemeMode(ThemeMode.dark);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('customColor'), AppColors.themePalette[4].toARGB32());
      expect(prefs.getInt('themeMode'), ThemeMode.dark.index);
    });
  });

  group('AppTheme', () {
    test('aclara los colores muy oscuros en fondo oscuro', () {
      final lightened = AppTheme.forDarkSurface(AppColors.darkBlue);
      expect(HSLColor.fromColor(lightened).lightness, greaterThan(0.45));
    });

    test('no toca los colores que ya se ven bien', () {
      const bright = Color(0xFF5B5FC7);
      expect(AppTheme.forDarkSurface(bright), bright);
    });

    test('los temas usan el color elegido', () {
      const color = Color(0xFFC2477A);
      expect(AppTheme.light(color).colorScheme.primary, color);
      expect(AppTheme.light(color).brightness, Brightness.light);
      expect(AppTheme.dark(color).brightness, Brightness.dark);
    });
  });

  group('buildDailyActivity', () {
    test('cuenta por día y rellena con ceros', () {
      final now = DateTime(2026, 10, 13, 15);
      final days = buildDailyActivity(
        now: now,
        messageDates: [
          DateTime(2026, 10, 13, 9),
          DateTime(2026, 10, 13, 10),
          DateTime(2026, 10, 12, 20),
        ],
        materialDates: [DateTime(2026, 10, 13, 11)],
      );

      expect(days.length, 28);
      expect(days.last.day, DateTime(2026, 10, 13));
      expect(days.last.messages, 2);
      expect(days.last.materials, 1);
      expect(days[days.length - 2].messages, 1);
      expect(days.first.total, 0);
    });

    test('ignora actividad anterior a la ventana', () {
      final days = buildDailyActivity(
        now: DateTime(2026, 10, 13),
        messageDates: [DateTime(2026, 8, 1)],
        materialDates: [],
      );

      expect(days.fold<int>(0, (s, d) => s + d.total), 0);
    });
  });
}

/// Crea el proveedor y espera a que termine su carga inicial desde el teléfono.
Future<AccessibilityProvider> _ready() async {
  final provider = AccessibilityProvider();
  await Future<void>.delayed(const Duration(milliseconds: 50));
  return provider;
}
