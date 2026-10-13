import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/subject.dart';

class SubjectProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  List<Subject> _subjects = [];
  bool _isLoading = false;

  List<Subject> get subjects => _subjects;
  bool get isLoading => _isLoading;

  SubjectProvider() {
    fetchSubjects();
  }

  Future<void> fetchSubjects() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _supabase.from('subjects').select();

      final List<dynamic> data = response as List<dynamic>;
      _subjects = data.map((json) => Subject.fromMap(json)).toList();
      debugPrint('>>> MATERIAS CARGADAS EN MEMORIA: ${_subjects.length}');

      // Copia en el teléfono para poder verlas sin conexión
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('subjects_cache', jsonEncode(data));
    } catch (e) {
      debugPrint('❌ ERROR AL CARGAR MATERIAS (sin conexión?): $e');
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('subjects_cache');
      if (cached != null && _subjects.isEmpty) {
        final List<dynamic> data = jsonDecode(cached) as List<dynamic>;
        _subjects = data.map((json) => Subject.fromMap(json)).toList();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addSubject(Subject subject) async {
    try {
      final user = _supabase.auth.currentUser;
      final map = subject.toMap();

      if (user != null &&
          (map['teacher_id'] == null || map['teacher_id'].toString().isEmpty)) {
        map['teacher_id'] = user.id;
      }

      if (map['id'] == null || map['id'].toString().isEmpty) {
        map.remove('id');
      }

      final response =
          await _supabase.from('subjects').insert(map).select().single();
      final newSubject = Subject.fromMap(response);

      _subjects.add(newSubject);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ ERROR AL AGREGAR MATERIA: $e');
      rethrow;
    }
  }

  /// Cambia nombre, curso, docente o descripción de una materia (uso: psico).
  Future<void> updateSubject(Subject subject) async {
    try {
      final map = subject.toMap()..remove('id');
      final updated = await _supabase
          .from('subjects')
          .update(map)
          .eq('id', subject.id)
          .select()
          .single();
      final index = _subjects.indexWhere((s) => s.id == subject.id);
      if (index >= 0) _subjects[index] = Subject.fromMap(updated);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ ERROR AL ACTUALIZAR MATERIA: $e');
      rethrow;
    }
  }

  Future<void> deleteSubject(String id) async {
    try {
      await _supabase.from('subjects').delete().eq('id', id);
      _subjects.removeWhere((sub) => sub.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('❌ ERROR AL ELIMINAR MATERIA: $e');
      rethrow;
    }
  }
}
