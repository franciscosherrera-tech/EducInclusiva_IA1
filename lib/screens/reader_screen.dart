import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final FlutterTts _tts = FlutterTts();
  final TextEditingController _textController = TextEditingController(
    text: 'EduInclusiva IA adapta los contenidos escolares para que todos los estudiantes aprendan a su propio ritmo con apoyo auditivo y visual.',
  );
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("es-ES");
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(
      0.45,
    ); // Tasa pausada para facilitar la comprensión

    _tts.setCompletionHandler(() {
      setState(() => _isSpeaking = false);
    });
  }

  Future<void> _speak() async {
    if (_textController.text.isNotEmpty) {
      setState(() => _isSpeaking = true);
      await _tts.speak(_textController.text);
    }
  }

  Future<void> _stop() async {
    await _tts.stop();
    setState(() => _isSpeaking = false);
  }

  @override
  void dispose() {
    _tts.stop();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lectura Fácil y Voz'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Texto para Adaptar / Leer:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              maxLines: 6,
              style: const TextStyle(fontSize: 18, height: 1.5),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                filled: true,
                fillColor: Colors.white,
                hintText: 'Ingresa o pega un texto aquí...',
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSpeaking ? _stop : _speak,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: _isSpeaking
                          ? Colors.redAccent
                          : const Color(0xFF0D47A1),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: Icon(
                      _isSpeaking ? Icons.stop : Icons.volume_up,
                      size: 28,
                    ),
                    label: Text(
                      _isSpeaking ? 'Detener' : 'Escuchar Texto',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
