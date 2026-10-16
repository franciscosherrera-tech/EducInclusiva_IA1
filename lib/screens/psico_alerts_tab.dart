import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Alerta: un alumno consultó varias veces a la IA sobre el mismo material.
class HelpAlert {
  final String id;
  final String studentName;
  final String materialTitle;
  final String subjectName;
  final int askCount;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  const HelpAlert({
    required this.id,
    required this.studentName,
    required this.materialTitle,
    required this.subjectName,
    required this.askCount,
    required this.createdAt,
    required this.resolvedAt,
  });

  bool get isOpen => resolvedAt == null;
}

class HelpAlertService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<HelpAlert>> load() async {
    final rows = List<Map<String, dynamic>>.from(await _supabase
        .from('help_alerts')
        .select()
        .order('created_at', ascending: false)
        .limit(100));
    if (rows.isEmpty) return [];

    List<String> ids(String key) =>
        rows.map((r) => r[key]).whereType<String>().toSet().toList();

    Future<Map<String, String>> names(
        String table, String column, List<String> keys) async {
      if (keys.isEmpty) return {};
      final data = await _supabase
          .from(table)
          .select('id, $column')
          .inFilter('id', keys);
      return {
        for (final r in List<Map<String, dynamic>>.from(data))
          r['id'] as String: (r[column] ?? '').toString(),
      };
    }

    final students = await names('profiles', 'name', ids('student_id'));
    final materials =
        await names('study_materials', 'title', ids('material_id'));
    final subjects = await names('subjects', 'name', ids('subject_id'));

    return rows
        .map((r) => HelpAlert(
              id: r['id'] as String,
              studentName: students[r['student_id']] ?? 'Alumno',
              materialTitle: materials[r['material_id']] ?? 'Material',
              subjectName: subjects[r['subject_id']] ?? '',
              askCount: (r['ask_count'] as num?)?.toInt() ?? 0,
              createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
              resolvedAt: r['resolved_at'] == null
                  ? null
                  : DateTime.parse(r['resolved_at'] as String).toLocal(),
            ))
        .toList();
  }

  Future<void> resolve(String id) => _supabase.from('help_alerts').update(
      {'resolved_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);
}

/// Pestaña del panel psico: alumnos que parecen necesitar ayuda.
class PsicoAlertsTab extends StatefulWidget {
  final Color primaryColor;

  const PsicoAlertsTab({super.key, required this.primaryColor});

  @override
  State<PsicoAlertsTab> createState() => _PsicoAlertsTabState();
}

class _PsicoAlertsTabState extends State<PsicoAlertsTab>
    with AutomaticKeepAliveClientMixin {
  final _service = HelpAlertService();
  List<HelpAlert> _alerts = [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

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
      final alerts = await _service.load();
      if (mounted) setState(() => _alerts = alerts);
    } catch (e) {
      debugPrint('Error al cargar alertas: $e');
      if (mounted) {
        setState(() => _error =
            'No se pudieron cargar las alertas (¿ejecutaste alertas_y_dispositivos.sql?).');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resolve(HelpAlert alert) async {
    try {
      await _service.resolve(alert.id);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo marcar como atendida: $e')),
        );
      }
    }
  }

  String _fmt(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }

    final open = _alerts.where((a) => a.isOpen).toList();
    final done = _alerts.where((a) => !a.isOpen).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            'Se genera una alerta cuando un alumno le pregunta 3 o más veces '
            'a la IA sobre el mismo material en una semana.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (_alerts.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(child: Text('No hay alertas por ahora 🎉')),
            ),
          for (final a in open) _card(a),
          if (done.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Atendidas', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            for (final a in done) _card(a),
          ],
        ],
      ),
    );
  }

  Widget _card(HelpAlert a) {
    final color = a.isOpen ? widget.primaryColor : Colors.grey;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(
          a.isOpen
              ? Icons.notifications_active_rounded
              : Icons.check_circle_rounded,
          color: color,
        ),
        title: Text(a.studentName,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          'Consultó ${a.askCount} veces «${a.materialTitle}»'
          '${a.subjectName.isEmpty ? '' : ' · ${a.subjectName}'}\n'
          '${_fmt(a.createdAt)}',
        ),
        isThreeLine: true,
        trailing: a.isOpen
            ? TextButton(
                onPressed: () => _resolve(a),
                child: const Text('Atendida'),
              )
            : null,
      ),
    );
  }
}
