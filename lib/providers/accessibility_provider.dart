import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  Color get customColor => _customColor;
  ThemeMode get themeMode => _themeMode;

  // Color principal activo según prioridades de accesibilidad
  Color get activePrimaryColor {
    if (_isHighContrast) return Colors.yellowAccent;
    if (_isColorBlindMode) return Colors.blue.shade700;
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
