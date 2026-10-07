// lib/screens/chat_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

import '../models/subject.dart';
import '../providers/accessibility_provider.dart';
import '../services/gemini_service.dart';
import '../services/pdf_export_service.dart';
import '../services/chat_service.dart';
import '../widgets/sign_language_interpreter.dart';
import 'main_navigation_screen.dart';

class ChatScreen extends StatefulWidget {
  final Subject? subject;

  const ChatScreen({super.key, this.subject});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final FlutterTts _flutterTts = FlutterTts();
  final GeminiService _geminiService = GeminiService();
  final ChatService _chatService = ChatService();
  final ImagePicker _imagePicker = ImagePicker();
  final stt.SpeechToText _speech = stt.SpeechToText();

  List<Map<String, dynamic>> _messages = [];
  List<Map<String, dynamic>> _subjectMaterials = [];
  bool _isLoading = false;
  bool _isLoadingMaterials = false;
  bool _isListening = false;
  bool _speechInitialized = false;
  String? _activeChatId;

  Uint8List? _attachedBytes;
  String? _attachedMimeType;
  String? _attachedFileName;

  Subject get _activeSubject =>
      widget.subject ??
      Subject(
        id: 'general',
        name: 'General',
        iconCode: Icons.chat.codePoint,
        colorValue: Colors.teal.value,
        description: 'Consultas generales',
      );

  @override
  void initState() {
    super.initState();
    _initTts();
    _initSpeech();
    _setupChatSession();
    _fetchSubjectMaterials();
  }

  /// Carga los materiales subidos por los docentes para esta materia específica
  Future<void> _fetchSubjectMaterials() async {
    if (_activeSubject.id == 'general' ||
        _activeSubject.id == '00000000-0000-0000-0000-000000000000') {
      return;
    }

    setState(() => _isLoadingMaterials = true);

    try {
      final response = await Supabase.instance.client
          .from('study_materials')
          .select('*')
          .eq('subject_id', _activeSubject.id)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _subjectMaterials = List<Map<String, dynamic>>.from(response);
          _isLoadingMaterials = false;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar materiales de la materia: $e');
      if (mounted) {
        setState(() => _isLoadingMaterials = false);
      }
    }
  }

  void _initTts() async {
    await _flutterTts.setLanguage("es-ES");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
  }

  void _initSpeech() async {
    _speechInitialized = await _speech.initialize(
      onError: (error) => setState(() => _isListening = false),
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
    );
    if (mounted) setState(() {});
  }

  Future<void> _setupChatSession() async {
    setState(() => _isLoading = true);

    _activeChatId = await _chatService.getOrCreateChat(_activeSubject.id);

    if (_activeChatId != null) {
      final loadedMessages = await _chatService.loadMessages(_activeChatId!);
      if (mounted) {
        setState(() {
          _messages = loadedMessages;
        });
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _clearChatHistory() async {
    if (_activeChatId != null) {
      await _chatService.clearChat(_activeChatId!);
    }
    setState(() {
      _messages.clear();
    });
  }

  void _listenVoice() async {
    var status = await Permission.microphone.status;

    if (status.isDenied) {
      status = await Permission.microphone.request();
    }

    if (status.isPermanentlyDenied) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'El permiso de micrófono está desactivado en los ajustes.'),
          action: SnackBarAction(
            label: 'Ajustes',
            onPressed: () => openAppSettings(),
          ),
        ),
      );
      return;
    }

    if (status.isGranted) {
      if (!_speechInitialized) {
        _speechInitialized = await _speech.initialize(
          onError: (error) => setState(() => _isListening = false),
          onStatus: (status) {
            if (status == 'done' || status == 'notListening') {
              setState(() => _isListening = false);
            }
          },
        );
      }

      if (_speechInitialized) {
        if (!_isListening) {
          setState(() => _isListening = true);
          await _speech.listen(
            localeId: "es_ES",
            onResult: (result) {
              setState(() {
                _controller.text = result.recognizedWords;
              });
            },
          );
        } else {
          await _speech.stop();
          setState(() => _isListening = false);
        }
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Se requiere permiso de micrófono para usar esta función.'),
        ),
      );
    }
  }

  Future<void> _speak(String text) async {
    final accessibility =
        Provider.of<AccessibilityProvider>(context, listen: false);
    await _flutterTts.stop();
    await _flutterTts.setSpeechRate(accessibility.speechRate);
    if (text.isNotEmpty) {
      await _flutterTts.speak(text);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? image = await _imagePicker.pickImage(source: source);
    if (image != null) {
      final bytes = await image.readAsBytes();
      final mime = image.mimeType ??
          (image.path.endsWith('.png') ? 'image/png' : 'image/jpeg');
      setState(() {
        _attachedBytes = bytes;
        _attachedMimeType = mime;
        _attachedFileName = image.name;
      });
    }
  }

  Future<void> _pickDocument() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt'],
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      final file = result.files.single;
      String mime = 'application/pdf';
      if (file.extension == 'txt') mime = 'text/plain';

      setState(() {
        _attachedBytes = file.bytes;
        _attachedMimeType = mime;
        _attachedFileName = file.name;
      });
    }
  }

  void _clearAttachment() {
    setState(() {
      _attachedBytes = null;
      _attachedMimeType = null;
      _attachedFileName = null;
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty && _attachedBytes == null) return;

    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    }

    final accessibility =
        Provider.of<AccessibilityProvider>(context, listen: false);

    final sentAttachmentName = _attachedFileName;
    final bytesToSend = _attachedBytes;
    final mimeToSend = _attachedMimeType;

    setState(() {
      _messages.add({
        "role": "user",
        "text": text,
        "fileName": sentAttachmentName,
        "bytes": bytesToSend,
        "mimeType": mimeToSend,
      });
      _isLoading = true;
      _controller.clear();
    });

    _clearAttachment();

    if (_activeChatId != null && text.isNotEmpty) {
      await _chatService.saveMessage(
        chatId: _activeChatId!,
        sender: 'user',
        content: text,
      );
    }

    final response = await _geminiService.sendMessageWithHistory(
      messagesHistory: _messages,
      isTeaMode: accessibility.isTeaMode,
    );

    setState(() {
      _messages.add({"role": "ai", "text": response});
      _isLoading = false;
    });

    if (_activeChatId != null) {
      await _chatService.saveMessage(
        chatId: _activeChatId!,
        sender: 'ai',
        content: response,
      );
    }

    if (accessibility.autoReadText) {
      _speak(response);
    }
  }

  void _showAttachmentModal() {
    final primaryColor =
        Provider.of<AccessibilityProvider>(context, listen: false)
            .activePrimaryColor;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt, color: primaryColor),
              title: const Text('Tomar Foto'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: primaryColor),
              title: const Text('Elegir de Galería'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Icon(Icons.picture_as_pdf, color: primaryColor),
              title: const Text('Adjuntar Documento (PDF/TXT)'),
              onTap: () {
                Navigator.pop(context);
                _pickDocument();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _speech.stop();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accessibility = Provider.of<AccessibilityProvider>(context);
    final primaryColor = accessibility.activePrimaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => const MainNavigationScreen(),
                ),
                (route) => false,
              );
            }
          },
        ),
        backgroundColor:
            accessibility.isHighContrast ? Colors.black : primaryColor,
        foregroundColor:
            accessibility.isHighContrast ? Colors.yellowAccent : Colors.white,
        title: Row(
          children: [
            Icon(
              _activeSubject.icon,
              color: accessibility.isHighContrast
                  ? Colors.yellowAccent
                  : Colors.white,
              size: 22,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _activeSubject.name,
                overflow: TextOverflow.ellipsis,
                style: accessibility.getTextStyle(
                  overrideSize: accessibility.fontSize * 1.0,
                  color: accessibility.isHighContrast
                      ? Colors.yellowAccent
                      : Colors.white,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Exportar a PDF',
            onPressed: _messages.isEmpty
                ? null
                : () => PdfExportService.exportChatToPdf(_messages),
          ),
          IconButton(
            icon: Icon(
              accessibility.isTeaMode
                  ? Icons.psychology
                  : Icons.psychology_outlined,
              color: accessibility.isTeaMode
                  ? (accessibility.isHighContrast
                      ? Colors.yellowAccent
                      : Colors.white)
                  : null,
            ),
            tooltip: 'Alternar Modo TEA',
            onPressed: () =>
                accessibility.toggleTeaMode(!accessibility.isTeaMode),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Borrar historial',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Borrar Conversación'),
                  content: Text(
                      '¿Deseas vaciar el historial de ${_activeSubject.id == "general" ? "Chat General" : _activeSubject.name}?'),
                  actions: [
                    TextButton(
                      child: const Text('Cancelar'),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                    TextButton(
                      child: const Text('Borrar',
                          style: TextStyle(color: Colors.red)),
                      onPressed: () {
                        _clearChatHistory();
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Sección Desplegable de Materiales del Profesor
              if (_activeSubject.id != 'general' &&
                  _activeSubject.id != '00000000-0000-0000-0000-000000000000')
                Container(
                  color: isDark ? const Color(0xFF1E232A) : Colors.teal.shade50,
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                    leading:
                        const Icon(Icons.folder_outlined, color: Colors.teal),
                    title: Text(
                      'Guías y trabajos del Profesor (${_subjectMaterials.length})',
                      style: accessibility.getTextStyle(
                        overrideSize: accessibility.fontSize * 0.85,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.teal.shade900,
                      ),
                    ),
                    children: _isLoadingMaterials
                        ? [
                            const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          ]
                        : _subjectMaterials.isEmpty
                            ? [
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    'No hay materiales de estudio subidos para esta materia.',
                                    style: accessibility.getTextStyle(
                                      overrideSize:
                                          accessibility.fontSize * 0.8,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                  ),
                                )
                              ]
                            : _subjectMaterials.map((mat) {
                                final title =
                                    mat['title'] ?? 'Material de clase';
                                final desc = mat['description'] ?? '';
                                final fileUrl = mat['file_url'] ??
                                    mat['url'] ??
                                    mat['file_path'];

                                return Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      top: BorderSide(
                                        color: isDark
                                            ? Colors.white12
                                            : Colors.teal.shade100,
                                      ),
                                    ),
                                  ),
                                  child: ListTile(
                                    dense: true,
                                    leading: const Icon(Icons.menu_book,
                                        color: Colors.teal, size: 20),
                                    title: Text(
                                      title,
                                      style: accessibility.getTextStyle(
                                        overrideSize:
                                            accessibility.fontSize * 0.85,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    subtitle: desc.isNotEmpty
                                        ? Text(
                                            desc,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: accessibility.getTextStyle(
                                              overrideSize:
                                                  accessibility.fontSize * 0.75,
                                              color: isDark
                                                  ? Colors.white70
                                                  : Colors.black54,
                                            ),
                                          )
                                        : null,
                                    trailing: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.teal,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 4),
                                      ),
                                      icon: const Icon(Icons.help_outline,
                                          size: 16),
                                      label: const Text('Preguntar',
                                          style: TextStyle(fontSize: 12)),
                                      onPressed: () async {
                                        setState(() => _isLoading = true);

                                        Uint8List? downloadedBytes;
                                        String? mimeType;

                                        if (fileUrl != null &&
                                            fileUrl.toString().isNotEmpty) {
                                          try {
                                            final res = await http.get(
                                                Uri.parse(fileUrl.toString()));
                                            if (res.statusCode == 200) {
                                              downloadedBytes = res.bodyBytes;
                                              mimeType = 'application/pdf';
                                            }
                                          } catch (e) {
                                            debugPrint(
                                                'Error al descargar el PDF: $e');
                                          }
                                        }

                                        if (mounted) {
                                          setState(() {
                                            _attachedBytes = downloadedBytes;
                                            _attachedMimeType = mimeType;
                                            _attachedFileName = '$title.pdf';
                                            _controller.text = desc.isNotEmpty
                                                ? 'Lee detenidamente el PDF adjunto ("$title"). Consigna: "$desc". ¿De qué trata y por dónde empezamos?'
                                                : 'Lee detenidamente el PDF adjunto ("$title"). ¿De qué trata y por dónde empezamos?';
                                            _isLoading = false;
                                          });

                                          await _sendMessage();
                                        }
                                      },
                                    ),
                                  ),
                                );
                              }).toList(),
                  ),
                ),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isUser = msg["role"] == "user";

                    final bubbleBg = isUser
                        ? (accessibility.isHighContrast
                            ? Colors.yellowAccent
                            : (accessibility.isTeaMode
                                ? Colors.teal.shade300
                                : primaryColor))
                        : (accessibility.isHighContrast
                            ? Colors.grey.shade900
                            : (isDark
                                ? const Color(0xFF222831)
                                : Colors.grey.shade200));

                    final userTextColor = accessibility.isHighContrast
                        ? Colors.black
                        : (bubbleBg.computeLuminance() > 0.5
                            ? Colors.black87
                            : Colors.white);

                    final aiTextColor = accessibility.isHighContrast
                        ? Colors.white
                        : (isDark ? Colors.white : Colors.black87);

                    final msgTextColor = isUser ? userTextColor : aiTextColor;

                    return Align(
                      alignment:
                          isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(12),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.85,
                        ),
                        decoration: BoxDecoration(
                          color: bubbleBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (msg["bytes"] != null &&
                                msg["mimeType"] != null) ...[
                              if (msg["mimeType"]
                                  .toString()
                                  .startsWith("image/"))
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(
                                      msg["bytes"] as Uint8List,
                                      height: 220,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                )
                              else ...[
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.picture_as_pdf,
                                          color: Colors.red, size: 28),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          msg["fileName"] ??
                                              "Documento adjunto",
                                          style: accessibility.getTextStyle(
                                            overrideSize:
                                                accessibility.fontSize * 0.85,
                                            color: msgTextColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                              ],
                            ],
                            if ((msg["text"] ?? "").isNotEmpty)
                              MarkdownBody(
                                data: msg["text"],
                                selectable: true,
                                styleSheet: MarkdownStyleSheet.fromTheme(
                                        Theme.of(context))
                                    .copyWith(
                                  p: accessibility.getTextStyle(
                                      color: msgTextColor),
                                  strong: accessibility.getTextStyle(
                                      color: msgTextColor,
                                      fontWeight: FontWeight.bold),
                                  em: accessibility
                                      .getTextStyle(color: msgTextColor)
                                      .copyWith(fontStyle: FontStyle.italic),
                                  code: accessibility
                                      .getTextStyle(color: msgTextColor)
                                      .copyWith(
                                        fontFamily: 'monospace',
                                        backgroundColor:
                                            const Color(0x22000000),
                                      ),
                                  codeblockPadding: const EdgeInsets.all(12),
                                  codeblockDecoration: BoxDecoration(
                                    color: const Color(0x11000000),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            if (!isUser) ...[
                              const SizedBox(height: 8),
                              IconButton(
                                icon: Icon(
                                  Icons.volume_up,
                                  size: 22,
                                  color:
                                      isDark ? Colors.white70 : Colors.black54,
                                ),
                                onPressed: () => _speak(msg["text"] ?? ""),
                              ),
                            ]
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (_isLoading) const LinearProgressIndicator(),
              if (_attachedFileName != null && _attachedBytes != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        isDark ? const Color(0xFF1E2E2E) : Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: isDark
                            ? Colors.teal.shade700
                            : Colors.teal.shade200),
                  ),
                  child: Row(
                    children: [
                      if (_attachedMimeType != null &&
                          _attachedMimeType!.startsWith('image/'))
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            _attachedBytes!,
                            width: 55,
                            height: 55,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Container(
                          width: 55,
                          height: 55,
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.picture_as_pdf,
                              color: Colors.red, size: 32),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _attachedFileName!,
                              overflow: TextOverflow.ellipsis,
                              style: accessibility.getTextStyle(
                                overrideSize: accessibility.fontSize * 0.85,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _attachedMimeType?.startsWith('image/') == true
                                  ? 'Vista previa de imagen'
                                  : 'Documento adjunto',
                              style: accessibility.getTextStyle(
                                overrideSize: accessibility.fontSize * 0.75,
                                color: isDark
                                    ? Colors.white70
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.grey),
                        onPressed: _clearAttachment,
                      )
                    ],
                  ),
                ),
              Container(
                padding: const EdgeInsets.all(8),
                color: isDark ? const Color(0xFF1E232A) : Colors.white,
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.add_circle_outline,
                          color: primaryColor, size: 28),
                      onPressed: _showAttachmentModal,
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: accessibility.getTextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: _isListening
                              ? 'Escuchando tu voz...'
                              : 'Escribe o habla tu duda...',
                          hintStyle: accessibility.getTextStyle(
                            color: isDark ? Colors.white54 : Colors.black38,
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: _isListening ? Colors.red : primaryColor,
                        size: 28,
                      ),
                      tooltip: 'Hablar',
                      onPressed: _listenVoice,
                    ),
                    IconButton(
                      icon: Icon(Icons.send, color: primaryColor, size: 28),
                      onPressed: _sendMessage,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (accessibility.isSignLanguageEnabled)
            Positioned(
              right: 16,
              bottom: 80,
              child: SignLanguageInterpreter(
                textToInterpret:
                    _messages.isNotEmpty && _messages.last["role"] == "ai"
                        ? (_messages.last["text"] ?? "")
                        : "",
                isLoading: _isLoading,
              ),
            ),
        ],
      ),
    );
  }
}
