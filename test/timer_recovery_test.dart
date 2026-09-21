import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/constants/event_types.dart';
import 'package:habit_tracker/core/time/time_service.dart';
import 'package:habit_tracker/data/database/app_database.dart' hide TimerState;
import 'package:habit_tracker/data/repositories/events_repository.dart';
import 'package:habit_tracker/data/repositories/timer_repository.dart';
import 'package:habit_tracker/features/timer/domain/timer_state.dart';
import 'package:habit_tracker/features/timer/presentation/timer_controller.dart';

void main() {
  late AppDatabase db;
  late TimeService timeService;
  late EventsRepository eventsRepo;
  late TimerRepository timerRepo;
  late int currentUtcMs;
  int clock() => currentUtcMs;

  const t0 = 1788948000000; // Base: 10:00:00 UTC

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    timeService = const TimeService(dayStartOffsetMinutes: 240);
    eventsRepo = EventsRepository(db: db, timeService: timeService);
    timerRepo = TimerRepository(db: db);
    currentUtcMs = t0;
  });

  tearDown(() async {
    await db.close();
  });

  TimerController createController() {
    return TimerController(
      eventsRepository: eventsRepo,
      timerRepository: timerRepo,
      timeService: timeService,
      clock: clock,
      foregroundService: null,
    );
  }

  group('Timer Recovery — SPEC.md §3.3 & §7 Fixture E', () {
    test('Fixture E: killed at t=10m of 25m session, relaunched at t=30m (§3.3 & §7)', () async {
      // 1. Simulate session started at t0 and active in database
      final sessionId = await timerRepo.createFocusSession(
        mode: 'pomodoro',
        plannedDurationS: 1500, // 25 min
        startedAt: t0,
        localDate: timeService.computeLocalDate(t0),
        tzOffsetMin: timeService.currentTzOffsetMin(t0),
        tzId: timeService.currentTzId(),
      );

      await timerRepo.persistTimerState(
        sessionId: sessionId,
        startedAtUtc: t0,
        plannedDurationS: 1500,
        mode: 'pomodoro',
        pausedAccumulatedS: 0,
        pausedAtUtc: null,
      );

      // Process killed at t = 10m (t0 + 600,000 ms).
      // Device advances to t = 30m (t0 + 1,800,000 ms).
      currentUtcMs = t0 + (30 * 60 * 1000);
      final expectedEnd = t0 + (25 * 60 * 1000);

      // 2. Relaunch app: create fresh controller and call initialize()
      final controller = createController();
      await controller.initialize();

      // Assert exactly one session_completed event logged
      final events = await db.select(db.events).get();
      final completedEvents = events.where((e) => e.type == EventTypes.sessionCompleted).toList();
      expect(completedEvents.length, equals(1));

      final completedEvent = completedEvents.first;
      // ended_at = expected_end (NOT now) per §3.3!
      expect(completedEvent.occurredAt, equals(expectedEnd));
      expect(completedEvent.occurredAt, isNot(equals(currentUtcMs)));

      final payload = jsonDecode(completedEvent.payload) as Map<String, dynamic>;
      // actual_duration_s = planned_duration_s (1500s)
      expect(payload['actual_duration_s'], equals(1500));

      // Assert focus_sessions read model row updated
      final sessionRow = await timerRepo.getFocusSession(sessionId);
      expect(sessionRow, isNotNull);
      expect(sessionRow!.outcome, equals('completed'));
      expect(sessionRow.endedAt, equals(expectedEnd));
      expect(sessionRow.actualDurationS, equals(1500));

      // Assert break screen is shown per §3.3
      expect(controller.state.status, equals(TimerStatus.breakRunning));
      expect(controller.state.breakDurationS, equals(300));

      controller.dispose();
    });

    test('now < expected_end: resumes running with correct remaining time (§3.3)', () async {
      // 1. Session started at t0, planned 1500s (25m)
      final sessionId = await timerRepo.createFocusSession(
        mode: 'pomodoro',
        plannedDurationS: 1500,
        startedAt: t0,
        localDate: timeService.computeLocalDate(t0),
        tzOffsetMin: timeService.currentTzOffsetMin(t0),
        tzId: timeService.currentTzId(),
      );

      await timerRepo.persistTimerState(
        sessionId: sessionId,
        startedAtUtc: t0,
        plannedDurationS: 1500,
        mode: 'pomodoro',
        pausedAccumulatedS: 0,
        pausedAtUtc: null,
      );

      // App killed at t=10m, relaunched at t=15m (t0 + 900s)
      currentUtcMs = t0 + (15 * 60 * 1000);

      final controller = createController();
      await controller.initialize();

      // Assert resumed in running state
      expect(controller.state.status, equals(TimerStatus.running));
      expect(controller.state.sessionId, equals(sessionId));

      // Remaining time is computed correctly: 1500 - 900 = 600s (10 min)
      expect(controller.state.computeRemainingSeconds(clock()), equals(600));
      expect(controller.state.computeElapsedSeconds(clock()), equals(900));

      // No session_completed event should be written
      final events = await db.select(db.events).get();
      expect(events.where((e) => e.type == EventTypes.sessionCompleted), isEmpty);

      controller.dispose();
    });

    test('Recovery when session was paused: stays paused with frozen time (§3.2, §3.3)', () async {
      final sessionId = await timerRepo.createFocusSession(
        mode: 'pomodoro',
        plannedDurationS: 1500,
        startedAt: t0,
        localDate: timeService.computeLocalDate(t0),
        tzOffsetMin: timeService.currentTzOffsetMin(t0),
        tzId: timeService.currentTzId(),
      );

      // Paused at t = t0 + 300s (5 min)
      final pausedAt = t0 + 300000;
      await timerRepo.persistTimerState(
        sessionId: sessionId,
        startedAtUtc: t0,
        plannedDurationS: 1500,
        mode: 'pomodoro',
        pausedAccumulatedS: 0,
        pausedAtUtc: pausedAt,
      );

      // Relaunched at t = t0 + 30 min (1800s)
      currentUtcMs = t0 + (30 * 60 * 1000);

      final controller = createController();
      await controller.initialize();

      // Assert resumed in paused state
      expect(controller.state.status, equals(TimerStatus.paused));
      expect(controller.state.pausedAtUtc, equals(pausedAt));

      // Elapsed must remain 300s (5m), remaining must remain 1200s (20m)
      expect(controller.state.computeElapsedSeconds(clock()), equals(300));
      expect(controller.state.computeRemainingSeconds(clock()), equals(1200));

      // No completion event written while paused
      final events = await db.select(db.events).get();
      expect(events.where((e) => e.type == EventTypes.sessionCompleted), isEmpty);

      controller.dispose();
    });

    test('Recovery with accumulated pauses respects extended expected_end', () async {
      final sessionId = await timerRepo.createFocusSession(
        mode: 'pomodoro',
        plannedDurationS: 1500, // 25 min
        startedAt: t0,
        localDate: timeService.computeLocalDate(t0),
        tzOffsetMin: timeService.currentTzOffsetMin(t0),
        tzId: timeService.currentTzId(),
      );

      // Session had 120s of accumulated pauses before being closed
      // expected_end = t0 + (1500 + 120) * 1000 = t0 + 1620s (27 min)
      await timerRepo.persistTimerState(
        sessionId: sessionId,
        startedAtUtc: t0,
        plannedDurationS: 1500,
        mode: 'pomodoro',
        pausedAccumulatedS: 120,
        pausedAtUtc: null,
      );

      // Relaunch at t = 26 min (1560s) -> now < expected_end (1620s)
      currentUtcMs = t0 + 1560000;

      final controller1 = createController();
      await controller1.initialize();

      expect(controller1.state.status, equals(TimerStatus.running));
      // Remaining = 1620s - 1560s = 60s
      expect(controller1.state.computeRemainingSeconds(clock()), equals(60));
      controller1.dispose();

      // Relaunch at t = 28 min (1680s) -> now >= expected_end (1620s)
      currentUtcMs = t0 + 1680000;

      final controller2 = createController();
      await controller2.initialize();

      expect(controller2.state.status, equals(TimerStatus.breakRunning));

      final events = await db.select(db.events).get();
      final completedEvent = events.firstWhere((e) => e.type == EventTypes.sessionCompleted);
      // Ended at expected_end (t0 + 1620s), NOT 28 min!
      expect(completedEvent.occurredAt, equals(t0 + 1620000));

      final payload = jsonDecode(completedEvent.payload);
      expect(payload['actual_duration_s'], equals(1500));

      controller2.dispose();
    });

    test('Break recovery: in progress resumes break; expired completes break', () async {
      // 1. Break in progress
      await timerRepo.persistTimerState(
        startedAtUtc: t0,
        plannedDurationS: 300, // 5 min
        mode: 'break',
        pausedAccumulatedS: 0,
      );

      // Relaunched at 2 min into break
      currentUtcMs = t0 + 120000;
      final controller1 = createController();
      await controller1.initialize();

      expect(controller1.state.status, equals(TimerStatus.breakRunning));
      expect(controller1.state.computeBreakRemainingSeconds(clock()), equals(180));
      controller1.dispose();

      // 2. Break expired while app closed (relaunched at 6 min)
      currentUtcMs = t0 + 360000;
      final controller2 = createController();
      await controller2.initialize();

      expect(controller2.state.status, equals(TimerStatus.idle));
      final events = await db.select(db.events).get();
      expect(events.any((e) => e.type == EventTypes.breakCompleted), isTrue);

      controller2.dispose();
    });

    test('Recovery across day-start boundary preserves focus_sessions local_date on session_completed (§1.4)', () async {
      final hermeticTimeService = TimeService(
        dayStartOffsetMinutes: 240,
        localize: (utcMs) => DateTime.fromMillisecondsSinceEpoch(utcMs, isUtc: true),
      );
      final hermeticEventsRepo = EventsRepository(db: db, timeService: hermeticTimeService);

      // Session started at 03:30 AM (logical date: 2026-09-09), planned 2700s (ends 04:15 AM)
      final startInstant = DateTime.utc(2026, 9, 10, 3, 30).millisecondsSinceEpoch;
      final expectedEnd = startInstant + 2700000;
      final sessionId = await timerRepo.createFocusSession(
        mode: 'pomodoro',
        plannedDurationS: 2700,
        startedAt: startInstant,
        localDate: '2026-09-09',
        tzOffsetMin: hermeticTimeService.currentTzOffsetMin(startInstant),
        tzId: hermeticTimeService.currentTzId(),
      );

      await timerRepo.persistTimerState(
        sessionId: sessionId,
        startedAtUtc: startInstant,
        plannedDurationS: 2700,
        mode: 'pomodoro',
        pausedAccumulatedS: 0,
        pausedAtUtc: null,
      );

      // App killed, relaunched at 05:00 AM (after expected end 04:15 AM)
      currentUtcMs = DateTime.utc(2026, 9, 10, 5, 0).millisecondsSinceEpoch;

      final controller = TimerController(
        eventsRepository: hermeticEventsRepo,
        timerRepository: timerRepo,
        timeService: hermeticTimeService,
        clock: clock,
        foregroundService: null,
      );

      await controller.initialize();

      // Assert session_completed has local_date == '2026-09-09' (from focus_sessions row)
      final events = await db.select(db.events).get();
      final completedEvent = events.firstWhere((e) => e.type == EventTypes.sessionCompleted);
      expect(completedEvent.occurredAt, equals(expectedEnd));
      expect(completedEvent.localDate, equals('2026-09-09'));

      final sessionRow = await timerRepo.getFocusSession(sessionId);
      expect(completedEvent.localDate, equals(sessionRow!.localDate));

      controller.dispose();
    });
  });

  group('reconcileOnResume — widget-driven state changes (§3.3)', () {
    test('idle in memory and no session in the DB leaves the user\'s picks alone', () async {
      final controller = createController();
      // The user opened the Timer screen, chose Flow and a custom length, but
      // has not started anything yet. A plain app-switch must not reset that.
      controller.setMode(TimerMode.flow);
      controller.setPlannedDuration(3000);

      await controller.reconcileOnResume();

      expect(controller.state.isIdle, isTrue);
      expect(controller.state.mode, equals(TimerMode.flow));
      expect(controller.state.plannedDurationS, equals(3000));

      controller.dispose();
    });

    test('idle in memory but a session in the DB recovers it (started from the widget)', () async {
      final controller = createController();
      expect(controller.state.isIdle, isTrue);

      // The widget's background isolate started a session while the app sat
      // on another tab.
      final sessionId = await timerRepo.createFocusSession(
        mode: 'pomodoro',
        plannedDurationS: 1500,
        startedAt: t0,
        localDate: timeService.computeLocalDate(t0),
        tzOffsetMin: timeService.currentTzOffsetMin(t0),
        tzId: timeService.currentTzId(),
      );
      await timerRepo.persistTimerState(
        sessionId: sessionId,
        startedAtUtc: t0,
        plannedDurationS: 1500,
        mode: 'pomodoro',
        pausedAccumulatedS: 0,
        pausedAtUtc: null,
      );

      currentUtcMs = t0 + (5 * 60 * 1000);
      await controller.reconcileOnResume();

      expect(controller.state.isRunning, isTrue);
      expect(controller.state.sessionId, equals(sessionId));
      expect(controller.state.computeRemainingSeconds(currentUtcMs), equals(20 * 60));

      controller.dispose();
    });

    test('running in memory but paused in the DB picks up the widget pause', () async {
      final controller = createController();
      await controller.startSession(plannedDurationS: 1500);
      expect(controller.state.isRunning, isTrue);

      // Widget Pause at t+5m writes timer_states directly.
      currentUtcMs = t0 + (5 * 60 * 1000);
      await timerRepo.persistTimerState(
        sessionId: controller.state.sessionId,
        startedAtUtc: t0,
        plannedDurationS: 1500,
        mode: 'pomodoro',
        pausedAccumulatedS: 0,
        pausedAtUtc: currentUtcMs,
      );

      currentUtcMs = t0 + (6 * 60 * 1000);
      await controller.reconcileOnResume();

      expect(controller.state.isPaused, isTrue);
      expect(controller.state.pausedAtUtc, equals(t0 + (5 * 60 * 1000)));
      // Clock kept moving while paused, but remaining is frozen at 20m.
      expect(controller.state.computeRemainingSeconds(currentUtcMs), equals(20 * 60));

      controller.dispose();
    });

    test('running in memory but cleared in the DB goes idle (widget Stop)', () async {
      final controller = createController();
      await controller.startSession(plannedDurationS: 1500);
      expect(controller.state.isRunning, isTrue);

      // Widget Stop abandons and clears timer_states.
      currentUtcMs = t0 + (3 * 60 * 1000);
      await timerRepo.clearTimerState();

      await controller.reconcileOnResume();

      expect(controller.state.isIdle, isTrue);
      expect(controller.state.sessionId, isNull);

      controller.dispose();
    });
  });
}
