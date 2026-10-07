import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class SignLanguageInterpreter extends StatefulWidget {
  final String textToInterpret;
  final bool isLoading;

  const SignLanguageInterpreter({
    super.key,
    required this.textToInterpret,
    required this.isLoading,
  });

  @override
  State<SignLanguageInterpreter> createState() =>
      _SignLanguageInterpreterState();
}

class _SignLanguageInterpreterState extends State<SignLanguageInterpreter>
    with SingleTickerProviderStateMixin {
  List<String> _words = [];
  int _currentWordIndex = 0;
  Timer? _interpretationTimer;
  bool _isPlaying = false;
  bool _isMinimized = false;
  double _playbackSpeed = 1.0;

  late AnimationController _animController;
  late Animation<double> _handAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _handAnimation = Tween<double>(begin: -0.2, end: 0.2).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant SignLanguageInterpreter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.textToInterpret != oldWidget.textToInterpret &&
        widget.textToInterpret.isNotEmpty) {
      _processTextAndPlay(widget.textToInterpret);
    }
  }

  void _processTextAndPlay(String rawText) {
    final cleaned =
        rawText.replaceAll(RegExp(r'[^\w\sáéíóúÁÉÍÓÚñÑ]'), '').toLowerCase();

    final stopWords = {
      'el',
      'la',
      'los',
      'las',
      'un',
      'una',
      'de',
      'del',
      'que',
      'y',
      'en',
      'a'
    };

    final parsedWords = cleaned
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty && !stopWords.contains(word))
        .toList();

    setState(() {
      _words = parsedWords.isEmpty ? ['hola'] : parsedWords;
      _currentWordIndex = 0;
      _isPlaying = true;
    });

    _startPlayback();
  }

  void _startPlayback() {
    _interpretationTimer?.cancel();
    if (_words.isEmpty) return;

    if (!_animController.isAnimating) {
      _animController.repeat(reverse: true);
    }

    final durationMs = (1200 / _playbackSpeed).round();
    _interpretationTimer =
        Timer.periodic(Duration(milliseconds: durationMs), (timer) {
      if (!mounted) return;
      setState(() {
        if (_currentWordIndex < _words.length - 1) {
          _currentWordIndex++;
        } else {
          _isPlaying = false;
          _animController.stop();
          _interpretationTimer?.cancel();
        }
      });
    });
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
    if (_isPlaying) {
      if (_currentWordIndex >= _words.length - 1) {
        _currentWordIndex = 0;
      }
      _startPlayback();
    } else {
      _animController.stop();
      _interpretationTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _interpretationTimer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isMinimized) {
      return FloatingActionButton.small(
        backgroundColor: Colors.teal.shade700,
        child: const Icon(Icons.accessibility_new, color: Colors.white),
        onPressed: () => setState(() => _isMinimized = false),
      );
    }

    final currentWord = _words.isNotEmpty && _currentWordIndex < _words.length
        ? _words[_currentWordIndex].toUpperCase()
        : 'LSA';

    return Container(
      width: 160,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.tealAccent, width: 2),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 12, offset: Offset(0, 4))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.accessibility_new,
                      color: Colors.tealAccent, size: 16),
                  SizedBox(width: 4),
                  Text('LSA Intérprete',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              InkWell(
                onTap: () => setState(() => _isMinimized = true),
                child: const Icon(Icons.close, color: Colors.grey, size: 18),
              )
            ],
          ),
          const SizedBox(height: 6),

          // Renderizado del Avatar Articulado
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF12121C),
              borderRadius: BorderRadius.circular(12),
            ),
            child: widget.isLoading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.tealAccent),
                        ),
                        SizedBox(height: 6),
                        Text('Traduciendo...',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 10)),
                      ],
                    ),
                  )
                : AnimatedBuilder(
                    animation: _animController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: AvatarLsaPainter(
                          word: currentWord,
                          animValue: _handAnimation.value,
                          isPlaying: _isPlaying,
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 6),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.teal.shade900,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              currentWord,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.tealAccent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 6),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  _isPlaying ? Icons.pause_circle : Icons.play_circle,
                  color: Colors.tealAccent,
                  size: 26,
                ),
                onPressed: widget.isLoading ? null : _togglePlayPause,
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    if (_playbackSpeed == 1.0) {
                      _playbackSpeed = 0.75;
                    } else if (_playbackSpeed == 0.75) {
                      _playbackSpeed = 0.5;
                    } else {
                      _playbackSpeed = 1.0;
                    }
                  });
                  if (_isPlaying) _startPlayback();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white38),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_playbackSpeed}x',
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AvatarLsaPainter extends CustomPainter {
  final String word;
  final double animValue;
  final bool isPlaying;

  AvatarLsaPainter({
    required this.word,
    required this.animValue,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final skin = Paint()..color = const Color(0xFFFFCC99);
    final shirt = Paint()..color = Colors.teal.shade700;
    final arm = Paint()
      ..color = const Color(0xFFFFBB88)
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final detail = Paint()
      ..color = Colors.black87
      ..strokeWidth = 1.5;

    // Cabeza y Rostro
    canvas.drawCircle(Offset(cx, cy - 22), 15, skin);
    canvas.drawCircle(Offset(cx - 4, cy - 25), 2, detail);
    canvas.drawCircle(Offset(cx + 4, cy - 25), 2, detail);

    // Torso
    final torso = Path()
      ..moveTo(cx - 16, cy - 5)
      ..lineTo(cx + 16, cy - 5)
      ..lineTo(cx + 18, cy + 30)
      ..lineTo(cx - 18, cy + 30)
      ..close();
    canvas.drawPath(torso, shirt);

    // Movimientos adaptativos según palabra/letra
    double rx = cx + 18 + (animValue * 10);
    double ry = cy - 8 + (animValue * 15);
    double lx = cx - 18 - (animValue * 8);
    double ly = cy + 2 + (animValue * 12);

    if (word.startsWith('A') || word.startsWith('E')) {
      rx = cx + 8;
      ry = cy - 18 + (animValue * 8);
    } else if (word.startsWith('I') ||
        word.startsWith('O') ||
        word.startsWith('U')) {
      rx = cx + 10;
      ry = cy - 30 + (animValue * 5);
    }

    // Brazo Izquierdo
    canvas.drawPath(
      Path()
        ..moveTo(cx - 14, cy - 2)
        ..quadraticBezierTo(cx - 24, cy + 8, lx, ly),
      arm,
    );

    // Brazo Derecho (Mano dominante)
    canvas.drawPath(
      Path()
        ..moveTo(cx + 14, cy - 2)
        ..quadraticBezierTo(cx + 24, cy - 4, rx, ry),
      arm,
    );

    // Manos y Gestos de Dedos
    canvas.drawCircle(Offset(lx, ly), 4, skin);
    canvas.drawCircle(Offset(rx, ry), 5, skin);

    if (isPlaying) {
      for (int i = 0; i < 3; i++) {
        final angle = (i * 0.5) - 0.5 + animValue;
        canvas.drawLine(
          Offset(rx, ry),
          Offset(rx + math.cos(angle) * 6, ry + math.sin(angle) * 6),
          Paint()
            ..color = const Color(0xFFFFCC99)
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant AvatarLsaPainter oldDelegate) => true;
}
