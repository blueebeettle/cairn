import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/event_types.dart';
import '../../../../core/time/time_service.dart';
import '../../../../data/database/app_database.dart' hide TimerState;
import '../../../../data/providers/database_provider.dart';
import '../../../../data/repositories/events_repository.dart';
import '../../../../data/repositories/timer_repository.dart';
import '../domain/timer_state.dart';
import '../services/timer_foreground_service.dart';

/// Provides the singleton [TimerForegroundService].
final timerForegroundServiceProvider = Provider<TimerForegroundService>((ref) {
  return TimerForegroundService();
});

/// StateNotifierProvider for the Timer state machine.
final timerControllerProvider =
    StateNotifierProvider<TimerController, TimerState>((ref) {
  final eventsRepo = ref.watch(eventsRepositoryProvider);
  final timerRepo = ref.watch(timerRepositoryProvider);
  final timeService = ref.watch(timeServiceProvider);
  final clock = ref.watch(clockProvider);
  final foregroundService = ref.watch(timerForegroundServiceProvider);

  final controller = TimerController(
    eventsRepository: eventsRepo,
    timerRepository: timerRepo,
    timeService: timeService,
    clock: clock,
    foregroundService: foregroundService,
    getSessionLengthSeconds: () => ref.read(sessionLengthSecondsProvider),
    getBreakLengthSeconds: () => ref.read(breakLengthSecondsProvider),
    getLongBreakLengthSeconds: () => ref.read(longBreakLengthSecondsProvider),
    getSessionsBeforeLongBreak: () => ref.read(sessionsBeforeLongBreakProvider),
  );

  ref.listen<int>(sessionLengthSecondsProvider, (_, next) {
    controller.onSessionLengthSettingChanged(next);
  });
  ref.listen<int>(breakLengthSecondsProvider, (_, next) {
    controller.onBreakLengthSettingChanged(next);
  });
  ref.listen<int>(longBreakLengthSecondsProvider, (_, next) {
    controller.onLongBreakLengthSettingChanged(next);
  });
  ref.listen<int>(sessionsBeforeLongBreakProvider, (_, next) {
    controller.onSessionsBeforeLongBreakSettingChanged(next);
  });

  return controller;
});

/// Controller implementing the Timer state machine per SPEC.md §3.
class TimerController extends StateNotifier<TimerState> {
  TimerController({
    required this.eventsRepository,
    required this.timerRepository,
    required this.timeService,
    required this.clock,
    this.foregroundService,
    int Function()? getSessionLengthSeconds,
    int Function()? getBreakLengthSeconds,
    int Function()? getLongBreakLengthSeconds,
    int Function()? getSessionsBeforeLongBreak,
  })  : _getSessionLengthSeconds = getSessionLengthSeconds ?? (() => 1500),
        _getBreakLengthSeconds = getBreakLengthSeconds ?? (() => 300),
        _getLongBreakLengthSeconds = getLongBreakLengthSeconds ?? (() => 900),
        _getSessionsBeforeLongBreak = getSessionsBeforeLongBreak ?? (() => 4),
        super(TimerState(
          plannedDurationS: (getSessionLengthSeconds ?? (() => 1500))(),
          breakDurationS: (getBreakLengthSeconds ?? (() => 300))(),
        )) {
    _listenToNotificationActions();
  }

  final EventsRepository eventsRepository;
  final TimerRepository timerRepository;
  final TimeService timeService;
  final Clock clock;
  final TimerForegroundService? foregroundService;

  final int Function() _getSessionLengthSeconds;
  final int Function() _getBreakLengthSeconds;
  final int Function() _getLongBreakLengthSeconds;
  final int Function() _getSessionsBeforeLongBreak;

  EventsRepository get _eventsRepo => eventsRepository;
  TimerRepository get _timerRepo => timerRepository;
  TimeService get _timeService => timeService;
  Clock get _clock => clock;
  TimerForegroundService? get _foregroundService => foregroundService;

  void onSessionLengthSettingChanged(int newLengthS) {
    if (state.isIdle || state.isAbandoned) {
      state = state.copyWith(plannedDurationS: newLengthS);
    }
  }

  void onBreakLengthSettingChanged(int newBreakS) {
    if (state.isIdle || state.isAbandoned) {
      state = state.copyWith(breakDurationS: newBreakS);
    }
  }

  void onLongBreakLengthSettingChanged(int newLongBreakS) {
    // Dynamic getter reads updated value on next long break calculation
  }

  void onSessionsBeforeLongBreakSettingChanged(int newCount) {
    // Dynamic getter reads updated value on next long break calculation
  }

  Timer? _ticker;

  void _listenToNotificationActions() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
    }
  }

  void _onReceiveTaskData(Object data) {
    if (data is Map && data['action'] != null) {
      final action = data['action'] as String;
      if (action == 'pause') {
        pauseSession();
      } else if (action == 'resume') {
        resumeSession();
      } else if (action == 'skip') {
        if (state.isBreakRunning) {
          skipBreak();
        } else if (state.isRunning || state.isPaused) {
          abandonSession();
        }
      }
    }
  }

  /// Cold-start recovery per SPEC.md §3.3.
  Future<void> initialize() async {
    final row = await _timerRepo.loadTimerState();
    if (row == null || row.startedAtUtc == null) {
      state = TimerState(
        plannedDurationS: _getSessionLengthSeconds(),
        breakDurationS: _getBreakLengthSeconds(),
      );
      return;
    }

    final now = _clock();

    // 1. Break recovery
    if (row.mode == 'break') {
      final breakDurationS =
          row.plannedDurationS > 0 ? row.plannedDurationS : _getBreakLengthSeconds();
      final breakStartedAt = row.startedAtUtc!;
      final breakEnd = breakStartedAt + breakDurationS * 1000;

      if (now < breakEnd) {
        state = state.copyWith(
          status: TimerStatus.breakRunning,
          breakDurationS: breakDurationS,
          breakStartedAtUtc: breakStartedAt,
        );
        _startTicker();
      } else {
        await _eventsRepo.logEvent(
          type: EventTypes.breakCompleted,
          occurredAtUtcMs: breakEnd,
          payload: {'duration_s': breakDurationS},
        );
        await _timerRepo.clearTimerState();
        state = TimerState(
          plannedDurationS: _getSessionLengthSeconds(),
          breakDurationS: _getBreakLengthSeconds(),
        );
      }
      return;
    }

    // 2. Focus session recovery
    final mode = TimerMode.fromDbValue(row.mode);
    final plannedDurationS = row.plannedDurationS;
    final startedAt = row.startedAtUtc!;
    final pausedAccumulatedS = row.pausedAccumulatedS;
    final pausedAt = row.pausedAtUtc;
    final sessionId = row.sessionId;

    FocusSession? sessionRow;
    if (sessionId != null) {
      sessionRow = await _timerRepo.getFocusSession(sessionId);
    }

    final interruptionsInternal = sessionRow?.interruptionsInternal ?? 0;
    final interruptionsExternal = sessionRow?.interruptionsExternal ?? 0;

    if (mode == TimerMode.flow) {
      if (pausedAt != null) {
        state = TimerState(
          status: TimerStatus.paused,
          mode: TimerMode.flow,
          sessionId: sessionId,
          startedAtUtc: startedAt,
          plannedDurationS: 0,
          pausedAccumulatedS: pausedAccumulatedS,
          pausedAtUtc: pausedAt,
          taskId: row.taskId,
          projectId: row.projectId,
          interruptionsInternal: interruptionsInternal,
          interruptionsExternal: interruptionsExternal,
          startLocalDate: sessionRow?.localDate,
        );
      } else {
        state = TimerState(
          status: TimerStatus.running,
          mode: TimerMode.flow,
          sessionId: sessionId,
          startedAtUtc: startedAt,
          plannedDurationS: 0,
          pausedAccumulatedS: pausedAccumulatedS,
          taskId: row.taskId,
          projectId: row.projectId,
          interruptionsInternal: interruptionsInternal,
          interruptionsExternal: interruptionsExternal,
          startLocalDate: sessionRow?.localDate,
        );
        _startTicker();
        _updateForegroundNotification();
      }
      return;
    }

    // Pomodoro recovery (§3.3)
    if (pausedAt != null) {
      // Session was paused when app closed
      state = TimerState(
        status: TimerStatus.paused,
        mode: TimerMode.pomodoro,
        sessionId: sessionId,
        startedAtUtc: startedAt,
        plannedDurationS: plannedDurationS,
        pausedAccumulatedS: pausedAccumulatedS,
        pausedAtUtc: pausedAt,
        taskId: row.taskId,
        projectId: row.projectId,
        interruptionsInternal: interruptionsInternal,
        interruptionsExternal: interruptionsExternal,
        startLocalDate: sessionRow?.localDate,
      );
    } else {
      // Session was running when app closed
      final expectedEnd =
          startedAt + (plannedDurationS + pausedAccumulatedS) * 1000;

      if (now < expectedEnd) {
        // now < expected_end -> resume with correct remaining time
        state = TimerState(
          status: TimerStatus.running,
          mode: TimerMode.pomodoro,
          sessionId: sessionId,
          startedAtUtc: startedAt,
          plannedDurationS: plannedDurationS,
          pausedAccumulatedS: pausedAccumulatedS,
          taskId: row.taskId,
          projectId: row.projectId,
          interruptionsInternal: interruptionsInternal,
          interruptionsExternal: interruptionsExternal,
          startLocalDate: sessionRow?.localDate,
        );
        _startTicker();
        _updateForegroundNotification();
      } else {
        // now >= expected_end -> write session_completed with
        // ended_at = expected_end (NOT now) and
        // actual_duration_s = planned_duration_s, then show the break screen.
        await _eventsRepo.logEvent(
          type: EventTypes.sessionCompleted,
          occurredAtUtcMs: expectedEnd,
          localDateOverride: sessionRow?.localDate,
          subjectType: SubjectTypes.session,
          subjectId: sessionId,
          payload: {'actual_duration_s': plannedDurationS},
        );

        if (sessionId != null) {
          await _timerRepo.finalizeSession(
            sessionId,
            endedAt: expectedEnd,
            actualDurationS: plannedDurationS,
            outcome: SessionOutcomes.completed,
          );
        }

        // Show break screen per §3.3
        final sessionsBeforeLong = _getSessionsBeforeLongBreak();
        final newPomodoroCount = state.completedPomodoroCount + 1;
        final isLong = newPomodoroCount > 0 &&
            (newPomodoroCount % sessionsBeforeLong == 0);
        final breakDurationS =
            isLong ? _getLongBreakLengthSeconds() : _getBreakLengthSeconds();
        await _eventsRepo.logEvent(
          type: EventTypes.breakStarted,
          occurredAtUtcMs: now,
          payload: {'duration_s': breakDurationS},
        );

        await _timerRepo.persistTimerState(
          startedAtUtc: now,
          plannedDurationS: breakDurationS,
          mode: 'break',
          pausedAccumulatedS: 0,
        );

        state = TimerState(
          status: TimerStatus.breakRunning,
          mode: TimerMode.pomodoro,
          sessionId: sessionId,
          breakDurationS: breakDurationS,
          breakStartedAtUtc: now,
          completedPomodoroCount: newPomodoroCount,
        );
        _startTicker();
      }
    }
  }

  /// Starts a new focus session (§3.1).
  Future<void> startSession({
    TimerMode? mode,
    int? plannedDurationS,
    String? taskId,
    String? projectId,
  }) async {
    final now = _clock();
    final selectedMode = mode ?? state.mode;
    final duration = selectedMode == TimerMode.flow
        ? 0
        : (plannedDurationS ??
            (state.status == TimerStatus.idle
                ? state.plannedDurationS
                : _getSessionLengthSeconds()));
    final targetTaskId = taskId ?? state.taskId;
    final targetProjectId = projectId ?? state.projectId;

    // Logical date of START (§1.4)
    final localDate = _timeService.computeLocalDate(now);
    final tzOffsetMin = _timeService.currentTzOffsetMin(now);
    final tzId = _timeService.currentTzId();

    // Create read model row first to get sessionId
    final sessionId = await _timerRepo.createFocusSession(
      mode: selectedMode.toDbValue(),
      plannedDurationS: duration,
      startedAt: now,
      localDate: localDate,
      tzOffsetMin: tzOffsetMin,
      tzId: tzId,
      taskId: targetTaskId,
      projectId: targetProjectId,
    );

    // Log immutable event per §2.2
    final payload = <String, dynamic>{
      'mode': selectedMode.toDbValue(),
      'planned_duration_s': duration,
    };
    if (targetTaskId != null) payload['task_id'] = targetTaskId;
    if (targetProjectId != null) payload['project_id'] = targetProjectId;

    await _eventsRepo.logEvent(
      type: EventTypes.sessionStarted,
      occurredAtUtcMs: now,
      subjectType: SubjectTypes.session,
      subjectId: sessionId,
      payload: payload,
    );

    // Persist to timer_states table (§3.2)
    await _timerRepo.persistTimerState(
      sessionId: sessionId,
      startedAtUtc: now,
      plannedDurationS: duration,
      mode: selectedMode.toDbValue(),
      pausedAccumulatedS: 0,
      pausedAtUtc: null,
      taskId: targetTaskId,
      projectId: targetProjectId,
    );

    state = TimerState(
      status: TimerStatus.running,
      mode: selectedMode,
      sessionId: sessionId,
      startedAtUtc: now,
      plannedDurationS: duration,
      pausedAccumulatedS: 0,
      pausedAtUtc: null,
      taskId: targetTaskId,
      projectId: targetProjectId,
      interruptionsInternal: 0,
      interruptionsExternal: 0,
      breakDurationS: state.breakDurationS,
      startLocalDate: localDate,
      completedPomodoroCount: state.completedPomodoroCount,
    );

    _startTicker();
    _startForegroundService();
  }

  /// Pauses the running session (§3.1).
  Future<void> pauseSession() async {
    if (state.status != TimerStatus.running) return;

    final now = _clock();
    await _timerRepo.persistTimerState(
      sessionId: state.sessionId,
      startedAtUtc: state.startedAtUtc,
      plannedDurationS: state.plannedDurationS,
      mode: state.mode.toDbValue(),
      pausedAccumulatedS: state.pausedAccumulatedS,
      pausedAtUtc: now,
      taskId: state.taskId,
      projectId: state.projectId,
    );

    _stopTicker();
    state = state.copyWith(
      status: TimerStatus.paused,
      pausedAtUtc: now,
    );

    _updateForegroundNotification();
  }

  /// Resumes a paused session (§3.1).
  Future<void> resumeSession() async {
    if (state.status != TimerStatus.paused || state.pausedAtUtc == null) return;

    final now = _clock();
    final additionalPausedS = (now - state.pausedAtUtc!) ~/ 1000;
    final totalPausedAccumulated =
        state.pausedAccumulatedS + (additionalPausedS > 0 ? additionalPausedS : 0);

    await _timerRepo.persistTimerState(
      sessionId: state.sessionId,
      startedAtUtc: state.startedAtUtc,
      plannedDurationS: state.plannedDurationS,
      mode: state.mode.toDbValue(),
      pausedAccumulatedS: totalPausedAccumulated,
      pausedAtUtc: null,
      taskId: state.taskId,
      projectId: state.projectId,
    );

    state = state.copyWith(
      status: TimerStatus.running,
      pausedAccumulatedS: totalPausedAccumulated,
      clearPausedAt: true,
    );

    _startTicker();
    _updateForegroundNotification();
  }

  /// Records an internal or external interruption (§2.2, §3 / item 6).
  Future<void> recordInterruption({required bool isInternal}) async {
    if (state.status != TimerStatus.running &&
        state.status != TimerStatus.paused) {
      return;
    }

    final now = _clock();
    final kind = isInternal
        ? InterruptionKinds.internalKind
        : InterruptionKinds.externalKind;

    await _eventsRepo.logEvent(
      type: EventTypes.sessionInterrupted,
      occurredAtUtcMs: now,
      localDateOverride: state.startLocalDate,
      subjectType: SubjectTypes.session,
      subjectId: state.sessionId,
      payload: {'kind': kind},
    );

    if (state.sessionId != null) {
      await _timerRepo.recordInterruption(
        state.sessionId!,
        isInternal: isInternal,
      );
    }

    if (isInternal) {
      state = state.copyWith(
        interruptionsInternal: state.interruptionsInternal + 1,
      );
    } else {
      state = state.copyWith(
        interruptionsExternal: state.interruptionsExternal + 1,
      );
    }
  }

  /// Abandons the active session (§3.1, §2.2).
  Future<void> abandonSession({
    String reason = AbandonReasons.userStopped,
  }) async {
    if (state.status != TimerStatus.running &&
        state.status != TimerStatus.paused) {
      return;
    }

    final now = _clock();
    final actualDurationS = state.computeElapsedSeconds(now);

    await _eventsRepo.logEvent(
      type: EventTypes.sessionAbandoned,
      occurredAtUtcMs: now,
      localDateOverride: state.startLocalDate,
      subjectType: SubjectTypes.session,
      subjectId: state.sessionId,
      payload: {
        'actual_duration_s': actualDurationS,
        'reason': reason,
      },
    );

    if (state.sessionId != null) {
      await _timerRepo.finalizeSession(
        state.sessionId!,
        endedAt: now,
        actualDurationS: actualDurationS,
        outcome: SessionOutcomes.abandoned,
      );
    }

    _lastAbandonedState = state;

    await _timerRepo.clearTimerState();
    _stopTicker();
    await _foregroundService?.stopService();

    state = state.copyWith(status: TimerStatus.abandoned);
  }

  TimerState? _lastAbandonedState;

  /// Restores the last abandoned session when Undo is tapped on the SnackBar.
  Future<void> undoAbandonSession() async {
    if (_lastAbandonedState == null) return;
    final restored = _lastAbandonedState!;
    _lastAbandonedState = null;

    if (restored.sessionId != null) {
      await _timerRepo.restoreSession(restored.sessionId!);
      await _timerRepo.persistTimerState(
        sessionId: restored.sessionId,
        startedAtUtc: restored.startedAtUtc,
        plannedDurationS: restored.plannedDurationS,
        mode: restored.mode.toDbValue(),
        pausedAccumulatedS: restored.pausedAccumulatedS,
        pausedAtUtc: restored.pausedAtUtc,
        taskId: restored.taskId,
        projectId: restored.projectId,
      );
    }

    state = restored;
    if (restored.isRunning) {
      _startTicker();
      _startForegroundService();
    }
  }

  /// Completes the session (§3.1).
  Future<void> completeSession() async {
    if (state.status != TimerStatus.running &&
        state.status != TimerStatus.paused) {
      return;
    }
    unawaited(HapticFeedback.mediumImpact().catchError((_) {}));

    final now = _clock();
    final int actualDurationS;
    final int endedAt;

    if (state.isPomodoro && state.expectedEndUtcMs != null && now >= state.expectedEndUtcMs!) {
      actualDurationS = state.plannedDurationS;
      endedAt = state.expectedEndUtcMs!;
    } else {
      actualDurationS = state.computeElapsedSeconds(now);
      endedAt = now;
    }

    await _eventsRepo.logEvent(
      type: EventTypes.sessionCompleted,
      occurredAtUtcMs: endedAt,
      localDateOverride: state.startLocalDate,
      subjectType: SubjectTypes.session,
      subjectId: state.sessionId,
      payload: {'actual_duration_s': actualDurationS},
    );

    if (state.sessionId != null) {
      await _timerRepo.finalizeSession(
        state.sessionId!,
        endedAt: endedAt,
        actualDurationS: actualDurationS,
        outcome: SessionOutcomes.completed,
      );
    }

    await _timerRepo.clearTimerState();
    _stopTicker();
    await _foregroundService?.stopService();

    final newPomodoroCount = state.isPomodoro
        ? state.completedPomodoroCount + 1
        : state.completedPomodoroCount;

    state = state.copyWith(
      status: TimerStatus.completed,
      completedPomodoroCount: newPomodoroCount,
    );
  }

  /// Submits post-session rating (1–5, null if skipped) and transitions to break (§3 / item 7).
  Future<void> submitRatingAndStartBreak({
    int? rating,
    String? note,
  }) async {
    if (state.sessionId != null && (rating != null || note != null)) {
      await _timerRepo.updateSessionRating(
        state.sessionId!,
        focusRating: rating,
        note: note,
      );
    }

    await startBreak();
  }

  /// Starts the break timer (§3.1).
  Future<void> startBreak({int? durationSeconds}) async {
    final now = _clock();
    final int breakDuration;
    if (durationSeconds != null) {
      breakDuration = durationSeconds;
    } else {
      final sessionsBeforeLong = _getSessionsBeforeLongBreak();
      final isLong = state.completedPomodoroCount > 0 &&
          (state.completedPomodoroCount % sessionsBeforeLong == 0);
      breakDuration =
          isLong ? _getLongBreakLengthSeconds() : _getBreakLengthSeconds();
    }

    await _eventsRepo.logEvent(
      type: EventTypes.breakStarted,
      occurredAtUtcMs: now,
      payload: {'duration_s': breakDuration},
    );

    await _timerRepo.persistTimerState(
      startedAtUtc: now,
      plannedDurationS: breakDuration,
      mode: 'break',
      pausedAccumulatedS: 0,
      pausedAtUtc: null,
    );

    state = state.copyWith(
      status: TimerStatus.breakRunning,
      breakDurationS: breakDuration,
      breakStartedAtUtc: now,
    );

    _startTicker();
    _updateForegroundNotification();
  }

  /// Skips or finishes break, returning to idle.
  Future<void> skipBreak() async {
    if (state.status != TimerStatus.breakRunning) return;

    final now = _clock();
    final elapsed = state.breakDurationS - state.computeBreakRemainingSeconds(now);
    final actualDurationS = elapsed > 0 ? elapsed : state.breakDurationS;

    await _eventsRepo.logEvent(
      type: EventTypes.breakCompleted,
      occurredAtUtcMs: now,
      payload: {'duration_s': actualDurationS},
    );

    await _timerRepo.clearTimerState();
    _stopTicker();
    await _foregroundService?.stopService();

    state = TimerState(
      status: TimerStatus.idle,
      mode: state.mode,
      plannedDurationS: _getSessionLengthSeconds(),
      breakDurationS: _getBreakLengthSeconds(),
      completedPomodoroCount: state.completedPomodoroCount,
    );
  }

  /// Updates selected mode while idle.
  void setMode(TimerMode mode) {
    if (state.isIdle || state.isAbandoned) {
      state = state.copyWith(mode: mode, status: TimerStatus.idle);
    }
  }

  /// Updates planned duration in seconds while idle.
  void setPlannedDuration(int seconds) {
    if (state.isIdle || state.isAbandoned) {
      state = state.copyWith(plannedDurationS: seconds, status: TimerStatus.idle);
    }
  }

  /// Resets timer to idle state.
  void resetToIdle() {
    _stopTicker();
    state = TimerState(
      status: TimerStatus.idle,
      mode: state.mode,
      plannedDurationS: _getSessionLengthSeconds(),
      breakDurationS: _getBreakLengthSeconds(),
      completedPomodoroCount: state.completedPomodoroCount,
    );
  }

  /// Attaches or updates the task linked to the current session (or idle state) (§2.4).
  Future<void> attachTask(String? taskId, {String? projectId}) async {
    state = state.copyWith(
      taskId: taskId,
      clearTaskId: taskId == null,
      projectId: projectId,
      clearProjectId: projectId == null,
    );

    if (state.sessionId != null) {
      await _timerRepo.updateSessionTask(
        state.sessionId!,
        taskId: taskId,
        projectId: projectId,
      );
    }

    await _timerRepo.persistTimerState(
      sessionId: state.sessionId,
      startedAtUtc: state.startedAtUtc,
      plannedDurationS: state.plannedDurationS,
      mode: state.mode.toDbValue(),
      pausedAccumulatedS: state.pausedAccumulatedS,
      pausedAtUtc: state.pausedAtUtc,
      taskId: taskId,
      projectId: projectId,
    );
  }

  /// Detaches any currently attached task.
  Future<void> detachTask() async {
    await attachTask(null, projectId: null);
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) => _onTick());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _onTick() {
    final now = _clock();

    if (state.status == TimerStatus.running) {
      if (state.isPomodoro) {
        final remaining = state.computeRemainingSeconds(now);
        if (remaining <= 0) {
          completeSession();
          return;
        }
      }
      _updateForegroundNotification();
      // Emitting a tick update for animated UI progress
      state = state.copyWith();
    } else if (state.status == TimerStatus.breakRunning) {
      final remainingBreak = state.computeBreakRemainingSeconds(now);
      if (remainingBreak <= 0) {
        skipBreak();
        return;
      }
      _updateForegroundNotification();
      state = state.copyWith();
    }
  }

  Future<void> _startForegroundService() async {
    final title = state.isFlow ? 'Flow Session' : 'Focus Session';
    final now = _clock();
    final remaining = state.isFlow
        ? state.computeElapsedSeconds(now)
        : state.computeRemainingSeconds(now);
    final text = _formatRemaining(remaining, isFlow: state.isFlow);

    await _foregroundService?.startService(
      title: title,
      text: text,
      isPaused: false,
    );
  }

  Future<void> _updateForegroundNotification() async {
    if (_foregroundService == null) return;

    final now = _clock();
    final String title;
    final String text;

    if (state.status == TimerStatus.breakRunning) {
      title = 'Break Time';
      final remaining = state.computeBreakRemainingSeconds(now);
      text = 'Remaining: ${_formatRemaining(remaining)}';
    } else if (state.isFlow) {
      title = state.isPaused ? 'Open-ended Session (Paused)' : 'Open-ended Session';
      final elapsed = state.computeElapsedSeconds(now);
      text = 'Elapsed: ${_formatRemaining(elapsed, isFlow: true)}';
    } else {
      title = state.isPaused ? 'Focus Session (Paused)' : 'Focus Session';
      final remaining = state.computeRemainingSeconds(now);
      text = 'Remaining: ${_formatRemaining(remaining)}';
    }

    await _foregroundService?.updateService(
      title: title,
      text: text,
      isPaused: state.isPaused,
    );
  }

  static String _formatRemaining(int seconds, {bool isFlow = false}) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    final mStr = m.toString().padLeft(2, '0');
    final sStr = s.toString().padLeft(2, '0');
    return '$mStr:$sStr';
  }

  @override
  void dispose() {
    _ticker?.cancel();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    }
    super.dispose();
  }
}
