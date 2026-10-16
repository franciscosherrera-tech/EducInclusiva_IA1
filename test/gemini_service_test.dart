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
    test('con sesión usa la función gemini-proxy y no toca Gemini directo',
        () async {
      final urls = <Uri>[];
      final client = MockClient((req) async {
        urls.add(req.url);
        return http.Response(_geminiAnswer('respuesta del proxy'), 200,
            headers: {'x-proxy': 'gemini'});
      });

      final answer = await _ask(GeminiService(
        client: client,
        tokenProvider: () => 'jwt-del-usuario',
        apiKey: 'clave-vieja',
      ));

      expect(answer, 'respuesta del proxy');
      expect(urls, hasLength(1));
      expect(urls.single.path, '/functions/v1/gemini-proxy');
      expect(urls.single.queryParameters['model'], startsWith('gemini-'));
    });

    test('manda el JWT del usuario y nunca la clave de Gemini al proxy',
        () async {
      late http.Request sent;
      final client = MockClient((req) async {
        sent = req;
        return http.Response(_geminiAnswer('ok'), 200,
            headers: {'x-proxy': 'gemini'});
      });

      await _ask(GeminiService(
        client: client,
        tokenProvider: () => 'jwt-del-usuario',
        apiKey: 'clave-secreta',
      ));

      expect(sent.headers['Authorization'], 'Bearer jwt-del-usuario');
      expect(sent.headers.containsKey('x-goog-api-key'), isFalse);
      expect(sent.body, isNot(contains('clave-secreta')));
    });

    test('si la función no está desplegada, usa el respaldo con la clave',
        () async {
      final hosts = <String>[];
      final client = MockClient((req) async {
        hosts.add(req.url.host);
        if (req.url.path.contains('gemini-proxy')) {
          // Respuesta genérica de Supabase: sin el encabezado x-proxy
          return http.Response('{"code":"NOT_FOUND"}', 404);
        }
        expect(req.headers['x-goog-api-key'], 'clave-de-respaldo');
        return http.Response(_geminiAnswer('respuesta directa'), 200);
      });

      final answer = await _ask(GeminiService(
        client: client,
        tokenProvider: () => 'jwt',
        apiKey: 'clave-de-respaldo',
      ));

      expect(answer, 'respuesta directa');
      expect(hosts.last, 'generativelanguage.googleapis.com');
    });

    test('sin sesión usa la clave directamente', () async {
      final urls = <Uri>[];
      final client = MockClient((req) async {
        urls.add(req.url);
        return http.Response(_geminiAnswer('directa'), 200);
      });

      final answer = await _ask(GeminiService(
        client: client,
        tokenProvider: () => null,
        apiKey: 'clave',
      ));

      expect(answer, 'directa');
      expect(urls.single.host, 'generativelanguage.googleapis.com');
    });

    test('un error de Gemini que pasa por el proxy se trata como siempre',
        () async {
      final client = MockClient((req) async => http.Response(
          '{"error":"no autorizado"}', 403,
          headers: {'x-proxy': 'gemini'}));

      final answer = await _ask(GeminiService(
        client: client,
        tokenProvider: () => 'jwt',
        apiKey: '',
      ));

      expect(answer, contains('Error de configuración'));
    });

    test('sin sesión y sin clave no llama a ningún lado y avisa', () async {
      var calls = 0;
      final client = MockClient((req) async {
        calls++;
        return http.Response('{}', 200);
      });

      final answer = await _ask(GeminiService(
        client: client,
        tokenProvider: () => null,
        apiKey: '',
      ));

      expect(calls, 0);
      expect(answer, contains('Error de configuración'));
    });
  });
}
