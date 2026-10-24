import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/log_sheet.dart';
import 'habit_detail_screen.dart';
import 'habit_editor_screen.dart';
import 'profile_screen.dart';
import 'task_editor_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  void _openTaskEditor() => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const TaskEditorScreen()));

  void _openHabitEditor() => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const HabitEditorScreen()));

  @override
  Widget build(BuildContext context) {
    const pages = <Widget>[_TodayPage(), _HabitsPage(), _InsightsPage()];
    return Scaffold(
      body: SafeArea(child: pages[_tab]),
      floatingActionButton: _tab == 2
          ? null
          : FloatingActionButton.extended(
              onPressed: _tab == 0 ? _openTaskEditor : _openHabitEditor,
              icon: const Icon(Icons.add),
              label: Text(_tab == 0 ? 'Add task' : 'Add habit'),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.check_circle_outline), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.local_fire_department_outlined), label: 'Habits'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), label: 'Insights'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Today
// ---------------------------------------------------------------------------

class _TodayPage extends StatelessWidget {
  const _TodayPage();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final today = dateOnly(DateTime.now());
    final tasks = store.tasksOn(today);
    final doneCount = tasks.where((t) => t.isDoneOn(today)).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(prettyDate(today), style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 2),
                  Text(
                    store.displayName.isEmpty ? 'Today' : 'Hi, ${store.displayName}',
                    style: theme.textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Profile and sharing',
              icon: const Icon(Icons.person_outline),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ProfileScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (tasks.isNotEmpty) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$doneCount of ${tasks.length} done',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      minHeight: 10,
                      value: tasks.isEmpty ? 0 : doneCount / tasks.length,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
        ],
        Text('Habits', style: theme.textTheme.titleLarge),
        const SizedBox(height: 10),
        if (store.habits.isEmpty)
          const _StartWithTemplates()
        else
          SizedBox(
            height: 128,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: store.habits.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _HabitQuickCard(habit: store.habits[i]),
            ),
          ),
        const SizedBox(height: 24),
        Text('Tasks', style: theme.textTheme.titleLarge),
        const SizedBox(height: 10),
        if (tasks.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                'Nothing scheduled today. Tap "Add task" to set a task with an alarm.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          )
        else
          for (final t in tasks) ...[
            _TaskTile(task: t, day: today),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _StartWithTemplates extends StatelessWidget {
  const _StartWithTemplates();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Start with just one habit. Pick one to begin:'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in kHabitTemplates)
                  ActionChip(
                    label: Text('${t.emoji} ${t.name}'),
                    onPressed: () => store.addHabit(Habit(
                      id: newId(),
                      name: t.name,
                      emoji: t.emoji,
                      color: t.color,
                      kind: t.kind,
                      weeklyTarget: t.weeklyTarget,
                      minimum: t.minimum,
                    )),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HabitQuickCard extends StatelessWidget {
  const _HabitQuickCard({required this.habit});
  final Habit habit;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final color = Color(habit.color);
    final today = dateOnly(DateTime.now());
    final value = store.valueOn(habit, today);
    final done = value > 0;
    final streak = store.streakFor(habit).current;

    return SizedBox(
      width: 132,
      child: Material(
        color: done ? tint(color, 0.22) : theme.colorScheme.surfaceContainerHighest.withAlpha(110),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => showLogSheet(context, habit),
          onLongPress: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => HabitDetailScreen(habitId: habit.id),
          )),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(habit.emoji, style: const TextStyle(fontSize: 26)),
                    const Spacer(),
                    if (done) Icon(Icons.check_circle, color: color),
                  ],
                ),
                const Spacer(),
                Text(habit.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall),
                Text(
                  done ? formatValue(habit.kind, value) : (streak > 0 ? '🔥 $streak day${streak == 1 ? '' : 's'}' : 'Tap to log'),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task, required this.day});
  final Task task;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final done = task.isDoneOn(day);
    final overdue = task.isOverdue(day);
    final habit = store.habitById(task.habitId);

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Checkbox(
          value: done,
          shape: const CircleBorder(),
          onChanged: (_) {
            final before = habit == null ? 0 : store.streakFor(habit).current;
            final messenger = ScaffoldMessenger.of(context);
            store.toggleTask(task, day);
            if (habit != null) {
              celebrateIfMilestone(messenger, habit, before, store.streakFor(habit).current);
            }
          },
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: done ? TextDecoration.lineThrough : null,
            color: done ? theme.colorScheme.onSurfaceVariant : null,
          ),
        ),
        subtitle: Text(
          [
            task.timeLabel,
            if (task.isRepeating) task.repeatLabel,
            if (overdue) 'Overdue',
            if (habit != null) '${habit.emoji} ${habit.name}',
          ].join('  ·  '),
        ),
        trailing: task.alarm
            ? Icon(Icons.alarm, size: 20, color: theme.colorScheme.primary)
            : null,
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => TaskEditorScreen(task: task),
        )),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Habits
// ---------------------------------------------------------------------------

class _HabitsPage extends StatelessWidget {
  const _HabitsPage();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      children: [
        Text('Habits',
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Tap a habit to see your graphs and share your streak.',
            style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        if (store.habits.isEmpty) const _StartWithTemplates(),
        for (final h in store.habits) ...[
          _HabitCard(habit: h),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({required this.habit});
  final Habit habit;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final color = Color(habit.color);
    final info = store.streakFor(habit);
    final doneThisWeek = store.daysDoneThisWeek(habit);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => HabitDetailScreen(habitId: habit.id),
        )),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: tint(color, 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(habit.emoji, style: const TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(habit.name, style: theme.textTheme.titleMedium),
                        Text(
                          info.current > 0
                              ? '🔥 ${info.current}-day streak'
                              : 'No streak yet',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Text('$doneThisWeek/${habit.weeklyTarget}',
                      style: theme.textTheme.titleMedium?.copyWith(color: color)),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  color: color,
                  backgroundColor: tint(color, 0.15),
                  value: (doneThisWeek / habit.weeklyTarget).clamp(0.0, 1.0).toDouble(),
                ),
              ),
              const SizedBox(height: 6),
              Text('days this week', style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Insights
// ---------------------------------------------------------------------------

class _InsightsPage extends StatelessWidget {
  const _InsightsPage();

  String? _change(AppStore store, Habit h) {
    final wd = DateTime.now().weekday;
    final now = store.weekTotal(h, weeksAgo: 0, upToWeekday: wd);
    final before = store.weekTotal(h, weeksAgo: 1, upToWeekday: wd);
    if (now == 0 && before == 0) return null;
    if (before == 0) return 'New this week';
    final pct = ((now - before) / before * 100).round();
    if (pct == 0) return 'Same as last week';
    return '${pct > 0 ? '+' : ''}$pct% vs last week';
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final theme = Theme.of(context);
    final wd = DateTime.now().weekday;

    final patterns = <String>[];
    for (final h in store.habits) {
      final best = store.bestWeekday(h);
      if (best != null) {
        patterns.add('${h.emoji} You do ${h.name} most on ${kWeekdayLong[best - 1]}s.');
      }
      final skipped = store.mostSkippedWeekday(h);
      if (skipped != null && skipped != best) {
        patterns.add(
            '${h.emoji} ${kWeekdayLong[skipped - 1]}s are your toughest day for ${h.name}. Try a smaller "bad day" version then.');
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      children: [
        Text('Insights',
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        if (store.habits.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Text('Add a habit and log a few days. Your weekly summary and patterns show up here.',
                  style: theme.textTheme.bodyMedium),
            ),
          ),
        if (store.habits.isNotEmpty) ...[
          Text('This week so far', style: theme.textTheme.titleLarge),
          const SizedBox(height: 10),
          for (final h in store.habits) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(h.emoji, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(h.name, style: theme.textTheme.titleMedium),
                          Text(
                            _change(store, h) ?? 'Nothing logged yet',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      h.kind == HabitKind.done
                          ? '${store.daysDoneThisWeek(h)} days'
                          : formatValue(h.kind, store.weekTotal(h, upToWeekday: wd)),
                      style: theme.textTheme.titleMedium?.copyWith(color: Color(h.color)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 16),
          Text('Patterns', style: theme.textTheme.titleLarge),
          const SizedBox(height: 10),
          if (patterns.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  'Keep logging. After about 10 days the app starts spotting which days you do best and which you skip.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            )
          else
            for (final p in patterns) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(p, style: theme.textTheme.bodyMedium),
                ),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ],
    );
  }
}
