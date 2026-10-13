import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/material_model.dart';

/// Guarda en el teléfono los archivos que el alumno ya descargó, para poder
/// abrirlos sin conexión.
class MaterialCache {
  Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/materials');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _safeName(StudyMaterial m) {
    final clean = m.fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return '${m.id}_$clean';
  }

  /// El archivo guardado, o null si todavía no se descargó.
  Future<File?> cachedFile(StudyMaterial m) async {
    if (kIsWeb) return null;
    final file = File('${(await _dir()).path}/${_safeName(m)}');
    return await file.exists() ? file : null;
  }

  Future<bool> isCached(StudyMaterial m) async => (await cachedFile(m)) != null;

  /// Descarga el archivo y lo guarda. Lanza una excepción si no hay conexión.
  Future<File> download(StudyMaterial m) async {
    final res = await http
        .get(Uri.parse(m.fileUrl))
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      throw Exception('No se pudo descargar el archivo (${res.statusCode}).');
    }
    final file = File('${(await _dir()).path}/${_safeName(m)}');
    await file.writeAsBytes(res.bodyBytes, flush: true);
    return file;
  }

  /// Borra el archivo guardado (por si el profe lo eliminó).
  Future<void> remove(StudyMaterial m) async {
    final file = await cachedFile(m);
    if (file != null) await file.delete();
  }
}
