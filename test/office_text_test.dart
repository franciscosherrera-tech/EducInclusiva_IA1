import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:eduinclusiva_ia/utils/docx_text.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _zip(Map<String, String> files) {
  final archive = Archive();
  files.forEach((name, content) {
    final data = utf8.encode(content);
    archive.addFile(ArchiveFile(name, data.length, data));
  });
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  xlsxTests();
  test('pptx: extrae el texto en orden numérico de diapositivas', () {
    final bytes = _zip({
      'ppt/slides/slide10.xml': '<p><a:p><a:r><a:t>Final</a:t></a:r></a:p></p>',
      'ppt/slides/slide2.xml':
          '<p><a:p><a:r><a:t>Dos &amp; más</a:t></a:r></a:p></p>',
      'ppt/slides/slide1.xml': '<p><a:p><a:r><a:t>Uno</a:t></a:r></a:p></p>',
    });

    final text = extractOfficeText(bytes, 'pptx')!;

    expect(text.indexOf('Uno'), lessThan(text.indexOf('Dos & más')));
    expect(text.indexOf('Dos & más'), lessThan(text.indexOf('Final')));
    expect(text, contains('Diapositiva 2'));
  });

  test('docx: extrae párrafos', () {
    final bytes = _zip({
      'word/document.xml':
          '<w:p><w:r><w:t>Hola</w:t></w:r></w:p><w:p><w:r><w:t>Mundo</w:t></w:r></w:p>',
    });
    expect(extractOfficeText(bytes, 'docx'), 'Hola\nMundo');
  });

  test('archivos inválidos o de otro tipo devuelven null', () {
    expect(extractOfficeText(Uint8List.fromList([1, 2, 3]), 'pptx'), isNull);
    expect(extractOfficeText(_zip({'x.txt': 'a'}), 'pptx'), isNull);
    expect(extractOfficeText(_zip({'x.txt': 'a'}), 'pdf'), isNull);
  });
}

void xlsxTests() {
  test('xlsx: lee textos compartidos, números y texto en línea', () {
    final bytes = _zip({
      'xl/sharedStrings.xml':
          '<sst><si><t>Nombre</t></si><si><t>Nota</t></si><si><t>Ana &amp; Co</t></si></sst>',
      'xl/worksheets/sheet1.xml':
          '<sheetData><row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c></row>'
              '<row r="2"><c r="A2" t="s"><v>2</v></c><c r="B2"><v>9.5</v></c>'
              '<c r="C2" t="inlineStr"><is><t>ok</t></is></c></row></sheetData>',
    });
    expect(extractOfficeText(bytes, 'xlsx'),
        '--- Hoja 1 ---\nNombre\tNota\nAna & Co\t9.5\tok');
  });
}
