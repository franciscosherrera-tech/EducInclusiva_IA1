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

/// Extrae el texto de una presentación PowerPoint (.pptx), diapositiva por
/// diapositiva. Devuelve null si no es un .pptx válido o no tiene texto.
String? extractPptxText(Uint8List bytes) {
  try {
    final archive = ZipDecoder().decodeBytes(bytes);
    final slideName = RegExp(r'^ppt/slides/slide(\d+)\.xml$');

    final slides = <int, ArchiveFile>{};
    for (final file in archive) {
      final m = slideName.firstMatch(file.name);
      if (m != null) slides[int.parse(m.group(1)!)] = file;
    }
    if (slides.isEmpty) return null;

    final out = StringBuffer();
    for (final n in (slides.keys.toList()..sort())) {
      var xml =
          utf8.decode(slides[n]!.content as List<int>, allowMalformed: true);
      xml = xml
          .replaceAll(RegExp(r'</a:p>'), '\n')
          .replaceAll(RegExp(r'<a:br\s*/>'), '\n')
          .replaceAll(RegExp(r'<[^>]+>'), '')
          .replaceAll('&amp;', '&')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"')
          .replaceAll('&apos;', "'");
      final text = xml.replaceAll(RegExp(r'\n{2,}'), '\n').trim();
      if (text.isNotEmpty) out.write('--- Diapositiva $n ---\n$text\n\n');
    }

    final result = out.toString().trim();
    return result.isEmpty ? null : result;
  } catch (_) {
    return null;
  }
}

/// Texto de un archivo de Office según su extensión ('docx' o 'pptx').
String? extractOfficeText(Uint8List bytes, String extension) {
  switch (extension.toLowerCase()) {
    case 'docx':
      return extractDocxText(bytes);
    case 'pptx':
      return extractPptxText(bytes);
  }
  return null;
}
