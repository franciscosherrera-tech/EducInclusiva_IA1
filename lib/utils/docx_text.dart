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

/// Texto de un archivo de Office según su extensión ('docx', 'pptx' o 'xlsx').
String? extractOfficeText(Uint8List bytes, String extension) {
  switch (extension.toLowerCase()) {
    case 'docx':
      return extractDocxText(bytes);
    case 'pptx':
      return extractPptxText(bytes);
    case 'xlsx':
      return extractXlsxText(bytes);
  }
  return null;
}

String _unescapeXml(String s) => s
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&amp;', '&');

/// Texto de todos los `<t>` dentro de un fragmento XML.
String _joinText(String xml) => RegExp(r'<t[^>]*>([^<]*)</t>')
    .allMatches(xml)
    .map((m) => _unescapeXml(m.group(1)!))
    .join();

/// Extrae el contenido de una planilla Excel (.xlsx): una hoja tras otra,
/// una fila por línea y las celdas separadas por tabulaciones.
String? extractXlsxText(Uint8List bytes) {
  try {
    final archive = ZipDecoder().decodeBytes(bytes);

    final shared = <String>[];
    final sharedFile = archive.findFile('xl/sharedStrings.xml');
    if (sharedFile != null) {
      final xml =
          utf8.decode(sharedFile.content as List<int>, allowMalformed: true);
      for (final m in RegExp(r'<si>(.*?)</si>', dotAll: true).allMatches(xml)) {
        shared.add(_joinText(m.group(1)!));
      }
    }

    final sheetName = RegExp(r'^xl/worksheets/sheet(\d+)\.xml$');
    final sheets = <int, ArchiveFile>{};
    for (final file in archive) {
      final m = sheetName.firstMatch(file.name);
      if (m != null) sheets[int.parse(m.group(1)!)] = file;
    }
    if (sheets.isEmpty) return null;

    final out = StringBuffer();
    for (final n in (sheets.keys.toList()..sort())) {
      final xml =
          utf8.decode(sheets[n]!.content as List<int>, allowMalformed: true);
      final rows = <String>[];
      for (final row
          in RegExp(r'<row[^>]*>(.*?)</row>', dotAll: true).allMatches(xml)) {
        final cells = <String>[];
        for (final c in RegExp(r'<c([^>]*?)(?:/>|>(.*?)</c>)', dotAll: true)
            .allMatches(row.group(1)!)) {
          final attrs = c.group(1) ?? '';
          final inner = c.group(2) ?? '';
          final type = RegExp(r't="(\w+)"').firstMatch(attrs)?.group(1);
          final v = RegExp(r'<v>([^<]*)</v>').firstMatch(inner)?.group(1);
          if (type == 'inlineStr') {
            cells.add(_joinText(inner));
          } else if (v == null) {
            cells.add('');
          } else if (type == 's') {
            final i = int.tryParse(v) ?? -1;
            cells.add(i >= 0 && i < shared.length ? shared[i] : '');
          } else {
            cells.add(_unescapeXml(v));
          }
        }
        if (cells.any((c) => c.isNotEmpty)) rows.add(cells.join('\t'));
      }
      if (rows.isNotEmpty) {
        out.write('--- Hoja $n ---\n${rows.join('\n')}\n\n');
      }
    }

    final result = out.toString().trim();
    return result.isEmpty ? null : result;
  } catch (_) {
    return null;
  }
}
