import 'package:flutter/material.dart';
import '../services/tracking_service.dart';

/// Barras de actividad del alumno: últimos 7 días o últimas 4 semanas.
/// Cada barra suma mensajes al tutor (color principal) y acciones sobre
/// contenidos (color secundario).
class ActivityChart extends StatefulWidget {
  final List<DayActivity> days;
  final Color primaryColor;

  const ActivityChart({
    super.key,
    required this.days,
    required this.primaryColor,
  });

  @override
  State<ActivityChart> createState() => _ActivityChartState();
}

class _Bar {
  final String label;
  final int messages;
  final int materials;

  const _Bar(this.label, this.messages, this.materials);

  int get total => messages + materials;
}

class _ActivityChartState extends State<ActivityChart> {
  bool _weekly = false;

  static const _dayNames = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  List<_Bar> _bars() {
    final days = widget.days;
    if (days.isEmpty) return const [];

    if (!_weekly) {
      return days.sublist(days.length - 7).map((d) {
        return _Bar(_dayNames[d.day.weekday - 1], d.messages, d.materials);
      }).toList();
    }

    // 4 semanas de 7 días, terminando hoy: "Hace 3 sem." ... "Esta sem."
    final bars = <_Bar>[];
    final weeks = days.length ~/ 7;
    for (var w = 0; w < weeks; w++) {
      final chunk = days.sublist(w * 7, w * 7 + 7);
      final label = w == weeks - 1 ? 'Esta' : 'Hace ${weeks - 1 - w}';
      bars.add(_Bar(
        label,
        chunk.fold(0, (s, d) => s + d.messages),
        chunk.fold(0, (s, d) => s + d.materials),
      ));
    }
    return bars;
  }

  @override
  Widget build(BuildContext context) {
    final bars = _bars();
    final secondary = Theme.of(context).colorScheme.tertiary;
    final maxTotal = bars.fold<int>(0, (m, b) => b.total > m ? b.total : m);
    final totalAll = bars.fold<int>(0, (s, b) => s + b.total);
    const chartHeight = 110.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.primaryColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.primaryColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Actividad',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: widget.primaryColor,
                  ),
                ),
              ),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
                segments: const [
                  ButtonSegment(value: false, label: Text('7 días')),
                  ButtonSegment(value: true, label: Text('4 semanas')),
                ],
                selected: {_weekly},
                onSelectionChanged: (s) => setState(() => _weekly = s.first),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (totalAll == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('Sin actividad en este período.'),
              ),
            )
          else
            SizedBox(
              height: chartHeight + 56,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: bars.map((b) {
                  final scale = maxTotal == 0 ? 0.0 : chartHeight / maxTotal;
                  return Expanded(
                    child: Semantics(
                      label:
                          '${b.label}: ${b.messages} mensajes, ${b.materials} acciones sobre contenidos',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            b.total == 0 ? '' : '${b.total}',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            width: 22,
                            height: b.materials * scale,
                            decoration: BoxDecoration(
                              color: secondary,
                              borderRadius: b.messages == 0
                                  ? BorderRadius.circular(4)
                                  : const BorderRadius.vertical(
                                      top: Radius.circular(4)),
                            ),
                          ),
                          Container(
                            width: 22,
                            height: b.messages * scale,
                            decoration: BoxDecoration(
                              color: widget.primaryColor,
                              borderRadius: b.materials == 0
                                  ? BorderRadius.circular(4)
                                  : const BorderRadius.vertical(
                                      bottom: Radius.circular(4)),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(b.label, style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            children: [
              _Legend(color: widget.primaryColor, text: 'Mensajes al tutor'),
              _Legend(color: secondary, text: 'Descargas y consultas'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String text;

  const _Legend({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
