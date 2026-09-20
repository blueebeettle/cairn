// ignore_for_file: avoid_print
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/time/time_service.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/data/dev/seed_data.dart';
import 'package:habit_tracker/data/repositories/events_repository.dart';
import 'package:habit_tracker/data/repositories/tasks_repository.dart';

void main() {
  test('POLISH §8 (Reseed) — Verify Today, Tasks Tabs, Archived Ordering & Timing', () async {
    final db = AppDatabase(NativeDatabase.memory());
    const timeService = TimeService(dayStartOffsetMinutes: 240);
    final eventsRepo = EventsRepository(db: db, timeService: timeService);
    final tasksRepo = TasksRepository(
      db: db,
      eventsRepository: eventsRepo,
      timeService: timeService,
      deviceId: 'reseed-device',
    );
    final seeder = SeedData(
      db: db,
      timeService: timeService,
      deviceId: 'reseed-device',
    );

    // 1. Wipe first, then seed 2 years (1000 tasks)
    print('\n==================== RESEED VERIFICATION ====================');
    await seeder.wipe();

    final seedSw = Stopwatch()..start();
    final report = await seeder.generate(days: 730, taskCount: 1000);
    seedSw.stop();
    print('Seeded in ${seedSw.elapsedMilliseconds}ms: ${report.tasks} tasks, ${report.events} events.');

    final allTasks = await db.select(db.tasks).get();
    expect(allTasks.length, equals(1000));

    final todayLocalDate = timeService.todayLocalDate();
    print('Today local date: $todayLocalDate');

    // Categorize tasks
    var doneCount = 0;
    var dueTodayCount = 0;
    var overdueCount = 0;
    var upcomingCount = 0;
    var inboxCount = 0;
    var withReschedulesCount = 0;

    for (final t in allTasks) {
      if (t.status == 'done') {
        doneCount++;
      } else {
        if (t.rescheduleCount > 0) withReschedulesCount++;
        if (t.dueAt == null) {
          inboxCount++;
        } else {
          final dueLocal = timeService.computeLocalDate(t.dueAt!);
          if (dueLocal == todayLocalDate) {
            dueTodayCount++;
          } else if (dueLocal.compareTo(todayLocalDate) < 0) {
            overdueCount++;
          } else {
            upcomingCount++;
          }
        }
      }
    }

    print('\n--- Generated Task Distribution ---');
    print('Done:                 $doneCount');
    print('Open, Due Today:      $dueTodayCount');
    print('Open, Overdue:        $overdueCount');
    print('Open, Upcoming:       $upcomingCount');
    print('Open, Inbox (no due): $inboxCount');
    print('Open, Rescheduled:    $withReschedulesCount');

    final rescheduleEvents = await (db.select(db.events)
          ..where((e) => e.type.equals('task_rescheduled')))
        .get();
    print('Task Rescheduled events logged: ${rescheduleEvents.length}');

    // 2. Open Today view: check counts and overdue distinction
    print('\n--- Today View Check ---');
    final todayTasks = await tasksRepo.watchTodayTasks(todayLocalDate).first;
    final todayOpen = todayTasks.where((t) => t.status == 'open').toList();
    final todayDone = todayTasks.where((t) => t.status == 'done').toList();
    print('Today screen total tasks loaded: ${todayTasks.length} (Open: ${todayOpen.length}, Done today: ${todayDone.length})');

    final overdueOnToday = todayOpen.where((t) {
      final task = t.task;
      return task.dueAt != null && timeService.computeLocalDate(task.dueAt!).compareTo(todayLocalDate) < 0;
    }).toList();
    final dueTodayOnToday = todayOpen.where((t) {
      final task = t.task;
      return task.dueAt != null && timeService.computeLocalDate(task.dueAt!) == todayLocalDate;
    }).toList();

    print('Today screen overdue count:   ${overdueOnToday.length}');
    print('Today screen due-today count: ${dueTodayOnToday.length}');
    expect(overdueOnToday.length, equals(overdueCount));
    expect(dueTodayOnToday.length, equals(dueTodayCount));

    // Truncation check (§1.3)
    final visibleTodayOpen = todayOpen.take(5).toList();
    final hasMoreOpen = todayOpen.length > 5;
    print('Truncation on Today screen:');
    print('   Visible rows rendered: ${visibleTodayOpen.length}');
    print('   "View all ${todayOpen.length} tasks" affordance shown: $hasMoreOpen');
    expect(visibleTodayOpen.length, equals(5));
    expect(hasMoreOpen, isTrue);

    // 3. Open Tasks screen: 3 tabs
    print('\n--- Tasks Screen (3 Tabs) ---');
    final inboxTasks = await tasksRepo.watchInboxTasks().first;
    final upcomingTasks = await tasksRepo.watchUpcomingTasks(todayLocalDate).first;

    print('Tab 1 (Today):    ${todayOpen.length} open tasks');
    print('Tab 2 (Upcoming): ${upcomingTasks.length} open tasks');
    print('Tab 3 (Inbox):    ${inboxTasks.length} open tasks');

    expect(todayOpen.length, equals(dueTodayCount + overdueCount));
    expect(upcomingTasks.length, equals(upcomingCount));
    expect(inboxTasks.length, equals(inboxCount));

    // 4. Archived view check
    print('\n--- Archived View Check ---');
    final initialArchived = await tasksRepo.watchArchivedTasks().first;
    print('Initial archived tasks: ${initialArchived.length}');
    expect(initialArchived.isEmpty, isTrue);

    // Archive 2 tasks
    final task1 = inboxTasks[0].task;
    final task2 = inboxTasks[1].task;
    await tasksRepo.archiveTask(task1.id);
    await Future.delayed(const Duration(milliseconds: 10));
    await tasksRepo.archiveTask(task2.id);

    final archivedList = await tasksRepo.watchArchivedTasks().first;
    print('Archived tasks count after archiving 2: ${archivedList.length}');
    expect(archivedList.length, equals(2));
    expect(archivedList[0].task.id, equals(task2.id));
    expect(archivedList[1].task.id, equals(task1.id));
    expect(archivedList[0].archivedAtMs >= archivedList[1].archivedAtMs, isTrue);
    print('Archived ordering verified: newest-archived-first.');

    // 5. Re-run timing benchmarks
    print('\n--- Timing Benchmarks (Differently Shaped Lists) ---');
    // Warm-up
    await tasksRepo.watchInboxTasks().first;
    await tasksRepo.watchTodayTasks(todayLocalDate).first;
    await tasksRepo.watchUpcomingTasks(todayLocalDate).first;

    // Benchmark Inbox (110 items)
    final swInbox = Stopwatch()..start();
    final bInbox = await tasksRepo.watchInboxTasks().first;
    swInbox.stop();
    final inboxMs = swInbox.elapsedMilliseconds;
    print('watchInboxTasks().first (${bInbox.length} items):    ${inboxMs}ms');

    // Benchmark Today (151 items)
    final swToday = Stopwatch()..start();
    final bToday = await tasksRepo.watchTodayTasks(todayLocalDate).first;
    swToday.stop();
    final todayMs = swToday.elapsedMilliseconds;
    print('watchTodayTasks().first (${bToday.length} items):    ${todayMs}ms');

    // Benchmark Upcoming (32 items)
    final swUpcoming = Stopwatch()..start();
    final bUpcoming = await tasksRepo.watchUpcomingTasks(todayLocalDate).first;
    swUpcoming.stop();
    final upcomingMs = swUpcoming.elapsedMilliseconds;
    print('watchUpcomingTasks().first (${bUpcoming.length} items): ${upcomingMs}ms');

    // Ticking benchmark
    final target = bInbox.first.task;
    final swTick = Stopwatch()..start();
    await tasksRepo.completeTask(target.id);
    await tasksRepo.watchInboxTasks().first;
    swTick.stop();
    print('Tick complete + stream update:               ${swTick.elapsedMilliseconds}ms');

    final swUntick = Stopwatch()..start();
    await tasksRepo.uncompleteTask(target.id);
    await tasksRepo.watchInboxTasks().first;
    swUntick.stop();
    print('Untick + stream update:                      ${swUntick.elapsedMilliseconds}ms');

    await db.close();
  });
}
