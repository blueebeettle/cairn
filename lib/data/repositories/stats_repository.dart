// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/constants/event_types.dart';
import '../../core/time/time_service.dart';
import '../database/app_database.dart';

/// Focus statistics per SPEC.md §4.1 and §4.3.
///
/// Note on zero vs undefined: SPEC.md §4 says an undefined metric shows an em
/// dash and never a zero. That rule is about metrics with a zero denominator —
/// completion rate with no sessions, interruptions per hour with no focus time.
/// Focus minutes and streak length are counts. A day with no focused work
/// genuinely has 0 minutes and a 0-day streak, and saying so is true and
/// useful. Do NOT render these as em dashes.
class FocusStats {
  const FocusStats({
    required this.focusMinutesToday,
    required this.currentStreakDays,
    required this.longestStreakDays,
    required this.dailyGoalMinutes,
  });

  final int focusMinutesToday;
  final int currentStreakDays;
  final int longestStreakDays;
  final int dailyGoalMinutes;

  bool get goalMet => focusMinutesToday >= dailyGoalMinutes;

  static const empty = FocusStats(
    focusMinutesToday: 0,
    currentStreakDays: 0,
    longestStreakDays: 0,
    dailyGoalMinutes: defaultDailyGoalMinutes,
  );

  /// SPEC.md §4.3 default.
  static const defaultDailyGoalMinutes = 25;
}

/// A day's focus summary for the 7-day bar strip.
class DayFocusSummary {
  const DayFocusSummary({
    required this.date,
    required this.label,
    required this.minutes,
    required this.isToday,
    required this.goalMet,
  });

  final String date;
  final String label;
  final int minutes;
  final bool isToday;
  final bool goalMet;
}

/// Throughput balance statistics per SPEC.md §4.10.
///
/// Created = count(task_created) - count(task_deleted where the task was never completed).
/// Net = created - completed.
class ThroughputStats {
  const ThroughputStats({
    required this.created,
    required this.completed,
    required this.net,
  });

  final int created;
  final int completed;
  final int net;

  static const empty = ThroughputStats(created: 0, completed: 0, net: 0);
}

class StatsRepository {
  StatsRepository({
    required AppDatabase db,
    required TimeService timeService,
  })  : _db = db,
        _timeService = timeService;

  final AppDatabase _db;
  final TimeService _timeService;

  /// Live focus statistics, recomputed whenever `focus_sessions` changes.
  Stream<FocusStats> watchFocusStats({
    int dailyGoalMinutes = FocusStats.defaultDailyGoalMinutes,
  }) {
    return _completedSecondsByDateQuery().watch().map((rows) {
      final byDate = _foldRows(rows);
      final today = _timeService.todayLocalDate();
      return FocusStats(
        focusMinutesToday: focusMinutesOn(byDate, today),
        currentStreakDays: currentStreak(byDate, today, dailyGoalMinutes),
        longestStreakDays: longestStreak(byDate, dailyGoalMinutes),
        dailyGoalMinutes: dailyGoalMinutes,
      );
    });
  }

  /// 7-day focus summary (today and 6 previous days) per SPEC.md.
  Stream<List<DayFocusSummary>> watchLast7DaysSummary({
    int dailyGoalMinutes = FocusStats.defaultDailyGoalMinutes,
  }) {
    return _completedSecondsByDateQuery().watch().map((rows) {
      final byDate = _foldRows(rows);
      final today = _timeService.todayLocalDate();
      const dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
      return List.generate(7, (index) {
        final daysAgo = 6 - index;
        final date = TimeService.addDays(today, -daysAgo);
        final mins = focusMinutesOn(byDate, date);
        final dt = TimeService.parseLocalDate(date);
        return DayFocusSummary(
          date: date,
          label: dayNames[dt.weekday - 1],
          minutes: mins,
          isToday: daysAgo == 0,
          goalMet: mins >= dailyGoalMinutes,
        );
      });
    });
  }

  Future<FocusStats> getFocusStats({
    int dailyGoalMinutes = FocusStats.defaultDailyGoalMinutes,
  }) async {
    final byDate = _foldRows(await _completedSecondsByDateQuery().get());
    final today = _timeService.todayLocalDate();
    return FocusStats(
      focusMinutesToday: focusMinutesOn(byDate, today),
      currentStreakDays: currentStreak(byDate, today, dailyGoalMinutes),
      longestStreakDays: longestStreak(byDate, dailyGoalMinutes),
      dailyGoalMinutes: dailyGoalMinutes,
    );
  }

  /// Total completed focus seconds per logical date.
  ///
  /// SPEC.md §4.1: abandoned sessions contribute zero focus minutes, so they
  /// are excluded here rather than filtered later.
  JoinedSelectStatement<HasResultSet, dynamic>
      _completedSecondsByDateQuery() {
    final sum = _db.focusSessions.actualDurationS.sum();
    return _db.selectOnly(_db.focusSessions)
      ..addColumns([_db.focusSessions.localDate, sum])
      ..where(_db.focusSessions.outcome.equals(SessionOutcomes.completed))
      ..groupBy([_db.focusSessions.localDate]);
  }

  Map<String, int> _foldRows(List<TypedResult> rows) {
    final sum = _db.focusSessions.actualDurationS.sum();
    return {
      for (final row in rows)
        // ignore: use_null_aware_elements
        if (row.read(_db.focusSessions.localDate) case final date?)
          date: row.read(sum) ?? 0,
    };
  }

  // ── Pure computation, testable without a database ──────────────────────

  /// SPEC.md §4.1 — focus minutes on one logical date.
  ///
  /// Seconds are summed first and converted once. Converting per session and
  /// then summing would discard up to 59 seconds per session.
  static int focusMinutesOn(Map<String, int> secondsByDate, String date) {
    return (secondsByDate[date] ?? 0) ~/ 60;
  }

  static bool _met(Map<String, int> byDate, String date, int goalMinutes) {
    return focusMinutesOn(byDate, date) >= goalMinutes;
  }

  /// SPEC.md §4.3 — current focus streak.
  ///
  /// The rule that matters: if today's goal is not met yet, the walk starts
  /// from YESTERDAY. Today is still in progress and must never break a streak
  /// — otherwise the app tells the user their streak is broken every morning.
  static int currentStreak(
    Map<String, int> secondsByDate,
    String today,
    int goalMinutes,
  ) {
    var cursor = today;
    if (!_met(secondsByDate, cursor, goalMinutes)) {
      cursor = TimeService.addDays(cursor, -1);
    }

    var count = 0;
    while (_met(secondsByDate, cursor, goalMinutes)) {
      count++;
      cursor = TimeService.addDays(cursor, -1);
    }
    return count;
  }

  /// SPEC.md §4.3 — longest run of consecutive met days over all history.
  static int longestStreak(Map<String, int> secondsByDate, int goalMinutes) {
    final metDates = secondsByDate.keys
        .where((d) => _met(secondsByDate, d, goalMinutes))
        .toList()
      ..sort(); // YYYY-MM-DD sorts lexicographically == chronologically

    if (metDates.isEmpty) return 0;

    var best = 1;
    var run = 1;
    for (var i = 1; i < metDates.length; i++) {
      // daysBetween is UTC-based, so a DST transition cannot make two
      // consecutive days measure as zero apart. See TimeService.parseLocalDate.
      if (TimeService.daysBetween(metDates[i - 1], metDates[i]) == 1) {
        run++;
      } else {
        run = 1;
      }
      if (run > best) best = run;
    }
    return best;
  }

  /// SPEC.md §4.10 — Throughput balance:
  /// Count of task_created vs task_completed events with local_date in P.
  /// Created = count(task_created) - count(task_deleted where the task was never completed).
  /// Net = created - completed.
  ///
  /// CRITICAL: Operates entirely over the immutable events table with zero joins back to tasks.
  Future<ThroughputStats> getThroughput({Set<String>? localDates}) async {
    final query = _db.select(_db.events)
      ..where((e) =>
          e.subjectType.equals('task') &
          (e.type.equals('task_created') |
              e.type.equals('task_completed') |
              e.type.equals('task_deleted')));

    final events = await query.get();
    return _calculateThroughputFromEvents(events, localDates);
  }

  /// Watches throughput balance over time.
  Stream<ThroughputStats> watchThroughput({Set<String>? localDates}) {
    final query = _db.select(_db.events)
      ..where((e) =>
          e.subjectType.equals('task') &
          (e.type.equals('task_created') |
              e.type.equals('task_completed') |
              e.type.equals('task_deleted')));

    return query.watch().map((events) => _calculateThroughputFromEvents(events, localDates));
  }

  static ThroughputStats _calculateThroughputFromEvents(
    List<Event> events, [
    Set<String>? localDates,
  ]) {
    var createdCount = 0;
    var completedCount = 0;
    var uncompletedDeletedCount = 0;

    for (final event in events) {
      if (event.type == 'task_created') {
        if (localDates == null || localDates.contains(event.localDate)) {
          createdCount++;
        }
      } else if (event.type == 'task_completed') {
        if (localDates == null || localDates.contains(event.localDate)) {
          completedCount++;
        }
      } else if (event.type == 'task_deleted') {
        try {
          final payload = jsonDecode(event.payload) as Map<String, dynamic>;
          final wasCompleted = payload['was_completed'] == true;
          final everCompleted = payload['ever_completed'] == true;
          final createdLocalDate = payload['created_local_date'] as String?;

          if (!wasCompleted && !everCompleted) {
            final matches = localDates == null ||
                localDates.contains(event.localDate) ||
                (createdLocalDate != null && localDates.contains(createdLocalDate));
            if (matches) {
              uncompletedDeletedCount++;
            }
          }
        } catch (_) {
          if (localDates == null || localDates.contains(event.localDate)) {
            uncompletedDeletedCount++;
          }
        }
      }
    }

    final netCreated = (createdCount - uncompletedDeletedCount).clamp(0, double.infinity).toInt();
    final net = netCreated - completedCount;

    return ThroughputStats(
      created: netCreated,
      completed: completedCount,
      net: net,
    );
  }
}
