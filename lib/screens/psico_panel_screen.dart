import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/student_settings.dart';
import '../providers/accessibility_provider.dart';
import '../providers/user_provider.dart';
import '../services/student_settings_service.dart';
import '../widgets/profile_avatar_button.dart';
import 'auth_screen.dart';
import 'psico_alerts_tab.dart';
import 'psico_materials_tab.dart';
import 'psico_subjects_tab.dart';
import 'psico_student_settings_screen.dart';
import 'psico_student_tracking_screen.dart';

String _fmtDate(String? iso) {
  if (iso == null) return '';
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

// ---------------------------------------------------------------------------
// 1) Tabla de alumnos
// ---------------------------------------------------------------------------
class PsicoPanelScreen extends StatefulWidget {
  const PsicoPanelScreen({super.key});

  @override
  State<PsicoPanelScreen> createState() => _PsicoPanelScreenState();
}

class _PsicoPanelScreenState extends State<PsicoPanelScreen> {
  static const String _filterAll = 'Todos';
  static const String _filterNoCourse = 'Sin curso';
  static const List<String> _filters = [
    _filterAll,
    'TEA',
    'TDAH',
    'Dislexia',
    'Disgrafía',
    'Disortografía',
    'Discalculia',
    'Daltonismo',
    'Lengua de señas',
    _filterNoCourse,
  ];

  final _search = TextEditingController();
  final _settingsService = StudentSettingsService();
  List<Map<String, dynamic>> _students = [];
  Map<String, StudentSettings> _settings = {};
  String _filter = _filterAll;
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
          .select('id, name, email, role, year, division')
          .order('name');
      final settings = await _settingsService.getAllSettings();
      if (!mounted) return;
      final all = List<Map<String, dynamic>>.from(data);
      setState(() {
        _students = all
            .where((p) =>
                (p['role'] ?? '').toString().toLowerCase() == 'estudiante')
            .toList();
        _settings = settings;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error al cargar alumnos: $e');
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

  StudentSettings _settingsOf(Map<String, dynamic> s) =>
      _settings[s['id']] ?? StudentSettings(studentId: s['id'] as String);

  String _courseOf(Map<String, dynamic> s) =>
      '${s['year'] ?? ''} ${s['division'] ?? ''}'.trim();

  Future<void> _openSettings(Map<String, dynamic> s, String name) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PsicoStudentSettingsScreen(
          studentId: s['id'] as String,
          studentName: name,
          year: s['year'] as String?,
          division: s['division'] as String?,
          settings: _settings[s['id']],
        ),
      ),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final accessibility = Provider.of<AccessibilityProvider>(context);
    final primaryColor = accessibility.activePrimaryColor;
    final appBarFg =
        accessibility.isHighContrast ? Colors.yellowAccent : Colors.white;

    final q = _search.text.trim().toLowerCase();
    final filtered = _students.where((s) {
      final name = (s['name'] ?? '').toString().toLowerCase();
      final email = (s['email'] ?? '').toString().toLowerCase();
      final matchesSearch = q.isEmpty || name.contains(q) || email.contains(q);
      if (!matchesSearch) return false;
      if (_filter == _filterAll) return true;
      if (_filter == _filterNoCourse) return _courseOf(s).isEmpty;
      return _settingsOf(s).activeConditions.contains(_filter);
    }).toList();

    Widget check(bool value) => value
        ? Icon(Icons.check_circle_rounded, color: primaryColor, size: 20)
        : Icon(Icons.remove, color: Colors.grey.shade400, size: 18);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor:
              accessibility.isHighContrast ? Colors.black : primaryColor,
          foregroundColor: appBarFg,
          title: const Text('Panel de psicopedagogía'),
          bottom: TabBar(
            labelColor: appBarFg,
            unselectedLabelColor: appBarFg.withValues(alpha: 0.7),
            indicatorColor: appBarFg,
            tabs: const [
              Tab(icon: Icon(Icons.groups_rounded), text: 'Alumnos'),
              Tab(icon: Icon(Icons.folder_copy_rounded), text: 'Materiales'),
              Tab(icon: Icon(Icons.menu_book_rounded), text: 'Materias'),
              Tab(
                  icon: Icon(Icons.notifications_active_rounded),
                  text: 'Alertas'),
            ],
          ),
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
            const ProfileAvatarButton(),
          ],
        ),
        body: TabBarView(
          children: [
            Column(
              children: [
                // --- Buscador + filtro ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Buscar alumno por nombre o correo',
                            prefixIcon: Icon(Icons.search, color: primaryColor),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        tooltip: 'Filtrar por condición',
                        icon: Badge(
                          isLabelVisible: _filter != _filterAll,
                          child: Icon(Icons.filter_list_rounded,
                              color: primaryColor),
                        ),
                        initialValue: _filter,
                        onSelected: (f) => setState(() => _filter = f),
                        itemBuilder: (_) => _filters
                            .map((f) => PopupMenuItem(value: f, child: Text(f)))
                            .toList(),
                      ),
                    ],
                  ),
                ),
                // --- Chips de filtro (scroll horizontal) ---
                SizedBox(
                  height: 48,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _filters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) {
                      final f = _filters[i];
                      return Center(
                        child: ChoiceChip(
                          label: Text(f),
                          selected: _filter == f,
                          selectedColor: primaryColor.withValues(alpha: 0.25),
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                      );
                    },
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
                                  child: SingleChildScrollView(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    padding: const EdgeInsets.only(bottom: 24),
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: DataTable(
                                        headingRowColor: WidgetStatePropertyAll(
                                            primaryColor.withValues(
                                                alpha: 0.12)),
                                        columnSpacing: 18,
                                        columns: const [
                                          DataColumn(label: Text('Alumno')),
                                          DataColumn(label: Text('Curso')),
                                          DataColumn(label: Text('TEA')),
                                          DataColumn(label: Text('TDAH')),
                                          DataColumn(label: Text('Dislexia')),
                                          DataColumn(label: Text('Disgrafía')),
                                          DataColumn(
                                              label: Text('Disortografía')),
                                          DataColumn(
                                              label: Text('Discalculia')),
                                          DataColumn(label: Text('Daltonismo')),
                                          DataColumn(label: Text('LSA')),
                                          DataColumn(label: Text('Acciones')),
                                        ],
                                        rows: filtered.map((s) {
                                          final name =
                                              (s['name'] ?? 'Sin nombre')
                                                  .toString();
                                          final st = _settingsOf(s);
                                          final course = _courseOf(s);
                                          return DataRow(cells: [
                                            DataCell(
                                              Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(name,
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold)),
                                                  Text(
                                                    (s['email'] ?? '')
                                                        .toString(),
                                                    style: const TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            DataCell(Text(
                                              course.isEmpty
                                                  ? 'Sin asignar'
                                                  : course,
                                              style: TextStyle(
                                                color: course.isEmpty
                                                    ? Colors.red
                                                    : null,
                                              ),
                                            )),
                                            DataCell(check(st.teaMode)),
                                            DataCell(check(st.adhd)),
                                            DataCell(check(st.dyslexia)),
                                            DataCell(check(st.dysgraphia)),
                                            DataCell(check(st.dysorthography)),
                                            DataCell(check(st.dyscalculia)),
                                            DataCell(
                                              st.colorBlindness ==
                                                      ColorBlindType.none
                                                  ? check(false)
                                                  : Text(
                                                      st.colorBlindness.label),
                                            ),
                                            DataCell(check(st.signLanguage)),
                                            DataCell(Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  tooltip: 'Configurar perfil',
                                                  icon: Icon(
                                                      Icons.settings_rounded,
                                                      color: primaryColor),
                                                  onPressed: () =>
                                                      _openSettings(s, name),
                                                ),
                                                IconButton(
                                                  tooltip:
                                                      'Seguimiento (materiales y chats)',
                                                  icon: Icon(
                                                      Icons.insights_rounded,
                                                      color: primaryColor),
                                                  onPressed: () =>
                                                      Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) =>
                                                          PsicoStudentTrackingScreen(
                                                        studentId:
                                                            s['id'] as String,
                                                        studentName: name,
                                                        year: s['year']
                                                            as String?,
                                                        division: s['division']
                                                            as String?,
                                                        settings: st,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            )),
                                          ]);
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                ),
              ],
            ),
            PsicoMaterialsTab(primaryColor: primaryColor),
            PsicoSubjectsTab(primaryColor: primaryColor),
            PsicoAlertsTab(primaryColor: primaryColor),
          ],
        ),
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
