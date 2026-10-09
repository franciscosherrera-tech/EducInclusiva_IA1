import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/student_settings.dart';

class StudentSettingsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Ajustes de un alumno, o null si la psicopedagoga todavía no lo configuró.
  Future<StudentSettings?> getSettings(String studentId) async {
    final data = await _supabase
        .from('student_settings')
        .select()
        .eq('student_id', studentId)
        .maybeSingle();
    return data == null ? null : StudentSettings.fromMap(data);
  }

  /// Ajustes de todos los alumnos, indexados por id (para el panel psico).
  Future<Map<String, StudentSettings>> getAllSettings() async {
    final data = await _supabase.from('student_settings').select();
    return {
      for (final row in List<Map<String, dynamic>>.from(data))
        row['student_id'].toString(): StudentSettings.fromMap(row),
    };
  }

  /// Guarda el perfil de accesibilidad y el curso asignado del alumno.
  Future<void> saveSettings({
    required StudentSettings settings,
    required String? year,
    required String? division,
  }) async {
    final user = _supabase.auth.currentUser;

    await _supabase.from('student_settings').upsert({
      ...settings.toMap(),
      'updated_by': user?.id,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });

    final updated = await _supabase
        .from('profiles')
        .update({'year': year, 'division': division})
        .eq('id', settings.studentId)
        .select('id');

    // Si RLS bloquea el UPDATE, Supabase no da error: solo devuelve 0 filas.
    if ((updated as List).isEmpty) {
      throw Exception(
          'No se pudo guardar el curso del alumno (revisá las políticas de "profiles").');
    }
  }
}
