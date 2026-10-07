import 'package:flutter/material.dart';
import '../models/subject.dart';
import '../models/material_model.dart';
import '../services/material_service.dart';

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
  bool _isLoading = true;
  List<StudyMaterial> _materials = [];

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    setState(() => _isLoading = true);
    try {
      final materials =
          await _materialService.getMaterialsBySubject(widget.subject.id);
      if (mounted) {
        setState(() {
          _materials = materials;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar materiales: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteMaterial(StudyMaterial material) async {
    try {
      await _materialService.deleteMaterial(material);
      if (mounted) {
        setState(() {
          _materials.removeWhere((m) => m.id == material.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Material eliminado correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar material: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.subject.name),
            if (widget.subject.year.isNotEmpty ||
                widget.subject.division.isNotEmpty)
              Text(
                '${widget.subject.year} ${widget.subject.division}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
          ],
        ),
        backgroundColor: widget.subject.color,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _materials.isEmpty
              ? const Center(
                  child: Text(
                    'No hay materiales subidos para este curso.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadMaterials,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _materials.length,
                    itemBuilder: (context, index) {
                      final material = _materials[index];
                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            backgroundColor:
                                widget.subject.color.withValues(alpha: 0.15),
                            child: Icon(
                              Icons.insert_drive_file,
                              color: widget.subject.color,
                            ),
                          ),
                          title: Text(
                            material.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Text(
                            (material.description != null &&
                                    material.description!.isNotEmpty)
                                ? material.description!
                                : material.fileName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: 'Eliminar material',
                            onPressed: () => _deleteMaterial(material),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
