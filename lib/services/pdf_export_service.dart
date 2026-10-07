import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfExportService {
  static Future<void> exportChatToPdf(
      List<Map<String, dynamic>> messages) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment
                    .spaceBetween, // <-- Corregido (mainAxisAlignment)
                children: [
                  pw.Text(
                    'Resumen de Estudio - Tutor IA',
                    style: pw.TextStyle(
                        fontSize: 20, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(DateTime.now().toString().split(' ')[0]),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            ...messages.map((msg) {
              final isUser = msg['role'] == 'user';
              final text = msg['text'] ?? '';
              final fileName = msg['fileName'];

              return pw.Container(
                margin: const pw.EdgeInsets.symmetric(vertical: 6),
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: isUser ? PdfColors.blue50 : PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(
                      color: isUser ? PdfColors.blue200 : PdfColors.grey300),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      isUser ? 'Estudiante:' : 'Tutor IA:',
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        color: isUser ? PdfColors.blue900 : PdfColors.teal900,
                      ),
                    ),
                    if (fileName != null)
                      pw.Text(
                        '[Archivo adjunto: $fileName]',
                        style: const pw.TextStyle(
                          fontStyle:
                              pw.FontStyle.italic, // <-- Corregido (fontStyle)
                          fontSize: 10,
                        ),
                      ),
                    pw.SizedBox(height: 4),
                    pw.Text(text),
                  ],
                ),
              );
            }),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Apuntes_Tutor_IA.pdf',
    );
  }
}
