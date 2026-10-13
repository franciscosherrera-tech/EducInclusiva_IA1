import 'package:flutter/material.dart';
import '../services/notes_service.dart';

/// Notas privadas de la psicopedagoga sobre un alumno.
class PsicoNotesTab extends StatefulWidget {
  final String studentId;
  final Color primaryColor;

  const PsicoNotesTab({
    super.key,
    required this.studentId,
    required this.primaryColor,
  });

  @override
  State<PsicoNotesTab> createState() => _PsicoNotesTabState();
}

class _PsicoNotesTabState extends State<PsicoNotesTab> {
  final _service = NotesService();
  final _controller = TextEditingController();
  List<StudentNote> _notes = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final notes = await _service.getNotes(widget.studentId);
      if (mounted) setState(() => _notes = notes);
    } catch (e) {
      debugPrint('Error al cargar notas: $e');
      if (mounted) {
        setState(() => _error =
            'No se pudieron cargar las notas (¿ejecutaste mejoras_v2.sql?).');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _saving = true);
    try {
      await _service.addNote(widget.studentId, text);
      _controller.clear();
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar la nota: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(StudentNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar nota'),
        content: const Text('¿Seguro que querés eliminar esta nota?'),
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
    if (confirmed != true) return;
    try {
      await _service.deleteNote(note.id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  String _fmt(DateTime d) {
    final l = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(l.day)}/${two(l.month)}/${l.year} ${two(l.hour)}:${two(l.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = widget.primaryColor;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Escribir una observación sobre el alumno...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Guardar nota',
                style: IconButton.styleFrom(backgroundColor: primaryColor),
                onPressed: _saving ? null : _add,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.add),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(_error!, textAlign: TextAlign.center),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: _notes.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 80),
                                Center(
                                  child: Text(
                                      'Todavía no hay notas para este alumno.'),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                              itemCount: _notes.length,
                              itemBuilder: (_, i) {
                                final n = _notes[i];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                        color: primaryColor.withValues(
                                            alpha: 0.3)),
                                  ),
                                  child: ListTile(
                                    leading: Icon(Icons.sticky_note_2_rounded,
                                        color: primaryColor),
                                    title: Text(n.body),
                                    subtitle: Text(
                                        '${n.authorName} · ${_fmt(n.createdAt)}'),
                                    trailing: IconButton(
                                      tooltip: 'Eliminar nota',
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.red),
                                      onPressed: () => _delete(n),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
        ),
      ],
    );
  }
}
