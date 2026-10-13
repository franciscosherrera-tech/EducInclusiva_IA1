import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';

/// Extrae el texto plano de un archivo Word (.docx).
/// Un .docx es un zip; el contenido está en word/document.xml.
/// Devuelve null si el archivo no es un .docx válido (ej. un .doc viejo).
String? extractDocxText(Uint8List bytes) {
  try {
    final archive = ZipDecoder().decodeBytes(bytes);
    final entry = archive.findFile('word/document.xml');
    if (entry == null) return null;

    var xml = utf8.decode(entry.content as List<int>, allowMalformed: true);

    xml = xml
        .replaceAll(RegExp(r'</w:p>'), '\n')
        .replaceAll(RegExp(r'<w:br\s*/>'), '\n')
        .replaceAll(RegExp(r'<w:tab\s*/>'), '\t')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");

    final text = xml.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    return text.isEmpty ? null : text;
  } catch (_) {
    return null;
  }
}
