import 'package:flutter/material.dart';

import '../models.dart';

/// GitHub-style activity grid: one column per week (Mon-Sun), newest on the right.
class Heatmap extends StatelessWidget {
  const Heatmap({
    super.key,
    required this.days,
    required this.color,
    this.weeks = 16,
    this.cell = 14,
    this.gap = 4,
    this.emptyColor,
  });

  final Set<String> days;
  final Color color;
  final int weeks;
  final double cell;
  final double gap;
  final Color? emptyColor;

  @override
  Widget build(BuildContext context) {
    final empty = emptyColor ?? Theme.of(context).colorScheme.surfaceContainerHighest;
    return CustomPaint(
      size: Size(weeks * (cell + gap) - gap, 7 * (cell + gap) - gap),
      painter: _HeatmapPainter(
        days: days,
        color: color,
        empty: empty,
        weeks: weeks,
        cell: cell,
        gap: gap,
        today: dateOnly(DateTime.now()),
      ),
    );
  }
}

class _HeatmapPainter extends CustomPainter {
  _HeatmapPainter({
    required this.days,
    required this.color,
    required this.empty,
    required this.weeks,
    required this.cell,
    required this.gap,
    required this.today,
  });

  final Set<String> days;
  final Color color;
  final Color empty;
  final int weeks;
  final double cell;
  final double gap;
  final DateTime today;

  @override
  void paint(Canvas canvas, Size size) {
    final start = addDays(weekStart(today), -7 * (weeks - 1));
    final doneFill = Paint()..color = color;
    final emptyFill = Paint()..color = empty;
    for (var w = 0; w < weeks; w++) {
      for (var d = 0; d < 7; d++) {
        final day = addDays(start, w * 7 + d);
        if (day.isAfter(today)) continue;
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(w * (cell + gap), d * (cell + gap), cell, cell),
          const Radius.circular(3),
        );
        canvas.drawRRect(rect, days.contains(dayKey(day)) ? doneFill : emptyFill);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter old) =>
      old.days.length != days.length || old.color != color || old.empty != empty;
}
