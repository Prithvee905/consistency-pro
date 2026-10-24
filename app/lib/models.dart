import 'dart:math';

// ---------------------------------------------------------------------------
// Date helpers. Days are stored as "yyyy-MM-dd" keys so they sort as strings
// and never depend on time zones.
// ---------------------------------------------------------------------------

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// Monday of the week containing [d].
DateTime weekStart(DateTime d) => addDays(d, -(d.weekday - 1));

const List<String> kWeekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const List<String> kWeekdayLong = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
];
const List<String> kMonthShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

String prettyDate(DateTime d) =>
    '${kWeekdayLong[d.weekday - 1]}, ${d.day} ${kMonthShort[d.month - 1]}';

String newId() {
  final r = Random();
  return '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${r.nextInt(1 << 20).toRadixString(36)}';
}

// ---------------------------------------------------------------------------
// Habits (things you track: gym, running, study...)
// ---------------------------------------------------------------------------

enum HabitKind { done, minutes, distance, count }

extension HabitKindX on HabitKind {
  String get label {
    switch (this) {
      case HabitKind.done:
        return 'Done / not done';
      case HabitKind.minutes:
        return 'Minutes';
      case HabitKind.distance:
        return 'Kilometres';
      case HabitKind.count:
        return 'Count';
    }
  }

  String get unit {
    switch (this) {
      case HabitKind.done:
        return '';
      case HabitKind.minutes:
        return 'min';
      case HabitKind.distance:
        return 'km';
      case HabitKind.count:
        return '';
    }
  }
}

String compactNumber(double v) =>
    v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

String formatValue(HabitKind kind, double v) {
  switch (kind) {
    case HabitKind.done:
      return v > 0 ? 'Done' : '-';
    case HabitKind.minutes:
      if (v >= 60) {
        final h = v ~/ 60;
        final m = (v - h * 60).round();
        return m == 0 ? '${h}h' : '${h}h ${m}m';
      }
      return '${v.round()} min';
    case HabitKind.distance:
      return '${compactNumber(v)} km';
    case HabitKind.count:
      return compactNumber(v);
  }
}

class Habit {
  Habit({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    required this.kind,
    this.weeklyTarget = 5,
    this.minimum = 1,
  });

  final String id;
  String name;
  String emoji;
  int color;
  HabitKind kind;

  /// Days per week the user wants to hit (1-7). Rest days don't break anything.
  int weeklyTarget;

  /// The "bad day" version: doing at least this much still counts.
  double minimum;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'color': color,
        'kind': kind.name,
        'weeklyTarget': weeklyTarget,
        'minimum': minimum,
      };

  factory Habit.fromJson(Map<String, dynamic> j) => Habit(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Habit',
        emoji: j['emoji'] as String? ?? '⭐',
        color: (j['color'] as num?)?.toInt() ?? 0xFF2E7D5B,
        kind: HabitKind.values.firstWhere(
          (k) => k.name == j['kind'],
          orElse: () => HabitKind.done,
        ),
        weeklyTarget: (j['weeklyTarget'] as num?)?.toInt() ?? 5,
        minimum: (j['minimum'] as num?)?.toDouble() ?? 1,
      );
}

class HabitTemplate {
  const HabitTemplate(
      this.name, this.emoji, this.kind, this.weeklyTarget, this.minimum, this.color);
  final String name;
  final String emoji;
  final HabitKind kind;
  final int weeklyTarget;
  final double minimum;
  final int color;
}

const List<HabitTemplate> kHabitTemplates = [
  HabitTemplate('Gym', '🏋️', HabitKind.minutes, 4, 15, 0xFFE11D48),
  HabitTemplate('Running', '🏃', HabitKind.distance, 3, 1, 0xFFF97316),
  HabitTemplate('Study', '📚', HabitKind.minutes, 6, 25, 0xFF3B82F6),
  HabitTemplate('Reading', '📖', HabitKind.minutes, 5, 10, 0xFF8B5CF6),
  HabitTemplate('Water', '💧', HabitKind.count, 7, 4, 0xFF0EA5E9),
  HabitTemplate('Sleep early', '😴', HabitKind.done, 5, 1, 0xFF2E7D5B),
];

// ---------------------------------------------------------------------------
// Tasks (to-dos with optional alarms)
// ---------------------------------------------------------------------------

class Task {
  Task({
    required this.id,
    required this.title,
    required this.hour,
    required this.minute,
    List<int>? weekdays,
    this.oneTimeDay,
    this.alarm = true,
    this.habitId,
    Set<String>? doneDays,
  })  : weekdays = weekdays ?? <int>[],
        doneDays = doneDays ?? <String>{};

  final String id;
  String title;
  int hour;
  int minute;

  /// 1 = Monday ... 7 = Sunday. Empty means a one-time task on [oneTimeDay].
  List<int> weekdays;
  String? oneTimeDay;
  bool alarm;

  /// Ticking this task also logs the habit's "bad day" minimum.
  String? habitId;
  Set<String> doneDays;

  bool get isRepeating => weekdays.isNotEmpty;

  String get timeLabel {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m ${hour < 12 ? 'AM' : 'PM'}';
  }

  String get repeatLabel {
    if (!isRepeating) return oneTimeDay ?? '';
    if (weekdays.length == 7) return 'Every day';
    final sorted = [...weekdays]..sort();
    return sorted.map((d) => kWeekdayShort[d - 1]).join(' ');
  }

  bool occursOn(DateTime day) {
    if (isRepeating) return weekdays.contains(day.weekday);
    return oneTimeDay == dayKey(day);
  }

  bool isDoneOn(DateTime day) => doneDays.contains(dayKey(day));

  /// A one-time task from a past day that was never ticked.
  bool isOverdue(DateTime today) =>
      !isRepeating &&
      oneTimeDay != null &&
      oneTimeDay!.compareTo(dayKey(today)) < 0 &&
      doneDays.isEmpty;

  /// Alarm times in the next [days] days that are still in the future and
  /// not already ticked off.
  List<DateTime> upcoming(DateTime now, {int days = 14}) {
    final out = <DateTime>[];
    for (var i = 0; i < days; i++) {
      final d = DateTime(now.year, now.month, now.day + i);
      if (!occursOn(d)) continue;
      if (doneDays.contains(dayKey(d))) continue;
      final when = DateTime(d.year, d.month, d.day, hour, minute);
      if (when.isAfter(now)) out.add(when);
    }
    return out;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'hour': hour,
        'minute': minute,
        'weekdays': weekdays,
        'oneTimeDay': oneTimeDay,
        'alarm': alarm,
        'habitId': habitId,
        'doneDays': doneDays.toList(),
      };

  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'] as String,
        title: j['title'] as String? ?? 'Task',
        hour: (j['hour'] as num?)?.toInt() ?? 9,
        minute: (j['minute'] as num?)?.toInt() ?? 0,
        weekdays: ((j['weekdays'] as List?) ?? const [])
            .map((e) => (e as num).toInt())
            .toList(),
        oneTimeDay: j['oneTimeDay'] as String?,
        alarm: j['alarm'] as bool? ?? true,
        habitId: j['habitId'] as String?,
        doneDays: ((j['doneDays'] as List?) ?? const [])
            .map((e) => e as String)
            .toSet(),
      );
}

class StreakInfo {
  const StreakInfo({required this.current, required this.best, required this.bridged});

  /// Current streak in days (frozen days bridge gaps but are not counted).
  final int current;
  final int best;

  /// How many missed days were bridged by the "never miss twice" freezes.
  final int bridged;
}
