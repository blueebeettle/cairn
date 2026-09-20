import 'package:drift/drift.dart';

/// FocusSessions table (SPEC.md §2.3) — read model derived from events.
class FocusSessions extends Table {
  /// Session identifier (UUID string).
  TextColumn get id => text()();

  /// Associated task ID, if any.
  TextColumn get taskId => text().nullable()();

  /// Denormalized from task at start so later reassignment doesn't rewrite history.
  TextColumn get projectId => text().nullable()();

  /// 'pomodoro' | 'flow'
  TextColumn get mode => text()();

  /// Planned duration in seconds (0 for flow mode).
  IntColumn get plannedDurationS => integer().withDefault(const Constant(0))();

  /// Actual duration in seconds, excluding paused time.
  IntColumn get actualDurationS => integer().withDefault(const Constant(0))();

  /// Start timestamp in UTC epoch milliseconds.
  IntColumn get startedAt => integer()();

  /// End timestamp in UTC epoch milliseconds.
  IntColumn get endedAt => integer()();

  /// Logical date in YYYY-MM-DD per session start.
  TextColumn get localDate => text()();

  /// Timezone offset in minutes east of UTC, captured at session START
  /// (SPEC.md §1.2). +330 in India, −360 in Alberta during summer.
  ///
  /// Carried on the session, not looked up when reading, because §4.4 bins
  /// sessions by local hour and the answer must not depend on where the phone
  /// is today. Without this column, flying from Ahmedabad to Edmonton moves
  /// every session ever recorded by 11½ hours and turns a morning habit into a
  /// late-night one.
  /// Required, with no default, on purpose. A default of 0 would be UTC, and a
  /// session that quietly claims to have happened in UTC is a wrong answer that
  /// nothing complains about. Required means the compiler asks every caller
  /// where the session happened.
  IntColumn get tzOffsetMin => integer()();

  /// IANA zone id at session start, e.g. `Asia/Kolkata`, `America/Edmonton`.
  ///
  /// Not used for any calculation — [tzOffsetMin] carries that. This is for
  /// showing "9am, Kolkata time" beside a session, and for diagnosing a
  /// timezone bug six months from now when the offset alone is not enough to
  /// tell you what happened.
  TextColumn get tzId => text().withDefault(const Constant(''))();

  /// 'completed' | 'abandoned'
  TextColumn get outcome => text()();

  /// Count of internal interruptions.
  IntColumn get interruptionsInternal =>
      integer().withDefault(const Constant(0))();

  /// Count of external interruptions.
  IntColumn get interruptionsExternal =>
      integer().withDefault(const Constant(0))();

  /// User rating 1–5, null if unrated.
  IntColumn get focusRating => integer().nullable()();

  /// Optional session note.
  TextColumn get note => text().nullable()();

  /// Whether this session was logged retroactively (0 = normal, 1 = manual).
  BoolColumn get isManual => boolean().withDefault(const Constant(false))();

  /// UTC epoch milliseconds, written on every update (§4).
  IntColumn get updatedAt => integer()();

  /// Which install made the last write (§4, §5).
  TextColumn get deviceId => text()();

  @override
  Set<Column> get primaryKey => {id};
}
