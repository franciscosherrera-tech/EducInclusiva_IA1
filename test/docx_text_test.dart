import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:eduinclusiva_ia/utils/docx_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extrae el texto de un .docx', () {
    const xml = '<w:document><w:body>'
        '<w:p><w:r><w:t>Ecuaciones &amp; sistemas</w:t></w:r></w:p>'
        '<w:p><w:r><w:t>Resolver 2x + 3 = 7</w:t></w:r></w:p>'
        '</w:body></w:document>';
    final archive = Archive()
      ..addFile(ArchiveFile.bytes('word/document.xml', utf8.encode(xml)));
    final bytes = Uint8List.fromList(ZipEncoder().encode(archive));

    expect(
        extractDocxText(bytes), 'Ecuaciones & sistemas\nResolver 2x + 3 = 7');
  });

  test('devuelve null si no es un .docx', () {
    expect(extractDocxText(Uint8List.fromList([1, 2, 3, 4])), isNull);
  });
}
