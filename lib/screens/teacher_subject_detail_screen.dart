import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/subject.dart';
import '../models/material_model.dart';
import '../providers/accessibility_provider.dart';
import '../services/material_service.dart';
import '../theme/app_colors.dart';

class TeacherSubjectDetailScreen extends StatefulWidget {
  final Subject subject;

  const TeacherSubjectDetailScreen({
    super.key,
    required this.subject,
  });

  @override
  State<TeacherSubjectDetailScreen> createState() =>
      _TeacherSubjectDetailScreenState();
}

class _TeacherSubjectDetailScreenState
    extends State<TeacherSubjectDetailScreen> {
  final MaterialService _materialService = MaterialService();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  bool _isLoading = true;
  bool _isUploading = false;
  PlatformFile? _selectedFile;
  List<StudyMaterial> _materials = [];

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  String get _courseLabel =>
      '${widget.subject.year} ${widget.subject.division}'.trim();

  String _sanitizeFileName(String fileName) {
    String clean = fileName.replaceAll(RegExp(r'[^\x00-\x7F]'), '');
    clean = clean.replaceAll(RegExp(r'\s+'), '_');
    clean = clean.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '');

    if (clean.isEmpty || clean.startsWith('.')) {
      clean = 'archivo_$clean';
    }
    return clean;
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} · ${two(local.hour)}:${two(local.minute)}';
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
          SnackBar(content: Text('Error al cargar las tareas: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'doc', 'docx'],
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() => _selectedFile = result.files.first);
    }
  }

  Future<void> _handleUpload() async {
    if (_titleController.text.trim().isEmpty || _selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un título y adjunta un archivo')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final safeFile = PlatformFile(
        name: _sanitizeFileName(_selectedFile!.name),
        size: _selectedFile!.size,
        path: _selectedFile!.path,
        bytes: _selectedFile!.bytes,
        readStream: _selectedFile!.readStream,
      );

      await _materialService.uploadMaterial(
        subjectId: widget.subject.id,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        file: safeFile,
      );

      if (!mounted) return;
      _titleController.clear();
      _descController.clear();
      setState(() => _selectedFile = null);
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tarea publicada exitosamente')),
      );
      await _loadMaterials();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir el archivo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _confirmDelete(StudyMaterial material) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar tarea'),
        content: Text('¿Seguro que querés eliminar "${material.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) await _deleteMaterial(material);
  }

  Future<void> _deleteMaterial(StudyMaterial material) async {
    try {
      await _materialService.deleteMaterial(material);
      if (mounted) {
        setState(() => _materials.removeWhere((m) => m.id == material.id));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tarea eliminada correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar la tarea: $e')),
        );
      }
    }
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

    return Scaffold(
      backgroundColor: accessibility.isHighContrast
          ? Colors.black
          : Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor:
            accessibility.isHighContrast ? Colors.black : primaryColor,
        foregroundColor:
            accessibility.isHighContrast ? Colors.yellowAccent : Colors.white,
        title: Text(
          widget.subject.name,
          style: accessibility.getTextStyle(
            overrideSize: accessibility.fontSize * 1.1,
            color: accessibility.isHighContrast
                ? Colors.yellowAccent
                : Colors.white,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadMaterials,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // --- Encabezado de la materia ---
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: accessibility.isHighContrast
                      ? [Colors.grey.shade900, Colors.grey.shade900]
                      : [primaryColor, primaryColor.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: onPrimary.withValues(alpha: 0.25),
                    child: Icon(widget.subject.icon,
                        color: accessibility.isHighContrast
                            ? Colors.yellowAccent
                            : Colors.white,
                        size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.subject.name,
                          style: accessibility.getTextStyle(
                            overrideSize: accessibility.fontSize * 1.3,
                            fontWeight: FontWeight.bold,
                            color: accessibility.isHighContrast
                                ? Colors.yellowAccent
                                : Colors.white,
                          ),
                        ),
                        if (_courseLabel.isNotEmpty)
                          Text(
                            _courseLabel,
                            style: accessibility.getTextStyle(
                              overrideSize: accessibility.fontSize * 0.9,
                              color: accessibility.isHighContrast
                                  ? Colors.white70
                                  : Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        if (widget.subject.description.isNotEmpty)
                          Text(
                            widget.subject.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: accessibility.getTextStyle(
                              overrideSize: accessibility.fontSize * 0.8,
                              color: accessibility.isHighContrast
                                  ? Colors.white70
                                  : Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // --- Formulario para subir una tarea ---
            Card(
              color: cardColor,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                    color: primaryColor.withValues(alpha: 0.4), width: 1.2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.upload_file_rounded, color: primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          'Subir nueva tarea',
                          style: accessibility.getTextStyle(
                            overrideSize: accessibility.fontSize * 1.05,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Título del trabajo / tema',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Descripción o consigna (opcional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _isUploading ? null : _pickFile,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryColor,
                        side: BorderSide(color: primaryColor),
                      ),
                      icon: const Icon(Icons.attach_file),
                      label: Text(
                        _selectedFile == null
                            ? 'Adjuntar PDF o Documento'
                            : 'Archivo: ${_selectedFile!.name}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: onPrimary,
                        ),
                        onPressed: _isUploading ? null : _handleUpload,
                        icon: _isUploading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: onPrimary),
                              )
                            : const Icon(Icons.send_rounded),
                        label: const Text('Publicar Tarea'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),

            // --- Tareas publicadas ---
            Text(
              'Tareas publicadas (${_materials.length})',
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
            else if (_materials.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Todavía no subiste tareas para este curso.',
                  textAlign: TextAlign.center,
                  style: accessibility.getTextStyle(
                    color: textColor.withValues(alpha: 0.6),
                  ),
                ),
              )
            else
              ..._materials.map(
                (material) => Card(
                  color: cardColor,
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: primaryColor.withValues(alpha: 0.15),
                      child: Icon(Icons.assignment_rounded,
                          color: accessibility.isHighContrast
                              ? Colors.yellowAccent
                              : primaryColor),
                    ),
                    title: Text(
                      material.title,
                      style: accessibility.getTextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (material.description != null &&
                            material.description!.isNotEmpty)
                          Text(
                            material.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: accessibility.getTextStyle(
                              overrideSize: accessibility.fontSize * 0.85,
                              color: textColor.withValues(alpha: 0.8),
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          'Publicada el ${_formatDate(material.createdAt)}',
                          style: accessibility.getTextStyle(
                            overrideSize: accessibility.fontSize * 0.75,
                            color: textColor.withValues(alpha: 0.6),
                          ),
                        ),
                        Text(
                          material.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: accessibility.getTextStyle(
                            overrideSize: accessibility.fontSize * 0.75,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: 'Eliminar tarea',
                      onPressed: () => _confirmDelete(material),
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
