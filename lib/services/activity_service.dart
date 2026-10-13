import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Acciones del alumno sobre un contenido, para el seguimiento de la psico.
class ActivityAction {
  static const String download = 'download';
  static const String askAi = 'ask_ai';
}

class ActivityService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Registra que el alumno abrió/descargó un contenido o se lo preguntó a la IA.
  /// Nunca interrumpe al alumno: si falla, solo lo deja en la consola.
  Future<void> log({
    required String materialId,
    required String subjectId,
    required String action,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      await _supabase.from('material_activity').insert({
        'student_id': user.id,
        'material_id': materialId,
        'subject_id': subjectId,
        'action': action,
      });
    } catch (e) {
      debugPrint('No se pudo registrar la actividad: $e');
    }
  }
}
