import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../core/constants/event_types.dart';
import '../../core/habits/habit_schedule.dart';
import '../../core/habits/habit_streak.dart';
import '../../core/time/time_service.dart';
import '../../data/database/app_database.dart';
import '../../data/providers/database_provider.dart';
import '../../data/repositories/events_repository.dart';
import '../../data/repositories/habits_repository.dart';
import '../../data/repositories/reminder_config_repository.dart';
import '../../data/repositories/settings_repository.dart';
import 'habit_digest_copy.dart';

/// Service managing scheduled task and habit reminder notifications per
/// PROMPT-reminders.md and SPEC.md §10.4/§11.
///
/// Owns every call into [FlutterLocalNotificationsPlugin]; nothing else touches the plugin.
///
/// Three kinds of notification come from here, each with its own id space:
/// - Task countdown reminders: one per live `task_reminder_offsets` row, id
///   allocated from the shared counter (§5) and stored on the row.
/// - Habit reminders: one per live `habit_reminder_times` row, same counter.
/// - The daily task digest: at most
///   [ReminderConfigRepository.maxRemindersPerItem] plus one notifications at
///   fixed ids 1..6 — a reserved low band, below where the shared counter
///   starts (1000), so there is nothing to persist: the Nth configured digest
///   time is always id `1 + N`.
/// - The daily habit digest: one notification at fixed id 7, for the same
///   reason.
class ReminderService {
  ReminderService({
    required this.db,
    required this.settingsRepo,
    required this.timeService,
    FlutterLocalNotificationsPlugin? plugin,
    this.habitsRepository,
    this.reminderConfigRepository,
    this.onNotificationTapped,
    this.onHabitNotificationTapped,
    this.onDigestTapped,
    this.onHabitDigestTapped,
    Random? random,
  })  : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _random = random ?? Random();

  final AppDatabase db;
  final SettingsRepository settingsRepo;
  final TimeService timeService;
  final FlutterLocalNotificationsPlugin _plugin;
  final void Function(String taskId)? onNotificationTapped;
  final void Function(String habitId)? onHabitNotificationTapped;
  final void Function()? onDigestTapped;
  final void Function()? onHabitDigestTapped;

  /// Owns the habit digest's variant choice. The copy itself lives in
  /// `habit_digest_copy.dart`, which stays deterministic — injectable here so
  /// a test can pin which variant comes out.
  final Random _random;

  /// Habit reads go through the repository — nothing outside it writes to
  /// `habits`. The fallback is only ever used for reads, which log no event,
  /// so its device id never reaches the log.
  final HabitsRepository? habitsRepository;
  late final HabitsRepository _habits = habitsRepository ??
      HabitsRepository(
        db: db,
        eventsRepository: EventsRepository(db: db, timeService: timeService),
        timeService: timeService,
        deviceId: 'reminder-service',
      );

  /// Reminder-row reads and notification-id bookkeeping go through here, for
  /// the same reason.
  final ReminderConfigRepository? reminderConfigRepository;
  late final ReminderConfigRepository _reminderConfig =
      reminderConfigRepository ??
          ReminderConfigRepository(
            db: db,
            eventsRepository: EventsRepository(db: db, timeService: timeService),
            settingsRepo: settingsRepo,
            timeService: timeService,
            deviceId: 'reminder-service',
          );

  static const String channelId = 'task_reminders';
  static const String channelName = 'Task reminders';

  /// The task digest's reserved id band is 1..[_maxDigestSlots].
  ///
  /// **Id 7 is taken too** — it is the habit digest
  /// ([habitDigestNotificationId]). Raising this constant would walk the task
  /// digest straight over it, so move the habit digest first if this ever
  /// needs to grow.
  static const int _maxDigestSlots = 6;

  /// The habit digest's fixed id, immediately after the task digest's band and
  /// far below where the shared counter starts (1000). Fixed rather than
  /// allocated for the same reason the task digest's ids are: there is then
  /// nothing to persist, and cancel-then-reschedule is always safe.
  static const int habitDigestNotificationId = 7;

  /// Settings key holding the last habit-digest variant index used, so the
  /// next digest of the same tone does not repeat the line. Same
  /// settings-backed-marker pattern as `MilestoneCelebrationController`'s
  /// `milestone_celebrated_v1`.
  static const String habitDigestLastIndexKey = 'habit_digest_last_index_v1';

  /// Default fire time for the habit digest: 20:00, in minutes past midnight.
  /// Evening, because the line it carries is about what is still open today.
  static const int defaultHabitDigestTimeMin = 20 * 60;

  static const AndroidNotificationDetails _androidDetails = AndroidNotificationDetails(
    channelId,
    channelName,
    channelDescription: 'Reminders for upcoming tasks and habits',
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );
  static const NotificationDetails _details = NotificationDetails(android: _androidDetails);

  /// Initializes the notification channel and timezone database.
  Future<void> initialize({String? tzId}) async {
    // 1. Timezone database initialization
    try {
      tz_data.initializeTimeZones();
      final effectiveTz = tzId ?? timeService.currentTzId();
      if (effectiveTz.isNotEmpty) {
        tz.setLocalLocation(tz.getLocation(effectiveTz));
      }
    } catch (_) {
      // Fallback to tz.local when id is empty or unknown
    }

    // 2. Local notifications plugin initialization
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (response) =>
          _dispatchPayload(response.payload),
    );

    // 3. Notification channel creation
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      const channel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: 'Reminders for upcoming tasks and habits',
        importance: Importance.defaultImportance,
      );
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  // ─────────────────────────────────────────────────────────────── tasks

  /// Cancels every existing countdown reminder for [task] and reschedules
  /// whichever configured offsets are still eligible.
  ///
  /// One task can now have several live `task_reminder_offsets` rows, so
  /// this always cancels all of them first — a task that went all-day, was
  /// completed, or lost its due date must not keep a stale id firing — then,
  /// only if still eligible, reschedules each row independently.
  Future<void> scheduleFor(Task task) async {
    final offsets = await _reminderConfig.taskReminderOffsets(task.id);
    for (final row in offsets) {
      if (row.notificationId != null) {
        await _plugin.cancel(id: row.notificationId!);
      }
    }
    if (offsets.isEmpty) return;

    // 1. Eligibility checks. All-day tasks have no time to count down to —
    // the daily digest covers those instead.
    if (task.dueAt == null) return;
    if (task.dueIsAllDay) return;
    if (task.status != 'open') return;
    if (task.deletedAt != null) return;

    final remindersEnabled = await settingsRepo.getBool('reminders_enabled') ?? true;
    if (!remindersEnabled) return;

    // 2. Notification content, shared by every offset for this task.
    String? projectName;
    if (task.projectId != null) {
      final project = await (db.select(db.projects)
            ..where((p) => p.id.equals(task.projectId!)))
          .getSingleOrNull();
      projectName = project?.name;
    }
    final dueLocal = timeService.toLocal(task.dueAt!);
    final timeStr = _formatTimeOfDay(dueLocal.hour, dueLocal.minute);
    final body = projectName != null ? '$projectName • $timeStr' : timeStr;

    final nowTz = tz.TZDateTime.now(tz.local);

    // 3. Schedule each configured offset independently. One in the past does
    // not cancel the others — "10 min before" can be gone while "the night
    // before" already fired or is still ahead.
    for (final row in offsets) {
      final targetMs = task.dueAt! - (row.offsetMin * 60 * 1000);
      final fireTz = tz.TZDateTime.fromMillisecondsSinceEpoch(tz.local, targetMs);
      if (!fireTz.isAfter(nowTz)) continue;

      var notifId = row.notificationId;
      if (notifId == null) {
        notifId = await settingsRepo.getNextNotificationId();
        await _reminderConfig.setTaskReminderOffsetNotificationId(row.id, notifId);
      }

      await _plugin.zonedSchedule(
        id: notifId,
        title: task.title,
        body: body,
        scheduledDate: fireTz,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'task:${task.id}',
      );
    }
  }

  /// Cancels every scheduled countdown reminder for [task].
  Future<void> cancelFor(Task task) async {
    final offsets = await _reminderConfig.taskReminderOffsets(task.id);
    for (final row in offsets) {
      if (row.notificationId != null) {
        await _plugin.cancel(id: row.notificationId!);
      }
    }
  }

  /// Reconciles all pending reminders: task countdowns, habit reminders, and
  /// the daily digest.
  ///
  /// Called on app startup, on reminder-setting changes, and by the day
  /// rollover watch — see `NavigationShell`.
  Future<void> reconcileAll() async {
    final remindersEnabled = await settingsRepo.getBool('reminders_enabled') ?? true;

    if (!remindersEnabled) {
      await _plugin.cancelAll();
      return;
    }

    // Fetch all open, non-deleted tasks that have a due date
    final openTasks = await (db.select(db.tasks)
          ..where((t) =>
              t.status.equals('open') &
              t.deletedAt.isNull() &
              t.dueAt.isNotNull()))
        .get();

    // Scheduled in parallel rather than one at a time — with dozens of open
    // dated tasks this loop was the single biggest contributor to startup
    // lag. One bad row must not stop every other task from reminding.
    await Future.wait(openTasks.map((task) async {
      try {
        await scheduleFor(task);
      } catch (e) {
        debugPrint('Task reminder reconcile failed for ${task.id}: $e');
      }
    }));

    await reconcileHabits();
    await reconcileDigest();
    await reconcileHabitDigest();
  }

  // ────────────────────────────────────────────────────────────────── habits

  /// Routes a tapped notification: `task:<id>`, `habit:<id>`, `digest` or
  /// `habit_digest`.
  ///
  /// `habit_digest` is checked before the `habit:` prefix would ever match it
  /// — it has no colon, so the two cannot collide, but the ordering is worth
  /// keeping deliberate if either string changes.
  void _dispatchPayload(String? payload) {
    if (payload == null) return;
    if (payload.startsWith('task:')) {
      onNotificationTapped?.call(payload.substring(5));
    } else if (payload == 'habit_digest') {
      onHabitDigestTapped?.call();
    } else if (payload.startsWith('habit:')) {
      onHabitNotificationTapped?.call(payload.substring(6));
    } else if (payload == 'digest') {
      onDigestTapped?.call();
    }
  }

  /// Handles the notification that cold-started the app, if one did.
  ///
  /// `onDidReceiveNotificationResponse` only fires while the app is running;
  /// a tap that launches it from dead arrives here instead.
  Future<void> dispatchLaunchNotification() async {
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp ?? false) {
        _dispatchPayload(details!.notificationResponse?.payload);
      }
    } catch (_) {
      // Unsupported platform or plugin unavailable.
    }
  }

  /// Cancels every existing reminder for [habit] and reschedules whichever
  /// configured times are still eligible.
  ///
  /// One pending notification per configured time, for the next *scheduled*
  /// day that is not already complete — never a plain daily repeat.
  /// Reminding someone about a Mon/Wed/Fri habit on Sunday is how
  /// notifications get switched off (SPEC §10.4). Because each is one-shot,
  /// the next occurrence is scheduled on every check-off, every edit, on
  /// resume and in [reconcileAll].
  Future<void> scheduleForHabit(Habit habit) async {
    // Re-read: the caller's row may predate a notification id allocated by an
    // earlier call, and cancelling with a stale id would leave a duplicate.
    final snapshot = await _habits.loadSnapshot(habit.id);
    final fresh = snapshot?.habit ?? habit;
    final times = await _reminderConfig.habitReminderTimes(fresh.id);

    for (final row in times) {
      if (row.notificationId != null) {
        await _plugin.cancel(id: row.notificationId!);
      }
    }
    if (times.isEmpty) return;

    if (snapshot == null) return;
    if (fresh.status != HabitStatuses.active || fresh.deletedAt != null) return;
    final remindersEnabled = await settingsRepo.getBool('reminders_enabled') ?? true;
    if (!remindersEnabled) return;

    // "Now" from the same clock that resolved "today" in the snapshot, so the
    // two cannot disagree about which day it is.
    final now = tz.TZDateTime.fromMillisecondsSinceEpoch(
      tz.local,
      timeService.nowUtcMs(),
    );

    final streak = snapshot.streaks.current;
    final target = fresh.targetCount;
    final unit = fresh.unitLabel;
    final String body;
    if (streak > 0) {
      body = 'Keep your $streak-day streak going';
    } else if (target > 1) {
      body = '$target${unit == null || unit.isEmpty ? '' : ' $unit'} today';
    } else {
      body = 'Due today';
    }

    for (final row in times) {
      final fireTz = nextHabitFireTime(snapshot, now, row.minutesPastMidnight);
      if (fireTz == null) continue;

      var notifId = row.notificationId;
      if (notifId == null) {
        notifId = await settingsRepo.getNextNotificationId();
        await _reminderConfig.setHabitReminderTimeNotificationId(row.id, notifId);
      }

      await _plugin.zonedSchedule(
        id: notifId,
        title: fresh.title,
        body: body,
        scheduledDate: fireTz,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'habit:${fresh.id}',
      );
    }
  }

  /// When [snapshot]'s next reminder at [minutes] past midnight should fire,
  /// strictly after [now].
  ///
  /// Today qualifies only while it is still pending — a habit already done,
  /// or marked as a rest day, is skipped to its next scheduled day. Any fire
  /// time not after [now] steps on to the following scheduled day, so this
  /// never returns the past.
  ///
  /// The reminder time is read against the LOGICAL day (SPEC §1.2). With the
  /// day starting at 04:00, a 01:30 reminder for Monday's habit fires at
  /// 01:30 on the Tuesday calendar date, which is still Monday's logical day.
  tz.TZDateTime? nextHabitFireTime(
    HabitSnapshot snapshot,
    tz.TZDateTime now,
    int minutes,
  ) {
    final rule = snapshot.rule;
    final anchor = snapshot.habit.anchorDate;

    String? date = snapshot.isScheduledToday &&
            snapshot.todayOutcome == HabitDayOutcome.pending
        ? snapshot.todayLocalDate
        : HabitSchedule.nextScheduledDate(
            rule: rule,
            anchorDate: anchor,
            localDate: snapshot.todayLocalDate,
          );

    for (var guard = 0; date != null && guard < 400; guard++) {
      final fire = _habitFireInstant(date, minutes);
      if (fire.isAfter(now)) return fire;
      date = HabitSchedule.nextScheduledDate(
        rule: rule,
        anchorDate: anchor,
        localDate: date,
      );
    }
    return null;
  }

  tz.TZDateTime _habitFireInstant(String logicalDate, int minutes) {
    final d = TimeService.parseLocalDate(logicalDate);
    final nextCalendarDay = minutes < timeService.dayStartOffsetMinutes ? 1 : 0;
    return tz.TZDateTime(
      tz.local,
      d.year,
      d.month,
      d.day + nextCalendarDay,
      minutes ~/ 60,
      minutes % 60,
    );
  }

  /// Cancels every scheduled reminder for [habit].
  Future<void> cancelForHabit(Habit habit) async {
    final times = await _reminderConfig.habitReminderTimes(habit.id);
    for (final row in times) {
      if (row.notificationId != null) {
        await _plugin.cancel(id: row.notificationId!);
      }
    }
  }

  /// Schedules every active habit's reminders and cancels the rest.
  ///
  /// Archived and deleted habits are included so reminders set before the
  /// habit was archived cannot keep firing.
  Future<void> reconcileHabits() async {
    final habits = await db.select(db.habits).get();
    // Scheduled in parallel rather than one at a time — see reconcileAll.
    await Future.wait(habits.map((habit) async {
      try {
        final live = habit.status == HabitStatuses.active && habit.deletedAt == null;
        if (live) {
          await scheduleForHabit(habit);
        } else {
          await cancelForHabit(habit);
        }
      } catch (e) {
        // One bad row must not stop every other habit from reminding.
        debugPrint('Habit reminder reconcile failed for ${habit.id}: $e');
      }
    }));
  }

  // ───────────────────────────────────────────────────────────────── digest

  /// Cancels and, if configured, reschedules the daily due-list digest — a
  /// single notification summarizing what's due today and overdue, for
  /// all-day tasks that have no specific time to count down to.
  ///
  /// Fixed low notification ids (1..[_maxDigestSlots]) mean nothing about the
  /// digest needs to be persisted: the Nth configured time is always id
  /// `1 + N`, cancel-and-reschedule is always safe, and the id space never
  /// collides with the shared counter (starts at 1000).
  ///
  /// The body reflects due/overdue counts *as of this call*, not as of the
  /// moment it actually fires — the same limitation the per-task reminders
  /// already have. Reconciling runs often enough (startup, every edit, every
  /// resume, the day-rollover watch) that this stays close enough in
  /// practice.
  Future<void> reconcileDigest() async {
    for (var i = 0; i < _maxDigestSlots; i++) {
      await _plugin.cancel(id: _digestNotificationId(i));
    }

    final digestEnabled = await settingsRepo.getBool('digest_enabled') ?? false;
    final remindersEnabled = await settingsRepo.getBool('reminders_enabled') ?? true;
    if (!digestEnabled || !remindersEnabled) return;

    final rawTimes = await settingsRepo.get('digest_times_min');
    final times = rawTimes is List
        ? (rawTimes.map((e) => (e as num).toInt()).toSet().toList()..sort())
        : <int>[];
    if (times.isEmpty) return;

    final body = await _digestBody();
    if (body == null) return;

    final nowTz = tz.TZDateTime.now(tz.local);
    for (var i = 0; i < times.length && i < _maxDigestSlots; i++) {
      final minutes = times[i];
      var fireTz = tz.TZDateTime(
        tz.local,
        nowTz.year,
        nowTz.month,
        nowTz.day,
        minutes ~/ 60,
        minutes % 60,
      );
      if (!fireTz.isAfter(nowTz)) {
        fireTz = fireTz.add(const Duration(days: 1));
      }

      await _plugin.zonedSchedule(
        id: _digestNotificationId(i),
        title: 'Today',
        body: body,
        scheduledDate: fireTz,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'digest',
      );
    }
  }

  int _digestNotificationId(int index) => 1 + index;

  /// "3 due today · 1 overdue", or null when there's nothing to say — an
  /// empty digest is worse than no digest.
  Future<String?> _digestBody() async {
    final today = timeService.todayLocalDate();
    final rows = await (db.select(db.tasks)
          ..where((t) =>
              t.status.equals('open') & t.deletedAt.isNull() & t.dueAt.isNotNull()))
        .get();

    var dueToday = 0;
    var overdue = 0;
    for (final task in rows) {
      final date = timeService.computeLocalDate(task.dueAt!);
      // 'YYYY-MM-DD' compares correctly as a plain string.
      if (date == today) {
        dueToday++;
      } else if (date.compareTo(today) < 0) {
        overdue++;
      }
    }
    if (dueToday == 0 && overdue == 0) return null;

    final parts = <String>[
      if (dueToday > 0) '$dueToday due today',
      if (overdue > 0) '$overdue overdue',
    ];
    return parts.join(' · ');
  }

  // ─────────────────────────────────────────────────────── habit digest

  /// Cancels and, if configured, reschedules the once-daily habit digest — a
  /// single "Cairn" notification whose one line is chosen from three tones by
  /// [selectHabitDigestTone].
  ///
  /// Opt-in and off by default, the same posture as the task digest: a new
  /// install gets no unrequested notifications. One configurable time rather
  /// than the task digest's list — a habit nudge is a single daily prompt, and
  /// a second one on the same day would be the same sentence again.
  ///
  /// Fixed id [habitDigestNotificationId] means nothing about the schedule has
  /// to be persisted; cancel-then-reschedule is always safe.
  ///
  /// The body reflects habit state *as of this call*, not as of the moment it
  /// actually fires — the same limitation the task digest and the per-task
  /// reminders already have. Reconciling runs often enough (startup, every
  /// reminder-setting change, the day-rollover watch) that this stays close
  /// enough in practice.
  Future<void> reconcileHabitDigest() async {
    await _plugin.cancel(id: habitDigestNotificationId);

    final digestEnabled = await settingsRepo.getBool('habit_digest_enabled') ?? false;
    final remindersEnabled = await settingsRepo.getBool('reminders_enabled') ?? true;
    if (!digestEnabled || !remindersEnabled) return;

    final today = timeService.todayLocalDate();
    final habits = [
      for (final snapshot in await _habits.loadActiveSnapshots())
        HabitDigestInput(
          currentStreak: snapshot.streaks.current,
          outcomes: snapshot.streaks.outcomes,
        ),
    ];

    final tone = selectHabitDigestTone(
      habits: habits,
      todayLocalDate: today,
      yesterdayLocalDate: TimeService.addDays(today, -1),
      startOfWeekLocalDate: timeService.startOfWeek(today),
    );
    // Nothing meaningful to say — schedule nothing, exactly as the task digest
    // does with an empty due list.
    if (tone == null) return;

    final content = selectHabitDigestBody(
      habits: habits,
      todayLocalDate: today,
      yesterdayLocalDate: TimeService.addDays(today, -1),
      startOfWeekLocalDate: timeService.startOfWeek(today),
      templateIndex: await _nextHabitDigestIndex(tone),
    );
    if (content == null) return;

    await settingsRepo.setInt(habitDigestLastIndexKey, content.templateIndex);

    final minutes = await settingsRepo.getInt('habit_digest_time_min') ??
        defaultHabitDigestTimeMin;
    final nowTz = tz.TZDateTime.now(tz.local);
    var fireTz = tz.TZDateTime(
      tz.local,
      nowTz.year,
      nowTz.month,
      nowTz.day,
      minutes ~/ 60,
      minutes % 60,
    );
    if (!fireTz.isAfter(nowTz)) {
      fireTz = fireTz.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id: habitDigestNotificationId,
      title: 'Cairn',
      body: content.body,
      scheduledDate: fireTz,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'habit_digest',
    );
  }

  /// A variant index for [tone] that is not the one used last time.
  ///
  /// Picks uniformly among the rest. With a single-variant pool there is no
  /// "rest" to pick from, so it repeats rather than looping forever looking
  /// for an alternative that does not exist.
  ///
  /// Only deduplicates within a pool. A tone change already produces a
  /// completely different sentence, so index 1 of the freeze pool following
  /// index 1 of the streak pool is not a repeat in any sense the reader would
  /// notice.
  Future<int> _nextHabitDigestIndex(HabitDigestTone tone) async {
    final count = habitDigestVariantCount(tone);
    if (count <= 1) return 0;

    final last = await settingsRepo.getInt(habitDigestLastIndexKey);
    if (last == null || last < 0 || last >= count) {
      return _random.nextInt(count);
    }

    // Draw from the count-1 indices that are not `last`, then step over it —
    // uniform across the alternatives, and no retry loop.
    final drawn = _random.nextInt(count - 1);
    return drawn >= last ? drawn + 1 : drawn;
  }

  String _formatTimeOfDay(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final m = minute.toString().padLeft(2, '0');
    return '$h12:$m $period';
  }
}

/// Provides the singleton [ReminderService].
final reminderServiceProvider = Provider<ReminderService>((ref) {
  final db = ref.watch(databaseProvider);
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  final timeService = ref.watch(timeServiceProvider);

  return ReminderService(
    db: db,
    settingsRepo: settingsRepo,
    timeService: timeService,
    onNotificationTapped: (taskId) {
      ref.read(activeTaskIdProvider.notifier).state = taskId;
      ref.read(navigationIndexProvider.notifier).state = NavTabs.tasks;
    },
    onHabitNotificationTapped: (habitId) {
      ref.read(navigationIndexProvider.notifier).state = NavTabs.habits;
      ref.read(pendingHabitDetailProvider.notifier).state = habitId;
    },
    onDigestTapped: () {
      ref.read(navigationIndexProvider.notifier).state = NavTabs.tasks;
    },
    onHabitDigestTapped: () {
      ref.read(navigationIndexProvider.notifier).state = NavTabs.habits;
    },
  );
});
