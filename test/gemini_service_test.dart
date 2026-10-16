import 'dart:convert';
import 'package:eduinclusiva_ia/services/gemini_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String _geminiAnswer(String text) => jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': text}
            ]
          }
        }
      ]
    });

Future<String> _ask(GeminiService service) => service.sendMessage('Hola');

void main() {
  group('GeminiService', () {
    test('con sesión llama a la función gemini-proxy y a nadie más', () async {
      final urls = <Uri>[];
      final client = MockClient((req) async {
        urls.add(req.url);
        return http.Response(_geminiAnswer('respuesta del proxy'), 200);
      });

      final answer =
          await _ask(GeminiService(client: client, tokenProvider: () => 'jwt'));

      expect(answer, 'respuesta del proxy');
      expect(urls, hasLength(1));
      expect(urls.single.path, '/functions/v1/gemini-proxy');
      expect(urls.single.queryParameters['model'], startsWith('gemini-'));
    });

    test('manda el JWT del usuario y ninguna clave de Gemini', () async {
      late http.Request sent;
      final client = MockClient((req) async {
        sent = req;
        return http.Response(_geminiAnswer('ok'), 200);
      });

      await _ask(GeminiService(client: client, tokenProvider: () => 'jwt-x'));

      expect(sent.headers['Authorization'], 'Bearer jwt-x');
      expect(sent.headers.containsKey('x-goog-api-key'), isFalse);
    });

    test('un error 403 de Gemini se informa como error de configuración',
        () async {
      final client = MockClient(
          (req) async => http.Response('{"error":"no autorizado"}', 403));

      final answer =
          await _ask(GeminiService(client: client, tokenProvider: () => 'jwt'));

      expect(answer, contains('Error de configuración'));
    });

    test('sin sesión no llama a ningún lado y avisa', () async {
      var calls = 0;
      final client = MockClient((req) async {
        calls++;
        return http.Response('{}', 200);
      });

      final answer =
          await _ask(GeminiService(client: client, tokenProvider: () => null));

      expect(calls, 0);
      expect(answer, contains('iniciá sesión'));
    });
  });
}
