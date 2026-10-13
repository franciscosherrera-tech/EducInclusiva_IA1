import 'package:flutter/foundation.dart';
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

/// Qué hizo el alumno con un contenido puntual.
class MaterialStats {
  int downloads = 0;
  int aiQuestions = 0;
  DateTime? last;

  bool get used => downloads > 0 || aiQuestions > 0;
}

class StudentTracking {
  final List<SubjectTracking> subjects;
  final List<ChatSummary> chats;

  /// Actividad por id de material. Vacío si todavía no hay registros.
  final Map<String, MaterialStats> activity;

  /// Actividad diaria de los últimos 28 días (del más viejo al más nuevo).
  final List<DayActivity> days;

  StudentTracking({
    required this.subjects,
    required this.chats,
    this.activity = const {},
    this.days = const [],
  });

  MaterialStats statsOf(String materialId) =>
      activity[materialId] ?? MaterialStats();

  int get totalMaterials =>
      subjects.fold(0, (sum, s) => sum + s.materials.length);
  int get materialsUsed => subjects.fold(
      0, (sum, s) => sum + s.materials.where((m) => statsOf(m.id).used).length);
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

    // --- Descargas y consultas a la IA sobre cada contenido ---
    final activity = <String, MaterialStats>{};
    final materialDates = <DateTime>[];
    try {
      final rows = List<Map<String, dynamic>>.from(await _supabase
          .from('material_activity')
          .select('material_id, action, created_at')
          .eq('student_id', studentId));
      for (final r in rows) {
        final stats = activity.putIfAbsent(
            r['material_id'].toString(), MaterialStats.new);
        if (r['action'] == 'download') stats.downloads++;
        if (r['action'] == 'ask_ai') stats.aiQuestions++;
        final date = DateTime.tryParse(r['created_at']?.toString() ?? '');
        if (date != null) materialDates.add(date);
        if (date != null && (stats.last == null || date.isAfter(stats.last!))) {
          stats.last = date;
        }
      }
    } catch (e) {
      // La tabla puede no existir todavía (falta correr actividad_y_permisos.sql)
      debugPrint('No se pudo leer la actividad de materiales: $e');
    }

    final messageDates = messageRows
        .where((m) => m['sender'] == 'user')
        .map((m) => DateTime.tryParse(m['created_at']?.toString() ?? ''))
        .whereType<DateTime>()
        .toList();

    return StudentTracking(
      subjects: subjectTracking,
      chats: chats,
      activity: activity,
      days: buildDailyActivity(
        messageDates: messageDates,
        materialDates: materialDates,
      ),
    );
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

/// Actividad de un día: mensajes al tutor y acciones sobre contenidos.
class DayActivity {
  final DateTime day;
  final int messages;
  final int materials;

  const DayActivity({
    required this.day,
    required this.messages,
    required this.materials,
  });

  int get total => messages + materials;
}

/// Agrupa la actividad por día, de los últimos [days] días terminando hoy
/// (del más viejo al más nuevo). Los días sin actividad quedan en cero.
List<DayActivity> buildDailyActivity({
  required List<DateTime> messageDates,
  required List<DateTime> materialDates,
  DateTime? now,
  int days = 28,
}) {
  final today = (now ?? DateTime.now()).toLocal();
  final start = DateTime(today.year, today.month, today.day)
      .subtract(Duration(days: days - 1));

  DateTime dayOf(DateTime d) {
    final l = d.toLocal();
    return DateTime(l.year, l.month, l.day);
  }

  final messages = <DateTime, int>{};
  final materials = <DateTime, int>{};
  for (final d in messageDates) {
    messages.update(dayOf(d), (v) => v + 1, ifAbsent: () => 1);
  }
  for (final d in materialDates) {
    materials.update(dayOf(d), (v) => v + 1, ifAbsent: () => 1);
  }

  return List.generate(days, (i) {
    final day = DateTime(start.year, start.month, start.day + i);
    return DayActivity(
      day: day,
      messages: messages[day] ?? 0,
      materials: materials[day] ?? 0,
    );
  });
}
