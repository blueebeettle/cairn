import 'dart:math';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/notifications/notification_permission_helper.dart';
import 'package:habit_tracker/core/time/time_service.dart';
import 'package:habit_tracker/data/database/app_database.dart' hide TimerState;
import 'package:habit_tracker/data/dev/seed_data.dart';
import 'package:habit_tracker/data/providers/database_provider.dart';
import 'package:habit_tracker/data/repositories/events_repository.dart';
import 'package:habit_tracker/data/repositories/reminder_config_repository.dart';
import 'package:habit_tracker/data/repositories/habits_repository.dart';
import 'package:habit_tracker/data/repositories/settings_repository.dart';
import 'package:habit_tracker/data/repositories/tasks_repository.dart';
import 'package:habit_tracker/data/repositories/timer_repository.dart';
import 'package:habit_tracker/features/reminders/notification_action_handler.dart';
import 'package:habit_tracker/features/reminders/notification_channels.dart';
import 'package:habit_tracker/features/reminders/reminder_copy.dart';
import 'package:habit_tracker/features/reminders/reminder_service.dart';
import 'package:habit_tracker/features/settings/presentation/settings_screen.dart';
import 'package:habit_tracker/features/tasks/presentation/widgets/task_detail_sheet.dart';
import 'package:habit_tracker/features/timer/domain/timer_state.dart';
import 'package:habit_tracker/features/timer/presentation/timer_controller.dart';
import 'package:habit_tracker/theme/app_theme.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Fake plugin to verify flutter_local_notifications calls without platform channels.
class FakeFlutterLocalNotificationsPlugin implements FlutterLocalNotificationsPlugin {
  final Map<int, ZonedScheduleCall> scheduledNotifications = {};

  /// Every zonedSchedule call in order, including ones later cancelled — the
  /// id-keyed map above loses a reschedule's history.
  final List<ZonedScheduleCall> scheduleLog = [];
  final List<int> cancelledIds = [];
  bool allCancelled = false;

  /// Captured from [initialize], so a test can assert iOS was configured.
  InitializationSettings? initializationSettings;
  DidReceiveBackgroundNotificationResponseCallback? backgroundHandler;

  Duration initDelay = Duration.zero;
  bool isInitializing = false;
  bool initializeCalled = false;
  DateTime? initializeStartTime;
  DateTime? initializeEndTime;

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback? onDidReceiveBackgroundNotificationResponse,
  }) async {
    initializeCalled = true;
    isInitializing = true;
    initializeStartTime = DateTime.now();
    if (initDelay > Duration.zero) {
      await Future.delayed(initDelay);
    }
    initializationSettings = settings;
    backgroundHandler = onDidReceiveBackgroundNotificationResponse;
    initializeEndTime = DateTime.now();
    isInitializing = false;
    return true;
  }

  @override
  Future<void> zonedSchedule({
    required int id,
    String? title,
    String? body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    scheduledNotifications[id] = ZonedScheduleCall(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      payload: payload,
      androidScheduleMode: androidScheduleMode,
      matchDateTimeComponents: matchDateTimeComponents,
      notificationDetails: notificationDetails,
    );
    scheduleLog.add(scheduledNotifications[id]!);
  }

  @override
  Future<void> cancel({required int id, String? tag}) async {
    scheduledNotifications.remove(id);
    cancelledIds.add(id);
  }

  @override
  Future<void> cancelAll() async {
    scheduledNotifications.clear();
    allCancelled = true;
  }

  @override
  T? resolvePlatformSpecificImplementation<T extends FlutterLocalNotificationsPlatform>() => null;

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async {
    return scheduledNotifications.values
        .map((s) => PendingNotificationRequest(
              s.id,
              s.title,
              s.body,
              s.payload,
            ))
        .toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class ZonedScheduleCall {
  final int id;
  final String? title;
  final String? body;
  final tz.TZDateTime scheduledDate;
  final String? payload;

  /// Captured so tests can assert exact-vs-inexact scheduling (Requirement A).
  final AndroidScheduleMode? androidScheduleMode;

  /// Captured so tests can assert true OS-level daily recurrence
  /// (Requirement B).
  final DateTimeComponents? matchDateTimeComponents;

  /// Captured so tests can assert importance/priority and action buttons
  /// (Requirement D).
  final NotificationDetails? notificationDetails;

  ZonedScheduleCall({
    required this.id,
    this.title,
    this.body,
    required this.scheduledDate,
    this.payload,
    this.androidScheduleMode,
    this.matchDateTimeComponents,
    this.notificationDetails,
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();

  late AppDatabase db;
  late SettingsRepository settingsRepo;
  late FakeFlutterLocalNotificationsPlugin fakePlugin;
  late ReminderService reminderService;
  late TasksRepository tasksRepo;
  late EventsRepository eventsRepo;
  late TimerRepository timerRepo;
  late TimeService timeService;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    settingsRepo = SettingsRepository(db: db);
    fakePlugin = FakeFlutterLocalNotificationsPlugin();
    timeService = const TimeService();
    reminderService = ReminderService(
      db: db,
      settingsRepo: settingsRepo,
      timeService: timeService,
      plugin: fakePlugin,
    );
    await reminderService.initialize();

    eventsRepo = EventsRepository(db: db, timeService: timeService);
    tasksRepo = TasksRepository(
      db: db,
      eventsRepository: eventsRepo,
      timeService: timeService,
      reminderService: reminderService,
    );
    timerRepo = TimerRepository(db: db, deviceId: 'test-device');
  });

  tearDown(() async {
    await db.close();
  });

  /// A task's live countdown-reminder rows, ascending by offset.
  Future<List<TaskReminderOffset>> taskOffsets(String taskId) {
    return (db.select(db.taskReminderOffsets)
          ..where((r) => r.taskId.equals(taskId)))
        .get();
  }

  group('Part A — Timer Settings Invariant Tests', () {
    test('Set 50 min, start session, change to 10 min mid-run: countdown unchanged; next session is 10 min', () async {
      var currentSetting = 3000; // 50 min in seconds
      var simulatedTimeMs = 1726300000000;

      final controller = TimerController(
        eventsRepository: eventsRepo,
        timerRepository: timerRepo,
        timeService: timeService,
        clock: () => simulatedTimeMs,
        getSessionLengthSeconds: () => currentSetting,
        getBreakLengthSeconds: () => 300,
        getLongBreakLengthSeconds: () => 900,
        getSessionsBeforeLongBreak: () => 4,
      );

      // Start the 50-minute session
      await controller.startSession();
      expect(controller.state.status, equals(TimerStatus.running));
      expect(controller.state.plannedDurationS, equals(3000));
      expect(controller.state.computeRemainingSeconds(simulatedTimeMs), equals(3000));

      // Advance clock by 10 minutes (600s)
      simulatedTimeMs += 600 * 1000;
      expect(controller.state.computeRemainingSeconds(simulatedTimeMs), equals(2400));

      // User changes setting to 10 minutes (600s) mid-session
      currentSetting = 600;
      controller.onSessionLengthSettingChanged(600);

      // Invariant: The running session must NOT change its planned duration or remaining time!
      expect(controller.state.plannedDurationS, equals(3000));
      expect(controller.state.computeRemainingSeconds(simulatedTimeMs), equals(2400));

      // Complete this session
      await controller.completeSession();
      expect(controller.state.status, equals(TimerStatus.completed));

      // Reset to idle
      controller.resetToIdle();
      expect(controller.state.status, equals(TimerStatus.idle));
      expect(controller.state.plannedDurationS, equals(600));

      // Next session starts with the new setting (10 minutes)
      await controller.startSession();
      expect(controller.state.status, equals(TimerStatus.running));
      expect(controller.state.plannedDurationS, equals(600));
      expect(controller.state.computeRemainingSeconds(simulatedTimeMs), equals(600));
    });
  });

  group('Part B — Task Reminders Lifecycle & Scheduling', () {
    test('Allocates monotonic notification IDs starting at 1000', () async {
      final id1 = await settingsRepo.getNextNotificationId();
      final id2 = await settingsRepo.getNextNotificationId();
      final id3 = await settingsRepo.getNextNotificationId();

      expect(id1, equals(1000));
      expect(id2, equals(1001));
      expect(id3, equals(1002));
    });

    // Reminder reconciliation schedules every task/habit in parallel
    // (ReminderService.reconcileAll/reconcileHabits use Future.wait), so
    // several rows that all still need a fresh id call this at the same
    // moment. Without the transaction in getNextNotificationId the
    // read-then-write interleaves and two callers are handed the same id,
    // silently collapsing two reminders into one Android notification.
    test('Allocates distinct notification IDs under concurrent callers', () async {
      const callers = 25;

      final ids = await Future.wait(
        List.generate(callers, (_) => settingsRepo.getNextNotificationId()),
      );

      expect(ids.toSet().length, equals(callers),
          reason: 'every concurrent caller must get its own id');
      expect(ids.toSet(), equals({for (var i = 0; i < callers; i++) 1000 + i}),
          reason: 'ids must stay a contiguous monotonic block, no gaps');
      expect(await settingsRepo.getInt('next_notification_id'),
          equals(1000 + callers),
          reason: 'counter must land exactly one past the last id handed out');
    });

    test('Creates task with future due date -> schedules reminder', () async {
      final futureDueMs = DateTime.now().add(const Duration(minutes: 30)).millisecondsSinceEpoch;

      final task = await tasksRepo.createTask(
        title: 'Review PR',
        dueAt: futureDueMs,
        dueIsAllDay: false,
      );

      // A new timed task starts with the global default offset (§11): [10].
      final offsets = await taskOffsets(task.id);
      expect(offsets, hasLength(1));
      expect(offsets.single.offsetMin, equals(10));
      final notifId = offsets.single.notificationId;
      expect(notifId, isNotNull);
      expect(notifId, equals(1000));
      expect(fakePlugin.scheduledNotifications.containsKey(1000), isTrue);

      final call = fakePlugin.scheduledNotifications[1000]!;
      expect(call.title, equals('Review PR'));
      final expectedFireMs = futureDueMs - 10 * 60 * 1000;
      expect(call.scheduledDate.millisecondsSinceEpoch, equals(expectedFireMs));
    });

    test('A task with several configured offsets schedules one notification per offset', () async {
      final futureDueMs = DateTime.now().add(const Duration(hours: 2)).millisecondsSinceEpoch;

      final task = await tasksRepo.createTask(
        title: 'Quarterly review',
        dueAt: futureDueMs,
        dueIsAllDay: false,
      );

      final reminderConfig = ReminderConfigRepository(
        db: db,
        eventsRepository: eventsRepo,
        settingsRepo: settingsRepo,
        timeService: timeService,
        deviceId: 'test-device',
      );
      await reminderConfig.setTaskReminderOffsets(task.id, [10, 60]);
      await reminderService.scheduleFor((await tasksRepo.getTask(task.id))!);

      final offsets = await taskOffsets(task.id);
      expect(offsets, hasLength(2));
      expect(fakePlugin.scheduledNotifications.length, equals(2));
      for (final row in offsets) {
        final call = fakePlugin.scheduledNotifications[row.notificationId]!;
        final expectedFireMs = futureDueMs - row.offsetMin * 60 * 1000;
        expect(call.scheduledDate.millisecondsSinceEpoch, equals(expectedFireMs));
      }
    });

    test('An all-day task gets no countdown offsets — the digest covers it instead', () async {
      final todayNoonMs = DateTime.now().millisecondsSinceEpoch;

      final task = await tasksRepo.createTask(
        title: 'Renew passport',
        dueAt: todayNoonMs,
        dueIsAllDay: true,
      );

      expect(await taskOffsets(task.id), isEmpty);
      expect(fakePlugin.scheduledNotifications, isEmpty);
    });

    test('Task with due date in past -> NEVER schedules reminder (zero notification storm)', () async {
      final pastDueMs = DateTime.now().subtract(const Duration(hours: 2)).millisecondsSinceEpoch;

      await tasksRepo.createTask(
        title: 'Overdue Task',
        dueAt: pastDueMs,
        dueIsAllDay: false,
      );

      // Must be empty! Zero notifications scheduled for past tasks!
      expect(fakePlugin.scheduledNotifications.isEmpty, isTrue);
    });

    test('Due date changed from 5m away to 30m away -> cancels old and schedules at later time', () async {
      final now = DateTime.now();
      final initialDueMs = now.add(const Duration(minutes: 20)).millisecondsSinceEpoch;

      final task = await tasksRepo.createTask(
        title: 'Doctor Appointment',
        dueAt: initialDueMs,
        dueIsAllDay: false,
      );

      final notifId = (await taskOffsets(task.id)).single.notificationId!;
      expect(fakePlugin.scheduledNotifications.containsKey(notifId), isTrue);

      // Reschedule to 1 hour away
      final updatedDueMs = now.add(const Duration(hours: 1)).millisecondsSinceEpoch;
      await tasksRepo.rescheduleTask(task.id, newDueAt: updatedDueMs);

      // Old was cancelled and rescheduled with new time
      expect(fakePlugin.cancelledIds.contains(notifId), isTrue);
      expect(fakePlugin.scheduledNotifications.containsKey(notifId), isTrue);
      final call = fakePlugin.scheduledNotifications[notifId]!;
      final expectedNewFire = updatedDueMs - 10 * 60 * 1000;
      expect(call.scheduledDate.millisecondsSinceEpoch, equals(expectedNewFire));
    });

    test('Completing a task cancels its scheduled reminder', () async {
      final futureDueMs = DateTime.now().add(const Duration(minutes: 30)).millisecondsSinceEpoch;

      final task = await tasksRepo.createTask(
        title: 'Buy Groceries',
        dueAt: futureDueMs,
        dueIsAllDay: false,
      );
      final notifId = (await taskOffsets(task.id)).single.notificationId!;
      expect(fakePlugin.scheduledNotifications.containsKey(notifId), isTrue);

      await tasksRepo.completeTask(task.id);

      expect(fakePlugin.scheduledNotifications.containsKey(notifId), isFalse);
      expect(fakePlugin.cancelledIds.contains(notifId), isTrue);
    });

    test('Uncompleting a task reschedules reminder if still in future', () async {
      final futureDueMs = DateTime.now().add(const Duration(minutes: 40)).millisecondsSinceEpoch;

      final task = await tasksRepo.createTask(
        title: 'Submit Expense Report',
        dueAt: futureDueMs,
        dueIsAllDay: false,
      );
      final notifId = (await taskOffsets(task.id)).single.notificationId!;

      await tasksRepo.completeTask(task.id);
      expect(fakePlugin.scheduledNotifications.containsKey(notifId), isFalse);

      await tasksRepo.uncompleteTask(task.id);
      expect(fakePlugin.scheduledNotifications.containsKey(notifId), isTrue);
    });

    test('Archiving or deleting a task cancels its reminder', () async {
      final futureDueMs = DateTime.now().add(const Duration(minutes: 50)).millisecondsSinceEpoch;

      final task1 = await tasksRepo.createTask(
        title: 'Task to Archive',
        dueAt: futureDueMs,
      );
      final id1 = (await taskOffsets(task1.id)).single.notificationId!;
      expect(fakePlugin.scheduledNotifications.containsKey(id1), isTrue);

      await tasksRepo.archiveTask(task1.id);
      expect(fakePlugin.scheduledNotifications.containsKey(id1), isFalse);

      final task2 = await tasksRepo.createTask(
        title: 'Task to Delete',
        dueAt: futureDueMs,
      );
      final id2 = (await taskOffsets(task2.id)).single.notificationId!;
      expect(fakePlugin.scheduledNotifications.containsKey(id2), isTrue);

      await tasksRepo.deleteTask(task2.id);
      expect(fakePlugin.scheduledNotifications.containsKey(id2), isFalse);
    });

    test('Master switch off cancels all; on returns future ones only', () async {
      final now = DateTime.now();
      final futureDueMs = now.add(const Duration(minutes: 30)).millisecondsSinceEpoch;

      final task = await tasksRepo.createTask(
        title: 'Future task',
        dueAt: futureDueMs,
      );
      final notifId = (await taskOffsets(task.id)).single.notificationId!;
      expect(fakePlugin.scheduledNotifications.containsKey(notifId), isTrue);

      // Turn master switch off
      await settingsRepo.setBool('reminders_enabled', false);
      await reminderService.reconcileAll();

      expect(fakePlugin.scheduledNotifications.isEmpty, isTrue);

      // Turn master switch back on
      await settingsRepo.setBool('reminders_enabled', true);
      await reminderService.reconcileAll();

      expect(fakePlugin.scheduledNotifications.containsKey(notifId), isTrue);
    });

    test('Two years of seeded data (135 overdue tasks) produces ZERO notification storm', () async {
      final seed = SeedData(db: db, timeService: timeService, deviceId: 'test-device');
      await seed.generate(days: 730, taskCount: 1000);

      // Clear any notifications recorded during seed creation
      fakePlugin.scheduledNotifications.clear();
      fakePlugin.cancelledIds.clear();

      // App starts and runs reconcileAll()
      await reminderService.reconcileAll();

      // Verify: all scheduled notifications must be in the FUTURE
      final nowTz = tz.TZDateTime.now(tz.local);
      for (final scheduled in fakePlugin.scheduledNotifications.values) {
        expect(scheduled.scheduledDate.isAfter(nowTz), isTrue,
            reason: 'Notification ${scheduled.id} was scheduled in the past!');
      }

      // Check overdue tasks in DB
      final nowUtcMs = timeService.nowUtcMs();
      final overdueTasks = await (db.select(db.tasks)
            ..where((t) =>
                t.status.equals('open') &
                t.deletedAt.isNull() &
                t.dueAt.isSmallerThanValue(nowUtcMs)))
          .get();

      expect(overdueTasks.isNotEmpty, isTrue);

      // None of the overdue tasks should be in the scheduled map
      for (final overdue in overdueTasks) {
        for (final row in await taskOffsets(overdue.id)) {
          if (row.notificationId != null) {
            expect(fakePlugin.scheduledNotifications.containsKey(row.notificationId!),
                isFalse);
          }
        }
      }
    });
  });

  group('First-item notification permission prompt', () {
    setUp(NotificationPermissionHelper.resetSessionPrompt);
    tearDown(NotificationPermissionHelper.resetSessionPrompt);

    testWidgets('prompts on the first created item and never again', (tester) async {
      NotificationPermissionHelper.mockPermissionGranted = false;
      var promptsShown = 0;

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                await NotificationPermissionHelper.ensureOnFirstItemCreated(
                  context,
                  settingsRepo,
                );
              },
              child: const Text('create'),
            ),
          ),
        ),
      ));

      // First creation: the pre-dialog appears.
      await tester.tap(find.text('create'));
      await tester.pumpAndSettle();
      if (find.text('Let Cairn notify you?').evaluate().isNotEmpty) {
        promptsShown++;
        await tester.tap(find.text('Not now'));
        await tester.pumpAndSettle();
      }
      expect(promptsShown, equals(1),
          reason: 'the first task or habit must trigger the prompt');
      expect(await settingsRepo.getInt(
              NotificationPermissionHelper.firstItemPromptedKey),
          equals(1),
          reason: 'the flag must persist so later launches stay quiet');

      // Declining is remembered even across a fresh app session.
      NotificationPermissionHelper.resetSessionPrompt();
      NotificationPermissionHelper.mockPermissionGranted = false;

      await tester.tap(find.text('create'));
      await tester.pumpAndSettle();
      expect(find.text('Let Cairn notify you?'), findsNothing,
          reason: 'a second creation must never re-prompt');
    });
  });

  group('Part B2 — Daily digest', () {
    test('Off by default: reconcileAll schedules nothing at the reserved digest ids', () async {
      await tasksRepo.createTask(
        title: 'All-day task due today',
        dueAt: DateTime.now().millisecondsSinceEpoch,
        dueIsAllDay: true,
      );

      await reminderService.reconcileAll();

      for (var i = 1; i <= 6; i++) {
        expect(fakePlugin.scheduledNotifications.containsKey(i), isFalse);
      }
    });

    test('Enabled with something due today schedules one digest notification per configured time', () async {
      await tasksRepo.createTask(
        title: 'All-day task due today',
        dueAt: DateTime.now().millisecondsSinceEpoch,
        dueIsAllDay: true,
      );
      await settingsRepo.setBool('digest_enabled', true);
      await settingsRepo.set('digest_times_min', [9 * 60, 17 * 60]);

      await reminderService.reconcileDigest();

      expect(fakePlugin.scheduledNotifications.containsKey(1), isTrue);
      expect(fakePlugin.scheduledNotifications.containsKey(2), isTrue);
      expect(fakePlugin.scheduledNotifications[1]!.body, contains('1 due today'));
    });

    test('Enabled with nothing due or overdue schedules no digest — an empty digest is worse than none', () async {
      await settingsRepo.setBool('digest_enabled', true);
      await settingsRepo.set('digest_times_min', [9 * 60]);

      await reminderService.reconcileDigest();

      expect(fakePlugin.scheduledNotifications.containsKey(1), isFalse);
    });
  });

  group('Part B3 — Habit digest', () {
    // Its own harness rather than the file-level one: the digest's tones are
    // about what happened yesterday and how long a streak runs, and
    // `createHabit` anchors a habit on the day it is created — so a habit
    // needs to be made in the past and the clock walked forward before it has
    // any history to describe. The file-level `timeService` is on the real
    // clock and cannot do that.
    late AppDatabase hdDb;
    late SettingsRepository hdSettings;
    late FakeFlutterLocalNotificationsPlugin hdPlugin;
    late HabitsRepository hdHabits;
    late ReminderService hdService;
    late int nowMs;

    const created = '2026-09-09'; // Wednesday
    const monday = '2026-09-14'; // the Monday that starts the week
    const wednesday = '2026-09-16';

    int at(String localDate, int hour) {
      final d = TimeService.parseLocalDate(localDate);
      return DateTime.utc(d.year, d.month, d.day, hour).millisecondsSinceEpoch;
    }

    /// Moves the harness's clock to noon on [localDate].
    void setNow(String localDate) => nowMs = at(localDate, 12);

    void buildService({int? randomSeed}) {
      hdService = ReminderService(
        db: hdDb,
        settingsRepo: hdSettings,
        timeService: TimeService(
          localize: (ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
          offsetMinutesAt: (_) => 0,
          tzIdProvider: () => 'UTC',
          nowProvider: () => nowMs,
        ),
        plugin: hdPlugin,
        habitsRepository: hdHabits,
        random: randomSeed == null ? null : Random(randomSeed),
      );
    }

    setUp(() async {
      hdDb = AppDatabase(NativeDatabase.memory());
      hdSettings = SettingsRepository(db: hdDb);
      hdPlugin = FakeFlutterLocalNotificationsPlugin();
      nowMs = at(created, 12);
      final time = TimeService(
        localize: (ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
        offsetMinutesAt: (_) => 0,
        tzIdProvider: () => 'UTC',
        nowProvider: () => nowMs,
      );
      hdHabits = HabitsRepository(
        db: hdDb,
        eventsRepository:
            EventsRepository(db: hdDb, timeService: time, deviceId: 'test'),
        timeService: time,
        deviceId: 'test',
      );
      buildService();
    });

    tearDown(() async => hdDb.close());

    ZonedScheduleCall? scheduled() =>
        hdPlugin.scheduledNotifications[ReminderService.habitDigestNotificationId];

    /// A daily habit created on [created] and checked off every day from then
    /// until the day before [today], so on [today] it has a live streak and is
    /// still pending.
    Future<String> seedStreak({String today = wednesday}) async {
      final id = await hdHabits.createHabit(
        title: 'Read',
        scheduleRule: 'FREQ=DAILY',
      );
      for (var date = created;
          date.compareTo(today) < 0;
          date = TimeService.addDays(date, 1)) {
        await hdHabits.check(id, localDate: date);
      }
      setNow(today);
      return id;
    }

    test('Off by default: reconcileAll schedules nothing at the habit digest id',
        () async {
      await seedStreak();

      await hdService.reconcileAll();

      expect(scheduled(), isNull);
    });

    test('Enabled with a live streak and something open schedules one digest',
        () async {
      await seedStreak();
      await hdSettings.setBool('habit_digest_enabled', true);

      await hdService.reconcileHabitDigest();

      expect(scheduled(), isNotNull);
      expect(scheduled()!.title, equals('Cairn'));
      expect(scheduled()!.payload, equals('habit_digest'));
      // Which of the three streak variants comes out is random by design, so
      // assert on what they all carry: the streak length and the open count.
      expect(scheduled()!.body, contains('7'));
      expect(scheduled()!.body, contains('1 habit'));
    });

    test('Uses exactly one fixed id, never the shared counter band', () async {
      await seedStreak();
      await hdSettings.setBool('habit_digest_enabled', true);

      await hdService.reconcileHabitDigest();

      expect(hdPlugin.scheduledNotifications.keys,
          equals({ReminderService.habitDigestNotificationId}));
      expect(ReminderService.habitDigestNotificationId, equals(7));
    });

    test('Fires at the configured time, in minutes past midnight', () async {
      await seedStreak();
      await hdSettings.setBool('habit_digest_enabled', true);
      await hdSettings.setInt('habit_digest_time_min', 7 * 60 + 30);

      await hdService.reconcileHabitDigest();

      expect(scheduled()!.scheduledDate.hour, equals(7));
      expect(scheduled()!.scheduledDate.minute, equals(30));
      expect(
        scheduled()!.scheduledDate.isAfter(tz.TZDateTime.now(tz.local)),
        isTrue,
        reason: 'a time already past today must roll to tomorrow',
      );
    });

    test('Defaults to 20:00 when no time is configured', () async {
      await seedStreak();
      await hdSettings.setBool('habit_digest_enabled', true);

      await hdService.reconcileHabitDigest();

      expect(scheduled()!.scheduledDate.hour, equals(20));
      expect(scheduled()!.scheduledDate.minute, equals(0));
      expect(ReminderService.defaultHabitDigestTimeMin, equals(20 * 60));
    });

    test('Nothing meaningful to say schedules no digest', () async {
      // A habit with no history at all: no streak to cite, no freeze
      // yesterday, and mid-week. Like the task digest with an empty due list,
      // it stays quiet rather than saying something empty.
      await hdHabits.createHabit(title: 'Read', scheduleRule: 'FREQ=DAILY');
      setNow(wednesday);
      await hdSettings.setBool('habit_digest_enabled', true);

      await hdService.reconcileHabitDigest();

      expect(scheduled(), isNull);
    });

    test('Everything already done today schedules no digest', () async {
      final id = await seedStreak();
      await hdHabits.check(id, localDate: wednesday);
      await hdSettings.setBool('habit_digest_enabled', true);

      await hdService.reconcileHabitDigest();

      expect(scheduled(), isNull,
          reason: '"0 habits are still open" is not a nudge');
    });

    test('No habits at all schedules no digest', () async {
      setNow(wednesday);
      await hdSettings.setBool('habit_digest_enabled', true);

      await hdService.reconcileHabitDigest();

      expect(scheduled(), isNull);
    });

    test('Reminders globally disabled wins over habit_digest_enabled',
        () async {
      await seedStreak();
      await hdSettings.setBool('habit_digest_enabled', true);
      await hdSettings.setBool('reminders_enabled', false);

      await hdService.reconcileHabitDigest();

      expect(scheduled(), isNull);
    });

    test('Turning it off cancels the previously scheduled digest', () async {
      await seedStreak();
      await hdSettings.setBool('habit_digest_enabled', true);
      await hdService.reconcileHabitDigest();
      expect(scheduled(), isNotNull);

      await hdSettings.setBool('habit_digest_enabled', false);
      await hdService.reconcileHabitDigest();

      expect(scheduled(), isNull);
    });

    test('The week-rollover tone wins on the first day of the week', () async {
      await seedStreak(today: monday);
      await hdSettings.setBool('habit_digest_enabled', true);

      await hdService.reconcileHabitDigest();

      expect(scheduled()!.body, contains('week'));
      expect(scheduled()!.body, contains('1 habit is'));
    });

    test('A freeze used yesterday outranks both other tones', () async {
      final id = await hdHabits.createHabit(
        title: 'Read',
        scheduleRule: 'FREQ=DAILY',
      );
      await hdHabits.check(id, localDate: created);
      await hdHabits.check(id, localDate: '2026-09-10');
      await hdHabits.check(id, localDate: '2026-09-11');
      await hdHabits.check(id, localDate: '2026-09-12');
      // Sunday excused, and Monday starts the week — the freeze still wins.
      await hdHabits.setSkipped(id, localDate: '2026-09-13');
      setNow(monday);
      await hdSettings.setBool('habit_digest_enabled', true);

      await hdService.reconcileHabitDigest();

      expect(scheduled()!.body!.toLowerCase(), contains('freeze'));
    });

    test('The chosen variant is remembered, and the next one differs',
        () async {
      await seedStreak();
      await hdSettings.setBool('habit_digest_enabled', true);

      await hdService.reconcileHabitDigest();
      final first =
          await hdSettings.getInt(ReminderService.habitDigestLastIndexKey);
      expect(first, isNotNull, reason: 'the index must be persisted');
      final firstBody = scheduled()!.body;

      await hdService.reconcileHabitDigest();

      expect(scheduled()!.body, isNot(equals(firstBody)));
      expect(
        await hdSettings.getInt(ReminderService.habitDigestLastIndexKey),
        isNot(equals(first)),
      );
    });

    test('Never repeats the immediately-previous line over many reconciles',
        () async {
      await seedStreak();
      await hdSettings.setBool('habit_digest_enabled', true);

      String? previous;
      for (var i = 0; i < 12; i++) {
        await hdService.reconcileHabitDigest();
        final body = scheduled()!.body;
        expect(body, isNot(equals(previous)), reason: 'run $i repeated a line');
        previous = body;
      }
    });

    test('A stored index outside the pool is treated as nothing stored',
        () async {
      // A pool that shrank in a later release would otherwise leave a stale
      // index that the modulo below could read as a valid "last used".
      await seedStreak();
      await hdSettings.setBool('habit_digest_enabled', true);
      await hdSettings.setInt(ReminderService.habitDigestLastIndexKey, 99);

      await hdService.reconcileHabitDigest();

      expect(scheduled(), isNotNull);
      final stored =
          await hdSettings.getInt(ReminderService.habitDigestLastIndexKey);
      expect(stored, isNotNull);
      expect(stored, lessThan(3));
    });

    test('reconcileAll schedules it alongside the task digest', () async {
      await seedStreak();
      final harnessTime = TimeService(
        localize: (ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
        offsetMinutesAt: (_) => 0,
        tzIdProvider: () => 'UTC',
        nowProvider: () => nowMs,
      );
      final hdTasks = TasksRepository(
        db: hdDb,
        eventsRepository: EventsRepository(
          db: hdDb,
          timeService: harnessTime,
          deviceId: 'test',
        ),
        timeService: harnessTime,
      );
      await hdTasks.createTask(
        title: 'All-day task due today',
        // Dated against the harness clock, not the wall clock — the digest
        // resolves "today" through the same fake `TimeService`.
        dueAt: at(wednesday, 10),
        dueIsAllDay: true,
      );
      await hdSettings.setBool('digest_enabled', true);
      await hdSettings.set('digest_times_min', [9 * 60]);
      await hdSettings.setBool('habit_digest_enabled', true);

      await hdService.reconcileAll();

      expect(hdPlugin.scheduledNotifications.containsKey(1), isTrue,
          reason: 'the task digest still schedules');
      expect(scheduled(), isNotNull);
    });

    // ───────────────── Requirements A & B, on the habit-side call sites ──

    test('Habit reminders request exact mode', () async {
      final harnessTime = TimeService(
        localize: (ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
        offsetMinutesAt: (_) => 0,
        tzIdProvider: () => 'UTC',
        nowProvider: () => nowMs,
      );
      final id = await seedStreak();
      // A reminder late enough on the harness day to still be in the future
      // at noon, so `nextHabitFireTime` returns today rather than skipping on.
      await ReminderConfigRepository(
        db: hdDb,
        eventsRepository: EventsRepository(
          db: hdDb,
          timeService: harnessTime,
          deviceId: 'test',
        ),
        settingsRepo: hdSettings,
        timeService: harnessTime,
        deviceId: 'test',
      ).setHabitReminderTimes(id, [21 * 60]);
      hdPlugin.scheduleLog.clear();

      await hdService.scheduleForHabit(
        (await hdHabits.loadSnapshot(id))!.habit,
      );

      expect(hdPlugin.scheduleLog, isNotEmpty,
          reason: 'the habit reminder must actually be scheduled');
      for (final call in hdPlugin.scheduleLog) {
        expect(call.androidScheduleMode,
            equals(AndroidScheduleMode.exactAllowWhileIdle));
      }
    });

    test('Habit digest requests exact mode', () async {
      await seedStreak();
      await hdSettings.setBool('habit_digest_enabled', true);

      await hdService.reconcileHabitDigest();

      expect(scheduled()!.androidScheduleMode,
          equals(AndroidScheduleMode.exactAllowWhileIdle));
    });

    test('Habit digest recurs daily at the OS level', () async {
      await seedStreak();
      await hdSettings.setBool('habit_digest_enabled', true);

      await hdService.reconcileHabitDigest();

      expect(scheduled()!.matchDateTimeComponents,
          equals(DateTimeComponents.time),
          reason: 'a one-shot digest stops forever if the app is not reopened');
    });

    test('Task digest recurs daily at the OS level', () async {
      final harnessTime = TimeService(
        localize: (ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
        offsetMinutesAt: (_) => 0,
        tzIdProvider: () => 'UTC',
        nowProvider: () => nowMs,
      );
      final hdTasks = TasksRepository(
        db: hdDb,
        eventsRepository: EventsRepository(
          db: hdDb,
          timeService: harnessTime,
          deviceId: 'test',
        ),
        timeService: harnessTime,
      );
      setNow(wednesday);
      await hdTasks.createTask(
        title: 'All-day task due today',
        dueAt: at(wednesday, 10),
        dueIsAllDay: true,
      );
      await hdSettings.setBool('digest_enabled', true);
      await hdSettings.set('digest_times_min', [9 * 60]);

      await hdService.reconcileDigest();

      expect(hdPlugin.scheduledNotifications[1]!.matchDateTimeComponents,
          equals(DateTimeComponents.time));
    });

    test('A day rollover with the app never reopened leaves the digest armed',
        () async {
      // The bug this replaces: the digest was a one-shot re-armed only by
      // `reconcileAll`/`_checkDay`, so a user who did not open the app the
      // next day got no further digest, ever. Recurrence now belongs to the
      // OS, so the proof is that the pending schedule survives a day rollover
      // with nothing calling back into the service.
      await seedStreak();
      await hdSettings.setBool('habit_digest_enabled', true);
      await hdService.reconcileHabitDigest();

      final armed = scheduled()!;
      expect(armed.matchDateTimeComponents, equals(DateTimeComponents.time));

      final callsBefore = hdPlugin.scheduleLog.length;

      // Roll the clock forward a full day. Deliberately no reconcile call of
      // any kind afterwards — that is the whole point.
      setNow(TimeService.addDays(wednesday, 1));

      // Nothing re-armed it, and it is still registered as a daily repeat.
      // Under the old one-shot model the next day's digest existed only if
      // something called reconcile here; now the single call above is enough.
      expect(hdPlugin.scheduleLog, hasLength(callsBefore),
          reason: 'no reschedule may be required after a rollover');
      final stillArmed = scheduled();
      expect(stillArmed, isNotNull,
          reason: 'the OS-level repeat must outlive the app being closed');
      expect(stillArmed!.matchDateTimeComponents,
          equals(DateTimeComponents.time));
      expect(await hdPlugin.pendingNotificationRequests(), isNotEmpty);
    });
  });

  group('Part C — Permission Pre-Dialog & UI Controls', () {
    testWidgets('Notification permission pre-dialog shows Cairn explanation before system prompt', (tester) async {
      NotificationPermissionHelper.resetSessionPrompt();
      NotificationPermissionHelper.mockPermissionGranted = false;

      bool continueTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  continueTapped = await NotificationPermissionHelper.ensureNotificationPermission(context);
                },
                child: const Text('Start'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      // Verify pre-dialog content
      expect(find.text('Let Cairn notify you?'), findsOneWidget);
      expect(find.textContaining('Cairn uses notifications to tell you when a focus session ends'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);

      // Tap Not now
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(continueTapped, isFalse);

      // Tapping Start again in same session should NOT ask again
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      expect(find.text('Let Cairn notify you?'), findsNothing);
    });

    testWidgets('SettingsScreen renders Reminders section with switch and controls', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            settingsRepositoryProvider.overrideWithValue(settingsRepo),
            reminderServiceProvider.overrideWithValue(reminderService),
          ],
          child: MaterialApp(
            theme: ThemeData.light().copyWith(extensions: const [AppTokens.light]),
            home: const SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Daily digest'),
        200,
        scrollable: find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        ),
      );

      // Reminders section header and switch
      expect(find.text('Reminders'), findsWidgets);
      expect(find.text('Notify you before tasks are due'), findsOneWidget);
      expect(find.text('Default reminders for new tasks'), findsOneWidget);
      expect(find.text('Daily digest'), findsOneWidget);
      expect(find.text('Habit check-in'), findsOneWidget);
    });

    /// The Settings screen, scrolled down to the habit check-in row.
    Future<void> pumpSettingsAtHabitRow(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            settingsRepositoryProvider.overrideWithValue(settingsRepo),
            reminderServiceProvider.overrideWithValue(reminderService),
          ],
          child: MaterialApp(
            theme: ThemeData.light().copyWith(extensions: const [AppTokens.light]),
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Habit check-in'),
        200,
        scrollable: find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        ),
      );
      await tester.pumpAndSettle();
    }

    /// The habit check-in row's switch.
    Finder habitDigestSwitch() => find.ancestor(
          of: find.text('Habit check-in'),
          matching: find.byType(SwitchListTile),
        );

    testWidgets('Habit check-in is off by default and hides its time picker',
        (tester) async {
      await pumpSettingsAtHabitRow(tester);

      expect(tester.widget<SwitchListTile>(habitDigestSwitch()).value, isFalse);
      // 8:00 PM is the default time, but the chip only exists once the
      // toggle is on — same convention as the daily digest's time chips.
      expect(find.text('8:00 PM'), findsNothing);
    });

    testWidgets('Turning Habit check-in on reveals the time and persists it',
        (tester) async {
      await pumpSettingsAtHabitRow(tester);

      await tester.tap(habitDigestSwitch());
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(habitDigestSwitch()).value, isTrue);
      expect(find.text('8:00 PM'), findsOneWidget,
          reason: 'the default 20:00 shows once the row is on');
      expect(await settingsRepo.getBool('habit_digest_enabled'), isTrue);
    });

    testWidgets('Turning it back off hides the time and persists the off state',
        (tester) async {
      await settingsRepo.setBool('habit_digest_enabled', true);
      await pumpSettingsAtHabitRow(tester);
      expect(find.text('8:00 PM'), findsOneWidget);

      await tester.tap(habitDigestSwitch());
      await tester.pumpAndSettle();

      expect(tester.widget<SwitchListTile>(habitDigestSwitch()).value, isFalse);
      expect(find.text('8:00 PM'), findsNothing);
      expect(await settingsRepo.getBool('habit_digest_enabled'), isFalse);
    });

    testWidgets('A stored time is loaded into the chip', (tester) async {
      await settingsRepo.setBool('habit_digest_enabled', true);
      await settingsRepo.setInt('habit_digest_time_min', 7 * 60 + 30);

      await pumpSettingsAtHabitRow(tester);

      expect(find.text('7:30 AM'), findsOneWidget);
      expect(find.text('8:00 PM'), findsNothing);
    });

    testWidgets('Tapping the time chip opens a time picker', (tester) async {
      await settingsRepo.setBool('habit_digest_enabled', true);
      await pumpSettingsAtHabitRow(tester);

      await tester.tap(find.text('8:00 PM'));
      await tester.pumpAndSettle();

      // The dial's internals move between Flutter versions, so this asserts
      // the picker opened and that cancelling leaves the value alone rather
      // than driving the dial itself. `reconcileHabitDigest`'s own tests
      // cover what a changed value does.
      expect(find.byType(TimePickerDialog), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('8:00 PM'), findsOneWidget);
      expect(
        await settingsRepo.getInt('habit_digest_time_min'),
        anyOf(isNull, equals(ReminderService.defaultHabitDigestTimeMin)),
      );
    });

    testWidgets('Changing the time persists it and reschedules', (tester) async {
      await settingsRepo.setBool('habit_digest_enabled', true);
      await pumpSettingsAtHabitRow(tester);

      // Driven through the notifier the picker's callback calls, so the
      // assertion is about the binding rather than the dial widget.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsScreen)),
      );
      container.read(habitDigestTimeMinProvider.notifier).setTime(9 * 60 + 15);
      await tester.pumpAndSettle();

      expect(find.text('9:15 AM'), findsOneWidget);
      expect(await settingsRepo.getInt('habit_digest_time_min'),
          equals(9 * 60 + 15));
    });

    testWidgets('The daily digest row is unaffected by the habit row',
        (tester) async {
      await settingsRepo.setBool('habit_digest_enabled', true);
      await pumpSettingsAtHabitRow(tester);

      // The daily digest row sits above the habit one and has been scrolled
      // out of the lazy ListView by `pumpSettingsAtHabitRow`, so walk back up
      // to it before reading its switch.
      await tester.scrollUntilVisible(
        find.text('Daily digest'),
        -200,
        scrollable: find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        ),
      );
      await tester.pumpAndSettle();

      final dailySwitch = find.ancestor(
        of: find.text('Daily digest'),
        matching: find.byType(SwitchListTile),
      );
      expect(tester.widget<SwitchListTile>(dailySwitch).value, isFalse,
          reason: 'the task digest keeps its own off-by-default state');
      expect(await settingsRepo.getBool('digest_enabled'), isNull);
    });

    testWidgets('TaskDetailSheet renders the default reminder chip and an add-reminder chip for a timed task', (tester) async {
      final now = DateTime.now();
      final dueAt = now.add(const Duration(hours: 3)).millisecondsSinceEpoch;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            settingsRepositoryProvider.overrideWithValue(settingsRepo),
            reminderServiceProvider.overrideWithValue(reminderService),
          ],
          child: MaterialApp(
            theme: ThemeData.light().copyWith(extensions: const [AppTokens.light]),
            home: Scaffold(
              body: TaskDetailSheet(
                initialTitle: 'Task with reminder',
                initialDueAt: dueAt,
                initialDueIsAllDay: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // "Remind me" header, the default offset loaded as a chip, and a way
      // to add another — no more single on/off switch.
      expect(find.text('Remind me'), findsOneWidget);
      expect(find.text('10m before'), findsOneWidget);
      expect(find.text('Add reminder'), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════════════════════════════════
  // Part D — Notification reliability & engagement
  // ══════════════════════════════════════════════════════════════════════

  group('Part D1 — Exact scheduling & engagement (Requirements A, D8, D9)', () {
    /// A dated task, with the schedule log cleared afterwards.
    ///
    /// `tasksRepo` is wired to `reminderService`, so creating a task already
    /// schedules its reminder; clearing here leaves the explicit
    /// `scheduleFor` under test as the only recorded call.
    Future<Task> timedTask({int hours = 3}) async {
      final task = await tasksRepo.createTask(
        title: 'Timed task',
        dueAt:
            DateTime.now().add(Duration(hours: hours)).millisecondsSinceEpoch,
      );
      fakePlugin.scheduleLog.clear();
      return task;
    }

    test('Task reminders request exact mode, not inexact', () async {
      await reminderService.scheduleFor(await timedTask());

      expect(fakePlugin.scheduleLog.single.androidScheduleMode,
          equals(AndroidScheduleMode.exactAllowWhileIdle));
    });

    test('Task digest requests exact mode', () async {
      await tasksRepo.createTask(
        title: 'All-day task due today',
        dueAt: DateTime.now().millisecondsSinceEpoch,
        dueIsAllDay: true,
      );
      await settingsRepo.setBool('digest_enabled', true);
      await settingsRepo.set('digest_times_min', [9 * 60]);

      await reminderService.reconcileDigest();

      expect(fakePlugin.scheduledNotifications[1]!.androidScheduleMode,
          equals(AndroidScheduleMode.exactAllowWhileIdle));
    });

    test('A declined exact-alarm permission degrades to inexact rather than '
        'scheduling nothing', () async {
      reminderService.exactAlarmsAllowedForTest = false;

      await reminderService.scheduleFor(await timedTask());

      expect(fakePlugin.scheduleLog.single.androidScheduleMode,
          equals(AndroidScheduleMode.inexactAllowWhileIdle),
          reason: 'must degrade, not drop');
      expect(fakePlugin.scheduledNotifications, isNotEmpty,
          reason: 'the reminder must still exist');
    });

    test('Reminders are high importance so they surface as a heads-up banner',
        () async {
      await reminderService.scheduleFor(await timedTask());

      final android = fakePlugin.scheduleLog.single.notificationDetails!.android!;
      expect(android.importance, equals(Importance.high));
      expect(android.priority, equals(Priority.high));
    });

    test('Task reminders carry Mark done and Snooze actions; digests do not',
        () async {
      await reminderService.scheduleFor(await timedTask());
      final actions =
          fakePlugin.scheduleLog.single.notificationDetails!.android!.actions!;
      expect(actions.map((a) => a.id),
          containsAll(<String>[actionMarkDone, actionSnooze]));

      await settingsRepo.setBool('digest_enabled', true);
      await settingsRepo.set('digest_times_min', [9 * 60]);
      await reminderService.reconcileDigest();
      expect(
        fakePlugin.scheduledNotifications[1]!.notificationDetails!.android!.actions,
        anyOf(isNull, isEmpty),
        reason: 'a digest summarises several items, so Mark done is ambiguous',
      );
    });
  });

  group('Part D2 — iOS initialization (Requirement C)', () {
    test('initialize() constructs and passes DarwinInitializationSettings',
        () async {
      final settings = fakePlugin.initializationSettings;
      expect(settings, isNotNull);
      expect(settings!.iOS, isNotNull,
          reason: 'iOS was previously never configured, so nothing fired');
      expect(settings.iOS!.requestAlertPermission, isTrue);
      expect(settings.iOS!.requestBadgePermission, isTrue);
      expect(settings.iOS!.requestSoundPermission, isTrue);
    });

    test('The Darwin category carries the same two action buttons', () async {
      final categories =
          fakePlugin.initializationSettings!.iOS!.notificationCategories;
      expect(categories, hasLength(1));
      expect(
        categories.single.actions.map((a) => a.identifier),
        containsAll(<String>[actionMarkDone, actionSnooze]),
      );
    });

    test('A background action handler is registered for terminated-app taps',
        () async {
      expect(fakePlugin.backgroundHandler, isNotNull);
    });
  });

  group('Part D3 — Notification actions (Requirement D9)', () {
    test('Mark done on a task reminder completes that task', () async {
      final task = await tasksRepo.createTask(title: 'Buy milk');

      final result = await applyNotificationAction(
        db: db,
        actionId: actionMarkDone,
        payload: 'task:${task.id}',
        timeService: timeService,
      );

      expect(result, equals(NotificationActionResult.markedDone));
      expect((await tasksRepo.getTask(task.id))!.status, equals('done'));
    });

    test('Mark done acts on the named task only', () async {
      final target = await tasksRepo.createTask(title: 'Target');
      final other = await tasksRepo.createTask(title: 'Other');

      await applyNotificationAction(
        db: db,
        actionId: actionMarkDone,
        payload: 'task:${target.id}',
        timeService: timeService,
      );

      expect((await tasksRepo.getTask(target.id))!.status, equals('done'));
      expect((await tasksRepo.getTask(other.id))!.status, equals('open'));
    });

    test('Mark done on a habit reminder checks that habit off', () async {
      final habitsRepo = HabitsRepository(
        db: db,
        eventsRepository: eventsRepo,
        timeService: timeService,
        deviceId: 'test',
      );
      final id = await habitsRepo.createHabit(
        title: 'Read',
        scheduleRule: 'FREQ=DAILY',
      );

      final result = await applyNotificationAction(
        db: db,
        actionId: actionMarkDone,
        payload: 'habit:$id',
        timeService: timeService,
      );

      expect(result, equals(NotificationActionResult.markedDone));
      expect((await habitsRepo.loadSnapshot(id))!.isDoneToday, isTrue);
    });

    test('A deleted task no-ops instead of crashing', () async {
      final task = await tasksRepo.createTask(title: 'Doomed');
      await tasksRepo.deleteTask(task.id);

      expect(
        await applyNotificationAction(
          db: db,
          actionId: actionMarkDone,
          payload: 'task:${task.id}',
          timeService: timeService,
        ),
        equals(NotificationActionResult.ignored),
      );
    });

    test('An unknown id no-ops instead of crashing', () async {
      expect(
        await applyNotificationAction(
          db: db,
          actionId: actionMarkDone,
          payload: 'task:does-not-exist',
          timeService: timeService,
        ),
        equals(NotificationActionResult.ignored),
      );
    });

    test('Malformed and non-action payloads are rejected', () async {
      for (final payload in <String?>[
        null,
        '',
        'task:',
        'habit:',
        'digest',
        'habit_digest',
        'nonsense',
        'TASK:abc',
      ]) {
        expect(
          await applyNotificationAction(
            db: db,
            actionId: actionMarkDone,
            payload: payload,
            timeService: timeService,
          ),
          equals(NotificationActionResult.ignored),
          reason: 'payload: $payload',
        );
      }
    });

    test('An unrecognised action id no-ops even on a valid task', () async {
      final task = await tasksRepo.createTask(title: 'Safe');

      expect(
        await applyNotificationAction(
          db: db,
          actionId: 'delete_everything',
          payload: 'task:${task.id}',
          timeService: timeService,
        ),
        equals(NotificationActionResult.ignored),
      );
      expect((await tasksRepo.getTask(task.id))!.status, equals('open'));
    });

    test('Snooze reschedules the reminder instead of completing it', () async {
      final task = await tasksRepo.createTask(title: 'Later');

      final result = await applyNotificationAction(
        db: db,
        actionId: actionSnooze,
        payload: 'task:${task.id}',
        plugin: fakePlugin,
        notificationId: 4242,
        timeService: timeService,
      );

      expect(result, equals(NotificationActionResult.snoozed));
      expect((await tasksRepo.getTask(task.id))!.status, equals('open'),
          reason: 'snooze must not complete the task');
      final call = fakePlugin.scheduledNotifications[4242]!;
      expect(call.payload, equals('task:${task.id}'));
      final deltaMs =
          call.scheduledDate.millisecondsSinceEpoch - timeService.nowUtcMs();
      expect(deltaMs, greaterThan(14 * 60 * 1000));
      expect(deltaMs, lessThanOrEqualTo(15 * 60 * 1000 + 5000));
    });

    test('parseNotificationTarget extracts subject and id', () {
      expect(parseNotificationTarget('task:abc'),
          equals(const NotificationTarget(NotificationSubject.task, 'abc')));
      expect(parseNotificationTarget('habit:xyz'),
          equals(const NotificationTarget(NotificationSubject.habit, 'xyz')));
      expect(parseNotificationTarget('digest'), isNull);
    });
  });

  group('Part D4 — Copy variety (Requirement D10)', () {
    test('Task reminder keeps the due time and project, varying only the '
        'lead-in', () {
      final body = taskReminderBody(
        timeStr: '3:30 PM',
        projectName: 'Home',
        templateIndex: 0,
      );
      expect(body, contains('3:30 PM'));
      expect(body, contains('Home'));
    });

    test('Task reminder omits an absent project rather than leaving a gap', () {
      final body = taskReminderBody(
        timeStr: '9:00 AM',
        projectName: null,
        templateIndex: 1,
      );
      expect(body, contains('9:00 AM'));
      expect(body, isNot(contains('•')));
    });

    test('Every task lead-in produces a distinct line', () {
      final seen = <String>{};
      for (var i = 0; i < taskLeadInCount(); i++) {
        seen.add(taskReminderBody(timeStr: '1:00 PM', templateIndex: i));
      }
      expect(seen, hasLength(taskLeadInCount()));
    });

    test('An out-of-range template index wraps instead of throwing', () {
      expect(() => taskReminderBody(timeStr: '1:00 PM', templateIndex: 99),
          returnsNormally);
      expect(() => taskReminderBody(timeStr: '1:00 PM', templateIndex: -1),
          returnsNormally);
    });

    test('Task reminders never repeat the previous lead-in', () async {
      final task = await tasksRepo.createTask(
        title: 'Recurring check',
        dueAt:
            DateTime.now().add(const Duration(hours: 5)).millisecondsSinceEpoch,
      );

      String? previous;
      for (var i = 0; i < 12; i++) {
        fakePlugin.scheduleLog.clear();
        await reminderService.scheduleFor(task);
        final body = fakePlugin.scheduleLog.single.body!;
        expect(body, isNot(equals(previous)), reason: 'run $i repeated a line');
        previous = body;
      }
    });

    test('Task digest never repeats the previous phrasing', () async {
      await tasksRepo.createTask(
        title: 'All-day task due today',
        dueAt: DateTime.now().millisecondsSinceEpoch,
        dueIsAllDay: true,
      );
      await settingsRepo.setBool('digest_enabled', true);
      await settingsRepo.set('digest_times_min', [9 * 60]);

      String? previous;
      for (var i = 0; i < 12; i++) {
        await reminderService.reconcileDigest();
        final call = fakePlugin.scheduledNotifications[1]!;
        final line = '${call.title}|${call.body}';
        expect(line, isNot(equals(previous)), reason: 'run $i repeated a line');
        previous = line;
      }
    });

    test('Task digest keeps the counts phrase intact in every variant', () {
      for (var i = 0; i < taskDigestVariantCount(); i++) {
        final (title, body) = taskDigestContent(
          countsPhrase: '3 due today · 1 overdue',
          templateIndex: i,
        );
        expect(title, isNotEmpty);
        expect(body, contains('3 due today · 1 overdue'));
      }
    });

    test('Habit reminder tone selection matches the previous branch order', () {
      expect(selectHabitReminderTone(currentStreak: 4, targetCount: 3),
          equals(HabitReminderTone.streak));
      expect(selectHabitReminderTone(currentStreak: 0, targetCount: 3),
          equals(HabitReminderTone.targetCount));
      expect(selectHabitReminderTone(currentStreak: 0, targetCount: 1),
          equals(HabitReminderTone.dueToday));
    });

    test('Habit reminder renders the streak and the target with its unit', () {
      expect(
        habitReminderBody(
          tone: HabitReminderTone.streak,
          currentStreak: 7,
          targetCount: 1,
          templateIndex: 0,
        ),
        contains('7'),
      );
      expect(
        habitReminderBody(
          tone: HabitReminderTone.targetCount,
          currentStreak: 0,
          targetCount: 3,
          unitLabel: 'glasses',
          templateIndex: 0,
        ),
        contains('3 glasses'),
      );
    });

    test('Every habit reminder variant within a tone is distinct', () {
      for (final tone in HabitReminderTone.values) {
        final seen = <String>{};
        for (var i = 0; i < habitReminderVariantCount(tone); i++) {
          seen.add(habitReminderBody(
            tone: tone,
            currentStreak: 5,
            targetCount: 3,
            templateIndex: i,
          ));
        }
        expect(seen, hasLength(habitReminderVariantCount(tone)),
            reason: '$tone has duplicate lines');
      }
    });
  });

  group('ReminderService — Initialization Parallelization', () {
    test('ReminderService.initialize runs timezone setup and plugin setup concurrently', () async {
      final fake = FakeFlutterLocalNotificationsPlugin();
      const delay = Duration(milliseconds: 100);
      fake.initDelay = delay;

      var tzBranchExecutedWhilePluginInFlight = false;
      DateTime? tzBranchExecutedAt;

      final localTimeService = TimeService(
        tzIdProvider: () {
          tzBranchExecutedAt = DateTime.now();
          if (fake.isInitializing) {
            tzBranchExecutedWhilePluginInFlight = true;
          }
          return 'America/Edmonton';
        },
      );

      final service = ReminderService(
        db: db,
        settingsRepo: settingsRepo,
        timeService: localTimeService,
        plugin: fake,
      );

      final sw = Stopwatch()..start();
      await service.initialize();
      sw.stop();

      // 1. Structural concurrency: ensure the timezone setup closure ran while the
      // fake plugin's initialize() future was active and awaiting its delay.
      expect(fake.initializeCalled, isTrue);
      expect(tzBranchExecutedAt, isNotNull);
      expect(fake.initializeStartTime, isNotNull);
      expect(fake.initializeEndTime, isNotNull);
      expect(
        tzBranchExecutedWhilePluginInFlight,
        isTrue,
        reason: 'Timezone initialization closure must run concurrently while plugin initialize() is in-flight',
      );
      expect(
        tzBranchExecutedAt!.isBefore(fake.initializeEndTime!),
        isTrue,
        reason: 'Timezone setup should execute before plugin initialize() finishes',
      );

      // 2. Wall-clock timing: with 100ms plugin delay running concurrently with timezone init,
      // total elapsed time should be bounded closely around the single delay (~100-140ms),
      // rather than the sequential sum.
      expect(
        sw.elapsedMilliseconds,
        lessThan(160),
        reason: 'Concurrent initialization (${sw.elapsedMilliseconds}ms) should complete in noticeably less time than sequential sum',
      );
    });
  });
}
