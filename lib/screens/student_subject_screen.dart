import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/material_model.dart';
import '../models/subject.dart';
import '../providers/accessibility_provider.dart';
import '../providers/new_content_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../services/activity_service.dart';
import '../services/material_cache.dart';
import '../services/material_service.dart';
import '../theme/app_colors.dart';
import '../widgets/profile_avatar_button.dart';
import 'chat_screen.dart';

/// Contenidos de una materia vistos por el alumno.
class StudentSubjectScreen extends StatefulWidget {
  final Subject subject;

  const StudentSubjectScreen({super.key, required this.subject});

  @override
  State<StudentSubjectScreen> createState() => _StudentSubjectScreenState();
}

class _StudentSubjectScreenState extends State<StudentSubjectScreen> {
  final MaterialService _materialService = MaterialService();
  final _search = TextEditingController();

  bool _isLoading = true;
  List<StudyMaterial> _materials = [];
  final Set<String> _newIds = {};
  final MaterialCache _cache = MaterialCache();
  Set<String> _cachedIds = {};
  bool _offline = false;

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadMaterials() async {
    setState(() => _isLoading = true);
    try {
      final materials =
          await _materialService.getMaterialsBySubject(widget.subject.id);
      if (!mounted) return;
      final newContent = context.read<NewContentProvider>();
      // Guardamos cuáles eran nuevos antes de marcarlos como vistos
      _newIds.addAll(
          materials.map((m) => m.id).where((id) => newContent.isNew(id)));
      setState(() {
        _materials = materials;
        _offline = MaterialService.lastLoadWasOffline;
      });
      newContent.markSeen(materials.map((m) => m.id));
      _refreshCached();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar los contenidos: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshCached() async {
    final cached = <String>{};
    for (final m in _materials) {
      if (await _cache.isCached(m)) cached.add(m.id);
    }
    if (mounted) setState(() => _cachedIds = cached);
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// Abre el archivo desde el teléfono; si todavía no está, lo descarga primero
  /// (así queda disponible sin conexión).
  Future<void> _download(StudyMaterial material) async {
    try {
      var file = await _cache.cachedFile(material);
      if (file == null) {
        _showMessage('Descargando...');
        file = await _cache.download(material);
        await _refreshCached();
      }

      final result = await OpenFilex.open(file.path);
      if (result.type == ResultType.noAppToOpen) {
        // Sin app para ese tipo de archivo: lo abrimos desde el navegador
        final uri = Uri.tryParse(material.fileUrl);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } else if (result.type != ResultType.done) {
        _showMessage('No se pudo abrir el archivo.');
        return;
      }

      ActivityService().log(
        materialId: material.id,
        subjectId: widget.subject.id,
        action: ActivityAction.download,
      );
    } catch (e) {
      debugPrint('Error al abrir/descargar: $e');
      _showMessage(
          'Sin conexión: este archivo todavía no está guardado en tu teléfono.');
    }
  }

  void _openChat({StudyMaterial? material}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          subject: widget.subject,
          initialMaterial: material,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final accessibility = Provider.of<AccessibilityProvider>(context);
    final Color primaryColor = accessibility.activePrimaryColor;
    final Color textColor = accessibility.isHighContrast
        ? Colors.white
        : (Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : AppColors.darkBlue);
    final Color cardColor = accessibility.isHighContrast
        ? Colors.grey.shade900
        : Theme.of(context).cardColor;
    final Color onPrimary =
        accessibility.isHighContrast ? Colors.black : Colors.white;
    final Color appBarFg =
        accessibility.isHighContrast ? Colors.yellowAccent : Colors.white;

    final query = _search.text.trim().toLowerCase();
    final filtered = _materials.where((m) {
      return query.isEmpty ||
          m.title.toLowerCase().contains(query) ||
          (m.description ?? '').toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: accessibility.isHighContrast
          ? Colors.black
          : Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor:
            accessibility.isHighContrast ? Colors.black : primaryColor,
        foregroundColor: appBarFg,
        leading: IconButton(
          tooltip: 'Inicio',
          icon: const Icon(Icons.home_rounded),
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
        ),
        titleSpacing: 0,
        title: Text(
          widget.subject.name,
          overflow: TextOverflow.ellipsis,
          style: accessibility.getTextStyle(
            overrideSize: accessibility.fontSize * 1.1,
            fontWeight: FontWeight.bold,
            color: appBarFg,
          ),
        ),
        actions: const [ProfileAvatarButton()],
      ),
      body: RefreshIndicator(
        onRefresh: _loadMaterials,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_offline) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off_rounded, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sin conexión: se muestra lo último que guardaste. Los archivos ya descargados se pueden abrir igual.',
                        style: accessibility.getTextStyle(
                          overrideSize: accessibility.fontSize * 0.8,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // --- Buscador desplegable de contenidos ---
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              style: accessibility.getTextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Buscar contenido...',
                prefixIcon: Icon(Icons.search, color: primaryColor),
                suffixIcon: _materials.isEmpty
                    ? null
                    : PopupMenuButton<String>(
                        tooltip: 'Ver todos los contenidos',
                        icon: Icon(Icons.arrow_drop_down_circle_outlined,
                            color: primaryColor),
                        onSelected: (title) {
                          _search.text = title;
                          setState(() {});
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: '',
                            child: Text('Todos los contenidos'),
                          ),
                          ..._materials.map(
                            (m) => PopupMenuItem(
                              value: m.title,
                              child: Text(m.title),
                            ),
                          ),
                        ],
                      ),
                filled: true,
                fillColor: cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      BorderSide(color: primaryColor.withValues(alpha: 0.4)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide:
                      BorderSide(color: primaryColor.withValues(alpha: 0.4)),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // --- Chat libre de la materia ---
            OutlinedButton.icon(
              onPressed: () => _openChat(),
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryColor,
                side: BorderSide(color: primaryColor),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.forum_rounded),
              label: Text(
                'Chatear con el Tutor IA sobre ${widget.subject.name}',
                style: accessibility.getTextStyle(
                  overrideSize: accessibility.fontSize * 0.9,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 18),

            Text(
              'Contenidos (${filtered.length})',
              style: accessibility.getTextStyle(
                overrideSize: accessibility.fontSize * 0.95,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 10),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Text(
                  _materials.isEmpty
                      ? 'Tu profe todavía no subió contenidos en esta materia.'
                      : 'No hay contenidos que coincidan con la búsqueda.',
                  textAlign: TextAlign.center,
                  style: accessibility.getTextStyle(
                    color: textColor.withValues(alpha: 0.6),
                  ),
                ),
              )
            else
              ...filtered.map(
                (material) => Card(
                  color: cardColor,
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side:
                        BorderSide(color: primaryColor.withValues(alpha: 0.3)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor:
                                  primaryColor.withValues(alpha: 0.15),
                              child: Icon(Icons.assignment_rounded,
                                  color: accessibility.isHighContrast
                                      ? Colors.yellowAccent
                                      : primaryColor),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        material.title,
                                        style: accessibility.getTextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: textColor,
                                        ),
                                      ),
                                      if (_newIds.contains(material.id))
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.redAccent,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: const Text(
                                            'NUEVO',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  Text(
                                    'Publicado el ${_formatDate(material.createdAt)}'
                                    '${_cachedIds.contains(material.id) ? ' · Disponible sin conexión' : ''}',
                                    style: accessibility.getTextStyle(
                                      overrideSize:
                                          accessibility.fontSize * 0.75,
                                      color: textColor.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (material.description != null &&
                            material.description!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            material.description!,
                            style: accessibility.getTextStyle(
                              overrideSize: accessibility.fontSize * 0.9,
                              color: textColor.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _download(material),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primaryColor,
                                side: BorderSide(color: primaryColor),
                              ),
                              icon: const Icon(Icons.download_rounded),
                              label: Text(_cachedIds.contains(material.id)
                                  ? 'Abrir'
                                  : 'Descargar'),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _openChat(material: material),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: onPrimary,
                              ),
                              icon: const Icon(Icons.auto_awesome),
                              label: const Text('Preguntar al Tutor IA'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
