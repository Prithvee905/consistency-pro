import 'package:flutter/material.dart';

import '../models.dart';

/// Seven bars for the last 7 days (oldest left, today right).
class WeekBars extends StatelessWidget {
  const WeekBars({super.key, required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxV = values.fold<double>(0, (a, b) => b > a ? b : a);
    final today = dateOnly(DateTime.now());
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    values[i] > 0 ? compactNumber(values[i]) : '',
                    style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 22,
                    height: maxV == 0 ? 4 : 4 + 90 * (values[i] / maxV),
                    decoration: BoxDecoration(
                      color: values[i] > 0 ? color : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    letters[addDays(today, i - (values.length - 1)).weekday - 1],
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: i == values.length - 1 ? FontWeight.w700 : FontWeight.w400,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
