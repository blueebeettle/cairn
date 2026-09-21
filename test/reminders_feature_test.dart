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
import 'package:habit_tracker/data/repositories/settings_repository.dart';
import 'package:habit_tracker/data/repositories/tasks_repository.dart';
import 'package:habit_tracker/data/repositories/timer_repository.dart';
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
  final List<int> cancelledIds = [];
  bool allCancelled = false;

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback? onDidReceiveBackgroundNotificationResponse,
  }) async => true;

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
    );
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

  ZonedScheduleCall({
    required this.id,
    this.title,
    this.body,
    required this.scheduledDate,
    this.payload,
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
}
