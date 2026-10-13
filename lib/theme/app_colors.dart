import 'package:flutter/material.dart';

class AppColors {
  static const Color darkBlue = Color(0xFF2C466C); // Azul Oscuro / Texto
  static const Color lavender = Color(0xFFC7A2F6); // Púrpura / Lavanda Pastel
  static const Color mint = Color(0xFF79E3C5); // Verde Menta / Turquesa
  static const Color lightBlue = Color(0xFF84DCF2); // Azul Celeste Pastel
  static const Color periwinkle = Color(0xFF9193EB); // Azul Violeta
  static const Color warmYellow =
      Color(0xFFFAD284); // Amarillo Cálido / Durazno
  static const Color background = Color(0xFFF8F7F3); // Fondo Perla / Off-White

  /// Colores que el usuario puede elegir como color principal. Todos tienen
  /// buen contraste con texto blanco (barras, botones).
  static const List<Color> themePalette = [
    darkBlue,
    Color(0xFF0277BD), // azul
    Color(0xFF5B5FC7), // índigo
    Color(0xFF8E5BD0), // violeta
    Color(0xFFC2477A), // rosa
    Color(0xFFD2562F), // coral
    Color(0xFFB7791F), // ámbar
    Color(0xFF2E8B57), // verde
    Color(0xFF00897B), // verde azulado
  ];

  /// Paleta para usuarios con daltonismo (basada en Okabe-Ito): colores que se
  /// distinguen entre sí aun con dificultades para ver el rojo, verde o azul.
  static const List<Color> colorBlindSafePalette = [
    Color(0xFF0072B2), // azul
    Color(0xFF007F5F), // verde azulado
    Color(0xFFD55E00), // bermellón
    Color(0xFFB36B00), // naranja oscuro
    Color(0xFFA8537F), // púrpura rojizo
    darkBlue,
  ];
}
