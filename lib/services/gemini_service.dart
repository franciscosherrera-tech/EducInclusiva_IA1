import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class GeminiService {
  final http.Client _client;
  final String? Function() _tokenProvider;

  /// [client] y [tokenProvider] solo se pasan en las pruebas.
  GeminiService({http.Client? client, String? Function()? tokenProvider})
      : _client = client ?? http.Client(),
        _tokenProvider = tokenProvider ?? _sessionToken;

  static String? _sessionToken() {
    try {
      return Supabase.instance.client.auth.currentSession?.accessToken;
    } catch (_) {
      return null; // Supabase sin inicializar (pruebas)
    }
  }

  /// Llama a Gemini a través de la función `gemini-proxy` de Supabase, donde
  /// vive la clave. La app nunca la tiene.
  Future<http.Response> _post(String modelo, String body, String token) {
    return _client
        .post(
          Uri.parse(
              '${SupabaseConfig.url}/functions/v1/gemini-proxy?model=$modelo'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
            'apikey': SupabaseConfig.anonKey,
          },
          body: body,
        )
        .timeout(const Duration(seconds: 60));
  }

  static const List<String> _modelos = [
    'gemini-3.5-flash-lite',
    'gemini-3.1-flash-lite',
    'gemini-3.5-flash',
    'gemini-3.8-flash',
    'gemini-flash-latest',
  ];

  static const int _intentosPorModelo = 3;

  static const String _baseInstruction = '''
Eres un Tutor Inteligente, accesible, empático y adaptativo para estudiantes.

Reglas de formato (la app muestra tus respuestas con Markdown):
1. Usa Markdown normal: **negrita** para términos clave, *cursiva* para énfasis,
   listas con "-" o numeradas, y títulos con "##" solo si hacen falta.
   No uses subrayado (no existe en Markdown); usa **negrita** en su lugar.
2. Matemática y fórmulas:
   - NO uses LaTeX, ni signos de dólar, ni barras invertidas.
   - Escribe con símbolos Unicode: × · ÷ ± √ π ≤ ≥ ≠ ≈ ², ³, ₁, ₂, ½, ¾.
   - Nunca uses "*" para multiplicar ni "^" para potencias.
   - Pon cada fórmula importante en su propia línea, dentro de un bloque de código
     (```), para que se vea clara.
   - Explica los pasos numerados, uno por línea.
3. Tienes acceso al historial completo de la conversación, incluidas las imágenes
   o documentos PDF adjuntos enviados por el estudiante. Analiza en profundidad
   el texto interno de los archivos PDF enviados.
''';

  static const String _teaInstruction = '''
MODO TEA ACTIVO: responde de forma muy directa y breve, con pasos enumerados,
frases cortas, lenguaje literal, sin metáforas ni ironías.
''';

  /// Un solo mensaje, sin historial.
  Future<String> sendMessage(
    String prompt, {
    bool isTeaMode = false,
    Uint8List? fileBytes,
    String? mimeType,
  }) {
    return sendMessageWithHistory(
      messagesHistory: [
        {
          'role': 'user',
          'text': prompt.trim().isEmpty
              ? 'Analiza este archivo adjunto y explícamelo de forma accesible.'
              : prompt,
          'bytes': fileBytes,
          'mimeType': mimeType,
        },
      ],
      isTeaMode: isTeaMode,
    );
  }

  /// Envía todo el historial (texto + imágenes/archivos PDF) para mantener memoria.
  Future<String> sendMessageWithHistory({
    required List<Map<String, dynamic>> messagesHistory,
    bool isTeaMode = false,
    String profileInstructions = '',
  }) async {
    final token = _tokenProvider();
    if (token == null) {
      return 'Error de configuración de la IA: iniciá sesión para usar el tutor.';
    }

    final List<Map<String, dynamic>> contents = [];

    for (final msg in messagesHistory) {
      final String role = msg['role'] == 'user' ? 'user' : 'model';
      final String text = (msg['text'] ?? '') as String;
      final Uint8List? bytes = msg['bytes'] as Uint8List?;
      final String? mimeType = msg['mimeType'] as String?;

      final List<Map<String, dynamic>> parts = [];

      if (bytes != null && mimeType != null) {
        parts.add({
          'inline_data': {
            'mime_type': mimeType,
            'data': base64Encode(bytes),
          },
        });
      }
      if (text.trim().isNotEmpty) {
        parts.add({'text': text});
      }
      if (parts.isNotEmpty) {
        contents.add({'role': role, 'parts': parts});
      }
    }

    if (contents.isEmpty) return 'No hay contenido para enviar.';

    String systemText =
        isTeaMode ? '$_baseInstruction\n$_teaInstruction' : _baseInstruction;
    if (profileInstructions.trim().isNotEmpty) {
      systemText += '\nPERFIL DEL ESTUDIANTE (adapta SIEMPRE tus respuestas):\n'
          '$profileInstructions\n';
    }

    final String body = jsonEncode({
      'system_instruction': {
        'parts': [
          {'text': systemText},
        ],
      },
      'contents': contents,
    });

    int? ultimoCodigo;

    for (final modelo in _modelos) {
      for (int intento = 1; intento <= _intentosPorModelo; intento++) {
        try {
          final response = await _post(modelo, body, token);

          if (response.statusCode == 200) {
            final data = jsonDecode(utf8.decode(response.bodyBytes));
            final candidates = data['candidates'] as List?;
            if (candidates == null || candidates.isEmpty) {
              return 'La IA no pudo generar una respuesta para esa consulta.';
            }
            final partsResp = candidates[0]['content']?['parts'] as List?;
            if (partsResp == null || partsResp.isEmpty) {
              return 'No se pudo generar una respuesta.';
            }
            final text = partsResp
                .where((p) => p['text'] != null && p['thought'] != true)
                .map((p) => p['text'] as String)
                .join();
            return text.isEmpty ? 'No se pudo generar una respuesta.' : text;
          }

          ultimoCodigo = response.statusCode;
          print(
              '[$modelo] intento $intento -> ${response.statusCode}: ${response.body}');

          if (response.statusCode == 404) break;

          if (response.statusCode == 400 ||
              response.statusCode == 401 ||
              response.statusCode == 403) {
            return 'Error de configuración de la IA. Código: ${response.statusCode}';
          }

          if (intento < _intentosPorModelo) {
            await Future.delayed(Duration(seconds: 3 * intento));
          }
        } catch (e) {
          print('[$modelo] intento $intento -> error de conexión: $e');
          if (intento < _intentosPorModelo) {
            await Future.delayed(Duration(seconds: 3 * intento));
          }
        }
      }
    }

    if (ultimoCodigo == 503 || ultimoCodigo == 429) {
      return 'La IA está muy ocupada en este momento. Intenta de nuevo en unos minutos.';
    }
    return 'No se pudo conectar con la IA. Revisa tu internet e intenta de nuevo.';
  }
}
