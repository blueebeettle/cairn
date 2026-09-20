// ignore_for_file: avoid_print
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/recurrence/recurrence.dart';
import 'package:habit_tracker/core/stats/statistics.dart';
import 'package:habit_tracker/core/time/time_service.dart';
import 'package:habit_tracker/data/database/app_database.dart' hide TimerState;
import 'package:habit_tracker/data/providers/database_provider.dart';
import 'package:habit_tracker/data/repositories/events_repository.dart';
import 'package:habit_tracker/data/repositories/settings_repository.dart';
import 'package:habit_tracker/data/repositories/timer_repository.dart';
import 'package:habit_tracker/features/settings/presentation/settings_screen.dart';
import 'package:habit_tracker/features/timer/domain/timer_state.dart';
import 'package:habit_tracker/features/timer/presentation/timer_controller.dart';
import 'package:habit_tracker/theme/app_theme.dart';

void main() {
  group('Settings Feature Tests (POLISH §4 & §2)', () {
    late AppDatabase db;
    late SettingsRepository settingsRepo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      settingsRepo = SettingsRepository(db: db);
    });

    tearDown(() async {
      await db.close();
    });

    test('1. All settings persist and reload with clamping on read and write', () async {
      final goalNotifier = DailyGoalMinutesNotifier(settingsRepo);
      final sessionNotifier = SessionLengthSecondsNotifier(settingsRepo);
      final breakNotifier = BreakLengthSecondsNotifier(settingsRepo);
      final longBreakNotifier = LongBreakLengthSecondsNotifier(settingsRepo);
      final cycleNotifier = SessionsBeforeLongBreakNotifier(settingsRepo);
      final weekStartNotifier = WeekStartNotifier(settingsRepo);

      // Defaults
      expect(goalNotifier.state, equals(25));
      expect(sessionNotifier.state, equals(1500));
      expect(breakNotifier.state, equals(300));
      expect(longBreakNotifier.state, equals(900));
      expect(cycleNotifier.state, equals(4));
      expect(weekStartNotifier.state, equals(DateTime.monday));

      // Normal writes
      goalNotifier.setGoal(45);
      sessionNotifier.setDuration(1800);
      breakNotifier.setDuration(600);
      longBreakNotifier.setDuration(1200);
      cycleNotifier.setCount(3);
      weekStartNotifier.setWeekStart(DateTime.sunday);

      // Verify immediate in-memory state
      expect(goalNotifier.state, equals(45));
      expect(sessionNotifier.state, equals(1800));
      expect(breakNotifier.state, equals(600));
      expect(longBreakNotifier.state, equals(1200));
      expect(cycleNotifier.state, equals(3));
      expect(weekStartNotifier.state, equals(DateTime.sunday));

      // Simulate app kill & reopen by creating new notifiers over same database
      await Future.delayed(const Duration(milliseconds: 20));
      final reloadedGoal = DailyGoalMinutesNotifier(settingsRepo);
      final reloadedSession = SessionLengthSecondsNotifier(settingsRepo);
      final reloadedBreak = BreakLengthSecondsNotifier(settingsRepo);
      final reloadedLongBreak = LongBreakLengthSecondsNotifier(settingsRepo);
      final reloadedCycle = SessionsBeforeLongBreakNotifier(settingsRepo);
      final reloadedWeekStart = WeekStartNotifier(settingsRepo);

      await Future.delayed(const Duration(milliseconds: 20));

      expect(reloadedGoal.state, equals(45));
      expect(reloadedSession.state, equals(1800));
      expect(reloadedBreak.state, equals(600));
      expect(reloadedLongBreak.state, equals(1200));
      expect(reloadedCycle.state, equals(3));
      expect(reloadedWeekStart.state, equals(DateTime.sunday));

      // Clamping test on write:
      goalNotifier.setGoal(0); // below min 5
      expect(goalNotifier.state, equals(5));
      goalNotifier.setGoal(1000); // above max 480
      expect(goalNotifier.state, equals(480));

      sessionNotifier.setDuration(100); // below 300
      expect(sessionNotifier.state, equals(300));
      sessionNotifier.setDuration(10000); // above 7200
      expect(sessionNotifier.state, equals(7200));

      breakNotifier.setDuration(10); // below 60
      expect(breakNotifier.state, equals(60));
      breakNotifier.setDuration(5000); // above 1800
      expect(breakNotifier.state, equals(1800));

      longBreakNotifier.setDuration(10); // below 60
      expect(longBreakNotifier.state, equals(60));
      longBreakNotifier.setDuration(5000); // above 3600
      expect(longBreakNotifier.state, equals(3600));

      cycleNotifier.setCount(1); // below 2
      expect(cycleNotifier.state, equals(2));
      cycleNotifier.setCount(20); // above 10
      expect(cycleNotifier.state, equals(10));

      weekStartNotifier.setWeekStart(0); // below 1
      expect(weekStartNotifier.state, equals(1));
      weekStartNotifier.setWeekStart(10); // above 7
      expect(weekStartNotifier.state, equals(7));

      // Clamping test on read (e.g. corrupt or hand-edited row in SQLite)
      await settingsRepo.setInt('daily_goal_minutes', 0);
      await settingsRepo.setInt('session_length_s', 50);
      await settingsRepo.setInt('break_length_s', 20);
      await settingsRepo.setInt('long_break_length_s', 20);
      await settingsRepo.setInt('sessions_before_long_break', 0);
      await settingsRepo.setInt('week_start', 99);

      final corruptGoal = DailyGoalMinutesNotifier(settingsRepo);
      final corruptSession = SessionLengthSecondsNotifier(settingsRepo);
      final corruptBreak = BreakLengthSecondsNotifier(settingsRepo);
      final corruptLongBreak = LongBreakLengthSecondsNotifier(settingsRepo);
      final corruptCycle = SessionsBeforeLongBreakNotifier(settingsRepo);
      final corruptWeekStart = WeekStartNotifier(settingsRepo);

      await Future.delayed(const Duration(milliseconds: 20));

      expect(corruptGoal.state, equals(5));
      expect(corruptSession.state, equals(300));
      expect(corruptBreak.state, equals(60));
      expect(corruptLongBreak.state, equals(60));
      expect(corruptCycle.state, equals(2));
      expect(corruptWeekStart.state, equals(7));
    });

    test('2. Invariant 1: Changing session length mid-session does not alter running countdown; next session uses new length', () async {
      const timeService = TimeService(dayStartOffsetMinutes: 240);
      final eventsRepo = EventsRepository(db: db, timeService: timeService);
      final timerRepo = TimerRepository(db: db, deviceId: 'test-device');

      var currentSessionLength = 3000; // 50 minutes (50 * 60)
      var currentBreakLength = 300;
      var currentLongBreakLength = 900;
      var currentSessionsBeforeLong = 4;
      var simulatedTimeMs = 1726300000000;

      final controller = TimerController(
        eventsRepository: eventsRepo,
        timerRepository: timerRepo,
        timeService: timeService,
        clock: () => simulatedTimeMs,
        getSessionLengthSeconds: () => currentSessionLength,
        getBreakLengthSeconds: () => currentBreakLength,
        getLongBreakLengthSeconds: () => currentLongBreakLength,
        getSessionsBeforeLongBreak: () => currentSessionsBeforeLong,
      );

      // Start session with 50 minutes
      await controller.startSession();
      expect(controller.state.status, equals(TimerStatus.running));
      expect(controller.state.plannedDurationS, equals(3000));
      expect(controller.state.computeRemainingSeconds(simulatedTimeMs), equals(3000));

      // Advance clock by 10 minutes (600s)
      simulatedTimeMs += 600 * 1000;
      expect(controller.state.computeRemainingSeconds(simulatedTimeMs), equals(2400));

      // User changes setting in Settings screen to 10 minutes (600s)
      currentSessionLength = 600;
      controller.onSessionLengthSettingChanged(600);

      // CRITICAL CHECK: Running countdown MUST NOT change!
      expect(controller.state.plannedDurationS, equals(3000));
      expect(controller.state.computeRemainingSeconds(simulatedTimeMs), equals(2400));

      // Advance clock another 5 minutes
      simulatedTimeMs += 300 * 1000;
      expect(controller.state.computeRemainingSeconds(simulatedTimeMs), equals(2100));

      // Finish this session
      await controller.completeSession();
      expect(controller.state.status, equals(TimerStatus.completed));

      // Reset back to idle
      controller.resetToIdle();
      expect(controller.state.status, equals(TimerStatus.idle));
      expect(controller.state.plannedDurationS, equals(600));

      // Start NEXT session
      await controller.startSession();
      expect(controller.state.status, equals(TimerStatus.running));
      expect(controller.state.plannedDurationS, equals(600)); // Next session is 10 minutes!
      expect(controller.state.computeRemainingSeconds(simulatedTimeMs), equals(600));
    });

    test('3. Invariant 5: Changing Day starts at does not rewrite historical figures', () async {
      var timeService = const TimeService(dayStartOffsetMinutes: 240); // 04:00 AM
      final eventsRepo = EventsRepository(db: db, timeService: timeService);
      final timerRepo = TimerRepository(db: db, deviceId: 'test-device');

      // 01:00 AM on 2026-09-14 UTC (which belongs to 2026-09-13 logical day under 04:00 AM offset)
      final earlyMorningUtcMs = 1726275600000; // 01:00 AM
      final historicalDate = timeService.computeLocalDate(earlyMorningUtcMs);

      final sessionId = await timerRepo.createFocusSession(
        mode: 'pomodoro',
        plannedDurationS: 1500,
        startedAt: earlyMorningUtcMs,
        localDate: historicalDate,
        tzOffsetMin: 0,
        tzId: 'UTC',
      );

      await eventsRepo.logEvent(
        type: 'session_completed',
        occurredAtUtcMs: earlyMorningUtcMs + 1500 * 1000,
        localDateOverride: historicalDate,
        subjectType: 'session',
        subjectId: sessionId,
        payload: {'actual_duration_s': 1500},
      );

      // Now user changes day start offset to 360 (06:00 AM)
      timeService = const TimeService(dayStartOffsetMinutes: 360);

      // Check DB records: historical row localDate remains untouched
      final sessionRow = await timerRepo.getFocusSession(sessionId);
      expect(sessionRow?.localDate, equals(historicalDate));

      final eventRow = (await db.select(db.events).get()).first;
      expect(eventRow.localDate, equals(historicalDate));
    });

    test('4. Invariant 6: Week start changes Stats week range but does NOT change RecurrenceRule', () async {
      // 1. TimeService with Monday start
      const timeServiceMon = TimeService(weekStart: DateTime.monday);
      final weekMon = StatsPeriod.week(timeServiceMon, '2026-09-16'); // Wednesday
      expect(weekMon.start, equals('2026-09-14')); // Monday
      expect(weekMon.end, equals('2026-09-20'));   // Sunday

      // 2. TimeService with Sunday start
      const timeServiceSun = TimeService(weekStart: DateTime.sunday);
      final weekSun = StatsPeriod.week(timeServiceSun, '2026-09-16'); // Wednesday
      expect(weekSun.start, equals('2026-09-13')); // Sunday
      expect(weekSun.end, equals('2026-09-19'));   // Saturday

      // 3. RecurrenceRule: must always anchor to Monday regardless of weekStart setting
      final rule = RecurrenceRule.parse('FREQ=WEEKLY;BYDAY=WE'); // every Wednesday
      expect(rule, isNotNull);
      final nextMon = rule!.nextAfter('2026-09-14');
      expect(nextMon, equals('2026-09-16'));

      // Recurrence rule has no knowledge of user weekStart and must never change
      final nextFromRule = rule.nextAfter('2026-09-16');
      expect(nextFromRule, equals('2026-09-23'));
    });

    test('5. Long break triggers after N completed Pomodoro sessions', () async {
      const timeService = TimeService(dayStartOffsetMinutes: 240);
      final eventsRepo = EventsRepository(db: db, timeService: timeService);
      final timerRepo = TimerRepository(db: db, deviceId: 'test-device');

      var simulatedTimeMs = 1726300000000;

      final controller = TimerController(
        eventsRepository: eventsRepo,
        timerRepository: timerRepo,
        timeService: timeService,
        clock: () => simulatedTimeMs,
        getSessionLengthSeconds: () => 1500,
        getBreakLengthSeconds: () => 300,
        getLongBreakLengthSeconds: () => 900,
        getSessionsBeforeLongBreak: () => 3, // Long break every 3 sessions
      );

      // Session 1
      await controller.startSession();
      await controller.completeSession();
      expect(controller.state.completedPomodoroCount, equals(1));
      await controller.startBreak();
      expect(controller.state.breakDurationS, equals(300)); // Short break
      await controller.skipBreak();

      // Session 2
      await controller.startSession();
      await controller.completeSession();
      expect(controller.state.completedPomodoroCount, equals(2));
      await controller.startBreak();
      expect(controller.state.breakDurationS, equals(300)); // Short break
      await controller.skipBreak();

      // Session 3 (Long break triggered!)
      await controller.startSession();
      await controller.completeSession();
      expect(controller.state.completedPomodoroCount, equals(3));
      await controller.startBreak();
      expect(controller.state.breakDurationS, equals(900)); // 15 min long break!
    });

    testWidgets('6. SettingsScreen renders cleanly at normal and 200% font scale without overflow',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844)); // standard phone dimensions

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            theme: ThemeData.light().copyWith(
              extensions: const [AppTokens.light],
            ),
            home: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(2.0), // 200% font scaling
              ),
              child: const SettingsScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify sections are rendered and reachable by scrolling
      expect(find.text('Focus'), findsOneWidget);

      final mainScrollable = find.byType(Scrollable).first;

      await tester.scrollUntilVisible(find.textContaining("Stopped sessions don't count toward your totals."), 200, scrollable: mainScrollable);
      expect(find.textContaining("Stopped sessions don't count toward your totals."), findsOneWidget);

      await tester.scrollUntilVisible(find.textContaining("Today can't break your streak."), 200, scrollable: mainScrollable);
      expect(find.textContaining("Today can't break your streak."), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Day & week'), 200, scrollable: mainScrollable);
      expect(find.text('Day & week'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Appearance'), 200, scrollable: mainScrollable);
      expect(find.text('Appearance'), findsOneWidget);

      await tester.scrollUntilVisible(find.widgetWithText(ListTile, 'Notifications'), 200, scrollable: mainScrollable);
      expect(find.widgetWithText(ListTile, 'Notifications'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Data'), 200, scrollable: mainScrollable);
      expect(find.text('Data'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('About'), 200, scrollable: mainScrollable);
      expect(find.text('About'), findsOneWidget);
      expect(find.textContaining("from beetlebyte"), findsOneWidget);

      // Scroll back up to open Daily goal slider dialog
      await tester.scrollUntilVisible(find.text('Daily goal'), -200, scrollable: mainScrollable);
      await tester.drag(mainScrollable, const Offset(0, 200));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Daily goal'));
      await tester.pumpAndSettle();

      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // No assertion errors or overflow exceptions thrown
      expect(tester.takeException(), isNull);
    });
  });
}
