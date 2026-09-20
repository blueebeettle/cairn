import 'package:flutter/foundation.dart';
import '../../../../core/time/time_service.dart';

/// Active timer states per SPEC.md §3.1.
enum TimerStatus {
  idle,
  running,
  paused,
  completed,
  breakRunning,
  abandoned,
}

/// Supported timer modes per SPEC.md §2.3 and §3.1.
enum TimerMode {
  pomodoro,
  flow;

  String toDbValue() {
    switch (this) {
      case TimerMode.pomodoro:
        return 'pomodoro';
      case TimerMode.flow:
        return 'flow';
    }
  }

  static TimerMode fromDbValue(String value) {
    if (value == 'flow') return TimerMode.flow;
    return TimerMode.pomodoro;
  }
}

/// Immutable domain state representation of the focus timer.
@immutable
class TimerState {
  const TimerState({
    this.status = TimerStatus.idle,
    this.mode = TimerMode.pomodoro,
    this.sessionId,
    this.startedAtUtc,
    this.plannedDurationS = 1500, // 25 minutes default
    this.pausedAccumulatedS = 0,
    this.pausedAtUtc,
    this.taskId,
    this.projectId,
    this.interruptionsInternal = 0,
    this.interruptionsExternal = 0,
    this.breakDurationS = 300, // 5 minutes default
    this.breakStartedAtUtc,
    this.focusRating,
    this.sessionNote,
    this.startLocalDate,
    this.completedPomodoroCount = 0,
  });

  final TimerStatus status;
  final TimerMode mode;
  final String? sessionId;
  final int? startedAtUtc;
  final int plannedDurationS;
  final int pausedAccumulatedS;
  final int? pausedAtUtc;
  final String? taskId;
  final String? projectId;
  final int interruptionsInternal;
  final int interruptionsExternal;
  final int breakDurationS;
  final int? breakStartedAtUtc;
  final int? focusRating;
  final String? sessionNote;
  final int completedPomodoroCount;

  /// Logical date of the session's START instant (YYYY-MM-DD per SPEC.md §1.4).
  final String? startLocalDate;

  bool get isRunning => status == TimerStatus.running;
  bool get isPaused => status == TimerStatus.paused;
  bool get isIdle => status == TimerStatus.idle;
  bool get isCompleted => status == TimerStatus.completed;
  bool get isBreakRunning => status == TimerStatus.breakRunning;
  bool get isAbandoned => status == TimerStatus.abandoned;

  bool get isFlow => mode == TimerMode.flow;
  bool get isPomodoro => mode == TimerMode.pomodoro;

  /// Total interruptions tally.
  int get totalInterruptions =>
      interruptionsInternal + interruptionsExternal;

  /// Expected completion UTC instant in ms for a running Pomodoro session.
  int? get expectedEndUtcMs {
    if (isFlow || startedAtUtc == null) return null;
    return startedAtUtc! + (plannedDurationS + pausedAccumulatedS) * 1000;
  }

  /// Computes elapsed duration in whole seconds excluding paused periods (§3.2).
  int computeElapsedSeconds(int nowUtcMs) {
    if (startedAtUtc == null) return 0;
    final result = TimeService.computeElapsed(
      startedAtUtcMs: startedAtUtc!,
      endedAtUtcMs: nowUtcMs,
      pausedAccumulatedSeconds: pausedAccumulatedS,
      pausedAtUtcMs: pausedAtUtc,
    );
    return result.elapsedSeconds;
  }

  /// Computes remaining time in whole seconds for Pomodoro mode (§3.2).
  int computeRemainingSeconds(int nowUtcMs) {
    if (isFlow) return 0;
    final elapsed = computeElapsedSeconds(nowUtcMs);
    final remaining = plannedDurationS - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  /// Computes remaining break time in whole seconds.
  int computeBreakRemainingSeconds(int nowUtcMs) {
    if (breakStartedAtUtc == null) return 0;
    final elapsed = (nowUtcMs - breakStartedAtUtc!) ~/ 1000;
    final remaining = breakDurationS - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  /// Computes normalized progress 0.0 to 1.0.
  double computeProgress(int nowUtcMs) {
    if (status == TimerStatus.breakRunning) {
      if (breakDurationS <= 0) return 1.0;
      final remaining = computeBreakRemainingSeconds(nowUtcMs);
      return (1.0 - (remaining / breakDurationS)).clamp(0.0, 1.0);
    }

    if (isFlow) return 0.0;
    if (plannedDurationS <= 0) return 1.0;
    final elapsed = computeElapsedSeconds(nowUtcMs);
    return (elapsed / plannedDurationS).clamp(0.0, 1.0);
  }

  TimerState copyWith({
    TimerStatus? status,
    TimerMode? mode,
    String? sessionId,
    int? startedAtUtc,
    int? plannedDurationS,
    int? pausedAccumulatedS,
    int? pausedAtUtc,
    bool clearPausedAt = false,
    String? taskId,
    bool clearTaskId = false,
    String? projectId,
    bool clearProjectId = false,
    int? interruptionsInternal,
    int? interruptionsExternal,
    int? breakDurationS,
    int? breakStartedAtUtc,
    bool clearBreakStarted = false,
    int? focusRating,
    bool clearRating = false,
    String? sessionNote,
    bool clearNote = false,
    String? startLocalDate,
    bool clearStartLocalDate = false,
    int? completedPomodoroCount,
  }) {
    return TimerState(
      status: status ?? this.status,
      mode: mode ?? this.mode,
      sessionId: sessionId ?? this.sessionId,
      startedAtUtc: startedAtUtc ?? this.startedAtUtc,
      plannedDurationS: plannedDurationS ?? this.plannedDurationS,
      pausedAccumulatedS: pausedAccumulatedS ?? this.pausedAccumulatedS,
      pausedAtUtc: clearPausedAt ? null : (pausedAtUtc ?? this.pausedAtUtc),
      taskId: clearTaskId ? null : (taskId ?? this.taskId),
      projectId: clearProjectId ? null : (projectId ?? this.projectId),
      interruptionsInternal:
          interruptionsInternal ?? this.interruptionsInternal,
      interruptionsExternal:
          interruptionsExternal ?? this.interruptionsExternal,
      breakDurationS: breakDurationS ?? this.breakDurationS,
      breakStartedAtUtc: clearBreakStarted
          ? null
          : (breakStartedAtUtc ?? this.breakStartedAtUtc),
      focusRating: clearRating ? null : (focusRating ?? this.focusRating),
      sessionNote: clearNote ? null : (sessionNote ?? this.sessionNote),
      startLocalDate: clearStartLocalDate
          ? null
          : (startLocalDate ?? this.startLocalDate),
      completedPomodoroCount:
          completedPomodoroCount ?? this.completedPomodoroCount,
    );
  }
}
