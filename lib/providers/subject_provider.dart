import 'package:flutter/material.dart';
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

      // Imprime en la consola de VS Code para ver la respuesta exacta
      debugPrint('>>> MATERIAS DESDE SUPABASE: $response');

      final List<dynamic> data = response as List<dynamic>;
      _subjects = data.map((json) => Subject.fromMap(json)).toList();
      debugPrint('>>> MATERIAS CARGADAS EN MEMORIA: ${_subjects.length}');
    } catch (e, stackTrace) {
      debugPrint('❌ ERROR AL CARGAR MATERIAS: $e');
      debugPrint('$stackTrace');
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
