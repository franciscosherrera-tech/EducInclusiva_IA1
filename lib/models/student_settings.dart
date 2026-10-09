/// Tipos de daltonismo (discromatopsia) según los conos afectados.
enum ColorBlindType {
  none('none', 'Sin daltonismo', ''),
  deuteranomaly('deuteranomaly', 'Deuteranomalía',
      'Rojo-verde leve: los verdes se ven más rojos. Es el tipo más frecuente.'),
  protanomaly('protanomaly', 'Protanomalía',
      'Rojo-verde leve: los rojos se ven más verdes y menos brillantes.'),
  deuteranopia('deuteranopia', 'Deuteranopía',
      'Rojo-verde: no distingue entre el rojo y el verde.'),
  protanopia('protanopia', 'Protanopía',
      'Rojo-verde: faltan los conos rojos, no distingue rojo de verde.'),
  tritanomaly('tritanomaly', 'Tritanomalía',
      'Azul-amarillo: le cuesta diferenciar azul de verde y amarillo de rojo.'),
  tritanopia('tritanopia', 'Tritanopía',
      'Azul-amarillo: no distingue azul/verde, violeta/rojo ni amarillo/rosado.'),
  achromatopsia('achromatopsia', 'Acromatopsia (monocromatismo)',
      'Ve solo en escala de grises, a menudo con sensibilidad a la luz.');

  final String code;
  final String label;
  final String description;

  const ColorBlindType(this.code, this.label, this.description);

  bool get isRedGreen =>
      this == deuteranomaly ||
      this == protanomaly ||
      this == deuteranopia ||
      this == protanopia;

  bool get isBlueYellow => this == tritanomaly || this == tritanopia;

  static ColorBlindType fromCode(String? code) => ColorBlindType.values
      .firstWhere((t) => t.code == code, orElse: () => ColorBlindType.none);
}

/// Perfil de accesibilidad de un alumno (tabla `student_settings`).
/// Lo configura la psicopedagoga; el alumno no puede modificarlo.
class StudentSettings {
  final String studentId;
  final bool teaMode;
  final bool adhd;
  final bool dyslexia;
  final bool dysgraphia;
  final bool dysorthography;
  final bool dyscalculia;
  final ColorBlindType colorBlindness;
  final bool signLanguage;
  final bool autoRead;
  final bool highContrast;
  final double fontSize;
  final double speechRate;

  const StudentSettings({
    required this.studentId,
    this.teaMode = false,
    this.adhd = false,
    this.dyslexia = false,
    this.dysgraphia = false,
    this.dysorthography = false,
    this.dyscalculia = false,
    this.colorBlindness = ColorBlindType.none,
    this.signLanguage = false,
    this.autoRead = false,
    this.highContrast = false,
    this.fontSize = 16.0,
    this.speechRate = 0.5,
  });

  /// Lista corta de las condiciones activas, para mostrar en tablas y filtros.
  List<String> get activeConditions => [
        if (teaMode) 'TEA',
        if (adhd) 'TDAH',
        if (dyslexia) 'Dislexia',
        if (dysgraphia) 'Disgrafía',
        if (dysorthography) 'Disortografía',
        if (dyscalculia) 'Discalculia',
        if (colorBlindness != ColorBlindType.none) 'Daltonismo',
        if (signLanguage) 'Lengua de señas',
      ];

  factory StudentSettings.fromMap(Map<String, dynamic> map) {
    return StudentSettings(
      studentId: map['student_id']?.toString() ?? '',
      teaMode: map['tea_mode'] == true,
      adhd: map['adhd'] == true,
      dyslexia: map['dyslexia'] == true,
      dysgraphia: map['dysgraphia'] == true,
      dysorthography: map['dysorthography'] == true,
      dyscalculia: map['dyscalculia'] == true,
      colorBlindness:
          ColorBlindType.fromCode(map['color_blindness']?.toString()),
      signLanguage: map['sign_language'] == true,
      autoRead: map['auto_read'] == true,
      highContrast: map['high_contrast'] == true,
      fontSize: (map['font_size'] as num?)?.toDouble() ?? 16.0,
      speechRate: (map['speech_rate'] as num?)?.toDouble() ?? 0.5,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'student_id': studentId,
      'tea_mode': teaMode,
      'adhd': adhd,
      'dyslexia': dyslexia,
      'dysgraphia': dysgraphia,
      'dysorthography': dysorthography,
      'dyscalculia': dyscalculia,
      'color_blindness': colorBlindness.code,
      'sign_language': signLanguage,
      'auto_read': autoRead,
      'high_contrast': highContrast,
      'font_size': fontSize,
      'speech_rate': speechRate,
    };
  }

  StudentSettings copyWith({
    bool? teaMode,
    bool? adhd,
    bool? dyslexia,
    bool? dysgraphia,
    bool? dysorthography,
    bool? dyscalculia,
    ColorBlindType? colorBlindness,
    bool? signLanguage,
    bool? autoRead,
    bool? highContrast,
    double? fontSize,
    double? speechRate,
  }) {
    return StudentSettings(
      studentId: studentId,
      teaMode: teaMode ?? this.teaMode,
      adhd: adhd ?? this.adhd,
      dyslexia: dyslexia ?? this.dyslexia,
      dysgraphia: dysgraphia ?? this.dysgraphia,
      dysorthography: dysorthography ?? this.dysorthography,
      dyscalculia: dyscalculia ?? this.dyscalculia,
      colorBlindness: colorBlindness ?? this.colorBlindness,
      signLanguage: signLanguage ?? this.signLanguage,
      autoRead: autoRead ?? this.autoRead,
      highContrast: highContrast ?? this.highContrast,
      fontSize: fontSize ?? this.fontSize,
      speechRate: speechRate ?? this.speechRate,
    );
  }
}
