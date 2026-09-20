import 'package:drift/drift.dart';

/// TimerState table (SPEC.md §2.5 & §3.2) — single row holding active timer state.
class TimerStates extends Table {
  /// Single row identifier (always 1). Device-local singleton, never synced.
  IntColumn get id => integer().withDefault(const Constant(1))();

  /// Currently active session ID (UUID string), if any.
  TextColumn get sessionId => text().nullable()();

  /// Start timestamp in UTC epoch milliseconds.
  IntColumn get startedAtUtc => integer().nullable()();

  /// Planned duration in seconds (0 for flow mode).
  IntColumn get plannedDurationS => integer().withDefault(const Constant(0))();

  /// 'pomodoro' | 'flow'
  TextColumn get mode => text().withDefault(const Constant('pomodoro'))();

  /// Accumulated paused seconds.
  IntColumn get pausedAccumulatedS => integer().withDefault(const Constant(0))();

  /// UTC epoch milliseconds when pause began, null when running.
  IntColumn get pausedAtUtc => integer().nullable()();

  /// Optional task ID (UUID string) associated with active session.
  TextColumn get taskId => text().nullable()();

  /// Optional project ID (UUID string) associated with active session.
  TextColumn get projectId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
