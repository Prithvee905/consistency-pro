import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';

class TaskEditorScreen extends StatefulWidget {
  const TaskEditorScreen({super.key, this.task});

  /// null = creating a new task.
  final Task? task;

  @override
  State<TaskEditorScreen> createState() => _TaskEditorScreenState();
}

class _TaskEditorScreenState extends State<TaskEditorScreen> {
  late final TextEditingController _title;
  late TimeOfDay _time;
  late Set<int> _weekdays;
  late DateTime _date;
  late bool _alarm;
  String? _habitId;
  String? _error;

  bool get _editing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _title = TextEditingController(text: t?.title ?? '');
    _time = t == null
        ? TimeOfDay.fromDateTime(DateTime.now().add(const Duration(hours: 1)))
        : TimeOfDay(hour: t.hour, minute: t.minute);
    _weekdays = {...?t?.weekdays};
    _date = (t?.oneTimeDay != null) ? AppStore.parseDayKey(t!.oneTimeDay!) : dateOnly(DateTime.now());
    _alarm = t?.alarm ?? true;
    _habitId = t?.habitId;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _pickDate() async {
    final now = dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(now) ? now : _date,
      firstDate: now,
      lastDate: addDays(now, 730),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _toggleAlarm(bool on) async {
    setState(() => _alarm = on);
    if (!on) return;
    final store = StoreScope.of(context);
    // Ask for notification permission the first time an alarm is switched on.
    if (!store.alarmPermissionAsked) {
      await store.notifications.requestPermissions();
      store.markAlarmPermissionAsked();
    }
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Give the task a name');
      return;
    }
    final store = StoreScope.of(context);
    final weekdays = _weekdays.toList()..sort();
    final oneTime = weekdays.isEmpty ? dayKey(_date) : null;

    final existing = widget.task;
    if (existing == null) {
      store.addTask(Task(
        id: newId(),
        title: title,
        hour: _time.hour,
        minute: _time.minute,
        weekdays: weekdays,
        oneTimeDay: oneTime,
        alarm: _alarm,
        habitId: _habitId,
      ));
    } else {
      existing
        ..title = title
        ..hour = _time.hour
        ..minute = _time.minute
        ..weekdays = weekdays
        ..oneTimeDay = oneTime
        ..alarm = _alarm
        ..habitId = _habitId;
      store.updateTask(existing);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit task' : 'New task'),
        actions: [
          if (_editing)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                store.deleteTask(widget.task!.id);
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _title,
            autofocus: !_editing,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: 'What do you need to do?', errorText: _error),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: const Text('Time'),
            trailing: Text(_time.format(context), style: theme.textTheme.titleMedium),
            onTap: _pickTime,
          ),
          const SizedBox(height: 4),
          Text('Repeat', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            children: [
              for (var d = 1; d <= 7; d++)
                FilterChip(
                  label: Text(kWeekdayShort[d - 1]),
                  selected: _weekdays.contains(d),
                  onSelected: (on) => setState(() {
                    if (on) {
                      _weekdays.add(d);
                    } else {
                      _weekdays.remove(d);
                    }
                  }),
                ),
            ],
          ),
          if (_weekdays.isEmpty)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: const Text('Date'),
              subtitle: const Text('Pick days above to repeat instead'),
              trailing: Text(prettyDate(_date), style: theme.textTheme.titleMedium),
              onTap: _pickDate,
            ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.alarm),
            title: const Text('Alarm'),
            subtitle: const Text('Notify me at this time'),
            value: _alarm,
            onChanged: _toggleAlarm,
          ),
          if (store.habits.isNotEmpty) ...[
            const SizedBox(height: 8),
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Counts toward a habit (optional)'),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: store.habitById(_habitId)?.id,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('None')),
                    for (final h in store.habits)
                      DropdownMenuItem<String?>(value: h.id, child: Text('${h.emoji} ${h.name}')),
                  ],
                  onChanged: (v) => setState(() => _habitId = v),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Ticking the task logs that habit\'s "bad day" version, so you never lose a streak on a busy day.',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 28),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
    );
  }
}
