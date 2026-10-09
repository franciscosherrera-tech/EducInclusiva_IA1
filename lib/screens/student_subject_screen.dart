import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/material_model.dart';
import '../models/subject.dart';
import '../providers/accessibility_provider.dart';
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
      if (mounted) setState(() => _materials = materials);
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

  Future<void> _download(StudyMaterial material) async {
    final uri = Uri.tryParse(material.fileUrl);
    final opened = uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el archivo.')),
      );
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
                    side: BorderSide(
                        color: primaryColor.withValues(alpha: 0.3)),
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
                                  Text(
                                    material.title,
                                    style: accessibility.getTextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  Text(
                                    'Publicado el ${_formatDate(material.createdAt)}',
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
                              label: const Text('Descargar'),
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
