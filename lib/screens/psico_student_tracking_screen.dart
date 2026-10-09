import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/material_model.dart';
import '../models/student_settings.dart';
import '../providers/accessibility_provider.dart';
import '../services/tracking_service.dart';
import 'psico_panel_screen.dart';

String _fmt(DateTime? date, {bool withTime = true}) {
  if (date == null) return 'Sin actividad';
  final d = date.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  final day = '${two(d.day)}/${two(d.month)}/${d.year}';
  return withTime ? '$day ${two(d.hour)}:${two(d.minute)}' : day;
}

Future<void> _openFile(BuildContext context, StudyMaterial material) async {
  final uri = Uri.tryParse(material.fileUrl);
  final opened =
      uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudo abrir el archivo.')),
    );
  }
}

/// Registro de cómo trabaja un alumno: lo que suben sus profes y cómo lo usa.
class PsicoStudentTrackingScreen extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String? year;
  final String? division;
  final StudentSettings settings;

  const PsicoStudentTrackingScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.year,
    required this.division,
    required this.settings,
  });

  @override
  State<PsicoStudentTrackingScreen> createState() =>
      _PsicoStudentTrackingScreenState();
}

class _PsicoStudentTrackingScreenState
    extends State<PsicoStudentTrackingScreen> {
  final _service = TrackingService();
  StudentTracking? _data;
  bool _loading = true;
  String? _error;

  String get _course => '${widget.year ?? ''} ${widget.division ?? ''}'.trim();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.loadStudent(
        studentId: widget.studentId,
        year: widget.year,
        division: widget.division,
      );
      if (mounted) setState(() => _data = data);
    } catch (e) {
      debugPrint('Error al cargar el seguimiento: $e');
      if (mounted) setState(() => _error = 'No se pudo cargar el seguimiento.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openChat(ChatSummary chat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatMessagesScreen(
          chatId: chat.id,
          title: '${widget.studentName} · ${chat.subjectName}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accessibility = Provider.of<AccessibilityProvider>(context);
    final primaryColor = accessibility.activePrimaryColor;
    final appBarFg =
        accessibility.isHighContrast ? Colors.yellowAccent : Colors.white;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor:
              accessibility.isHighContrast ? Colors.black : primaryColor,
          foregroundColor: appBarFg,
          title: Text('Seguimiento de ${widget.studentName}',
              overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              tooltip: 'Actualizar',
              icon: const Icon(Icons.refresh),
              onPressed: _load,
            ),
          ],
          bottom: TabBar(
            labelColor: appBarFg,
            unselectedLabelColor: appBarFg.withValues(alpha: 0.7),
            indicatorColor: appBarFg,
            tabs: const [
              Tab(icon: Icon(Icons.insights_rounded), text: 'Resumen'),
              Tab(icon: Icon(Icons.menu_book_rounded), text: 'Por materia'),
              Tab(icon: Icon(Icons.forum_rounded), text: 'Chats'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : TabBarView(
                    children: [
                      _buildSummary(primaryColor),
                      _buildBySubject(primaryColor),
                      _buildChats(primaryColor),
                    ],
                  ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Resumen
  // -------------------------------------------------------------------------
  Widget _buildSummary(Color primaryColor) {
    final data = _data!;
    final conditions = widget.settings.activeConditions;
    final unused = data.subjects
        .where((s) => s.materials.isNotEmpty && s.chat == null)
        .toList();

    Widget stat(IconData icon, String value, String label) {
      return Container(
        width: 150,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: primaryColor),
            const SizedBox(height: 8),
            Text(value,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: primaryColor.withValues(alpha: 0.2),
                child: Text(
                  widget.studentName.isNotEmpty
                      ? widget.studentName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                      color: primaryColor, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(widget.studentName,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                  _course.isEmpty ? 'Sin curso asignado' : 'Curso $_course'),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: conditions.isEmpty
                ? [const Chip(label: Text('Sin condiciones cargadas'))]
                : conditions
                    .map((c) => Chip(
                          label: Text(c),
                          backgroundColor: primaryColor.withValues(alpha: 0.15),
                        ))
                    .toList(),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              stat(Icons.send_rounded, '${data.totalStudentMessages}',
                  'Mensajes enviados'),
              stat(Icons.forum_rounded, '${data.chats.length}',
                  'Chats abiertos'),
              stat(Icons.assignment_rounded, '${data.totalMaterials}',
                  'Contenidos de sus profes'),
              stat(Icons.schedule_rounded,
                  _fmt(data.lastActivity, withTime: false), 'Última actividad'),
            ],
          ),
          const SizedBox(height: 20),
          if (_course.isEmpty)
            const Text(
              'Asignale un curso para ver las materias y los contenidos de sus profes.',
              style: TextStyle(color: Colors.red),
            )
          else if (unused.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                const SizedBox(width: 6),
                Text('Materias con contenidos que todavía no consultó',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: primaryColor)),
              ],
            ),
            const SizedBox(height: 6),
            ...unused.map((s) => ListTile(
                  dense: true,
                  leading: Icon(s.subject.icon, color: primaryColor),
                  title: Text(s.subject.name),
                  subtitle: Text(
                      '${s.materials.length} contenido(s) · Prof. ${s.teacherName}'),
                )),
          ] else
            Row(
              children: [
                Icon(Icons.check_circle_rounded, color: primaryColor),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                      'Consultó el chat de todas las materias que tienen contenidos.'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Por materia: lo que subió el profe + cómo lo trabajó el alumno
  // -------------------------------------------------------------------------
  Widget _buildBySubject(Color primaryColor) {
    final subjects = _data!.subjects;
    if (subjects.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _course.isEmpty
                ? 'El alumno no tiene curso asignado.'
                : 'El curso $_course todavía no tiene materias.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: subjects.map((s) {
          final chat = s.chat;
          return Card(
            margin: const EdgeInsets.only(bottom: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: primaryColor.withValues(alpha: 0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: primaryColor.withValues(alpha: 0.2),
                        child: Icon(s.subject.icon, color: primaryColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.subject.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            Text('Prof. ${s.teacherName}',
                                style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Text('Lo que subió el profe (${s.materials.length})',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: primaryColor)),
                  if (s.materials.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 6),
                      child: Text('Todavía no subió contenidos.',
                          style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ...s.materials.map((m) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.assignment_rounded,
                              color: primaryColor),
                          title: Text(m.title),
                          subtitle: Text(
                              'Publicado el ${_fmt(m.createdAt, withTime: false)}'),
                          trailing: IconButton(
                            tooltip: 'Abrir archivo',
                            icon: const Icon(Icons.download_rounded),
                            onPressed: () => _openFile(context, m),
                          ),
                        )),
                  const SizedBox(height: 8),
                  Text('Cómo lo trabajó el alumno',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: primaryColor)),
                  const SizedBox(height: 4),
                  if (chat == null)
                    const Text('Todavía no usó el chat de esta materia.',
                        style: TextStyle(color: Colors.grey))
                  else
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.forum_rounded, color: primaryColor),
                      title: Text(
                          '${chat.studentMessages} mensajes del alumno · ${chat.aiMessages} del tutor'),
                      subtitle: Text('Última vez: ${_fmt(chat.lastActivity)}'),
                      trailing: TextButton(
                        onPressed: () => _openChat(chat),
                        child: const Text('Ver chat'),
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Todos los chats (incluye el Chat General y materias anteriores)
  // -------------------------------------------------------------------------
  Widget _buildChats(Color primaryColor) {
    final chats = _data!.chats;
    if (chats.isEmpty) {
      return const Center(child: Text('Este alumno todavía no tiene chats.'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: chats.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final c = chats[i];
          return ListTile(
            leading: Icon(Icons.chat_bubble_outline, color: primaryColor),
            title: Text(c.subjectName),
            subtitle: Text(
                '${c.studentMessages} mensajes del alumno · ${_fmt(c.lastActivity)}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openChat(c),
          );
        },
      ),
    );
  }
}
