import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';

/// Schedules task alarms as local notifications.
///
/// Repeating tasks are expanded into the next ~14 days of one-off alarms and
/// re-planned every time the app opens or a task changes. This avoids
/// time-zone bugs and works the same on Android and iOS.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      // Permissions are requested later, when the user turns on their first alarm.
      const ios = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Notifications init failed: $e');
    }
  }

  /// Ask for notification (and exact-alarm) permission. Call this the first
  /// time the user switches an alarm on, not at install.
  Future<bool> requestPermissions() async {
    if (!_ready) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final ok = await android.requestNotificationsPermission() ?? false;
        await android.requestExactAlarmsPermission();
        return ok;
      }
      final ios = _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, badge: true, sound: true) ??
            false;
      }
    } catch (e) {
      debugPrint('Permission request failed: $e');
    }
    return false;
  }

  /// Replace every scheduled alarm with a fresh plan for [tasks].
  Future<void> scheduleAll(List<Task> tasks) async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
      final now = DateTime.now();
      final plan = <MapEntry<DateTime, Task>>[];
      for (final t in tasks) {
        if (!t.alarm) continue;
        for (final when in t.upcoming(now)) {
          plan.add(MapEntry(when, t));
        }
      }
      plan.sort((a, b) => a.key.compareTo(b.key));

      // iOS keeps only 64 pending notifications.
      final limit = (!kIsWeb && Platform.isIOS) ? 60 : 200;
      var id = 0;
      for (final entry in plan.take(limit)) {
        await _scheduleOne(id++, entry.value, entry.key);
      }
    } catch (e) {
      debugPrint('Scheduling failed: $e');
    }
  }

  Future<void> _scheduleOne(int id, Task task, DateTime when) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'task_alarms',
        'Task alarms',
        channelDescription: 'Alarms for your scheduled tasks',
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
      ),
      iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
    );
    // Using UTC is fine: we pass an absolute instant computed from local time.
    final instant = tz.TZDateTime.from(when, tz.UTC);
    try {
      await _plugin.zonedSchedule(
        id,
        task.title,
        'Time for it. Tap to open Consistency.',
        instant,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      // Exact alarms not allowed: fall back to an inexact (still on-time-ish) alarm.
      await _plugin.zonedSchedule(
        id,
        task.title,
        'Time for it. Tap to open Consistency.',
        instant,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }
}
