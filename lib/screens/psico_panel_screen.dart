import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/user_provider.dart';
import 'auth_screen.dart';

String _fmtDate(String? iso) {
  if (iso == null) return '';
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

// ---------------------------------------------------------------------------
// 1) Lista de alumnos
// ---------------------------------------------------------------------------
class PsicoPanelScreen extends StatefulWidget {
  const PsicoPanelScreen({super.key});

  @override
  State<PsicoPanelScreen> createState() => _PsicoPanelScreenState();
}

class _PsicoPanelScreenState extends State<PsicoPanelScreen> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _students = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('id, name, email, role')
          .order('name');
      if (!mounted) return;
      final all = List<Map<String, dynamic>>.from(data);
      setState(() {
        _students = all
            .where((p) =>
                (p['role'] ?? '').toString().toLowerCase() != 'psicopedagoga')
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar la lista de alumnos.';
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    await context.read<UserProvider>().signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final filtered = _students.where((s) {
      final name = (s['name'] ?? '').toString().toLowerCase();
      final email = (s['email'] ?? '').toString().toLowerCase();
      return q.isEmpty || name.contains(q) || email.contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de psicopedagogía'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre o correo',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : filtered.isEmpty
                        ? const Center(
                            child: Text('No hay alumnos para mostrar.'))
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final s = filtered[i];
                                final name =
                                    (s['name'] ?? 'Sin nombre').toString();
                                return ListTile(
                                  leading: CircleAvatar(
                                    child: Text(name.isNotEmpty
                                        ? name[0].toUpperCase()
                                        : '?'),
                                  ),
                                  title: Text(name),
                                  subtitle: Text((s['email'] ?? '').toString()),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => StudentChatsScreen(
                                        studentId: s['id'] as String,
                                        studentName: name,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2) Chats de un alumno
// ---------------------------------------------------------------------------
class StudentChatsScreen extends StatefulWidget {
  final String studentId;
  final String studentName;

  const StudentChatsScreen({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<StudentChatsScreen> createState() => _StudentChatsScreenState();
}

class _StudentChatsScreenState extends State<StudentChatsScreen> {
  List<Map<String, dynamic>> _chats = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await Supabase.instance.client
          .from('chats')
          .select('id, title, subject_id, created_at, updated_at')
          .eq('user_id', widget.studentId)
          .order('updated_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _chats = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar los chats.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.studentName)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _chats.isEmpty
                  ? const Center(
                      child: Text('Este alumno todavía no tiene chats.'))
                  : ListView.separated(
                      itemCount: _chats.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final c = _chats[i];
                        final title = (c['title'] ?? '').toString();
                        final subject = (c['subject_id'] ?? '').toString();
                        return ListTile(
                          leading: const Icon(Icons.chat_bubble_outline),
                          title:
                              Text(title.isEmpty ? 'Chat sin título' : title),
                          subtitle: Text(
                              '$subject · ${_fmtDate(c['updated_at'] as String?)}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatMessagesScreen(
                                chatId: c['id'] as String,
                                title: title.isEmpty ? 'Chat' : title,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3) Conversación completa (solo lectura)
// ---------------------------------------------------------------------------
class ChatMessagesScreen extends StatefulWidget {
  final String chatId;
  final String title;

  const ChatMessagesScreen({
    super.key,
    required this.chatId,
    required this.title,
  });

  @override
  State<ChatMessagesScreen> createState() => _ChatMessagesScreenState();
}

class _ChatMessagesScreenState extends State<ChatMessagesScreen> {
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await Supabase.instance.client
          .from('messages')
          .select('sender, content, created_at')
          .eq('chat_id', widget.chatId)
          .order('created_at', ascending: true);
      if (!mounted) return;
      setState(() {
        _messages = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar la conversación.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar:
          AppBar(title: Text(widget.title, overflow: TextOverflow.ellipsis)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _messages.isEmpty
                  ? const Center(child: Text('Esta conversación está vacía.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) {
                        final m = _messages[i];
                        final isStudent = m['sender'] == 'user';
                        final content = (m['content'] ?? '').toString();

                        return Align(
                          alignment: isStudent
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.85,
                            ),
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isStudent
                                  ? scheme.primaryContainer
                                  : scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isStudent ? 'Alumno' : 'Tutor IA',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                isStudent
                                    ? SelectableText(content)
                                    : MarkdownBody(
                                        data: content, selectable: true),
                                const SizedBox(height: 4),
                                Text(
                                  _fmtDate(m['created_at'] as String?),
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
