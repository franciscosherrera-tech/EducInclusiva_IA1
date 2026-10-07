import 'package:flutter/material.dart';

class Subject {
  final String id;
  final String teacherId;
  final String name;
  final String description;
  final String year;
  final String division;
  final int iconCode;
  final int colorValue;

  Subject({
    required this.id,
    this.teacherId = '',
    required this.name,
    this.description = '',
    this.year = '',
    this.division = '',
    required this.iconCode,
    required this.colorValue,
  });

  IconData get icon => IconData(iconCode, fontFamily: 'MaterialIcons');
  Color get color => Color(colorValue);

  factory Subject.fromMap(Map<String, dynamic> map) {
    return Subject(
      id: map['id']?.toString() ?? '',
      teacherId: map['teacher_id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      year: map['year']?.toString() ?? '',
      division: map['division']?.toString() ?? '',
      iconCode: map['icon_code'] ?? map['iconCode'] ?? 57415,
      colorValue: map['color_value'] ?? map['colorValue'] ?? 0xFF2196F3,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'teacher_id': teacherId,
      'name': name,
      'description': description,
      'year': year,
      'division': division,
      'icon_code': iconCode,
      'color_value': colorValue,
    };
  }

  factory Subject.fromJson(Map<String, dynamic> json) => Subject.fromMap(json);
  Map<String, dynamic> toJson() => toMap();
}
