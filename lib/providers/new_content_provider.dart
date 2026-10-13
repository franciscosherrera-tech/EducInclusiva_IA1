import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/subject.dart';

/// Avisa al alumno cuando un docente sube contenido nuevo en sus materias.
/// "Nuevo" = un contenido que el alumno todavía no vio al entrar a la materia.
/// Mientras la app está abierta, se actualiza sola (Supabase Realtime).
class NewContentProvider extends ChangeNotifier {
  List<Subject> _subjects = [];
  final Map<String, String> _titleById = {};
  final Map<String, String> _subjectById = {};
  Set<String> _newIds = {};
  RealtimeChannel? _channel;

  /// Último contenido que llegó en vivo, para mostrar un aviso breve.
  String? latestTitle;

  Set<String> get newIds => _newIds;
  int get totalNew => _newIds.length;

  int newCountFor(String subjectId) =>
      _newIds.where((id) => _subjectById[id] == subjectId).length;

  bool isNew(String materialId) => _newIds.contains(materialId);

  List<String> newTitles({int max = 3}) => _newIds
      .map((id) => _titleById[id] ?? '')
      .where((t) => t.isNotEmpty)
      .take(max)
      .toList();

  String? get _uid {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  String get _seenKey => 'seen_materials_${_uid ?? 'guest'}';

  /// Vuelve a calcular qué contenidos son nuevos para las materias del curso.
  Future<void> refresh(List<Subject> courseSubjects) async {
    _subjects = courseSubjects;
    _subscribe();

    if (courseSubjects.isEmpty) {
      _newIds = {};
      notifyListeners();
      return;
    }

    try {
      final rows = List<Map<String, dynamic>>.from(await Supabase
          .instance.client
          .from('study_materials')
          .select('id, subject_id, title')
          .inFilter('subject_id', courseSubjects.map((s) => s.id).toList()));

      _titleById.clear();
      _subjectById.clear();
      for (final r in rows) {
        _titleById[r['id'].toString()] = (r['title'] ?? '').toString();
        _subjectById[r['id'].toString()] = r['subject_id'].toString();
      }

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_seenKey);
      if (stored == null) {
        // Primera vez en este teléfono: lo que ya existe no cuenta como nuevo
        await prefs.setStringList(_seenKey, _titleById.keys.toList());
        _newIds = {};
      } else {
        _newIds = _titleById.keys.toSet().difference(stored.toSet());
      }
      notifyListeners();
    } catch (e) {
      debugPrint('No se pudo calcular el contenido nuevo: $e');
    }
  }

  /// Marca como vistos estos contenidos (al abrir la materia).
  Future<void> markSeen(Iterable<String> materialIds) async {
    final ids = materialIds.toSet();
    if (ids.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final seen = (prefs.getStringList(_seenKey) ?? []).toSet()..addAll(ids);
    await prefs.setStringList(_seenKey, seen.toList());
    _newIds = _newIds.difference(ids);
    notifyListeners();
  }

  void _subscribe() {
    if (_channel != null) return;
    try {
      _channel = Supabase.instance.client
          .channel('new-materials')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'study_materials',
            callback: (payload) {
              final subjectId = payload.newRecord['subject_id']?.toString();
              if (_subjects.any((s) => s.id == subjectId)) {
                latestTitle = payload.newRecord['title']?.toString();
                refresh(_subjects);
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('No se pudo activar el aviso en vivo: $e');
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}
