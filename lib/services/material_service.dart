import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/material_model.dart';

class MaterialService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> uploadMaterial({
    required String subjectId,
    required String title,
    String? description,
    required PlatformFile file,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Usuario no autenticado');

    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';

    // 1. Subir archivo al bucket 'materials'
    if (kIsWeb || file.bytes != null) {
      await _supabase.storage
          .from('materials')
          .uploadBinary(fileName, file.bytes!);
    } else if (file.path != null) {
      final ioFile = File(file.path!);
      await _supabase.storage.from('materials').upload(fileName, ioFile);
    } else {
      throw Exception('No se pudo obtener el contenido del archivo.');
    }

    // 2. Obtener URL pública desde el bucket 'materials'
    final publicUrl =
        _supabase.storage.from('materials').getPublicUrl(fileName);

    // 3. Registrar metadata en la base de datos
    await _supabase.from('study_materials').insert({
      'subject_id': subjectId,
      'title': title,
      'description': description,
      'file_url': publicUrl,
      'file_name': file.name,
      'uploaded_by': user.id,
    });
  }

  Future<List<StudyMaterial>> getMaterialsBySubject(String subjectId) async {
    final response = await _supabase
        .from('study_materials')
        .select()
        .eq('subject_id', subjectId)
        .order('created_at', ascending: false);

    final List<dynamic> data = response as List<dynamic>;
    return data.map((json) => StudyMaterial.fromMap(json)).toList();
  }

  /// Elimina el archivo del Storage en Supabase y el registro en la base de datos
  Future<void> deleteMaterial(StudyMaterial material) async {
    if (material.fileUrl.isNotEmpty) {
      try {
        final fileName = Uri.parse(material.fileUrl).pathSegments.last;
        await _supabase.storage.from('materials').remove([fileName]);
      } catch (e) {
        debugPrint('Error al eliminar archivo de Storage: $e');
      }
    }

    await _supabase.from('study_materials').delete().eq('id', material.id);
  }
}
