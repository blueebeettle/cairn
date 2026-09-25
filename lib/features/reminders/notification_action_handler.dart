/// Handling for the "Mark done" / "Snooze 15 min" buttons on reminders.
///
/// An action button can be tapped while the app is foregrounded, backgrounded
/// or fully terminated, so the work has to be expressible without a Riverpod
/// container. [applyNotificationAction] therefore takes an open [AppDatabase]
/// and builds throwaway repositories over it — the same shape
/// `home_screen_widget_service.dart`'s background callbacks already use, and
/// for the same reason: the database is the shared source of truth and the app
/// re-reads it on resume.
///
/// [notificationActionBackgroundHandler] is the terminated-app entry point the
/// plugin requires to be a top-level function.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../core/time/time_service.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/events_repository.dart';
import '../../data/repositories/habits_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/tasks_repository.dart';
import 'notification_channels.dart';

/// What a payload refers to.
enum NotificationSubject { task, habit }

/// A validated `task:<id>` / `habit:<id>` payload.
@immutable
class NotificationTarget {
  const NotificationTarget(this.subject, this.id);

  final NotificationSubject subject;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is NotificationTarget &&
      other.subject == subject &&
      other.id == id;

  @override
  int get hashCode => Object.hash(subject, id);
}

/// What [applyNotificationAction] did, so callers and tests can assert on it.
enum NotificationActionResult {
  /// The task was completed or the habit checked off.
  markedDone,

  /// The reminder was rescheduled [snoozeDuration] out.
  snoozed,

  /// Nothing to do: unrecognised action, malformed payload, or the referenced
  /// row is missing or deleted.
  ignored,
}

/// Parses a notification payload into a target, or null if it is not one.
///
/// Deliberately strict: the payload is the only untrusted input reaching this
/// path, so anything that is not exactly a known prefix followed by a
/// non-empty id is rejected rather than coerced. Digest payloads (`digest`,
/// `habit_digest`) legitimately parse to null — they carry no actions.
NotificationTarget? parseNotificationTarget(String? payload) {
  if (payload == null) return null;
  const prefixes = {
    'task:': NotificationSubject.task,
    'habit:': NotificationSubject.habit,
  };
  for (final entry in prefixes.entries) {
    if (!payload.startsWith(entry.key)) continue;
    final id = payload.substring(entry.key.length);
    if (id.isEmpty) return null;
    return NotificationTarget(entry.value, id);
  }
  return null;
}

/// Applies [actionId] to whatever [payload] names, against [db].
///
/// Returns [NotificationActionResult.ignored] rather than throwing for every
/// failure mode — a missing row, a deleted row, a malformed payload or an
/// unknown action id. A reminder's button must never crash the app or the
/// background isolate.
///
/// [plugin] is only needed for [actionSnooze]; pass null (and it will no-op
/// the reschedule) when there is nothing to schedule with.
Future<NotificationActionResult> applyNotificationAction({
  required AppDatabase db,
  required String? actionId,
  required String? payload,
  FlutterLocalNotificationsPlugin? plugin,
  int? notificationId,
  TimeService? timeService,
}) async {
  if (actionId != actionMarkDone && actionId != actionSnooze) {
    return NotificationActionResult.ignored;
  }
  final target = parseNotificationTarget(payload);
  if (target == null) return NotificationActionResult.ignored;

  final settingsRepo = SettingsRepository(db: db);
  final deviceId = await settingsRepo.getOrCreateDeviceId();
  final time = timeService ??
      TimeService(
        dayStartOffsetMinutes:
            await settingsRepo.getInt('day_start_offset') ?? 240,
      );
  final eventsRepo =
      EventsRepository(db: db, timeService: time, deviceId: deviceId);

  // Existence check first, for both actions. `deviceId` is deliberately NOT
  // part of this test: the column records which install made the *last write*
  // (see `tables/tasks.dart`), not who owns the row, so a task restored from a
  // backup or last edited on another install would fail an ownership test it
  // should pass. The database is local to this device, so "present and live
  // here" is what ownership actually means; the real risk this guards is a
  // stale or malformed payload naming a row that is gone.
  final String title;
  switch (target.subject) {
    case NotificationSubject.task:
      final task = await (db.select(db.tasks)
            ..where((t) => t.id.equals(target.id)))
          .getSingleOrNull();
      if (task == null || task.deletedAt != null) {
        return NotificationActionResult.ignored;
      }
      title = task.title;
    case NotificationSubject.habit:
      final habit = await (db.select(db.habits)
            ..where((h) => h.id.equals(target.id)))
          .getSingleOrNull();
      if (habit == null || habit.deletedAt != null) {
        return NotificationActionResult.ignored;
      }
      title = habit.title;
  }

  if (actionId == actionSnooze) {
    await _snooze(
      plugin: plugin,
      notificationId: notificationId,
      payload: payload!,
      title: title,
      time: time,
    );
    return NotificationActionResult.snoozed;
  }

  switch (target.subject) {
    case NotificationSubject.task:
      await TasksRepository(
        db: db,
        eventsRepository: eventsRepo,
        timeService: time,
        deviceId: deviceId,
      ).completeTask(target.id);
    case NotificationSubject.habit:
      await HabitsRepository(
        db: db,
        eventsRepository: eventsRepo,
        timeService: time,
        deviceId: deviceId,
      ).check(target.id, localDate: time.todayLocalDate());
  }
  return NotificationActionResult.markedDone;
}

Future<void> _snooze({
  required FlutterLocalNotificationsPlugin? plugin,
  required int? notificationId,
  required String payload,
  required String title,
  required TimeService time,
}) async {
  if (plugin == null || notificationId == null) return;
  final fireAt = tz.TZDateTime.fromMillisecondsSinceEpoch(
    tz.local,
    time.nowUtcMs() + snoozeDuration.inMilliseconds,
  );
  await plugin.zonedSchedule(
    id: notificationId,
    title: title,
    body: 'Snoozed reminder',
    scheduledDate: fireAt,
    notificationDetails: actionableReminderDetails,
    // A snooze is a one-shot the user explicitly asked for at a precise
    // moment, so it takes the same exact mode the original reminder used.
    // If the exact-alarm permission is absent the platform degrades this to
    // inexact on its own rather than refusing it.
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    payload: payload,
  );
}

/// Background entry point for an action tapped while the app is terminated.
///
/// Must be a top-level function annotated `@pragma('vm:entry-point')` — the
/// plugin looks it up by name in a fresh isolate, which has none of the app's
/// state. Opens its own database and closes it again, exactly as
/// `homeWidgetBackgroundCallback` does.
@pragma('vm:entry-point')
Future<void> notificationActionBackgroundHandler(
  NotificationResponse response,
) async {
  if (response.actionId == null) return;
  WidgetsFlutterBinding.ensureInitialized();
  try {
    tz_data.initializeTimeZones();
  } catch (_) {
    // Already initialised, or unavailable — snooze falls back to tz.local.
  }

  final db = AppDatabase();
  final plugin = FlutterLocalNotificationsPlugin();
  try {
    await applyNotificationAction(
      db: db,
      actionId: response.actionId,
      payload: response.payload,
      plugin: plugin,
      notificationId: response.id,
    );
  } catch (e, st) {
    debugPrint('Notification action background handler failed: $e\n$st');
  } finally {
    await db.close();
  }
}
