import 'package:consistency/cloud.dart';
import 'package:consistency/models.dart';
import 'package:consistency/notifications.dart';
import 'package:consistency/store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppStore> _makeStore() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return AppStore.load(prefs, NotificationService(), CloudService());
}

Habit _habit() => Habit(
      id: 'h1',
      name: 'Study',
      emoji: '📚',
      color: 0xFF3B82F6,
      kind: HabitKind.minutes,
      weeklyTarget: 5,
      minimum: 15,
    );

void _logDaysAgo(AppStore s, Habit h, List<int> daysAgo) {
  final today = dateOnly(DateTime.now());
  for (final n in daysAgo) {
    s.addLog(h, addDays(today, -n), 30);
  }
}

void main() {
  group('streaks', () {
    test('consecutive days including today', () async {
      final s = await _makeStore();
      final h = _habit()..let(s.addHabit);
      _logDaysAgo(s, h, [0, 1, 2]);
      expect(s.streakFor(h).current, 3);
    });

    test('today not logged yet does not break the streak', () async {
      final s = await _makeStore();
      final h = _habit()..let(s.addHabit);
      _logDaysAgo(s, h, [1, 2]);
      expect(s.streakFor(h).current, 2);
    });

    test('one missed day is bridged', () async {
      final s = await _makeStore();
      final h = _habit()..let(s.addHabit);
      _logDaysAgo(s, h, [0, 2, 3]);
      final info = s.streakFor(h);
      expect(info.current, 3);
      expect(info.bridged, 1);
    });

    test('two missed days in a row break the streak', () async {
      final s = await _makeStore();
      final h = _habit()..let(s.addHabit);
      _logDaysAgo(s, h, [0, 3]);
      expect(s.streakFor(h).current, 1);
    });

    test('no logs means no streak', () async {
      final s = await _makeStore();
      final h = _habit()..let(s.addHabit);
      expect(s.streakFor(h).current, 0);
    });
  });

  group('tasks', () {
    test('repeating task occurs only on chosen weekdays', () {
      final t = Task(id: 't', title: 'Gym', hour: 6, minute: 30, weekdays: [1, 3, 5]);
      expect(t.occursOn(DateTime(2026, 10, 26)), isTrue); // Monday
      expect(t.occursOn(DateTime(2026, 10, 27)), isFalse); // Tuesday
    });

    test('upcoming skips days already ticked and times in the past', () {
      final now = DateTime(2026, 10, 24, 10, 0); // Saturday
      final t = Task(id: 't', title: 'Read', hour: 9, minute: 0, weekdays: [1, 2, 3, 4, 5, 6, 7]);
      t.doneDays.add('2026-10-25');
      final times = t.upcoming(now, days: 3);
      // Today 09:00 already passed, tomorrow is ticked, so only the day after.
      expect(times, [DateTime(2026, 10, 26, 9, 0)]);
    });
  });
}

extension _Let<T> on T {
  void let(void Function(T) f) => f(this);
}
