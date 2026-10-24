import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';

const List<String> _emojiChoices = [
  '🏋️', '🏃', '🚴', '🏊', '🧘', '📚', '📖', '✍️', '💻', '🎯', '💧', '🥗', '😴', '🎸', '🎨',
];

class HabitEditorScreen extends StatefulWidget {
  const HabitEditorScreen({super.key, this.habit});

  /// null = creating a new habit.
  final Habit? habit;

  @override
  State<HabitEditorScreen> createState() => _HabitEditorScreenState();
}

class _HabitEditorScreenState extends State<HabitEditorScreen> {
  late final TextEditingController _name;
  late final TextEditingController _minimum;
  late String _emoji;
  late int _color;
  late HabitKind _kind;
  late int _target;
  String? _error;

  bool get _editing => widget.habit != null;

  @override
  void initState() {
    super.initState();
    final h = widget.habit;
    _name = TextEditingController(text: h?.name ?? '');
    _minimum = TextEditingController(text: compactNumber(h?.minimum ?? 10));
    _emoji = h?.emoji ?? '🎯';
    _color = h?.color ?? kHabitColors.first;
    _kind = h?.kind ?? HabitKind.minutes;
    _target = h?.weeklyTarget ?? 5;
  }

  @override
  void dispose() {
    _name.dispose();
    _minimum.dispose();
    super.dispose();
  }

  void _applyTemplate(HabitTemplate t) {
    setState(() {
      _name.text = t.name;
      _emoji = t.emoji;
      _color = t.color;
      _kind = t.kind;
      _target = t.weeklyTarget;
      _minimum.text = compactNumber(t.minimum);
      _error = null;
    });
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the habit a name');
      return;
    }
    final store = StoreScope.of(context);
    final minimum = _kind == HabitKind.done
        ? 1.0
        : (double.tryParse(_minimum.text.trim()) ?? 1.0).clamp(0.1, 100000.0).toDouble();

    final existing = widget.habit;
    if (existing == null) {
      store.addHabit(Habit(
        id: newId(),
        name: name,
        emoji: _emoji,
        color: _color,
        kind: _kind,
        weeklyTarget: _target,
        minimum: minimum,
      ));
    } else {
      existing
        ..name = name
        ..emoji = _emoji
        ..color = _color
        ..kind = _kind
        ..weeklyTarget = _target
        ..minimum = minimum;
      store.updateHabit(existing);
    }
    Navigator.of(context).pop();
  }

  Future<void> _confirmDelete() async {
    final store = StoreScope.of(context);
    final nav = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this habit?'),
        content: const Text('All its logs and graphs will be removed from this phone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      store.deleteHabit(widget.habit!.id);
      nav.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit habit' : 'New habit'),
        actions: [
          if (_editing)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (!_editing) ...[
            Text('Quick start', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in kHabitTemplates)
                  ActionChip(
                    label: Text('${t.emoji} ${t.name}'),
                    onPressed: () => _applyTemplate(t),
                  ),
              ],
            ),
            const SizedBox(height: 20),
          ],
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: 'Habit name', errorText: _error),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 20),
          Text('Icon', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in _emojiChoices)
                ChoiceChip(
                  label: Text(e, style: const TextStyle(fontSize: 20)),
                  selected: _emoji == e,
                  onSelected: (_) => setState(() => _emoji = e),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Colour', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: [
              for (final c in kHabitColors)
                GestureDetector(
                  onTap: () => setState(() => _color = c),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(
                        width: 3,
                        color: _color == c ? theme.colorScheme.onSurface : Colors.transparent,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text('How do you measure it?', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<HabitKind>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: HabitKind.done, label: Text('Done')),
              ButtonSegment(value: HabitKind.minutes, label: Text('Min')),
              ButtonSegment(value: HabitKind.distance, label: Text('Km')),
              ButtonSegment(value: HabitKind.count, label: Text('Count')),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: 20),
          Text('Goal: $_target day${_target == 1 ? '' : 's'} a week',
              style: theme.textTheme.titleSmall),
          Slider(
            value: _target.toDouble(),
            min: 1,
            max: 7,
            divisions: 6,
            label: '$_target',
            onChanged: (v) => setState(() => _target = v.round()),
          ),
          Text(
            'Rest days are fine. You only need to hit your weekly goal.',
            style: theme.textTheme.bodySmall,
          ),
          if (_kind != HabitKind.done) ...[
            const SizedBox(height: 20),
            TextField(
              controller: _minimum,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Bad-day version${_kind.unit.isEmpty ? '' : ' (${_kind.unit})'}',
                helperText: 'Doing at least this much still counts and keeps your streak.',
              ),
            ),
          ],
          const SizedBox(height: 28),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
    );
  }
}
