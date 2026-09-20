import 'package:drift/drift.dart';

/// Events table (SPEC.md §2.1) — append-only, immutable event log.
///
/// Every user action writes an immutable row here. Module tables are a read model
/// derived from these events. Events are never updated and never deleted.
@TableIndex(name: 'events_local_date_idx', columns: {#localDate})
@TableIndex(name: 'events_type_local_date_idx', columns: {#type, #localDate})
@TableIndex(name: 'events_subject_idx', columns: {#subjectType, #subjectId})
class Events extends Table {
  /// Primary key UUID string.
  TextColumn get id => text()();

  /// Event type string (see EventTypes constants, SPEC.md §2.2).
  TextColumn get type => text()();

  /// UTC epoch milliseconds when the event actually occurred.
  IntColumn get occurredAt => integer()();

  /// UTC epoch milliseconds when the event was recorded in the database.
  /// (Differs from occurredAt for manual entries).
  IntColumn get recordedAt => integer()();

  /// Logical date in YYYY-MM-DD format per SPEC.md §1.2.
  /// Computed once at write time: (local_datetime - day_start_offset).date. Never recomputed.
  TextColumn get localDate => text()();

  /// IANA timezone identifier at write time (e.g. 'America/Edmonton').
  TextColumn get tzId => text()();

  /// Timezone offset in minutes at write time.
  IntColumn get tzOffsetMin => integer()();

  /// Subject type: 'session' | 'task' | 'habit' | null.
  TextColumn get subjectType => text().nullable()();

  /// Subject primary key ID, or null for events with no subject.
  TextColumn get subjectId => text().nullable()();

  /// JSON-encoded type-specific payload.
  TextColumn get payload => text()();

  /// Device ID of the installation that logged this event (§4, §5).
  TextColumn get deviceId => text()();

  @override
  Set<Column> get primaryKey => {id};
}
