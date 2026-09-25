import 'dart:convert';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/constants/event_types.dart';
import 'package:habit_tracker/core/time/time_service.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/data/dev/seed_data.dart';
import 'package:habit_tracker/data/repositories/analytics_repository.dart';
import 'package:habit_tracker/data/repositories/events_repository.dart';
import 'package:habit_tracker/data/repositories/habits_repository.dart';
import 'package:habit_tracker/data/repositories/settings_repository.dart';
import 'package:habit_tracker/data/repositories/stats_repository.dart';
import 'package:habit_tracker/data/repositories/tasks_repository.dart';

void main() {
  group('Query Equivalence Tests', () {
    late AppDatabase db;
    late TimeService timeService;
    late EventsRepository eventsRepo;
    late SettingsRepository settingsRepo;
    late StatsRepository statsRepo;
    late TasksRepository tasksRepo;
    late AnalyticsRepository analyticsRepo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      timeService = const TimeService(dayStartOffsetMinutes: 240);
      eventsRepo = EventsRepository(db: db, timeService: timeService);
      settingsRepo = SettingsRepository(db: db);
      statsRepo = StatsRepository(db: db, timeService: timeService);
      tasksRepo = TasksRepository(
        db: db,
        eventsRepository: eventsRepo,
        timeService: timeService,
        deviceId: 'equiv-device-1',
      );
      analyticsRepo = AnalyticsRepository(
        db: db,
        timeService: timeService,
        settings: settingsRepo,
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Empty database edge case: all queries return empty results without error', () async {
      final today = timeService.todayLocalDate();

      // Stats queries
      final focusStats = await statsRepo.getFocusStats();
      expect(focusStats.focusMinutesToday, equals(0));
      expect(focusStats.currentStreakDays, equals(0));
      expect(focusStats.longestStreakDays, equals(0));

      final last7Days = await statsRepo.watchLast7DaysSummary().first;
      expect(last7Days.length, equals(7));
      for (final day in last7Days) {
        expect(day.minutes, equals(0));
        expect(day.goalMet, isFalse);
      }

      final throughput = await statsRepo.getThroughput(
        localDates: {today, TimeService.addDays(today, -1)},
      );
      expect(throughput.created, equals(0));
      expect(throughput.completed, equals(0));
      expect(throughput.net, equals(0));

      final totalCompleted = await analyticsRepo.totalCompletedSessions();
      expect(totalCompleted, equals(0));

      // Tasks queries
      final todayTasks = await tasksRepo.watchTodayTasks(today).first;
      expect(todayTasks, isEmpty);

      final upcomingTasks = await tasksRepo.watchUpcomingTasks(today).first;
      expect(upcomingTasks, isEmpty);

      final inboxTasks = await tasksRepo.watchInboxTasks().first;
      expect(inboxTasks, isEmpty);

      final archivedTasks = await tasksRepo.watchArchivedTasks().first;
      expect(archivedTasks, isEmpty);
    });

    test('Seeded dataset equivalence: rewritten repository methods match naive full-scan', () async {
      final seeder = SeedData(
        db: db,
        timeService: timeService,
        deviceId: 'equiv-device-1',
      );

      // Seed realistic data
      await seeder.generate(days: 90, taskCount: 150);
      final today = timeService.todayLocalDate();

      // ── 1. StatsRepository: watchLast7DaysSummary equivalence ──
      final optimized7Days = await statsRepo.watchLast7DaysSummary().first;

      // Naive full scan calculation:
      final allSessions = await db.select(db.focusSessions).get();
      final naiveMinutesByDate = <String, int>{};
      for (final s in allSessions) {
        if (s.outcome == SessionOutcomes.completed) {
          naiveMinutesByDate[s.localDate] =
              (naiveMinutesByDate[s.localDate] ?? 0) + s.actualDurationS;
        }
      }
      for (final entry in naiveMinutesByDate.entries.toList()) {
        naiveMinutesByDate[entry.key] = entry.value ~/ 60;
      }

      for (var i = 0; i < 7; i++) {
        final daysAgo = 6 - i;
        final date = TimeService.addDays(today, -daysAgo);
        final expectedMinutes = naiveMinutesByDate[date] ?? 0;
        expect(
          optimized7Days[i].minutes,
          equals(expectedMinutes),
          reason: 'Day $date focus minutes must match naive calculation',
        );
        expect(optimized7Days[i].date, equals(date));
      }

      // ── 2. StatsRepository: getThroughput equivalence ──
      final last7DaysDates = {
        for (var i = 0; i < 7; i++) TimeService.addDays(today, -i),
      };
      final optimizedThroughput = await statsRepo.getThroughput(localDates: last7DaysDates);

      // Naive throughput over all events:
      final allEvents = await db.select(db.events).get();
      var naiveCreated = 0;
      var naiveCompleted = 0;
      var naiveUncompletedDeleted = 0;
      for (final event in allEvents) {
        if (event.type == 'task_created') {
          if (last7DaysDates.contains(event.localDate)) naiveCreated++;
        } else if (event.type == 'task_completed') {
          if (last7DaysDates.contains(event.localDate)) naiveCompleted++;
        } else if (event.type == 'task_deleted') {
          try {
            final payload = jsonDecode(event.payload) as Map<String, dynamic>;
            final wasCompleted = payload['was_completed'] == true;
            final everCompleted = payload['ever_completed'] == true;
            final createdLocalDate = payload['created_local_date'] as String?;
            if (!wasCompleted && !everCompleted) {
              if (last7DaysDates.contains(event.localDate) ||
                  (createdLocalDate != null && last7DaysDates.contains(createdLocalDate))) {
                naiveUncompletedDeleted++;
              }
            }
          } catch (_) {
            if (last7DaysDates.contains(event.localDate)) naiveUncompletedDeleted++;
          }
        }
      }
      final naiveNetCreated = (naiveCreated - naiveUncompletedDeleted).clamp(0, double.infinity).toInt();
      final naiveNet = naiveNetCreated - naiveCompleted;

      expect(optimizedThroughput.created, equals(naiveNetCreated));
      expect(optimizedThroughput.completed, equals(naiveCompleted));
      expect(optimizedThroughput.net, equals(naiveNet));

      // ── 3. AnalyticsRepository: totalCompletedSessions equivalence ──
      final totalCompleted = await analyticsRepo.totalCompletedSessions();
      final naiveCompletedCount = allSessions.where((s) => s.outcome == 'completed').length;
      expect(totalCompleted, equals(naiveCompletedCount));

      // ── 4. TasksRepository: watchTodayTasks equivalence ──
      final optimizedToday = await tasksRepo.watchTodayTasks(today).first;

      // Naive today tasks calculation:
      final allTasks = await (db.select(db.tasks)
            ..where((t) =>
                t.parentId.isNull() &
                t.status.isNotValue('archived') &
                t.deletedAt.isNull()))
          .get();
      final naiveTodayTasks = allTasks.where((t) {
        if (t.status == 'done') {
          return t.completedLocalDate == today;
        }
        if (t.dueAt == null) return false;
        final taskLocalDate = timeService.computeLocalDate(t.dueAt!);
        return taskLocalDate == today || taskLocalDate.compareTo(today) < 0;
      }).toList();

      expect(
        optimizedToday.length,
        equals(naiveTodayTasks.length),
        reason: 'Optimized watchTodayTasks must return exact count of naive filter',
      );
      final optimizedTodayIds = optimizedToday.map((t) => t.id).toSet();
      final naiveTodayIds = naiveTodayTasks.map((t) => t.id).toSet();
      expect(optimizedTodayIds, equals(naiveTodayIds));

      // Verify task enrichment correctness on Today tasks
      for (final taskDetails in optimizedToday) {
        if (taskDetails.task.projectId != null) {
          expect(taskDetails.project, isNotNull);
          expect(taskDetails.project!.id, equals(taskDetails.task.projectId));
        }
      }

      // ── 5. TasksRepository: watchUpcomingTasks equivalence ──
      final optimizedUpcoming = await tasksRepo.watchUpcomingTasks(today).first;
      final naiveUpcomingTasks = allTasks.where((t) {
        if (t.status != 'open') return false;
        if (t.dueAt == null) return false;
        final taskLocalDate = timeService.computeLocalDate(t.dueAt!);
        return taskLocalDate.compareTo(today) > 0;
      }).toList();

      expect(
        optimizedUpcoming.length,
        equals(naiveUpcomingTasks.length),
        reason: 'Optimized watchUpcomingTasks must return exact count of naive filter',
      );
      final optimizedUpcomingIds = optimizedUpcoming.map((t) => t.id).toSet();
      final naiveUpcomingIds = naiveUpcomingTasks.map((t) => t.id).toSet();
      expect(optimizedUpcomingIds, equals(naiveUpcomingIds));

      // ── 6. TasksRepository: watchInboxTasks equivalence ──
      final optimizedInbox = await tasksRepo.watchInboxTasks().first;
      final naiveInboxTasks = allTasks.where((t) {
        return t.status == 'open' && t.dueAt == null;
      }).toList();

      expect(optimizedInbox.length, equals(naiveInboxTasks.length));
      final optimizedInboxIds = optimizedInbox.map((t) => t.id).toSet();
      final naiveInboxIds = naiveInboxTasks.map((t) => t.id).toSet();
      expect(optimizedInboxIds, equals(naiveInboxIds));

      // ── 7. TasksRepository: watchArchivedTasks equivalence ──
      // Create some archived tasks to test archival equivalence
      final taskToArchive = naiveInboxTasks.first;
      await tasksRepo.archiveTask(taskToArchive.id);

      final archivedList = await tasksRepo.watchArchivedTasks().first;
      expect(archivedList.any((a) => a.id == taskToArchive.id), isTrue);
      final archivedItem = archivedList.firstWhere((a) => a.id == taskToArchive.id);
      expect(archivedItem.archivedAtMs, greaterThan(0));
    });

    test('Habit with multi-year history correctly computes streaks', () async {
      final habitsRepo = HabitsRepository(
        db: db,
        eventsRepository: eventsRepo,
        timeService: timeService,
        deviceId: 'equiv-device-1',
      );

      final today = timeService.todayLocalDate();
      final twoYearsAgo = TimeService.addDays(today, -729);

      // Create a daily habit with anchor two years ago
      final habitId = await habitsRepo.createHabit(
        title: 'Daily Meditation',
        scheduleRule: 'FREQ=DAILY',
      );

      // Manually set anchor to two years ago
      await (db.update(db.habits)..where((h) => h.id.equals(habitId))).write(
        HabitsCompanion(anchorDate: Value(twoYearsAgo)),
      );

      // Insert check-offs for all 730 days
      for (var i = 0; i < 730; i++) {
        final date = TimeService.addDays(twoYearsAgo, i);
        await db.into(db.habitEntries).insert(
          HabitEntriesCompanion.insert(
            id: 'entry_$i',
            habitId: habitId,
            localDate: date,
            checkCount: const Value(1),
            skipped: const Value(false),
            lastCheckedAt: const Value(1000),
            createdAt: 1000,
            updatedAt: 1000,
            deviceId: 'equiv-device-1',
            tzOffsetMin: 0,
          ),
        );
      }

      final snapshots = await habitsRepo.loadActiveSnapshots();
      expect(snapshots.length, equals(1));
      final snapshot = snapshots.first;
      expect(snapshot.streaks.current, equals(730));
      expect(snapshot.streaks.longest, equals(730));
    });
  });
}
