import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cloud.dart';
import 'models.dart';
import 'notifications.dart';

/// Everything the app knows, saved on the phone as one JSON blob.
class AppStore extends ChangeNotifier {
  AppStore._(this._prefs, this.notifications, this.cloud);

  final SharedPreferences _prefs;
  final NotificationService notifications;
  final CloudService cloud;

  static const String _key = 'consistency_v1';

  /// A missed day can be bridged at most this many times inside one streak,
  /// and never two days in a row ("never miss twice").
  static const int maxBridges = 2;

  List<Habit> habits = [];
  List<Task> tasks = [];

  /// habitId -> (dayKey -> value). A value > 0 means the day counts.
  Map<String, Map<String, double>> logs = {};

  String displayName = '';
  String slug = '';
  bool published = false;
  bool alarmPermissionAsked = false;

  factory AppStore.load(
    SharedPreferences prefs,
    NotificationService notifications,
    CloudService cloud,
  ) {
    final s = AppStore._(prefs, notifications, cloud);
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        s.habits = ((j['habits'] as List?) ?? const [])
            .map((e) => Habit.fromJson(e as Map<String, dynamic>))
            .toList();
        s.tasks = ((j['tasks'] as List?) ?? const [])
            .map((e) => Task.fromJson(e as Map<String, dynamic>))
            .toList();
        final rawLogs = (j['logs'] as Map?) ?? const {};
        s.logs = rawLogs.map((hid, days) => MapEntry(
              hid as String,
              (days as Map).map((d, v) => MapEntry(d as String, (v as num).toDouble())),
            ));
        s.displayName = j['displayName'] as String? ?? '';
        s.slug = j['slug'] as String? ?? '';
        s.published = j['published'] as bool? ?? false;
        s.alarmPermissionAsked = j['alarmPermissionAsked'] as bool? ?? false;
      } catch (e) {
        debugPrint('Could not read saved data: $e');
      }
    }
    return s;
  }

  Future<void> _save() async {
    final j = {
      'habits': habits.map((h) => h.toJson()).toList(),
      'tasks': tasks.map((t) => t.toJson()).toList(),
      'logs': logs,
      'displayName': displayName,
      'slug': slug,
      'published': published,
      'alarmPermissionAsked': alarmPermissionAsked,
    };
    await _prefs.setString(_key, jsonEncode(j));
  }

  void _changed({bool reschedule = false}) {
    notifyListeners();
    _save();
    if (reschedule) rescheduleAlarms();
  }

  Future<void> rescheduleAlarms() => notifications.scheduleAll(tasks);

  Habit? habitById(String? id) {
    if (id == null) return null;
    for (final h in habits) {
      if (h.id == id) return h;
    }
    return null;
  }

  // ------------------------------------------------------------------ habits

  void addHabit(Habit h) {
    habits.add(h);
    _changed();
  }

  void updateHabit(Habit h) => _changed();

  void deleteHabit(String id) {
    habits.removeWhere((h) => h.id == id);
    logs.remove(id);
    for (final t in tasks) {
      if (t.habitId == id) t.habitId = null;
    }
    _changed();
  }

  // -------------------------------------------------------------------- logs

  double valueOn(Habit h, DateTime day) => logs[h.id]?[dayKey(day)] ?? 0;

  void addLog(Habit h, DateTime day, double amount) {
    final m = logs.putIfAbsent(h.id, () => {});
    final k = dayKey(day);
    final next = (m[k] ?? 0) + amount;
    if (next <= 0) {
      m.remove(k);
    } else {
      m[k] = next;
    }
    _changed();
  }

  void clearLog(Habit h, DateTime day) {
    logs[h.id]?.remove(dayKey(day));
    _changed();
  }

  Set<String> doneDays(Habit h) {
    final m = logs[h.id];
    if (m == null) return <String>{};
    return m.entries.where((e) => e.value > 0).map((e) => e.key).toSet();
  }

  // ------------------------------------------------------------------ streaks

  /// Current + best streak.
  ///
  /// * Today not being logged yet does not break the streak.
  /// * One missed day can be bridged (up to [maxBridges] times per streak),
  ///   but never two missed days in a row.
  StreakInfo streakFor(Habit h) {
    final days = doneDays(h);
    if (days.isEmpty) return const StreakInfo(current: 0, best: 0, bridged: 0);
    final today = dateOnly(DateTime.now());

    bool done(DateTime d) => days.contains(dayKey(d));
    bool activityBefore(DateTime d) {
      final k = dayKey(d);
      return days.any((x) => x.compareTo(k) < 0);
    }

    var cursor = done(today) ? today : addDays(today, -1);
    var current = 0;
    var bridged = 0;
    var lastWasBridge = false;
    while (true) {
      if (done(cursor)) {
        current++;
        lastWasBridge = false;
      } else if (!lastWasBridge && bridged < maxBridges && activityBefore(cursor)) {
        bridged++;
        lastWasBridge = true;
      } else {
        break;
      }
      cursor = addDays(cursor, -1);
    }

    // Best = longest run of plain consecutive days ever logged.
    final sorted = days.map(parseDayKey).toList()..sort();
    var best = 1;
    var run = 1;
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i].difference(sorted[i - 1]).inHours.abs() <= 25 &&
          dayKey(addDays(sorted[i - 1], 1)) == dayKey(sorted[i])) {
        run++;
      } else {
        run = 1;
      }
      best = max(best, run);
    }
    return StreakInfo(current: current, best: max(best, current), bridged: bridged);
  }

  static DateTime parseDayKey(String k) {
    final p = k.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  // ------------------------------------------------------------------ weekly

  /// Days logged in the current Mon-Sun week.
  int daysDoneThisWeek(Habit h) {
    final days = doneDays(h);
    final start = weekStart(DateTime.now());
    var n = 0;
    for (var i = 0; i < 7; i++) {
      if (days.contains(dayKey(addDays(start, i)))) n++;
    }
    return n;
  }

  /// Sum of values for the week [weeksAgo] weeks back, counting only the
  /// first [upToWeekday] days (1-7), so "this week so far" is compared fairly
  /// against the same days last week.
  double weekTotal(Habit h, {int weeksAgo = 0, int upToWeekday = 7}) {
    final start = addDays(weekStart(DateTime.now()), -7 * weeksAgo);
    var total = 0.0;
    for (var i = 0; i < upToWeekday; i++) {
      total += valueOn(h, addDays(start, i));
    }
    return total;
  }

  /// Values for the last 7 days, oldest first, ending today.
  List<double> last7(Habit h) {
    final today = dateOnly(DateTime.now());
    return [for (var i = 6; i >= 0; i--) valueOn(h, addDays(today, -i))];
  }

  /// Weekday (1-7) the user logs most on, or null with too little data.
  int? bestWeekday(Habit h) {
    final days = doneDays(h);
    if (days.length < 6) return null;
    final counts = List<int>.filled(8, 0);
    for (final k in days) {
      counts[parseDayKey(k).weekday]++;
    }
    var bestDay = 1;
    for (var d = 2; d <= 7; d++) {
      if (counts[d] > counts[bestDay]) bestDay = d;
    }
    return counts[bestDay] == 0 ? null : bestDay;
  }

  /// Weekday (1-7) with the most misses over the last 8 weeks, or null.
  int? mostSkippedWeekday(Habit h) {
    final days = doneDays(h);
    if (days.length < 10) return null;
    final today = dateOnly(DateTime.now());
    final missed = List<int>.filled(8, 0);
    for (var i = 1; i <= 56; i++) {
      final d = addDays(today, -i);
      if (!days.contains(dayKey(d))) missed[d.weekday]++;
    }
    var worst = 1;
    for (var d = 2; d <= 7; d++) {
      if (missed[d] > missed[worst]) worst = d;
    }
    return worst;
  }

  // -------------------------------------------------------------------- tasks

  List<Task> tasksOn(DateTime day) {
    final today = dateOnly(DateTime.now());
    final list = tasks
        .where((t) =>
            t.occursOn(day) ||
            t.isDoneOn(day) ||
            (dateOnly(day) == today && t.isOverdue(today)))
        .toList();
    list.sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
    return list;
  }

  void addTask(Task t) {
    tasks.add(t);
    _changed(reschedule: true);
  }

  void updateTask(Task t) => _changed(reschedule: true);

  void deleteTask(String id) {
    tasks.removeWhere((t) => t.id == id);
    _changed(reschedule: true);
  }

  /// Tick / untick a task for [day]. A task linked to a habit also logs that
  /// habit's "bad day" minimum (and takes it back if you untick).
  void toggleTask(Task t, DateTime day) {
    final k = dayKey(day);
    final habit = habitById(t.habitId);
    if (t.doneDays.contains(k)) {
      t.doneDays.remove(k);
      if (habit != null) {
        addLog(habit, day, -(habit.kind == HabitKind.done ? 1 : habit.minimum));
      }
    } else {
      t.doneDays.add(k);
      if (habit != null) {
        addLog(habit, day, habit.kind == HabitKind.done ? 1 : habit.minimum);
      }
    }
    _changed(reschedule: true);
  }

  // ----------------------------------------------------------------- profile

  void setDisplayName(String name) {
    displayName = name.trim();
    _changed();
  }

  void markAlarmPermissionAsked() {
    alarmPermissionAsked = true;
    _changed();
  }

  /// Data for the public share page. Only what the user chose to publish:
  /// name, habit names and day counts. No location, no task titles.
  Map<String, dynamic> publicProfile() {
    return {
      'name': displayName.isEmpty ? 'Someone consistent' : displayName,
      'habits': [
        for (final h in habits)
          () {
            final info = streakFor(h);
            final today = dateOnly(DateTime.now());
            final days = doneDays(h);
            final recent = [
              for (var i = 0; i < 112; i++)
                if (days.contains(dayKey(addDays(today, -i)))) dayKey(addDays(today, -i)),
            ];
            return {
              'name': h.name,
              'emoji': h.emoji,
              'color': h.color,
              'streak': info.current,
              'best': info.best,
              'weeklyDone': daysDoneThisWeek(h),
              'weeklyTarget': h.weeklyTarget,
              'days': recent,
            };
          }(),
      ],
    };
  }

  String ensureSlug() {
    if (slug.isEmpty) {
      const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
      final r = Random.secure();
      slug = List.generate(10, (_) => chars[r.nextInt(chars.length)]).join();
      _changed();
    }
    return slug;
  }

  Future<void> publish() async {
    final s = ensureSlug();
    await cloud.publish(s, publicProfile());
    published = true;
    _changed();
  }

  Future<void> unpublish() async {
    if (slug.isNotEmpty) await cloud.unpublish(slug);
    slug = '';
    published = false;
    _changed();
  }
}

/// Makes the store available to every screen: `StoreScope.of(context)`.
class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child})
      : super(notifier: store);

  static AppStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}
