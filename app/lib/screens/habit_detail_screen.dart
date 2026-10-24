import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/heatmap.dart';
import '../widgets/log_sheet.dart';
import '../widgets/week_bars.dart';
import 'habit_editor_screen.dart';
import 'share_card_screen.dart';

class HabitDetailScreen extends StatelessWidget {
  const HabitDetailScreen({super.key, required this.habitId});
  final String habitId;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final habit = store.habitById(habitId);

    if (habit == null) {
      // Habit was deleted while this screen was open: close it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      return const Scaffold();
    }

    final theme = Theme.of(context);
    final color = Color(habit.color);
    final info = store.streakFor(habit);
    final today = dateOnly(DateTime.now());
    final doneToday = store.valueOn(habit, today) > 0;
    final thisWeek = store.weekTotal(habit);
    final lastWeek = store.weekTotal(habit, weeksAgo: 1);

    return Scaffold(
      appBar: AppBar(
        title: Text('${habit.emoji}  ${habit.name}'),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => HabitEditorScreen(habit: habit),
            )),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Row(
            children: [
              Expanded(child: _Stat(label: 'Streak', value: '🔥 ${info.current}', color: color)),
              const SizedBox(width: 10),
              Expanded(child: _Stat(label: 'Best', value: '${info.best}', color: color)),
              const SizedBox(width: 10),
              Expanded(
                child: _Stat(
                  label: 'This week',
                  value: '${store.daysDoneThisWeek(habit)}/${habit.weeklyTarget}',
                  color: color,
                ),
              ),
            ],
          ),
          if (info.current > 0 && info.bridged > 0) ...[
            const SizedBox(height: 10),
            Text(
              'A missed day was covered so your streak survived. Never miss twice!',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: color),
            onPressed: () => showLogSheet(context, habit),
            icon: Icon(doneToday ? Icons.check : Icons.add),
            label: Text(doneToday
                ? (habit.kind == HabitKind.done ? 'Done today (tap to undo)' : 'Add more today')
                : (habit.kind == HabitKind.done ? 'Mark done today' : 'Log today')),
          ),
          const SizedBox(height: 28),
          Text('Last 7 days', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
              child: WeekBars(values: store.last7(habit), color: color),
            ),
          ),
          if (habit.kind != HabitKind.done) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _Stat(
                      label: 'This week so far',
                      value: formatValue(habit.kind, thisWeek),
                      color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Stat(
                      label: 'Last week',
                      value: formatValue(habit.kind, lastWeek),
                      color: color),
                ),
              ],
            ),
          ],
          const SizedBox(height: 28),
          Text('Last 16 weeks', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Heatmap(days: store.doneDays(habit), color: color),
              ),
            ),
          ),
          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => ShareCardScreen(habitId: habit.id),
            )),
            icon: const Icon(Icons.ios_share),
            label: const Text('Share my streak'),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: tint(color, 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
