import 'package:supabase_flutter/supabase_flutter.dart';

class StudentNote {
  final String id;
  final String body;
  final DateTime createdAt;
  final String authorName;

  StudentNote({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.authorName,
  });
}

/// Notas privadas de la psicopedagoga sobre cada alumno.
class NotesService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<StudentNote>> getNotes(String studentId) async {
    final rows = List<Map<String, dynamic>>.from(await _supabase
        .from('student_notes')
        .select('id, body, created_at, author_id')
        .eq('student_id', studentId)
        .order('created_at', ascending: false));

    final authorIds =
        rows.map((r) => r['author_id'].toString()).toSet().toList();
    final names = <String, String>{};
    if (authorIds.isNotEmpty) {
      final profiles = List<Map<String, dynamic>>.from(await _supabase
          .from('profiles')
          .select('id, name')
          .inFilter('id', authorIds));
      for (final p in profiles) {
        names[p['id'].toString()] = (p['name'] ?? 'Psicopedagoga').toString();
      }
    }

    return rows
        .map((r) => StudentNote(
              id: r['id'].toString(),
              body: r['body'].toString(),
              createdAt: DateTime.parse(r['created_at'].toString()),
              authorName: names[r['author_id'].toString()] ?? 'Psicopedagoga',
            ))
        .toList();
  }

  Future<void> addNote(String studentId, String body) async {
    await _supabase.from('student_notes').insert({
      'student_id': studentId,
      'body': body.trim(),
    });
  }

  Future<void> deleteNote(String noteId) async {
    final deleted = await _supabase
        .from('student_notes')
        .delete()
        .eq('id', noteId)
        .select('id');
    if ((deleted as List).isEmpty) {
      throw Exception('Solo quien escribió la nota puede borrarla.');
    }
  }
}
