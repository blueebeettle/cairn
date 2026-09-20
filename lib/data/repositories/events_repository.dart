import 'dart:convert';
import 'package:drift/drift.dart';

import '../../core/ids.dart';
import '../../core/time/time_service.dart';
import '../database/app_database.dart';

/// Repository for managing immutable event records per SPEC.md §0 and §2.1.
///
/// Every state change in the app originates from an immutable row written here.
/// Events are never updated and never deleted.
class EventsRepository {
  EventsRepository({
    required this.db,
    required this.timeService,
    this.deviceId = 'default-device-id',
  });

  final AppDatabase db;
  final TimeService timeService;
  final String deviceId;

  AppDatabase get _db => db;
  TimeService get _timeService => timeService;

  /// Appends an immutable event to the `events` table.
  ///
  /// Time semantics:
  /// - `occurred_at`: UTC epoch ms when action occurred (defaults to now).
  /// - `recorded_at`: UTC epoch ms when written to DB (now).
  /// - `local_date`: computed once at write time from `occurred_at`, unless
  ///   [localDateOverride] is supplied.
  /// - `tz_id` and `tz_offset_min`: captured from environment at write time.
  /// - `device_id`: held in-memory installation ID.
  ///
  /// ## When to pass [localDateOverride]
  ///
  /// For most events the instant and the day agree, and the default is right.
  /// Session lifecycle events are the exception. SPEC.md §1.4 says a session
  /// belongs *entirely* to the logical day on which it STARTED, but a session
  /// that crosses the day-start boundary ends on the following logical day:
  ///
  ///   day start 04:00, session runs 03:30 -> 04:15
  ///     started -> logical day D
  ///     ended   -> logical day D+1
  ///
  /// Left to the default, `focus_sessions.local_date` would say D while the
  /// `session_completed` event said D+1. SPEC.md §0 exists precisely so the
  /// event log and the read model cannot disagree about a day — so pass the
  /// session's START logical date on `session_completed`, `session_abandoned`
  /// and `session_interrupted`.
  ///
  /// `occurred_at` still records the true instant. The two fields answer
  /// different questions: when it happened, and which day it counts toward.
  Future<Event> logEvent({
    required String type,
    int? occurredAtUtcMs,
    String? localDateOverride,
    String? subjectType,
    String? subjectId,
    Map<String, dynamic> payload = const {},
  }) async {
    final nowUtcMs = _timeService.nowUtcMs();
    final occurredAt = occurredAtUtcMs ?? nowUtcMs;
    final recordedAt = nowUtcMs;
    final localDate =
        localDateOverride ?? _timeService.computeLocalDate(occurredAt);
    final tzId = _timeService.currentTzId();
    final tzOffsetMin = _timeService.currentTzOffsetMin();
    final payloadJson = jsonEncode(payload);
    final id = newId();

    final companion = EventsCompanion.insert(
      id: id,
      type: type,
      occurredAt: occurredAt,
      recordedAt: recordedAt,
      localDate: localDate,
      tzId: tzId,
      tzOffsetMin: tzOffsetMin,
      subjectType: subjectType != null ? Value(subjectType) : const Value.absent(),
      subjectId: subjectId != null ? Value(subjectId) : const Value.absent(),
      payload: payloadJson,
      deviceId: deviceId,
    );

    await _db.into(_db.events).insert(companion);

    return Event(
      id: id,
      type: type,
      occurredAt: occurredAt,
      recordedAt: recordedAt,
      localDate: localDate,
      tzId: tzId,
      tzOffsetMin: tzOffsetMin,
      subjectType: subjectType,
      subjectId: subjectId,
      payload: payloadJson,
      deviceId: deviceId,
    );
  }

  /// Watches all events for a given logical date string (YYYY-MM-DD).
  Stream<List<Event>> watchEventsForDate(String localDate) {
    return (_db.select(_db.events)
          ..where((tbl) => tbl.localDate.equals(localDate))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.occurredAt)]))
        .watch();
  }

  /// Fetches all events for a given logical date string (YYYY-MM-DD).
  Future<List<Event>> getEventsForDate(String localDate) {
    return (_db.select(_db.events)
          ..where((tbl) => tbl.localDate.equals(localDate))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.occurredAt)]))
        .get();
  }

  /// Watches all events by subject type and subject ID.
  Stream<List<Event>> watchEventsForSubject(String subjectType, String subjectId) {
    return (_db.select(_db.events)
          ..where((tbl) =>
              tbl.subjectType.equals(subjectType) &
              tbl.subjectId.equals(subjectId))
          ..orderBy([(tbl) => OrderingTerm.asc(tbl.occurredAt)]))
        .watch();
  }

  /// Watches all events in the log.
  Stream<List<Event>> watchAllEvents() {
    return (_db.select(_db.events)
          ..orderBy([(tbl) => OrderingTerm.desc(tbl.occurredAt)]))
        .watch();
  }
}
