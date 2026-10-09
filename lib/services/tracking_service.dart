import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/material_model.dart';
import '../models/subject.dart';

/// Chat de un alumno con sus estadísticas de uso.
class ChatSummary {
  final String id;
  final String subjectId;
  final String subjectName;
  final int studentMessages;
  final int aiMessages;
  final DateTime? lastActivity;

  ChatSummary({
    required this.id,
    required this.subjectId,
    required this.subjectName,
    required this.studentMessages,
    required this.aiMessages,
    required this.lastActivity,
  });
}

/// Una materia del curso del alumno, con lo que subió el profe y su chat.
class SubjectTracking {
  final Subject subject;
  final String teacherName;
  final List<StudyMaterial> materials;
  final ChatSummary? chat;

  SubjectTracking({
    required this.subject,
    required this.teacherName,
    required this.materials,
    required this.chat,
  });
}

class StudentTracking {
  final List<SubjectTracking> subjects;
  final List<ChatSummary> chats;

  StudentTracking({required this.subjects, required this.chats});

  int get totalMaterials =>
      subjects.fold(0, (sum, s) => sum + s.materials.length);
  int get totalStudentMessages =>
      chats.fold(0, (sum, c) => sum + c.studentMessages);

  DateTime? get lastActivity {
    final dates = chats.map((c) => c.lastActivity).whereType<DateTime>();
    if (dates.isEmpty) return null;
    return dates.reduce((a, b) => a.isAfter(b) ? a : b);
  }
}

/// Material subido por un docente, con su materia y autor (vista psico).
class MaterialEntry {
  final StudyMaterial material;
  final Subject? subject;
  final String teacherName;

  MaterialEntry({
    required this.material,
    required this.subject,
    required this.teacherName,
  });

  String get course =>
      subject == null ? '' : '${subject!.year} ${subject!.division}'.trim();
}

class TrackingService {
  static const String generalChatId = '00000000-0000-0000-0000-000000000000';

  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, String>> _profileNames(Iterable<String> ids) async {
    final unique = ids.where((id) => id.isNotEmpty).toSet().toList();
    if (unique.isEmpty) return {};
    final data = await _supabase
        .from('profiles')
        .select('id, name')
        .inFilter('id', unique);
    return {
      for (final p in List<Map<String, dynamic>>.from(data))
        p['id'].toString(): (p['name'] ?? 'Sin nombre').toString(),
    };
  }

  Future<List<Subject>> _allSubjects() async {
    final data = await _supabase.from('subjects').select();
    return List<Map<String, dynamic>>.from(data).map(Subject.fromMap).toList();
  }

  String _subjectName(String subjectId, Map<String, Subject> subjectsById) {
    if (subjectId == generalChatId || subjectId == 'general') {
      return 'Chat General';
    }
    return subjectsById[subjectId]?.name ?? 'Materia anterior ($subjectId)';
  }

  /// Todo lo necesario para el seguimiento de un alumno.
  Future<StudentTracking> loadStudent({
    required String studentId,
    required String? year,
    required String? division,
  }) async {
    final subjects = await _allSubjects();
    final subjectsById = {for (final s in subjects) s.id: s};

    // --- Chats del alumno y conteo de mensajes ---
    final chatRows = List<Map<String, dynamic>>.from(await _supabase
        .from('chats')
        .select('id, subject_id, updated_at')
        .eq('user_id', studentId)
        .order('updated_at', ascending: false));

    final chatIds = chatRows.map((c) => c['id'].toString()).toList();
    final messageRows = chatIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(await _supabase
            .from('messages')
            .select('chat_id, sender, created_at')
            .inFilter('chat_id', chatIds));

    final chats = chatRows.map((c) {
      final id = c['id'].toString();
      final msgs = messageRows.where((m) => m['chat_id'].toString() == id);
      final dates = msgs
          .map((m) => DateTime.tryParse(m['created_at']?.toString() ?? ''))
          .whereType<DateTime>();
      final subjectId = c['subject_id']?.toString() ?? '';
      return ChatSummary(
        id: id,
        subjectId: subjectId,
        subjectName: _subjectName(subjectId, subjectsById),
        studentMessages: msgs.where((m) => m['sender'] == 'user').length,
        aiMessages: msgs.where((m) => m['sender'] == 'ai').length,
        lastActivity: dates.isEmpty
            ? DateTime.tryParse(c['updated_at']?.toString() ?? '')
            : dates.reduce((a, b) => a.isAfter(b) ? a : b),
      );
    }).toList();

    // --- Materias del curso y lo que subió cada profe ---
    final courseSubjects = subjects
        .where((s) => s.year == year && s.division == division)
        .toList();
    final courseIds = courseSubjects.map((s) => s.id).toList();

    final materials = courseIds.isEmpty
        ? <StudyMaterial>[]
        : List<Map<String, dynamic>>.from(await _supabase
                .from('study_materials')
                .select()
                .inFilter('subject_id', courseIds)
                .order('created_at', ascending: false))
            .map(StudyMaterial.fromMap)
            .toList();

    final teachers =
        await _profileNames(courseSubjects.map((s) => s.teacherId));

    final subjectTracking = courseSubjects.map((s) {
      final chat = chats.where((c) => c.subjectId == s.id);
      return SubjectTracking(
        subject: s,
        teacherName: teachers[s.teacherId] ?? 'Sin docente',
        materials: materials.where((m) => m.subjectId == s.id).toList(),
        chat: chat.isEmpty ? null : chat.first,
      );
    }).toList();

    return StudentTracking(subjects: subjectTracking, chats: chats);
  }

  /// Todos los materiales subidos por los docentes, del más nuevo al más viejo.
  Future<List<MaterialEntry>> loadAllMaterials() async {
    final subjects = await _allSubjects();
    final subjectsById = {for (final s in subjects) s.id: s};

    final materials = List<Map<String, dynamic>>.from(await _supabase
            .from('study_materials')
            .select()
            .order('created_at', ascending: false))
        .map(StudyMaterial.fromMap)
        .toList();

    final teachers = await _profileNames(materials.map((m) => m.uploadedBy));

    return materials
        .map((m) => MaterialEntry(
              material: m,
              subject: subjectsById[m.subjectId],
              teacherName: teachers[m.uploadedBy] ?? 'Docente',
            ))
        .toList();
  }
}
