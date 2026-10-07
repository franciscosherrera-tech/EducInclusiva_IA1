import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/accessibility_provider.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback onGoToChat;

  const HomeScreen({super.key, required this.onGoToChat});

  @override
  Widget build(BuildContext context) {
    final accessibility = Provider.of<AccessibilityProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'EduInclusiva IA',
          style: TextStyle(fontSize: accessibility.fontSize * 1.2),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, // <-- Corregido aquí
          children: [
            const SizedBox(height: 20),
            Icon(
              Icons.school,
              size: 80,
              color: accessibility.isTeaMode ? Colors.teal : Colors.blue,
            ),
            const SizedBox(height: 20),
            Text(
              '¡Hola! Bienvenido a EduInclusiva IA',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: accessibility.fontSize * 1.3,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Tu asistente educativo adaptable para aprender a tu propio ritmo.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: accessibility.fontSize),
            ),
            const Spacer(),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                backgroundColor:
                    accessibility.isTeaMode ? Colors.teal : Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon:
                  const Icon(Icons.chat_bubble, size: 28, color: Colors.white),
              label: Text(
                'Iniciar Tutoría IA',
                style: TextStyle(
                  fontSize: accessibility.fontSize * 1.1,
                  color: Colors.white,
                ),
              ),
              onPressed: onGoToChat,
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
