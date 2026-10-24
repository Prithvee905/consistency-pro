import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';

const List<int> _milestones = [3, 7, 14, 21, 30, 50, 75, 100, 150, 200, 365];

/// Shows a small celebration when a log pushes the streak onto a milestone.
void celebrateIfMilestone(ScaffoldMessengerState messenger, Habit h, int before, int after) {
  if (after > before && _milestones.contains(after)) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('🔥 $after-day ${h.name} streak!')));
  }
}

/// Log today's progress for a habit. For "done" habits it is a simple toggle.
Future<void> showLogSheet(BuildContext context, Habit habit) async {
  final store = StoreScope.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final today = dateOnly(DateTime.now());

  if (habit.kind == HabitKind.done) {
    final before = store.streakFor(habit).current;
    if (store.valueOn(habit, today) > 0) {
      store.clearLog(habit, today);
    } else {
      store.addLog(habit, today, 1);
      celebrateIfMilestone(messenger, habit, before, store.streakFor(habit).current);
    }
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _LogSheet(habit: habit, messenger: messenger),
  );
}

class _LogSheet extends StatefulWidget {
  const _LogSheet({required this.habit, required this.messenger});
  final Habit habit;
  final ScaffoldMessengerState messenger;

  @override
  State<_LogSheet> createState() => _LogSheetState();
}

class _LogSheetState extends State<_LogSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add(double amount) {
    final store = StoreScope.of(context);
    final h = widget.habit;
    final before = store.streakFor(h).current;
    store.addLog(h, dateOnly(DateTime.now()), amount);
    celebrateIfMilestone(widget.messenger, h, before, store.streakFor(h).current);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final h = widget.habit;
    final today = dateOnly(DateTime.now());
    final soFar = store.valueOn(h, today);
    final unit = h.kind.unit;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${h.emoji}  ${h.name}', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            soFar > 0
                ? 'Today so far: ${formatValue(h.kind, soFar)}'
                : 'Nothing logged today yet',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: unit.isEmpty ? 'How many?' : 'How many $unit?',
            ),
            onSubmitted: (_) {
              final v = double.tryParse(_controller.text.trim());
              if (v != null && v > 0) _add(v);
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.bolt, size: 18),
                label: Text('Bad day: ${formatValue(h.kind, h.minimum)}'),
                onPressed: () => _add(h.minimum),
              ),
              if (soFar > 0)
                ActionChip(
                  label: const Text('Clear today'),
                  onPressed: () {
                    store.clearLog(h, today);
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final v = double.tryParse(_controller.text.trim());
                if (v != null && v > 0) _add(v);
              },
              child: const Text('Add to today'),
            ),
          ),
        ],
      ),
    );
  }
}
