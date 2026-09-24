import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:habit_tracker/core/time/time_service.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/data/providers/database_provider.dart';
import 'package:habit_tracker/data/repositories/events_repository.dart';
import 'package:habit_tracker/data/repositories/tasks_repository.dart';
import 'package:habit_tracker/features/tasks/presentation/archived_tasks_screen.dart';
import 'package:habit_tracker/features/tasks/presentation/tasks_screen.dart';
import 'package:habit_tracker/features/tasks/presentation/widgets/quick_capture_sheet.dart';
import 'package:habit_tracker/features/tasks/presentation/widgets/task_detail_sheet.dart';
import 'package:habit_tracker/features/today/presentation/today_screen.dart';
import 'package:habit_tracker/theme/app_theme.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  final testDate = '2026-09-13';
  final testTask = Task(
    id: 'task-101',
    title: 'Review PR and deploy to prod',
    priority: 1,
    status: 'open',
    createdAt: 1726230000000,
    createdLocalDate: testDate,
    rescheduleCount: 0,
    dueAt: 1726248000000,
    dueIsAllDay: false,
    estimatePomodoros: 2,
    sortOrder: 0.0,
    updatedAt: 1726230000000,
    deviceId: 'device-test',
  );

  final testTaskDetails = TaskWithDetails(
    task: testTask,
    project: const Project(
      id: 'proj-1',
      name: 'Work',
      colorIndex: 0,
      archived: false,
      updatedAt: 1000,
      deviceId: 'device-test',
    ),
    tags: const [
      Tag(
        id: 'tag-1',
        name: 'deploy',
        updatedAt: 1000,
        deviceId: 'device-test',
      ),
    ],
    subtasks: const [],
  );

  group('TasksScreen — SPEC.md §2.4, §2.6', () {
    testWidgets('renders three view segments: Today, Upcoming, Inbox',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            todayTasksStreamProvider.overrideWith(
              (ref, date) => Stream.value([testTaskDetails]),
            ),
            upcomingTasksStreamProvider.overrideWith(
              (ref, date) => Stream.value([]),
            ),
            inboxTasksStreamProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
            projectsStreamProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const TasksScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Inbox'), findsOneWidget);
      expect(find.text('Review PR and deploy to prod'), findsOneWidget);
      expect(find.text('2p'), findsOneWidget);
      expect(find.text('Add Task'), findsOneWidget);
    });

    testWidgets('renders updated empty state copy when no tasks exist',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            todayTasksStreamProvider.overrideWith(
              (ref, date) => Stream.value([]),
            ),
            upcomingTasksStreamProvider.overrideWith(
              (ref, date) => Stream.value([]),
            ),
            inboxTasksStreamProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
            projectsStreamProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const TasksScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Nothing due today.'), findsOneWidget);
      expect(
        find.text('Tap + to capture a task, or long-press for the full form.'),
        findsOneWidget,
      );
    });

    testWidgets('long-pressing Add Task FAB opens TaskDetailSheet in create mode',
        (WidgetTester tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final timeService = TimeService(
        dayStartOffsetMinutes: 240,
        localize: (utcMs) => DateTime.fromMillisecondsSinceEpoch(utcMs, isUtc: true),
        offsetMinutesAt: (_) => 0,
        tzIdProvider: () => 'UTC',
      );
      final eventsRepo = EventsRepository(db: db, timeService: timeService);
      final tasksRepo = TasksRepository(
        db: db,
        eventsRepository: eventsRepo,
        timeService: timeService,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            timeServiceProvider.overrideWithValue(timeService),
            tasksRepositoryProvider.overrideWithValue(tasksRepo),
            todayTasksStreamProvider.overrideWith(
              (ref, date) => Stream.value([]),
            ),
            upcomingTasksStreamProvider.overrideWith(
              (ref, date) => Stream.value([]),
            ),
            inboxTasksStreamProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
            projectsStreamProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const TasksScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Long-press the FAB
      await tester.longPress(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Verify create mode
      expect(find.text('New Task'), findsOneWidget);
      expect(find.text('Create task'), findsOneWidget);
      expect(find.byTooltip('Archive Task'), findsNothing);
      expect(find.text('SUBTASKS'), findsNothing);

      await db.close();
    });
  });

  group('TodayScreen — TASKS Section', () {
    testWidgets('renders TASKS header and task card on Today screen',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            todayTasksStreamProvider.overrideWith(
              (ref, date) => Stream.value([testTaskDetails]),
            ),
            todayEventsStreamProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
            eventsForDateStreamProvider.overrideWith(
              (ref, date) => Stream.value([]),
            ),
            sessionsForDateStreamProvider.overrideWith(
              (ref, date) => Stream.value([]),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const TodayScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // TASKS sits below the first frame's viewport on the Today screen.
      await tester.scrollUntilVisible(
        find.text('TASKS'),
        150,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('TASKS'), findsOneWidget);
      expect(find.text('Review PR and deploy to prod'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('2p'), findsOneWidget);
    });
  });

  group('QuickCaptureSheet — Natural Language Parsing & More Options', () {
    testWidgets('parses input and displays preview chips live',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            timeServiceProvider.overrideWithValue(
              const TimeService(dayStartOffsetMinutes: 240),
            ),
            projectsStreamProvider.overrideWith(
              (ref) => Stream.value([
                const Project(
                  id: 'proj-1',
                  name: 'work',
                  colorIndex: 0,
                  archived: false,
                  updatedAt: 1000,
                  deviceId: 'device-test',
                ),
              ]),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: QuickCaptureSheet(initialDate: '2026-09-13'),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Enter sample command
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);

      await tester.enterText(textField, 'finish report fri 5pm !p1 #work ~3p');
      await tester.pump();

      // Check preview chips
      expect(find.text('P1'), findsOneWidget);
      expect(find.text('#work'), findsOneWidget);
      expect(find.text('3p'), findsOneWidget);
      expect(find.text('More options'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Add Task'), findsOneWidget);
    });

    testWidgets('tapping More options opens TaskDetailSheet carrying over typed tokens',
        (WidgetTester tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final timeService = TimeService(
        dayStartOffsetMinutes: 240,
        localize: (utcMs) => DateTime.fromMillisecondsSinceEpoch(utcMs, isUtc: true),
        offsetMinutesAt: (_) => 0,
        tzIdProvider: () => 'UTC',
      );
      final eventsRepo = EventsRepository(db: db, timeService: timeService);
      final tasksRepo = TasksRepository(
        db: db,
        eventsRepository: eventsRepo,
        timeService: timeService,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            timeServiceProvider.overrideWithValue(timeService),
            tasksRepositoryProvider.overrideWithValue(tasksRepo),
            projectsStreamProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () => QuickCaptureSheet.show(context, initialDate: '2026-09-13'),
                    child: const Text('Open QC'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Open QuickCaptureSheet
      await tester.tap(find.text('Open QC'));
      await tester.pumpAndSettle();

      // Type command with title, priority, tag, estimate
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'submit report fri 5pm !p1 #work ~2p');
      await tester.pump();

      // Tap "More options"
      await tester.tap(find.text('More options'));
      await tester.pumpAndSettle();

      // TaskDetailSheet should be open in create mode with carried-over values
      expect(find.text('New Task'), findsOneWidget);
      expect(find.text('Create task'), findsOneWidget);
      expect(find.text('submit report'), findsOneWidget);
      expect(find.text('#work'), findsOneWidget);

      await db.close();
    });
  });

  group('TaskDetailSheet — Create Mode & Validation', () {
    testWidgets('null taskDetails starts empty, disables Create task until title typed, then creates task',
        (WidgetTester tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final timeService = TimeService(
        dayStartOffsetMinutes: 240,
        localize: (utcMs) => DateTime.fromMillisecondsSinceEpoch(utcMs, isUtc: true),
        offsetMinutesAt: (_) => 0,
        tzIdProvider: () => 'UTC',
      );
      final eventsRepo = EventsRepository(db: db, timeService: timeService);
      final tasksRepo = TasksRepository(
        db: db,
        eventsRepository: eventsRepo,
        timeService: timeService,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            timeServiceProvider.overrideWithValue(timeService),
            tasksRepositoryProvider.overrideWithValue(tasksRepo),
            projectsStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () => TaskDetailSheet.show(context, initialDate: '2026-09-13'),
                    child: const Text('Open Editor'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // Open editor in create mode
      await tester.tap(find.text('Open Editor'));
      await tester.pumpAndSettle();

      // Header is "New Task"
      expect(find.text('New Task'), findsOneWidget);
      expect(find.byTooltip('Archive Task'), findsNothing);
      expect(find.text('SUBTASKS'), findsNothing);

      // "Create task" button is disabled when title is empty
      final createBtn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Create task'),
      );
      expect(createBtn.onPressed, isNull);

      // Enter title
      final titleField = find.widgetWithText(TextField, 'Title');
      await tester.enterText(titleField, 'Deploy new release');
      await tester.pump();

      // Button is now enabled
      final enabledCreateBtn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Create task'),
      );
      expect(enabledCreateBtn.onPressed, isNotNull);

      // Tap Create task
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Create task'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Create task'));
      await tester.pumpAndSettle();

      // Sheet is closed
      expect(find.text('New Task'), findsNothing);

      // Assert task exists in database
      final allTasks = await db.select(db.tasks).get();
      expect(allTasks, hasLength(1));
      expect(allTasks.first.title, equals('Deploy new release'));

      await db.close();
    });
  });

  group('Tasks Feature — Ordering, Completed Row, 5-Cap & Archive (§1.1-§2.4)', () {
    final openTask1 = TaskWithDetails(
      task: Task(
        id: 'task-1',
        title: 'Open Task P1',
        priority: 1,
        status: 'open',
        createdAt: 1000,
        createdLocalDate: testDate,
        rescheduleCount: 0,
        sortOrder: 0.0,
        dueIsAllDay: false,
        updatedAt: 1000,
        deviceId: 'device-test',
      ),
    );

    final openTask4 = TaskWithDetails(
      task: Task(
        id: 'task-4',
        title: 'Open Task P4',
        priority: 4,
        status: 'open',
        createdAt: 500, // created earlier, but lower priority
        createdLocalDate: testDate,
        rescheduleCount: 0,
        sortOrder: 0.0,
        dueIsAllDay: false,
        updatedAt: 500,
        deviceId: 'device-test',
      ),
    );

    final doneTask = TaskWithDetails(
      task: Task(
        id: 'task-99',
        title: 'Completed Task',
        priority: 1,
        status: 'done',
        createdAt: 100,
        createdLocalDate: testDate,
        completedAt: 2000,
        completedLocalDate: testDate,
        rescheduleCount: 0,
        sortOrder: 0.0,
        dueIsAllDay: false,
        updatedAt: 2000,
        deviceId: 'device-test',
      ),
    );

    testWidgets('open tasks sort above completed on Today screen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final tasks = [doneTask, openTask1];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            todayTasksStreamProvider.overrideWith((ref, date) => Stream.value(tasks)),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: TodayScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Open Task P1'), findsOneWidget);
      expect(find.text('1 done today'), findsOneWidget);
      expect(find.text('Completed Task'), findsNothing); // collapsed by default

      final openPosToday = tester.getTopLeft(find.text('Open Task P1')).dy;
      final donePosToday = tester.getTopLeft(find.text('1 done today')).dy;
      expect(openPosToday, lessThan(donePosToday), reason: 'Open task must be above completed summary row on Today');

      // Tap to expand completed row
      await tester.tap(find.text('1 done today'));
      await tester.pumpAndSettle();
      expect(find.text('Completed Task'), findsOneWidget);
    });

    testWidgets('open tasks sort above completed on Tasks screen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final tasks = [doneTask, openTask1];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            todayTasksStreamProvider.overrideWith((ref, date) => Stream.value(tasks)),
            upcomingTasksStreamProvider.overrideWith((ref, date) => Stream.value([])),
            inboxTasksStreamProvider.overrideWith((ref) => Stream.value([])),
            projectsStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const TasksScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Open Task P1'), findsOneWidget);
      expect(find.text('1 done'), findsOneWidget);
      expect(find.text('Completed Task'), findsNothing); // collapsed by default

      final openPosTasks = tester.getTopLeft(find.text('Open Task P1')).dy;
      final donePosTasks = tester.getTopLeft(find.text('1 done')).dy;
      expect(openPosTasks, lessThan(donePosTasks), reason: 'Open task must be above completed summary row on Tasks');

      // Tap to expand completed row
      await tester.tap(find.text('1 done'));
      await tester.pumpAndSettle();
      expect(find.text('Completed Task'), findsOneWidget);
    });

    testWidgets('priority ordering puts p1 above p4 on both screens', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final tasks = [openTask4, openTask1]; // passed in p4-first order

      // Today screen
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            todayTasksStreamProvider.overrideWith((ref, date) => Stream.value(tasks)),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: TodayScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final p1Pos = tester.getTopLeft(find.text('Open Task P1')).dy;
      final p4Pos = tester.getTopLeft(find.text('Open Task P4')).dy;
      expect(p1Pos, lessThan(p4Pos), reason: 'P1 task must be rendered above P4 task');
    });

    testWidgets('Today caps at 5 open tasks and shows the view-all row at 6+', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final sevenTasks = List.generate(
        7,
        (i) => TaskWithDetails(
          task: Task(
            id: 'task-${10 + i}',
            title: 'Task Number ${i + 1}',
            priority: 2,
            status: 'open',
            createdAt: 1000 + i,
            createdLocalDate: testDate,
            rescheduleCount: 0,
            sortOrder: 0.0,
            dueIsAllDay: false,
            updatedAt: 1000 + i,
            deviceId: 'device-test',
          ),
        ),
      );

      late ProviderContainer container;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container = ProviderContainer(
            overrides: [
              todayTasksStreamProvider.overrideWith((ref, date) => Stream.value(sevenTasks)),
            ],
          ),
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: TodayScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Only first 5 tasks are shown
      for (int i = 1; i <= 5; i++) {
        expect(find.text('Task Number $i'), findsOneWidget);
      }
      expect(find.text('Task Number 6'), findsNothing);
      expect(find.text('Task Number 7'), findsNothing);

      // "View all 7 tasks" row is visible
      expect(find.text('View all 7 tasks'), findsOneWidget);

      // Tapping "View all 7 tasks" switches to Tasks tab on its Today view
      await tester.tap(find.text('View all 7 tasks'));
      await tester.pumpAndSettle();

      expect(container.read(navigationIndexProvider), equals(2));
      expect(container.read(taskViewTabProvider), equals(TaskViewTab.today));
    });

    testWidgets('Today empty state: nothing open/done shows "Nothing due today."', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            todayTasksStreamProvider.overrideWith((ref, date) => Stream.value([])),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: TodayScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nothing due today.'), findsOneWidget);
      expect(find.textContaining('done today'), findsNothing);
    });

    testWidgets('Today empty state: nothing open but some done shows only summary row', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            todayTasksStreamProvider.overrideWith((ref, date) => Stream.value([doneTask])),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: TodayScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nothing due today.'), findsNothing);
      expect(find.text('1 done today'), findsOneWidget);
    });

    testWidgets('Tasks screen overflow menu opens ArchivedTasksScreen with live count', (tester) async {
      final archivedItem = ArchivedTaskItem(
        taskDetails: TaskWithDetails(
          task: Task(
            id: 'task-201',
            title: 'Old Archived Project Plan',
            priority: 3,
            status: 'archived',
            createdAt: 1000,
            createdLocalDate: testDate,
            rescheduleCount: 0,
            sortOrder: 0.0,
            dueIsAllDay: false,
            updatedAt: 1000,
            deviceId: 'device-test',
          ),
          project: const Project(
            id: 'proj-1',
            name: 'Work',
            colorIndex: 0,
            archived: false,
            updatedAt: 1000,
            deviceId: 'device-test',
          ),
        ),
        archivedAtMs: 1726200000000,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            todayTasksStreamProvider.overrideWith((ref, date) => Stream.value([])),
            upcomingTasksStreamProvider.overrideWith((ref, date) => Stream.value([])),
            inboxTasksStreamProvider.overrideWith((ref) => Stream.value([])),
            projectsStreamProvider.overrideWith((ref) => Stream.value([])),
            archivedTasksStreamProvider.overrideWith((ref) => Stream.value([archivedItem])),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const TasksScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap overflow menu
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();

      expect(find.text('Archived (1)'), findsOneWidget);

      // Tap Archived (1) to open screen
      await tester.tap(find.text('Archived (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Archived'), findsOneWidget);
      expect(find.text('Old Archived Project Plan'), findsOneWidget);
      expect(find.text('P3'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
    });
  });

  group('Task Deletion Feature (§1, §2, §3, §4, §6)', () {
    testWidgets('Long-press on task row shows modal bottom sheet with Archive and Delete', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final timeService = TimeService(
        dayStartOffsetMinutes: 240,
        localize: (ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
        offsetMinutesAt: (_) => 0,
        tzIdProvider: () => 'UTC',
      );
      final eventsRepo = EventsRepository(db: db, timeService: timeService);
      final tasksRepo = TasksRepository(db: db, eventsRepository: eventsRepo, timeService: timeService);

      await tasksRepo.createTask(
        title: 'Long press test task',
        dueAt: DateTime.utc(2026, 9, 13, 12, 0).millisecondsSinceEpoch,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            tasksRepositoryProvider.overrideWithValue(tasksRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const TasksScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Long press on task card
      await tester.longPress(find.text('Long press test task'));
      await tester.pumpAndSettle();

      expect(find.text('Archive'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('Deleting a task with no history deletes and shows 6s undo SnackBar', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final timeService = TimeService(
        dayStartOffsetMinutes: 240,
        localize: (ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
        offsetMinutesAt: (_) => 0,
        tzIdProvider: () => 'UTC',
      );
      final eventsRepo = EventsRepository(db: db, timeService: timeService);
      final tasksRepo = TasksRepository(db: db, eventsRepository: eventsRepo, timeService: timeService);

      await tasksRepo.createTask(
        title: 'Accidental add',
        dueAt: DateTime.utc(2026, 9, 13, 12, 0).millisecondsSinceEpoch,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            tasksRepositoryProvider.overrideWithValue(tasksRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const TasksScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Long press to open menu
      await tester.longPress(find.text('Accidental add'));
      await tester.pumpAndSettle();

      // Tap Delete in menu
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Task is gone from view
      expect(find.text('Accidental add'), findsNothing);

      // 6-second SnackBar is shown with Undo action
      expect(find.text('Deleted "Accidental add".'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);

      // Tap Undo
      await tester.tap(find.text('Undo'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 7));
      await tester.pumpAndSettle();

      // Task is restored in view
      expect(find.text('Accidental add'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('TaskDetailSheet has Delete action button alongside Archive', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final timeService = TimeService(
        dayStartOffsetMinutes: 240,
        localize: (ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
        offsetMinutesAt: (_) => 0,
        tzIdProvider: () => 'UTC',
      );
      final eventsRepo = EventsRepository(db: db, timeService: timeService);
      final tasksRepo = TasksRepository(db: db, eventsRepository: eventsRepo, timeService: timeService);

      final task = await tasksRepo.createTask(title: 'Detail sheet task');
      final details = TaskWithDetails(task: task);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            tasksRepositoryProvider.overrideWithValue(tasksRepo),
            projectsStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: TaskDetailSheet(taskDetails: details),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Archive Task'), findsOneWidget);
      expect(find.byTooltip('Delete Task'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('Deleting a task with completions shows confirmation dialog naming history', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final timeService = TimeService(
        dayStartOffsetMinutes: 240,
        localize: (ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
        offsetMinutesAt: (_) => 0,
        tzIdProvider: () => 'UTC',
      );
      final eventsRepo = EventsRepository(db: db, timeService: timeService);
      final tasksRepo = TasksRepository(db: db, eventsRepository: eventsRepo, timeService: timeService);

      final task = await tasksRepo.createTask(title: 'Take Meds');
      await tasksRepo.completeTask(task.id);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            tasksRepositoryProvider.overrideWithValue(tasksRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const TasksScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Expand completed tasks
      await tester.tap(find.text('1 done'));
      await tester.pumpAndSettle();

      // Long press completed task
      await tester.longPress(find.text('Take Meds'));
      await tester.pumpAndSettle();

      // Tap Delete
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Confirmation dialog appears
      expect(find.text('Delete task?'), findsOneWidget);
      expect(find.textContaining('Take Meds has 1 completion'), findsOneWidget);
      expect(find.text('Archive'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Delete'), findsOneWidget);

      // Dismiss dialog cleanly
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('ArchivedTasksScreen gets Delete all archived button in app bar', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final timeService = TimeService(
        dayStartOffsetMinutes: 240,
        localize: (ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
        offsetMinutesAt: (_) => 0,
        tzIdProvider: () => 'UTC',
      );
      final eventsRepo = EventsRepository(db: db, timeService: timeService);
      final tasksRepo = TasksRepository(db: db, eventsRepository: eventsRepo, timeService: timeService);

      final task = await tasksRepo.createTask(title: 'Archived task 1');
      await tasksRepo.archiveTask(task.id);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            tasksRepositoryProvider.overrideWithValue(tasksRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const ArchivedTasksScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Delete all archived'), findsOneWidget);

      // Tap Delete all archived
      await tester.tap(find.text('Delete all archived'));
      await tester.pumpAndSettle();

      expect(find.text('Delete all archived?'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Delete all'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Delete all'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      // Tasks deleted
      expect(await tasksRepo.getTask(task.id), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });
  });
}
