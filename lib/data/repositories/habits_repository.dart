import 'package:drift/drift.dart';

import '../../core/constants/event_types.dart';
import '../../core/habits/habit_schedule.dart';
import '../../core/habits/habit_streak.dart';
import '../../core/ids.dart';
import '../../core/recurrence/recurrence.dart';
import '../../core/time/time_service.dart';
import '../database/app_database.dart';
import 'events_repository.dart';

/// A habit together with everything the UI needs to draw it (SPEC.md §10.5).
///
/// Loaded as one bundle from one consistent read, for the same reason
/// `StatsBundle` exists: a streak computed from one query and a day grid
/// computed from another can disagree across a midnight boundary, and that
/// disagreement is invisible in testing and obvious to a user.
class HabitSnapshot {
  const HabitSnapshot({
    required this.habit,
    required this.scheduledDates,
    required this.entries,
    required this.streaks,
    required this.todayLocalDate,
  });

  final Habit habit;

  /// Every scheduled date from the habit's anchor through today, ascending.
  final List<String> scheduledDates;

  /// Raw day records, keyed by logical date.
  final Map<String, HabitDayRecord> entries;

  final HabitStreakResult streaks;
  final String todayLocalDate;

  RecurrenceRule? get rule => RecurrenceRule.parse(habit.scheduleRule);

  bool get isScheduledToday => scheduledDates.isNotEmpty &&
      scheduledDates.last == todayLocalDate;

  HabitDayOutcome? get todayOutcome => streaks.outcomes[todayLocalDate];

  bool get isDoneToday => todayOutcome == HabitDayOutcome.done;

  /// Check-offs recorded today, for "3 of 8 glasses".
  int get countToday => entries[todayLocalDate]?.count ?? 0;

  /// Rest days already excused this calendar month.
  int get excusedThisMonth => HabitStats.excusedSkipsInMonth(
        scheduledDates: scheduledDates,
        outcomes: streaks.outcomes,
        yearMonth: todayLocalDate.substring(0, 7),
      );

  /// Share of scheduled days met over the whole loaded history.
  /// Null when nothing was ever asked — render an em dash, not 0%.
  double? get completionRate => HabitStats.completionRate(
        scheduledDates: scheduledDates,
        outcomes: streaks.outcomes,
      );

  /// The next day this habit is due after today, or null if the rule is bad.
  String? get nextDueDate => HabitSchedule.nextScheduledDate(
        rule: rule,
        anchorDate: habit.anchorDate,
        localDate: todayLocalDate,
      );
}

/// Habits read model and event writer (SPEC.md §10).
///
/// Every mutating method here writes its event *first* and then updates the
/// read model, per SPEC.md §0. If a projection is ever found to be wrong it
/// can be rebuilt from `events`; the reverse is not true.
class HabitsRepository {
  HabitsRepository({
    required this.db,
    required this.eventsRepository,
    required this.timeService,
    required this.deviceId,
  });

  final AppDatabase db;
  final EventsRepository eventsRepository;
  final TimeService timeService;
  final String deviceId;

  // ---------------------------------------------------------------- lifecycle

  Future<String> createHabit({
    required String title,
    required String scheduleRule,
    String? notes,
    int colorIndex = 0,
    String iconName = 'check',
    int targetCount = 1,
    String? unitLabel,
    int skipAllowancePerMonth = 2,
    double? sortOrder,
  }) async {
    if (RecurrenceRule.parse(scheduleRule) == null) {
      // Storing an unparseable rule creates a habit that is never due and
      // never complains — the worst possible failure for a streak feature.
      throw ArgumentError.value(
          scheduleRule, 'scheduleRule', 'Not a recognised schedule rule');
    }
    final id = newId();
    final now = timeService.nowUtcMs();
    final today = timeService.todayLocalDate();
    final order = sortOrder ?? now.toDouble();

    // Every field written to the projection below must be in this payload,
    // for the same reason as `changed` in [updateHabit]: a value that reaches
    // the read model but not the log cannot be rebuilt from it (SPEC §0).
    //
    // Event and projection go in one transaction: written one after the
    // other, a crash between the two leaves an orphan event with no habit
    // behind it, or — worse — a habit with no event a rebuild could find.
    await db.transaction(() async {
      await eventsRepository.logEvent(
        type: EventTypes.habitCreated,
        subjectType: SubjectTypes.habit,
        subjectId: id,
        payload: {
          'title': title,
          'schedule_rule': scheduleRule,
          'anchor_date': today,
          'notes': ?notes,
          'color_index': colorIndex,
          'icon_name': iconName,
          'target_count': targetCount,
          'unit_label': ?unitLabel,
          'skip_allowance_per_month': skipAllowancePerMonth,
          'sort_order': order,
        },
      );

      await db.into(db.habits).insert(
            HabitsCompanion.insert(
              id: id,
              title: title,
              scheduleRule: scheduleRule,
              // The anchor is the creation day: "every 3 days" counts from
              // when you started, not from an epoch.
              anchorDate: today,
              notes: Value(notes),
              colorIndex: Value(colorIndex),
              iconName: Value(iconName),
              targetCount: Value(targetCount),
              unitLabel: Value(unitLabel),
              skipAllowancePerMonth: Value(skipAllowancePerMonth),
              sortOrder: Value(order),
              status: const Value(HabitStatuses.active),
              createdAt: now,
              createdLocalDate: today,
              updatedAt: now,
              deviceId: deviceId,
            ),
          );
    });
    return id;
  }

  Future<void> updateHabit(
    String habitId, {
    String? title,
    String? notes,
    int? colorIndex,
    String? iconName,
    String? scheduleRule,
    int? targetCount,
    String? unitLabel,
    bool clearUnitLabel = false,
    int? skipAllowancePerMonth,
  }) async {
    if (scheduleRule != null && RecurrenceRule.parse(scheduleRule) == null) {
      throw ArgumentError.value(
          scheduleRule, 'scheduleRule', 'Not a recognised schedule rule');
    }

    // Every field written below must appear here too. A field that reaches the
    // projection but not the log makes §0 false: the log can no longer rebuild
    // the read model, and nothing warns you that it cannot.
    final changed = <String, dynamic>{
      'title': ?title,
      'notes': ?notes,
      'color_index': ?colorIndex,
      'icon_name': ?iconName,
      'schedule_rule': ?scheduleRule,
      'target_count': ?targetCount,
      'unit_label': ?unitLabel,
      if (clearUnitLabel) 'unit_label': null,
      'skip_allowance_per_month': ?skipAllowancePerMonth,
    };
    await db.transaction(() async {
      if (changed.isNotEmpty) {
        await eventsRepository.logEvent(
          type: EventTypes.habitUpdated,
          subjectType: SubjectTypes.habit,
          subjectId: habitId,
          payload: changed,
        );
      }

      // The anchor is deliberately NOT moved when the schedule changes.
      // Moving it would re-derive every past scheduled day under the new
      // rule and rewrite history — a user who switches from daily to
      // Mon/Wed/Fri would watch a streak they earned change value.
      await (db.update(db.habits)..where((h) => h.id.equals(habitId))).write(
        HabitsCompanion(
          title: title == null ? const Value.absent() : Value(title),
          notes: notes == null ? const Value.absent() : Value(notes),
          colorIndex:
              colorIndex == null ? const Value.absent() : Value(colorIndex),
          iconName: iconName == null ? const Value.absent() : Value(iconName),
          scheduleRule: scheduleRule == null
              ? const Value.absent()
              : Value(scheduleRule),
          targetCount:
              targetCount == null ? const Value.absent() : Value(targetCount),
          unitLabel: clearUnitLabel
              ? const Value<String?>(null)
              : (unitLabel == null ? const Value.absent() : Value(unitLabel)),
          skipAllowancePerMonth: skipAllowancePerMonth == null
              ? const Value.absent()
              : Value(skipAllowancePerMonth),
          updatedAt: Value(timeService.nowUtcMs()),
          deviceId: Value(deviceId),
        ),
      );
    });
  }

  Future<void> archiveHabit(String habitId) async {
    final now = timeService.nowUtcMs();
    await db.transaction(() async {
      await eventsRepository.logEvent(
        type: EventTypes.habitArchived,
        subjectType: SubjectTypes.habit,
        subjectId: habitId,
      );
      await (db.update(db.habits)..where((h) => h.id.equals(habitId))).write(
        HabitsCompanion(
          status: const Value(HabitStatuses.archived),
          archivedAt: Value(now),
          updatedAt: Value(now),
          deviceId: Value(deviceId),
        ),
      );
    });
  }

  Future<void> restoreHabit(String habitId) async {
    final now = timeService.nowUtcMs();
    await db.transaction(() async {
      await eventsRepository.logEvent(
        type: EventTypes.habitRestored,
        subjectType: SubjectTypes.habit,
        subjectId: habitId,
      );
      await (db.update(db.habits)..where((h) => h.id.equals(habitId))).write(
        HabitsCompanion(
          status: const Value(HabitStatuses.active),
          archivedAt: const Value<int?>(null),
          updatedAt: Value(now),
          deviceId: Value(deviceId),
        ),
      );
    });
  }

  /// Tombstones the habit. The entries and the event log are left intact, so
  /// a restore from backup still reconstructs the history.
  Future<void> deleteHabit(String habitId) async {
    final now = timeService.nowUtcMs();
    await db.transaction(() async {
      await eventsRepository.logEvent(
        type: EventTypes.habitDeleted,
        subjectType: SubjectTypes.habit,
        subjectId: habitId,
      );
      await (db.update(db.habits)..where((h) => h.id.equals(habitId))).write(
        HabitsCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
          deviceId: Value(deviceId),
        ),
      );
    });
  }

  // ---------------------------------------------------------------- check-off

  /// Records one check-off for [habitId] on [localDate] (default: today).
  ///
  /// Runs in a transaction: the read and the write must not be separated, or
  /// a double tap produces two rows for one day. The unique index on
  /// `(habit_id, local_date)` is the backstop if one ever slips through.
  ///
  /// Passing a past [localDate] is legitimate — the day grid lets you fill in
  /// yesterday. The event then carries the true instant in `occurred_at` and
  /// the backfilled day in `local_date`, which is exactly the split
  /// `EventsRepository.logEvent` documents.
  Future<void> check(String habitId, {String? localDate}) async {
    final date = localDate ?? timeService.todayLocalDate();
    final now = timeService.nowUtcMs();

    await db.transaction(() async {
      final existing = await _entryFor(habitId, date);
      final next = (existing?.checkCount ?? 0) + 1;

      // The event and the projection go in ONE transaction. Written one after
      // the other, a crash in between leaves them disagreeing — and §0 only
      // holds while the log is never behind the read model.
      await eventsRepository.logEvent(
        type: EventTypes.habitChecked,
        subjectType: SubjectTypes.habit,
        subjectId: habitId,
        localDateOverride: date,
        payload: {'count_after': next},
      );
      await _upsertEntry(
        habitId: habitId,
        date: date,
        existing: existing,
        checkCount: next,
        // Checking a day off clears an earlier rest-day mark: you cannot both
        // rest and do it.
        skipped: false,
        lastCheckedAt: now,
      );
    });
  }

  /// Undoes one check-off. Floors at zero rather than going negative.
  Future<void> uncheck(String habitId, {String? localDate}) async {
    final date = localDate ?? timeService.todayLocalDate();

    await db.transaction(() async {
      final existing = await _entryFor(habitId, date);
      final next = existing == null
          ? 0
          : (existing.checkCount > 0 ? existing.checkCount - 1 : 0);

      await eventsRepository.logEvent(
        type: EventTypes.habitUnchecked,
        subjectType: SubjectTypes.habit,
        subjectId: habitId,
        localDateOverride: date,
        payload: {'count_after': next},
      );
      if (existing == null) return;
      await _upsertEntry(
        habitId: habitId,
        date: date,
        existing: existing,
        checkCount: next,
        skipped: existing.skipped,
        lastCheckedAt: existing.lastCheckedAt,
      );
    });
  }

  /// Marks [localDate] a deliberate rest day.
  ///
  /// Writes `habit_skipped` always, and `habit_freeze_used` **in addition**
  /// when the skip lands inside the month's allowance and therefore protects
  /// the streak. Two facts, two events — what the user did, and what it cost.
  ///
  /// Returns true when the streak is protected, so the caller can say
  /// "2 of 2 rest days used this month" instead of reporting a broken streak
  /// after the fact.
  Future<bool> setSkipped(
    String habitId, {
    String? localDate,
    bool skipped = true,
  }) async {
    final date = localDate ?? timeService.todayLocalDate();

    return db.transaction(() async {
      final existing = await _entryFor(habitId, date);

      await eventsRepository.logEvent(
        type: EventTypes.habitSkipped,
        subjectType: SubjectTypes.habit,
        subjectId: habitId,
        localDateOverride: date,
        payload: {'skipped': skipped},
      );
      await _upsertEntry(
        habitId: habitId,
        date: date,
        existing: existing,
        // A rest day is not a partial day. Clearing the count keeps
        // "skipped" and "did some of it" from both being true at once.
        checkCount: skipped ? 0 : (existing?.checkCount ?? 0),
        skipped: skipped,
        lastCheckedAt: existing?.lastCheckedAt,
      );

      if (!skipped) return false;

      // Re-read through the same engine the UI uses, inside the same
      // transaction, so this answer and the number on screen cannot disagree.
      final snapshot = await loadSnapshot(habitId);
      final excused = snapshot != null &&
          snapshot.streaks.outcomes[date] == HabitDayOutcome.neutral;

      if (excused) {
        await eventsRepository.logEvent(
          type: EventTypes.habitFreezeUsed,
          subjectType: SubjectTypes.habit,
          subjectId: habitId,
          localDateOverride: date,
          payload: {'month': date.substring(0, 7)},
        );
      }
      return excused;
    });
  }

  /// Sets or clears the day's note — the journal entry for that day.
  Future<void> setNote(
    String habitId, {
    String? localDate,
    required String? note,
  }) async {
    final date = localDate ?? timeService.todayLocalDate();
    final trimmed = (note == null || note.trim().isEmpty) ? null : note.trim();

    await db.transaction(() async {
      final existing = await _entryFor(habitId, date);
      await eventsRepository.logEvent(
        type: EventTypes.habitNoteSet,
        subjectType: SubjectTypes.habit,
        subjectId: habitId,
        localDateOverride: date,
        // The note text lives in the payload, not only in the read model:
        // SPEC.md §0 means the log must be able to rebuild the projection.
        payload: {'note': trimmed},
      );
      await _upsertEntry(
        habitId: habitId,
        date: date,
        existing: existing,
        checkCount: existing?.checkCount ?? 0,
        skipped: existing?.skipped ?? false,
        lastCheckedAt: existing?.lastCheckedAt,
        note: Value(trimmed),
      );
    });
  }

  // -------------------------------------------------------------------- reads

  Future<Habit?> habitById(String habitId) {
    return (db.select(db.habits)
          ..where((h) => h.id.equals(habitId) & h.deletedAt.isNull()))
        .getSingleOrNull();
  }

  Stream<List<Habit>> watchActiveHabits() {
    return (db.select(db.habits)
          ..where((h) =>
              h.status.equals(HabitStatuses.active) & h.deletedAt.isNull())
          ..orderBy([(h) => OrderingTerm.asc(h.sortOrder)]))
        .watch();
  }

  Stream<List<Habit>> watchArchivedHabits() {
    return (db.select(db.habits)
          ..where((h) =>
              h.status.equals(HabitStatuses.archived) & h.deletedAt.isNull())
          ..orderBy([(h) => OrderingTerm.desc(h.archivedAt)]))
        .watch();
  }

  /// Loads one habit with its full history and computed streaks.
  Future<HabitSnapshot?> loadSnapshot(String habitId) async {
    final habit = await habitById(habitId);
    if (habit == null) return null;
    final rows = await (db.select(db.habitEntries)
          ..where((e) => e.habitId.equals(habitId) & e.deletedAt.isNull()))
        .get();
    return _buildSnapshot(habit, rows);
  }

  /// Loads every active habit with its history, in one pass.
  ///
  /// One query for the habits and one for all their entries — not one query
  /// per habit. The N+1 that this avoids is the same one that cost the Tasks
  /// screen 120ms before it was batched.
  Future<List<HabitSnapshot>> loadActiveSnapshots() async {
    final habits = await (db.select(db.habits)
          ..where((h) =>
              h.status.equals(HabitStatuses.active) & h.deletedAt.isNull())
          ..orderBy([(h) => OrderingTerm.asc(h.sortOrder)]))
        .get();
    if (habits.isEmpty) return const [];

    final ids = habits.map((h) => h.id).toList();
    final rows = await (db.select(db.habitEntries)
          ..where((e) => e.habitId.isIn(ids) & e.deletedAt.isNull()))
        .get();

    final byHabit = <String, List<HabitEntry>>{};
    for (final row in rows) {
      byHabit.putIfAbsent(row.habitId, () => []).add(row);
    }
    return [
      for (final habit in habits)
        _buildSnapshot(habit, byHabit[habit.id] ?? const []),
    ];
  }

  HabitSnapshot _buildSnapshot(Habit habit, List<HabitEntry> rows) {
    final today = timeService.todayLocalDate();
    final rule = RecurrenceRule.parse(habit.scheduleRule);

    final scheduled = HabitSchedule.scheduledBetween(
      rule: rule,
      anchorDate: habit.anchorDate,
      start: habit.anchorDate,
      end: today,
    );

    final entries = <String, HabitDayRecord>{
      for (final row in rows)
        row.localDate:
            HabitDayRecord(count: row.checkCount, skipped: row.skipped),
    };

    final streaks = HabitStats.computeStreaks(
      scheduledDates: scheduled,
      entries: entries,
      targetCount: habit.targetCount,
      todayLocalDate: today,
      skipAllowancePerMonth: habit.skipAllowancePerMonth,
    );

    return HabitSnapshot(
      habit: habit,
      scheduledDates: scheduled,
      entries: entries,
      streaks: streaks,
      todayLocalDate: today,
    );
  }

  /// Day notes for one habit, newest first — the journal timeline.
  Future<List<HabitEntry>> journalFor(String habitId, {int limit = 200}) {
    return (db.select(db.habitEntries)
          ..where((e) =>
              e.habitId.equals(habitId) &
              e.deletedAt.isNull() &
              e.note.isNotNull())
          ..orderBy([(e) => OrderingTerm.desc(e.localDate)])
          ..limit(limit))
        .get();
  }

  // ----------------------------------------------------------------- internal

  /// Deliberately does NOT filter out tombstoned rows.
  ///
  /// `UNIQUE(habit_id, local_date)` covers every row, tombstoned or not. If a
  /// soft-deleted entry were invisible here, [_upsertEntry] would take the
  /// insert branch and the insert would throw. Nothing tombstones entries
  /// today, which is exactly why this would surface later as a crash rather
  /// than now as a test failure.
  Future<HabitEntry?> _entryFor(String habitId, String date) {
    return (db.select(db.habitEntries)
          ..where((e) =>
              e.habitId.equals(habitId) & e.localDate.equals(date)))
        .getSingleOrNull();
  }

  Future<void> _upsertEntry({
    required String habitId,
    required String date,
    required HabitEntry? existing,
    required int checkCount,
    required bool skipped,
    int? lastCheckedAt,
    Value<String?> note = const Value.absent(),
  }) async {
    final now = timeService.nowUtcMs();
    if (existing == null) {
      await db.into(db.habitEntries).insert(
            HabitEntriesCompanion.insert(
              id: newId(),
              habitId: habitId,
              localDate: date,
              checkCount: Value(checkCount),
              skipped: Value(skipped),
              note: note,
              lastCheckedAt: Value(lastCheckedAt),
              // Captured at write time so a day grid can be drawn in the zone
              // the check-off happened in, not the device's current one.
              tzOffsetMin: timeService.currentTzOffsetMin(),
              createdAt: now,
              updatedAt: now,
              deviceId: deviceId,
            ),
          );
    } else {
      await (db.update(db.habitEntries)
            ..where((e) => e.id.equals(existing.id)))
          .write(
        HabitEntriesCompanion(
          checkCount: Value(checkCount),
          skipped: Value(skipped),
          note: note,
          lastCheckedAt: Value(lastCheckedAt),
          // Writing to a tombstoned day revives it.
          deletedAt: const Value<int?>(null),
          updatedAt: Value(now),
          deviceId: Value(deviceId),
        ),
      );
    }
  }
}
