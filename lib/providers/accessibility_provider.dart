import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/student_settings.dart';
import '../services/student_settings_service.dart';
import '../theme/app_colors.dart';

class AccessibilityProvider extends ChangeNotifier {
  double _fontSize = 16.0;
  bool _isTeaMode = false;
  bool _autoReadText = false;
  bool _isSignLanguageEnabled = false;

  bool _isHighContrast = false;
  bool _isDyslexicFriendly = false;
  double _speechRate = 0.5;

  bool _isColorBlindMode = false;
  bool _isFocusMode = false;

  // Condiciones específicas que configura la psicopedagoga
  bool _hasDysgraphia = false;
  bool _hasDysorthography = false;
  bool _hasDyscalculia = false;
  ColorBlindType _colorBlindType = ColorBlindType.none;

  Color _customColor = AppColors.darkBlue;
  ThemeMode _themeMode = ThemeMode.system;

  // Getters
  double get fontSize => _fontSize;
  bool get isTeaMode => _isTeaMode;
  bool get autoReadText => _autoReadText;
  bool get isSignLanguageEnabled => _isSignLanguageEnabled;
  bool get isHighContrast => _isHighContrast;
  bool get isDyslexicFriendly => _isDyslexicFriendly;
  double get speechRate => _speechRate;
  bool get isColorBlindMode => _isColorBlindMode;
  bool get isFocusMode => _isFocusMode;
  bool get hasDysgraphia => _hasDysgraphia;
  bool get hasDysorthography => _hasDysorthography;
  bool get hasDyscalculia => _hasDyscalculia;
  ColorBlindType get colorBlindType => _colorBlindType;
  Color get customColor => _customColor;
  ThemeMode get themeMode => _themeMode;

  // Color principal activo según prioridades de accesibilidad
  Color get activePrimaryColor {
    if (_isHighContrast) return Colors.yellowAccent;
    if (_isColorBlindMode) {
      // Rojo-verde: el azul se distingue bien. Azul-amarillo: usamos un rosa
      // intenso, que contrasta con los tonos que se confunden.
      if (_colorBlindType.isBlueYellow) return const Color(0xFFC2185B);
      return Colors.blue.shade700;
    }
    return _customColor;
  }

  AccessibilityProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _fontSize = prefs.getDouble('fontSize') ?? 16.0;
    _isTeaMode = prefs.getBool('isTeaMode') ?? false;
    _autoReadText = prefs.getBool('autoReadText') ?? false;
    _isSignLanguageEnabled = prefs.getBool('isSignLanguageEnabled') ?? false;
    _isHighContrast = prefs.getBool('isHighContrast') ?? false;
    _isDyslexicFriendly = prefs.getBool('isDyslexicFriendly') ?? false;
    _speechRate = prefs.getDouble('speechRate') ?? 0.5;
    _isColorBlindMode = prefs.getBool('isColorBlindMode') ?? false;
    _isFocusMode = prefs.getBool('isFocusMode') ?? false;
    _hasDysgraphia = prefs.getBool('hasDysgraphia') ?? false;
    _hasDysorthography = prefs.getBool('hasDysorthography') ?? false;
    _hasDyscalculia = prefs.getBool('hasDyscalculia') ?? false;
    _colorBlindType =
        ColorBlindType.fromCode(prefs.getString('colorBlindType'));

    final savedColor = prefs.getInt('customColor');
    if (savedColor != null) {
      _customColor = Color(savedColor);
    }

    final savedThemeIndex = prefs.getInt('themeMode');
    if (savedThemeIndex != null) {
      _themeMode = ThemeMode.values[savedThemeIndex];
    }

    notifyListeners();
  }

  void setCustomColor(Color color) async {
    _customColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('customColor', color.value);
  }

  void setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('themeMode', mode.index);
  }

  void setFontSize(double size) async {
    _fontSize = size;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble('fontSize', size);
  }

  void toggleTeaMode(bool value) async {
    _isTeaMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('isTeaMode', value);
  }

  void toggleAutoRead(bool value) async {
    _autoReadText = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('autoReadText', value);
  }

  void toggleAutoReadText(bool value) => toggleAutoRead(value);

  void toggleSignLanguage(bool value) async {
    _isSignLanguageEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('isSignLanguageEnabled', value);
  }

  void toggleHighContrast(bool value) async {
    _isHighContrast = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('isHighContrast', value);
  }

  void toggleDyslexicFriendly(bool value) async {
    _isDyslexicFriendly = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('isDyslexicFriendly', value);
  }

  void setSpeechRate(double rate) async {
    _speechRate = rate;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble('speechRate', rate);
  }

  void toggleColorBlindMode(bool value) async {
    _isColorBlindMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('isColorBlindMode', value);
  }

  void toggleFocusMode(bool value) async {
    _isFocusMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('isFocusMode', value);
  }

  /// Trae el perfil que cargó la psicopedagoga para el alumno logueado y lo
  /// aplica. Si todavía no tiene perfil, se mantienen los ajustes locales.
  Future<void> loadStudentSettings() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final settings = await StudentSettingsService().getSettings(user.id);
      if (settings != null) await applyStudentSettings(settings);
    } catch (e) {
      debugPrint('Error al cargar el perfil de accesibilidad: $e');
    }
  }

  Future<void> applyStudentSettings(StudentSettings s) async {
    _isTeaMode = s.teaMode;
    _isFocusMode = s.adhd;
    _isDyslexicFriendly = s.dyslexia;
    _hasDysgraphia = s.dysgraphia;
    _hasDysorthography = s.dysorthography;
    _hasDyscalculia = s.dyscalculia;
    _colorBlindType = s.colorBlindness;
    _isColorBlindMode = s.colorBlindness != ColorBlindType.none;
    _isSignLanguageEnabled = s.signLanguage;
    _autoReadText = s.autoRead;
    // Con acromatopsia el color no aporta información: forzamos alto contraste.
    _isHighContrast =
        s.highContrast || s.colorBlindness == ColorBlindType.achromatopsia;
    _fontSize = s.fontSize;
    _speechRate = s.speechRate;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isTeaMode', _isTeaMode);
    await prefs.setBool('isFocusMode', _isFocusMode);
    await prefs.setBool('isDyslexicFriendly', _isDyslexicFriendly);
    await prefs.setBool('hasDysgraphia', _hasDysgraphia);
    await prefs.setBool('hasDysorthography', _hasDysorthography);
    await prefs.setBool('hasDyscalculia', _hasDyscalculia);
    await prefs.setString('colorBlindType', _colorBlindType.code);
    await prefs.setBool('isColorBlindMode', _isColorBlindMode);
    await prefs.setBool('isSignLanguageEnabled', _isSignLanguageEnabled);
    await prefs.setBool('autoReadText', _autoReadText);
    await prefs.setBool('isHighContrast', _isHighContrast);
    await prefs.setDouble('fontSize', _fontSize);
    await prefs.setDouble('speechRate', _speechRate);
  }

  /// Indicaciones extra para el Tutor IA según el perfil del alumno.
  String get aiProfileInstructions {
    final lines = <String>[
      if (_isFocusMode)
        'TDAH: respuestas cortas y en bloques pequeños, una sola tarea por vez, '
            'con una pregunta final para mantener la atención.',
      if (_isDyslexicFriendly)
        'DISLEXIA: frases cortas, palabras simples y frecuentes, párrafos de 2 '
            'líneas como máximo. Resalta en negrita solo las palabras clave.',
      if (_hasDysgraphia)
        'DISGRAFÍA: no le pidas respuestas escritas largas. Ofrece opciones para '
            'elegir, completar o responder con pocas palabras o por voz.',
      if (_hasDysorthography)
        'DISORTOGRAFÍA: interpreta lo que quiso escribir aunque tenga errores. '
            'No lo corrijas ni lo marques; si hace falta, muestra la palabra '
            'bien escrita de forma natural.',
      if (_hasDyscalculia)
        'DISCALCULIA: explica la matemática paso a paso, una operación por línea, '
            'con ejemplos concretos y cotidianos (dinero, objetos) y números chicos '
            'antes de generalizar.',
      if (_isColorBlindMode)
        'DALTONISMO: nunca uses el color como única forma de diferenciar '
            'información; usa etiquetas, símbolos o palabras.',
    ];
    return lines.join('\n');
  }

  TextStyle getTextStyle({
    double? overrideSize,
    Color? color,
    FontWeight? fontWeight,
  }) {
    return TextStyle(
      fontSize: overrideSize ?? _fontSize,
      color: color,
      fontWeight: fontWeight ??
          (_isDyslexicFriendly ? FontWeight.w600 : FontWeight.normal),
      letterSpacing: _isDyslexicFriendly ? 1.2 : 0.0,
      wordSpacing: _isDyslexicFriendly ? 2.0 : 0.0,
      height: _isDyslexicFriendly ? 1.5 : 1.2,
    );
  }
}
