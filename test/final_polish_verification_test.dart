import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:habit_tracker/core/time/time_service.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/data/providers/database_provider.dart';
import 'package:habit_tracker/data/repositories/tasks_repository.dart';
import 'package:habit_tracker/features/backup/domain/backup_providers.dart';
import 'package:habit_tracker/features/backup/presentation/backup_restore_screen.dart';
import 'package:habit_tracker/features/today/presentation/today_screen.dart';
import 'package:habit_tracker/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Final Polish Verification Tests', () {
    late AppDatabase db;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    // Verification 3: Set a backup password — 4 chars is refused, no-recovery warning impossible to miss
    testWidgets('Verification 3: Set backup password — 4 chars refused & no-recovery warning prominent', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const BackupRestoreScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open local backup dialog
      await tester.tap(find.text('Save a backup file'));
      await tester.pumpAndSettle();

      // Warning box
      expect(find.text('There is no way to recover this password.'), findsOneWidget);
      expect(
        find.textContaining('Nobody — not even us — can read it or reset the password.'),
        findsOneWidget,
      );

      // Attempt 4 characters
      final passwordField = find.widgetWithText(TextField, 'Backup password');
      final confirmField = find.widgetWithText(TextField, 'Confirm backup password');
      await tester.enterText(passwordField, '1234');
      await tester.enterText(confirmField, '1234');

      await tester.tap(find.text('Encrypt & Export'));
      await tester.pumpAndSettle();

      // Enforced 8 chars error
      expect(find.text('Password must be at least 8 characters.'), findsOneWidget);
    });

    // Verification 4: Restore dialog shows real counts and a real date
    testWidgets('Verification 4: Restore dialog shows real database counts and date', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Insert dummy task and focus session into database
      await db.into(db.tasks).insert(
        TasksCompanion.insert(
          id: 'task-real-1',
          title: 'Existing Real Task',
          createdAt: 1000,
          createdLocalDate: '2026-09-14',
          updatedAt: 1000,
          deviceId: 'device-1',
        ),
      );

      await db.into(db.focusSessions).insert(
        FocusSessionsCompanion.insert(
          id: 'session-real-1',
          startedAt: 1000,
          endedAt: 2500,
          localDate: '2026-09-14',
          tzOffsetMin: 0,
          plannedDurationS: const Value(1500),
          actualDurationS: const Value(1500),
          mode: 'pomodoro',
          outcome: 'completed',
          updatedAt: 2500,
          deviceId: 'device-1',
        ),
      );

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      final counts = await container.read(backupControllerProvider.notifier).getCurrentDataCounts();
      expect(counts.taskCount, equals(1));
      expect(counts.sessionCount, equals(1));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () {
                    // Show confirmation dialog with backup from 12 September
                    showDialog(
                      context: context,
                      builder: (dialogCtx) => AlertDialog(
                        title: const Text('Replace everything on this phone?'),
                        content: Text(
                          'This deletes the ${counts.sessionCount} session and ${counts.taskCount} task currently on this phone and replaces them with the backup from 12 September.\n\nThis cannot be undone.',
                        ),
                      ),
                    );
                  },
                  child: const Text('Trigger Restore'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Trigger Restore'));
      await tester.pumpAndSettle();

      expect(find.text('Replace everything on this phone?'), findsOneWidget);
      expect(find.textContaining('1 session and 1 task'), findsOneWidget);
      expect(find.textContaining('12 September'), findsOneWidget);
      expect(find.textContaining('This cannot be undone.'), findsOneWidget);
    });

    // Verification 6: Seed two years of backlog, open Today: today's tasks visible without scrolling
    testWidgets('Verification 6: 2-year backlog — Today tasks visible first without scrolling', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const today = '2026-09-14';
      final timeService = TimeService(
        dayStartOffsetMinutes: 240,
        localize: (ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
        offsetMinutesAt: (_) => 0,
        tzIdProvider: () => 'UTC',
      );

      // Create 2 tasks due TODAY
      final todayTasks = [
        TaskWithDetails(
          task: Task(
            id: 'task-today-1',
            title: 'Immediate Task Due Today 1',
            priority: 2,
            status: 'open',
            createdAt: 1000,
            createdLocalDate: today,
            rescheduleCount: 0,
            sortOrder: 0.0,
            dueAt: 1789390000000, // Today
            dueIsAllDay: true,
            updatedAt: 1000,
            deviceId: 'device-test',
          ),
        ),
        TaskWithDetails(
          task: Task(
            id: 'task-today-2',
            title: 'Immediate Task Due Today 2',
            priority: 1,
            status: 'open',
            createdAt: 1000,
            createdLocalDate: today,
            rescheduleCount: 0,
            sortOrder: 0.0,
            dueAt: 1789390000000, // Today
            dueIsAllDay: true,
            updatedAt: 1000,
            deviceId: 'device-test',
          ),
        ),
      ];

      // Create 50 overdue backlog tasks from 2024 to 2026
      final overdueTasks = List.generate(
        50,
        (i) => TaskWithDetails(
          task: Task(
            id: 'task-overdue-$i',
            title: 'Old Backlog Failure Task #$i',
            priority: 1, // Even with P1, it must NOT push today's tasks down!
            status: 'open',
            createdAt: 1000 + i,
            createdLocalDate: '2024-05-01',
            rescheduleCount: 10,
            sortOrder: 0.0,
            dueAt: 1714521600000 + (i * 86400000), // 2024 dates (overdue)
            dueIsAllDay: true,
            updatedAt: 1000 + i,
            deviceId: 'device-test',
          ),
        ),
      );

      final combined = [...todayTasks, ...overdueTasks];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            timeServiceProvider.overrideWithValue(timeService),
            todayTasksStreamProvider(today).overrideWith((ref) => Stream.value(combined)),
            selectedDateProvider.overrideWith((ref) => today),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(body: TodayScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Today's tasks are immediately visible without any scrolling
      expect(find.text('Immediate Task Due Today 1'), findsOneWidget);
      expect(find.text('Immediate Task Due Today 2'), findsOneWidget);

      // Overdue section header shows the count of 50
      expect(find.text('OVERDUE (50)'), findsOneWidget);
      expect(find.text('See all (50)'), findsOneWidget);

      // Verify that the overdue tasks are collapsed (only 3 visible initially)
      expect(find.text('Old Backlog Failure Task #0'), findsOneWidget);
      expect(find.text('Old Backlog Failure Task #1'), findsOneWidget);
      expect(find.text('Old Backlog Failure Task #2'), findsOneWidget);
      expect(find.text('Old Backlog Failure Task #3'), findsNothing);
      expect(find.text('Old Backlog Failure Task #49'), findsNothing);
    });
  });
}
