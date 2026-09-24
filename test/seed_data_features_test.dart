import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/habits/milestone_thresholds.dart';
import 'package:habit_tracker/core/stats/statistics.dart';
import 'package:habit_tracker/core/time/time_service.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/data/dev/seed_data.dart';
import 'package:habit_tracker/data/repositories/events_repository.dart';
import 'package:habit_tracker/data/repositories/habit_analytics_repository.dart';
import 'package:habit_tracker/data/repositories/habits_repository.dart';
import 'package:habit_tracker/data/repositories/settings_repository.dart';
import 'package:habit_tracker/features/habits/domain/habit_presentation.dart';
import 'package:habit_tracker/features/today/presentation/widgets/grow_your_cairn_card.dart';
import 'package:habit_tracker/features/today/presentation/widgets/momentum_week_strip.dart';

void main() {
  test('SeedData satisfies all 6 requirements from direct audit', () async {
    final db = AppDatabase(NativeDatabase.memory());
    const timeService = TimeService(dayStartOffsetMinutes: 240);
    final settingsRepo = SettingsRepository(db: db);
    final eventsRepo = EventsRepository(db: db, timeService: timeService);
    final habitsRepo = HabitsRepository(
      db: db,
      eventsRepository: eventsRepo,
      timeService: timeService,
      deviceId: 'audit-test-device',
    );
    final habitAnalyticsRepo = HabitAnalyticsRepository(
      db: db,
      timeService: timeService,
      settings: settingsRepo,
      habitsRepository: habitsRepo,
    );

    final seeder = SeedData(
      db: db,
      timeService: timeService,
      deviceId: 'audit-test-device',
    );

    await seeder.generate(days: 730, taskCount: 1000);

    // ── Requirement 1: Notification/digest settings are seeded and on ─────────
    final digestEnabled = await settingsRepo.getBool('digest_enabled');
    final digestTimes = await settingsRepo.get('digest_times_min');
    final habitDigestEnabled = await settingsRepo.getBool('habit_digest_enabled');
    final habitDigestTime = await settingsRepo.getInt('habit_digest_time_min');

    expect(digestEnabled, isTrue);
    expect(digestTimes, isList);
    expect((digestTimes as List).isNotEmpty, isTrue);
    expect(habitDigestEnabled, isTrue);
    expect(habitDigestTime, equals(1200)); // 20:00 default

    // ── Requirement 2: Milestone threshold reached for at least one habit ────
    final today = timeService.todayLocalDate();
    final snapshots = await habitsRepo.loadActiveSnapshots();

    final milestoneHabits = snapshots.where((s) => s.milestoneToday != null).toList();
    expect(milestoneHabits.isNotEmpty, isTrue,
        reason: 'At least one habit must have milestoneToday != null');

    final milestoneHabit = milestoneHabits.first;
    expect(MilestoneThresholds.reached(milestoneHabit.streaks.current), isTrue);
    expect(milestoneHabit.streaks.current, equals(30),
        reason: 'Meditation streak is engineered to be exactly 30');

    // ── Requirement 3: Current week momentum strip shows partial pattern ─────
    final days = MomentumWeekStrip.daysFor(
      weekOf: today,
      todayLocalDate: today,
      snapshots: snapshots,
      weekStart: DateTime.monday,
    );

    final completedPastDays = days.where((d) => !d.isFuture && d.completed).length;
    final uncompletedPastDays = days.where((d) => !d.isFuture && !d.completed).length;

    // Must show a partial pattern: not all past days completed, but some completed
    expect(completedPastDays, greaterThan(0));
    expect(uncompletedPastDays, greaterThanOrEqualTo(1),
        reason: 'At least 1-2 days in the current week must show as NOT completed');

    // Today's cairn-stone count must be partial (not 0 and not full 4)
    final dueToday = snapshots.where((s) => s.isScheduledToday).toList();
    final doneToday = dueToday.where((s) => s.isDoneToday).toList();
    final stones = cairnStoneCount(checked: doneToday.length, total: dueToday.length);
    expect(stones, greaterThan(0));
    expect(stones, lessThan(4),
        reason: 'Today must show partial cairn stone count (not full)');

    // ── Requirement 4: Focus sessions link to tasks, has isManual, has notes ──
    final allSessions = await db.select(db.focusSessions).get();
    expect(allSessions.isNotEmpty, isTrue);

    final sessionsWithTasks = allSessions.where((s) => s.taskId != null).toList();
    final manualSessions = allSessions.where((s) => s.isManual).toList();
    final sessionsWithNotes = allSessions.where((s) => s.note != null && s.note!.isNotEmpty).toList();

    expect(sessionsWithTasks.length, greaterThan(100),
        reason: '~20% of sessions must have non-null taskId');
    expect(manualSessions.length, greaterThan(20),
        reason: 'Some sessions must have isManual: true');
    expect(sessionsWithNotes.length, greaterThan(50),
        reason: 'Some sessions must have realistic notes');

    // Confirm taskIds belong to real tasks in db
    final allTaskIds = (await db.select(db.tasks).get()).map((t) => t.id).toSet();
    for (final s in sessionsWithTasks.take(20)) {
      expect(allTaskIds.contains(s.taskId), isTrue,
          reason: 'Session taskId must match a real seeded task');
    }

    // ── Requirement 5: Count-habit partial progress is represented ────────────
    final waterHabit = snapshots.firstWhere((s) => s.habit.title == 'Drink water');
    final allWaterEntries = await (db.select(db.habitEntries)
          ..where((e) => e.habitId.equals(waterHabit.habit.id)))
        .get();

    final partialWaterEntries = allWaterEntries
        .where((e) => e.checkCount > 0 && e.checkCount < waterHabit.habit.targetCount)
        .toList();

    expect(partialWaterEntries.length, greaterThan(30),
        reason: 'Count habit (water) must have dozens of genuine partial-progress days');

    // Water today has partial progress
    final todayWaterEntry = allWaterEntries.firstWhere((e) => e.localDate == today);
    expect(todayWaterEntry.checkCount, equals(3));
    expect(todayWaterEntry.checkCount < waterHabit.habit.targetCount, isTrue);

    // ── Requirement 6: Recent-window stats are realistic (not ~100%) ──────────
    final weekStats = await habitAnalyticsRepo.load(StatsPeriod.week(timeService, today));
    expect(weekStats.completionRate.rate, isNotNull);
    final weekRate = weekStats.completionRate.rate!;

    // Must be realistic: non-degenerate (e.g. > 0.40) and not artificially flat (~100%)
    expect(weekRate, greaterThan(0.50));
    expect(weekRate, lessThan(0.85),
        reason: 'Week completion rate should show realistic human variation (< 85%, not ~100%)');

    // ── Wipe confirmation: wipe preserves settings, deletes everything else ────
    await seeder.wipe();

    final eventsAfter = await db.select(db.events).get();
    final sessionsAfter = await db.select(db.focusSessions).get();
    final tasksAfter = await db.select(db.tasks).get();
    final habitsAfter = await db.select(db.habits).get();
    final habitEntriesAfter = await db.select(db.habitEntries).get();

    expect(eventsAfter, isEmpty);
    expect(sessionsAfter, isEmpty);
    expect(tasksAfter, isEmpty);
    expect(habitsAfter, isEmpty);
    expect(habitEntriesAfter, isEmpty);

    // Settings survive wipe
    final digestAfterWipe = await settingsRepo.getBool('digest_enabled');
    expect(digestAfterWipe, isTrue);

    await db.close();
  });
}
