import 'package:drift/drift.dart';

import '../../core/ids.dart';
import '../database/app_database.dart';

/// Repository for managing timer persistence (`timer_states` table)
/// and the `focus_sessions` read model per SPEC.md §2.3, §2.5, and §3.2.
class TimerRepository {
  TimerRepository({
    required this.db,
    this.deviceId = 'default-device-id',
  });

  final AppDatabase db;
  final String deviceId;

  AppDatabase get _db => db;

  /// Loads the persisted timer state (id = 1).
  Future<TimerState?> loadTimerState() async {
    return (_db.select(_db.timerStates)..where((tbl) => tbl.id.equals(1)))
        .getSingleOrNull();
  }

  /// Persists active timer state to `timer_states` table on every transition (§3.2).
  Future<void> persistTimerState({
    String? sessionId,
    int? startedAtUtc,
    required int plannedDurationS,
    required String mode,
    int pausedAccumulatedS = 0,
    int? pausedAtUtc,
    String? taskId,
    String? projectId,
  }) async {
    final companion = TimerStatesCompanion(
      id: const Value(1),
      sessionId: Value(sessionId),
      startedAtUtc: Value(startedAtUtc),
      plannedDurationS: Value(plannedDurationS),
      mode: Value(mode),
      pausedAccumulatedS: Value(pausedAccumulatedS),
      pausedAtUtc: Value(pausedAtUtc),
      taskId: Value(taskId),
      projectId: Value(projectId),
    );

    await _db.into(_db.timerStates).insertOnConflictUpdate(companion);
  }

  /// Clears active timer state, returning to idle.
  Future<void> clearTimerState() async {
    final companion = TimerStatesCompanion(
      id: const Value(1),
      sessionId: const Value(null),
      startedAtUtc: const Value(null),
      plannedDurationS: const Value(0),
      mode: const Value('pomodoro'),
      pausedAccumulatedS: const Value(0),
      pausedAtUtc: const Value(null),
      taskId: const Value(null),
      projectId: const Value(null),
    );

    await _db.into(_db.timerStates).insertOnConflictUpdate(companion);
  }

  /// Inserts a new row in the `focus_sessions` read model at session start.
  ///
  /// Outcome is set to 'running' until finalized as 'completed' or 'abandoned'.
  Future<String> createFocusSession({
    required String mode,
    required int plannedDurationS,
    required int startedAt,
    required String localDate,
    required int tzOffsetMin,
    required String tzId,
    String? taskId,
    String? projectId,
  }) async {
    final id = newId();
    final companion = FocusSessionsCompanion.insert(
      id: id,
      mode: mode,
      plannedDurationS: Value(plannedDurationS),
      actualDurationS: const Value(0),
      startedAt: startedAt,
      endedAt: startedAt,
      localDate: localDate,
      tzOffsetMin: tzOffsetMin,
      tzId: Value(tzId),
      outcome: 'running',
      taskId: taskId != null ? Value(taskId) : const Value.absent(),
      projectId: projectId != null ? Value(projectId) : const Value.absent(),
      interruptionsInternal: const Value(0),
      interruptionsExternal: const Value(0),
      updatedAt: startedAt,
      deviceId: deviceId,
    );

    await _db.into(_db.focusSessions).insert(companion);
    return id;
  }

  /// Increments internal or external interruption count on the `focus_sessions` row (§3 / item 6).
  Future<void> recordInterruption(String sessionId, {required bool isInternal}) async {
    final current = await getFocusSession(sessionId);
    if (current == null) return;
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;

    if (isInternal) {
      await (_db.update(_db.focusSessions)..where((tbl) => tbl.id.equals(sessionId))).write(
        FocusSessionsCompanion(
          interruptionsInternal: Value(current.interruptionsInternal + 1),
          updatedAt: Value(nowMs),
          deviceId: Value(deviceId),
        ),
      );
    } else {
      await (_db.update(_db.focusSessions)..where((tbl) => tbl.id.equals(sessionId))).write(
        FocusSessionsCompanion(
          interruptionsExternal: Value(current.interruptionsExternal + 1),
          updatedAt: Value(nowMs),
          deviceId: Value(deviceId),
        ),
      );
    }
  }

  /// Finalizes the `focus_sessions` read model row on session completion or abandonment.
  Future<void> finalizeSession(
    String sessionId, {
    required int endedAt,
    required int actualDurationS,
    required String outcome,
    int? focusRating,
    String? note,
  }) async {
    await (_db.update(_db.focusSessions)..where((tbl) => tbl.id.equals(sessionId))).write(
      FocusSessionsCompanion(
        endedAt: Value(endedAt),
        actualDurationS: Value(actualDurationS),
        outcome: Value(outcome),
        focusRating: focusRating != null ? Value(focusRating) : const Value.absent(),
        note: note != null ? Value(note) : const Value.absent(),
        updatedAt: Value(endedAt),
        deviceId: Value(deviceId),
      ),
    );
  }

  /// Updates post-session rating (1–5, null if skipped) and optional note.
  Future<void> updateSessionRating(
    String sessionId, {
    int? focusRating,
    String? note,
  }) async {
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    await (_db.update(_db.focusSessions)..where((tbl) => tbl.id.equals(sessionId))).write(
      FocusSessionsCompanion(
        focusRating: Value(focusRating),
        note: note != null ? Value(note) : const Value.absent(),
        updatedAt: Value(nowMs),
        deviceId: Value(deviceId),
      ),
    );
  }

  /// Fetches a focus session by ID.
  Future<FocusSession?> getFocusSession(String sessionId) {
    return (_db.select(_db.focusSessions)..where((tbl) => tbl.id.equals(sessionId)))
        .getSingleOrNull();
  }

  /// Watches all focus sessions for a given logical date string (YYYY-MM-DD),
  /// sorted chronologically descending (newest first).
  Stream<List<FocusSession>> watchSessionsForDate(String localDate) {
    return (_db.select(_db.focusSessions)
          ..where((tbl) => tbl.localDate.equals(localDate))
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.startedAt)]))
        .watch();
  }

  /// Restores a previously abandoned session back to running state upon undo.
  Future<void> restoreSession(String sessionId) async {
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    await (_db.update(_db.focusSessions)..where((tbl) => tbl.id.equals(sessionId))).write(
      FocusSessionsCompanion(
        outcome: const Value('running'),
        updatedAt: Value(nowMs),
        deviceId: Value(deviceId),
      ),
    );
  }

  /// Updates the attached task and project for an active focus session (§2.4).
  Future<void> updateSessionTask(
    String sessionId, {
    String? taskId,
    String? projectId,
  }) async {
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    await (_db.update(_db.focusSessions)..where((tbl) => tbl.id.equals(sessionId))).write(
      FocusSessionsCompanion(
        taskId: Value(taskId),
        projectId: Value(projectId),
        updatedAt: Value(nowMs),
        deviceId: Value(deviceId),
      ),
    );
  }
}
