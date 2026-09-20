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

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    timeService = const TimeService(dayStartOffsetMinutes: 240);
    eventsRepo = EventsRepository(db: db, timeService: timeService);
    timerRepo = TimerRepository(db: db);
    // Base test time: 2026-09-10 10:00:00 UTC (1788948000000)
    currentUtcMs = 1788948000000;
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
      foregroundService: null, // No-op for tests
    );
  }

  group('Timer State Machine — SPEC.md §3.1', () {
    test('Initial state is idle with 25 min default Pomodoro', () {
      final controller = createController();
      expect(controller.state.status, equals(TimerStatus.idle));
      expect(controller.state.mode, equals(TimerMode.pomodoro));
      expect(controller.state.plannedDurationS, equals(1500));
      expect(controller.state.breakDurationS, equals(300));
      controller.dispose();
    });

    test('Mode switching and planned duration updates while idle', () {
      final controller = createController();
      controller.setMode(TimerMode.flow);
      expect(controller.state.mode, equals(TimerMode.flow));

      controller.setMode(TimerMode.pomodoro);
      controller.setPlannedDuration(1800); // 30 min
      expect(controller.state.plannedDurationS, equals(1800));
      controller.dispose();
    });

    test('Start Pomodoro session writes event and creates read model', () async {
      final controller = createController();
      await controller.startSession(plannedDurationS: 1500);

      expect(controller.state.status, equals(TimerStatus.running));
      expect(controller.state.sessionId, isNotNull);
      expect(controller.state.startedAtUtc, equals(currentUtcMs));
      expect(controller.state.plannedDurationS, equals(1500));

      // Assert immutable event written (§2.1, §2.2)
      final allEvents = await db.select(db.events).get();
      expect(allEvents.length, equals(1));
      final event = allEvents.first;
      expect(event.type, equals(EventTypes.sessionStarted));
      expect(event.occurredAt, equals(currentUtcMs));
      expect(event.subjectType, equals(SubjectTypes.session));
      expect(event.subjectId, equals(controller.state.sessionId));

      final payload = jsonDecode(event.payload) as Map<String, dynamic>;
      expect(payload['mode'], equals('pomodoro'));
      expect(payload['planned_duration_s'], equals(1500));

      // Assert focus_sessions read model row created (§2.3)
      final sessionRow = await timerRepo.getFocusSession(controller.state.sessionId!);
      expect(sessionRow, isNotNull);
      expect(sessionRow!.mode, equals('pomodoro'));
      expect(sessionRow.plannedDurationS, equals(1500));
      expect(sessionRow.startedAt, equals(currentUtcMs));
      expect(sessionRow.outcome, equals('running'));

      // Assert timer_states persistence (§3.2)
      final timerRow = await timerRepo.loadTimerState();
      expect(timerRow, isNotNull);
      expect(timerRow!.sessionId, equals(controller.state.sessionId));
      expect(timerRow.startedAtUtc, equals(currentUtcMs));
      expect(timerRow.plannedDurationS, equals(1500));
      expect(timerRow.pausedAccumulatedS, equals(0));
      expect(timerRow.pausedAtUtc, isNull);

      controller.dispose();
    });

    test('Start Flow session sets planned_duration_s = 0 and counts up', () async {
      final controller = createController();
      await controller.startSession(mode: TimerMode.flow);

      expect(controller.state.status, equals(TimerStatus.running));
      expect(controller.state.mode, equals(TimerMode.flow));
      expect(controller.state.plannedDurationS, equals(0));

      // Advance clock by 45 seconds
      currentUtcMs += 45000;
      expect(controller.state.computeElapsedSeconds(clock()), equals(45));
      expect(controller.state.computeRemainingSeconds(clock()), equals(0));

      controller.dispose();
    });

    test('Pause and Resume: elapsed time does NOT advance during pause (§3.2)', () async {
      final controller = createController();
      await controller.startSession(plannedDurationS: 1500);

      // Run for 100 seconds
      currentUtcMs += 100000;
      expect(controller.state.computeElapsedSeconds(clock()), equals(100));
      expect(controller.state.computeRemainingSeconds(clock()), equals(1400));

      // Pause session
      await controller.pauseSession();
      expect(controller.state.status, equals(TimerStatus.paused));
      expect(controller.state.pausedAtUtc, equals(currentUtcMs));

      // Advance clock by 300 seconds while paused
      currentUtcMs += 300000;
      // Elapsed must remain 100s, remaining must remain 1400s!
      expect(controller.state.computeElapsedSeconds(clock()), equals(100));
      expect(controller.state.computeRemainingSeconds(clock()), equals(1400));

      // Resume session
      await controller.resumeSession();
      expect(controller.state.status, equals(TimerStatus.running));
      expect(controller.state.pausedAccumulatedS, equals(300));
      expect(controller.state.pausedAtUtc, isNull);

      // Run for another 50 seconds
      currentUtcMs += 50000;
      expect(controller.state.computeElapsedSeconds(clock()), equals(150));
      expect(controller.state.computeRemainingSeconds(clock()), equals(1350));

      // Verify timer_states table in DB has accurate pausedAccumulatedS
      final timerRow = await timerRepo.loadTimerState();
      expect(timerRow!.pausedAccumulatedS, equals(300));
      expect(timerRow.pausedAtUtc, isNull);

      controller.dispose();
    });

    test('Multiple pauses accumulate correctly into pausedAccumulatedS', () async {
      final controller = createController();
      await controller.startSession(plannedDurationS: 1500);

      // Run 60s
      currentUtcMs += 60000;
      // Pause 1: 40s
      await controller.pauseSession();
      currentUtcMs += 40000;
      await controller.resumeSession();

      // Run 60s
      currentUtcMs += 60000;
      // Pause 2: 20s
      await controller.pauseSession();
      currentUtcMs += 20000;
      await controller.resumeSession();

      expect(controller.state.pausedAccumulatedS, equals(60));
      expect(controller.state.computeElapsedSeconds(clock()), equals(120));
      expect(controller.state.computeRemainingSeconds(clock()), equals(1380));

      controller.dispose();
    });

    test('Interruption tally writes events and updates focus_sessions row (§2.2 / item 6)', () async {
      final controller = createController();
      await controller.startSession(plannedDurationS: 1500);

      // 1 internal interruption
      await controller.recordInterruption(isInternal: true);
      expect(controller.state.interruptionsInternal, equals(1));
      expect(controller.state.interruptionsExternal, equals(0));

      // 2 external interruptions
      await controller.recordInterruption(isInternal: false);
      await controller.recordInterruption(isInternal: false);
      expect(controller.state.interruptionsInternal, equals(1));
      expect(controller.state.interruptionsExternal, equals(2));
      expect(controller.state.totalInterruptions, equals(3));

      // Verify events log
      final events = await db.select(db.events).get();
      final interruptionEvents = events.where((e) => e.type == EventTypes.sessionInterrupted).toList();
      expect(interruptionEvents.length, equals(3));

      final payload1 = jsonDecode(interruptionEvents[0].payload);
      expect(payload1['kind'], equals('internal'));
      final payload2 = jsonDecode(interruptionEvents[1].payload);
      expect(payload2['kind'], equals('external'));

      // Verify focus_sessions read model row updated
      final sessionRow = await timerRepo.getFocusSession(controller.state.sessionId!);
      expect(sessionRow!.interruptionsInternal, equals(1));
      expect(sessionRow.interruptionsExternal, equals(2));

      controller.dispose();
    });

    test('Abandon session logs session_abandoned and updates read model (§2.2, §3.1)', () async {
      final controller = createController();
      await controller.startSession(plannedDurationS: 1500);

      // Run for 300s then abandon
      currentUtcMs += 300000;
      await controller.abandonSession(reason: AbandonReasons.userStopped);

      expect(controller.state.status, equals(TimerStatus.abandoned));

      // Verify event
      final events = await db.select(db.events).get();
      final abandonEvent = events.firstWhere((e) => e.type == EventTypes.sessionAbandoned);
      final payload = jsonDecode(abandonEvent.payload);
      expect(payload['actual_duration_s'], equals(300));
      expect(payload['reason'], equals(AbandonReasons.userStopped));

      // Verify focus_sessions read model
      final sessionRow = await timerRepo.getFocusSession(controller.state.sessionId!);
      expect(sessionRow!.outcome, equals('abandoned'));
      expect(sessionRow.actualDurationS, equals(300));
      expect(sessionRow.endedAt, equals(currentUtcMs));

      // Verify timer_states cleared
      final timerRow = await timerRepo.loadTimerState();
      expect(timerRow!.sessionId, isNull);
      expect(timerRow.startedAtUtc, isNull);

      controller.dispose();
    });

    test('Complete session, submit rating 1-5, and transition to break (§3.1, §3 / item 7)', () async {
      final controller = createController();
      await controller.startSession(plannedDurationS: 1500);

      // Advance to completion
      currentUtcMs += 1500000;
      await controller.completeSession();

      expect(controller.state.status, equals(TimerStatus.completed));

      // Verify session_completed event
      final events = await db.select(db.events).get();
      final completedEvent = events.firstWhere((e) => e.type == EventTypes.sessionCompleted);
      final payload = jsonDecode(completedEvent.payload);
      expect(payload['actual_duration_s'], equals(1500));

      // Submit rating 4 with note
      await controller.submitRatingAndStartBreak(
        rating: 4,
        note: 'High productivity session',
      );

      // Verify focus_sessions row has rating and note
      final sessionRow = await timerRepo.getFocusSession(controller.state.sessionId!);
      expect(sessionRow!.focusRating, equals(4));
      expect(sessionRow.note, equals('High productivity session'));
      expect(sessionRow.outcome, equals('completed'));

      // Verify transition to break_running
      expect(controller.state.status, equals(TimerStatus.breakRunning));
      expect(controller.state.breakDurationS, equals(300));

      // Verify break_started event
      final allEvents = await db.select(db.events).get();
      expect(allEvents.any((e) => e.type == EventTypes.breakStarted), isTrue);

      controller.dispose();
    });

    test('Rating skipped leaves focus_rating null — never defaults to 3 (§3 / item 7)', () async {
      final controller = createController();
      await controller.startSession(plannedDurationS: 1500);

      currentUtcMs += 1500000;
      await controller.completeSession();

      // Skip rating
      await controller.submitRatingAndStartBreak(rating: null);

      final sessionRow = await timerRepo.getFocusSession(controller.state.sessionId!);
      expect(sessionRow!.focusRating, isNull); // Must be null, never 3!

      controller.dispose();
    });

    test('Skip break transitions to idle and writes break_completed event', () async {
      final controller = createController();
      await controller.startBreak(durationSeconds: 300);

      expect(controller.state.status, equals(TimerStatus.breakRunning));

      currentUtcMs += 120000; // 2 min into 5 min break
      await controller.skipBreak();

      expect(controller.state.status, equals(TimerStatus.idle));

      final events = await db.select(db.events).get();
      final breakComp = events.firstWhere((e) => e.type == EventTypes.breakCompleted);
      final payload = jsonDecode(breakComp.payload);
      expect(payload['duration_s'], equals(120));

      // timer_states cleared
      final timerRow = await timerRepo.loadTimerState();
      expect(timerRow!.startedAtUtc, isNull);

      controller.dispose();
    });

    test('Session belongs to logical date of START (§1.4)', () async {
      // 23:50 on 2026-09-09 with 04:00 day start -> logical date is 2026-09-09
      // (Wait: 23:50 is AFTER 04:00, so it belongs to 2026-09-09.
      // At 03:50 on 2026-09-10 with 04:00 day start -> logical date is 2026-09-09!)
      // Let's test 03:50 AM UTC on 2026-09-10 with localize returning 03:50 AM:
      final localDateAtStart = timeService.computeLocalDate(currentUtcMs);

      final controller = createController();
      await controller.startSession(plannedDurationS: 1500);

      final sessionRow = await timerRepo.getFocusSession(controller.state.sessionId!);
      expect(sessionRow!.localDate, equals(localDateAtStart));

      controller.dispose();
    });

    test('Session crossing day-start boundary threads start logical date to session_completed (§1.4)', () async {
      // Configure hermetic timeService with 04:00 (240 min) day start
      final hermeticTimeService = TimeService(
        dayStartOffsetMinutes: 240,
        localize: (utcMs) => DateTime.fromMillisecondsSinceEpoch(utcMs, isUtc: true),
      );
      final hermeticEventsRepo = EventsRepository(db: db, timeService: hermeticTimeService);

      // Start session at 03:30 AM UTC on 2026-09-10 (before 04:00 boundary)
      // Logical date of 03:30 AM with 04:00 day start is 2026-09-09
      final startInstant = DateTime.utc(2026, 9, 10, 3, 30).millisecondsSinceEpoch;
      currentUtcMs = startInstant;

      final controller = TimerController(
        eventsRepository: hermeticEventsRepo,
        timerRepository: timerRepo,
        timeService: hermeticTimeService,
        clock: clock,
        foregroundService: null,
      );

      // Planned 45 min (2700s) session -> ends at 04:15 AM (after 04:00 boundary)
      await controller.startSession(plannedDurationS: 2700);

      final sessionId = controller.state.sessionId!;
      final sessionRowBefore = await timerRepo.getFocusSession(sessionId);
      expect(sessionRowBefore!.localDate, equals('2026-09-09'));

      // Log interruption at 04:05 AM (after the day boundary)
      currentUtcMs = DateTime.utc(2026, 9, 10, 4, 5).millisecondsSinceEpoch;
      await controller.recordInterruption(isInternal: true);

      // End session at 04:15 AM (after the 04:00 boundary)
      currentUtcMs = DateTime.utc(2026, 9, 10, 4, 15).millisecondsSinceEpoch;
      await controller.completeSession();

      final sessionRowAfter = await timerRepo.getFocusSession(sessionId);
      expect(sessionRowAfter!.localDate, equals('2026-09-09'));

      // Verify that session_completed event has local_date equal to focus_sessions.local_date (§0 & §1.4)
      final events = await db.select(db.events).get();
      final completedEvent = events.firstWhere((e) => e.type == EventTypes.sessionCompleted);
      expect(completedEvent.localDate, equals('2026-09-09'));
      expect(completedEvent.localDate, equals(sessionRowAfter.localDate));

      // Verify session_interrupted also has local_date equal to session start date
      final interruptedEvent = events.firstWhere((e) => e.type == EventTypes.sessionInterrupted);
      expect(interruptedEvent.localDate, equals('2026-09-09'));

      controller.dispose();
    });
  });
}
