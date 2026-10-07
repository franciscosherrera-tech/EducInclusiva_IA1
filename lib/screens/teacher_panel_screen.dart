import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../models/subject.dart';
import '../providers/subject_provider.dart';
import '../services/material_service.dart';
import 'teacher_subject_detail_screen.dart';
import 'profile_screen.dart';

class TeacherPanelScreen extends StatefulWidget {
  const TeacherPanelScreen({super.key});

  @override
  State<TeacherPanelScreen> createState() => _TeacherPanelScreenState();
}

class _TeacherPanelScreenState extends State<TeacherPanelScreen> {
  final _supabase = Supabase.instance.client;
  final MaterialService _materialService = MaterialService();

  String _teacherName = 'Docente';
  String? _avatarUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTeacherData();
  }

  Future<void> _loadTeacherData() async {
    setState(() => _isLoading = true);
    await _loadTeacherProfile();
    if (mounted) {
      await Provider.of<SubjectProvider>(context, listen: false)
          .fetchSubjects();
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTeacherProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final profileData = await _supabase
          .from('profiles')
          .select('name, photo_url')
          .eq('id', user.id)
          .maybeSingle();

      if (profileData != null && mounted) {
        setState(() {
          _teacherName = profileData['name'] ?? 'Docente';
          _avatarUrl = profileData['photo_url'];
        });
      }
    } catch (_) {}
  }

  String _sanitizeFileName(String fileName) {
    String clean = fileName.replaceAll(RegExp(r'[^\x00-\x7F]'), '');
    clean = clean.replaceAll(RegExp(r'\s+'), '_');
    clean = clean.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '');

    if (clean.isEmpty || clean.startsWith('.')) {
      clean = 'archivo_$clean';
    }
    return clean;
  }

  void _showAddSubjectDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final yearController = TextEditingController();
    final divisionController = TextEditingController();

    IconData selectedIcon = Icons.school;
    const Color selectedColor = Colors.teal;

    final availableIcons = [
      Icons.school,
      Icons.book,
      Icons.calculate,
      Icons.science,
      Icons.palette,
      Icons.computer,
      Icons.fitness_center,
      Icons.biotech,
      Icons.public,
      Icons.history_edu,
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateModal) => AlertDialog(
          title: const Text(
            'Crear Nueva Materia',
            style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la Materia',
                    hintText: 'Ej. Matemáticas, Robótica',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: yearController,
                        decoration: const InputDecoration(
                          labelText: 'Año / Nivel',
                          hintText: 'Ej. 1°',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: divisionController,
                        decoration: const InputDecoration(
                          labelText: 'División',
                          hintText: 'Ej. A',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción (opcional)',
                  ),
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Elige un ícono:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: availableIcons.map((icon) {
                    final isSelected = selectedIcon == icon;
                    return InkWell(
                      onTap: () => setStateModal(() => selectedIcon = icon),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.teal.withValues(alpha: 0.15)
                              : Colors.grey.shade200,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.teal, width: 2)
                              : null,
                        ),
                        child: Icon(
                          icon,
                          color: isSelected ? Colors.teal : Colors.black87,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  final newSub = Subject(
                    id: '',
                    name: name,
                    year: yearController.text.trim(),
                    division: divisionController.text.trim(),
                    iconCode: selectedIcon.codePoint,
                    colorValue: selectedColor.value,
                    description: descController.text.trim(),
                  );

                  try {
                    await Provider.of<SubjectProvider>(context, listen: false)
                        .addSubject(newSub);
                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Materia creada con éxito')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error al crear materia: $e')),
                      );
                    }
                  }
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showUploadModal(BuildContext context, List<Subject> subjects) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _UploadMaterialModal(
        subjects: subjects,
        materialService: _materialService,
        sanitizeFileName: _sanitizeFileName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subjects = Provider.of<SubjectProvider>(context).subjects;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Docente'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 28),
            tooltip: 'Crear nueva materia',
            onPressed: () => _showAddSubjectDialog(context),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0, left: 8.0),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ).then((_) => _loadTeacherData());
              },
              borderRadius: BorderRadius.circular(20),
              child: CircleAvatar(
                backgroundColor: Colors.white24,
                backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty
                    ? NetworkImage(_avatarUrl!)
                    : null,
                child: _avatarUrl == null || _avatarUrl!.isEmpty
                    ? Text(
                        _teacherName.isNotEmpty
                            ? _teacherName[0].toUpperCase()
                            : 'D',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTeacherData,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Hola, $_teacherName 👋',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _showAddSubjectDialog(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade50,
                            foregroundColor: Colors.teal,
                            elevation: 0,
                            side: const BorderSide(color: Colors.teal),
                          ),
                          icon: const Icon(Icons.add, size: 20),
                          label: const Text('Nueva Materia'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Selecciona un curso para ver sus archivos o sube nuevo contenido:',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: subjects.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 100),
                                Center(
                                  child: Text(
                                    'No hay materias creadas.\n\nUsa el botón "+ Nueva Materia" para agregar una.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 16, color: Colors.grey),
                                  ),
                                ),
                              ],
                            )
                          : GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1.05,
                              ),
                              itemCount: subjects.length,
                              itemBuilder: (context, index) {
                                final subject = subjects[index];
                                return InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            TeacherSubjectDetailScreen(
                                          subject: subject,
                                        ),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color:
                                          subject.color.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: subject.color
                                            .withValues(alpha: 0.31),
                                        width: 1.5,
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: subject.color,
                                          child: Icon(
                                            subject.icon,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          subject.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: subject.color
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            subject.year.isNotEmpty
                                                ? '${subject.year} ${subject.division}'
                                                : 'Materia',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: subject.color,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUploadModal(context, subjects),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Subir Material'),
      ),
    );
  }
}

class _UploadMaterialModal extends StatefulWidget {
  final List<Subject> subjects;
  final MaterialService materialService;
  final String Function(String) sanitizeFileName;

  const _UploadMaterialModal({
    required this.subjects,
    required this.materialService,
    required this.sanitizeFileName,
  });

  @override
  State<_UploadMaterialModal> createState() => _UploadMaterialModalState();
}

class _UploadMaterialModalState extends State<_UploadMaterialModal> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  String? _selectedSubjectId;
  PlatformFile? _selectedFile;
  bool _isUploading = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'doc', 'docx'],
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _selectedFile = result.files.first;
      });
    }
  }

  Future<void> _handleUpload() async {
    if (_selectedSubjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una materia')),
      );
      return;
    }

    if (_titleController.text.trim().isEmpty || _selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un título y adjunta un archivo')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final cleanName = widget.sanitizeFileName(_selectedFile!.name);
      final safeFile = PlatformFile(
        name: cleanName,
        size: _selectedFile!.size,
        path: _selectedFile!.path,
        bytes: _selectedFile!.bytes,
        readStream: _selectedFile!.readStream,
      );

      await widget.materialService.uploadMaterial(
        subjectId: _selectedSubjectId!,
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        file: safeFile,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Material cargado exitosamente')),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Subir Material de Estudio',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedSubjectId,
              decoration: const InputDecoration(
                labelText: 'Materia / Curso',
                border: OutlineInputBorder(),
              ),
              items: widget.subjects.map((sub) {
                return DropdownMenuItem(
                  value: sub.id,
                  child: Text(
                      '${sub.name} ${sub.year.isNotEmpty ? "(${sub.year} ${sub.division})" : ""}'),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedSubjectId = val),
            ),
            const SizedBox(height: 12),
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
              onPressed: _pickFile,
              icon: const Icon(Icons.attach_file),
              label: Text(_selectedFile == null
                  ? 'Adjuntar PDF o Documento'
                  : 'Archivo: ${_selectedFile!.name}'),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
                onPressed: _isUploading ? null : _handleUpload,
                child: _isUploading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Publicar Material'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
