// ignore_for_file: avoid_print
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/time/time_service.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/data/dev/seed_data.dart';
import 'package:habit_tracker/data/repositories/events_repository.dart';
import 'package:habit_tracker/data/repositories/tasks_repository.dart';

void main() {
  test('Batch Task Loading Verification: Performance, Ticking, Archived Ordering, and Details', () async {
    final db = AppDatabase(NativeDatabase.memory());
    const timeService = TimeService(dayStartOffsetMinutes: 240);
    final eventsRepo = EventsRepository(db: db, timeService: timeService);
    final tasksRepo = TasksRepository(
      db: db,
      eventsRepository: eventsRepo,
      timeService: timeService,
      deviceId: 'test-device',
    );
    final seeder = SeedData(
      db: db,
      timeService: timeService,
      deviceId: 'test-device',
    );

    // 1. Seed 2 years of data (1000 tasks)
    print('\n--- Seeding 2 years (1000 tasks) ---');
    final report = await seeder.generate(days: 730, taskCount: 1000);
    print('Seeded in ${report.elapsedMs}ms: ${report.tasks} tasks, ${report.events} events.');

    // 2. Measure Tasks list load time
    final sw = Stopwatch()..start();
    final inboxTasks = await tasksRepo.watchInboxTasks().first;
    sw.stop();
    final inboxLoadMs = sw.elapsedMilliseconds;
    print('1. watchInboxTasks().first took ${inboxLoadMs}ms for ${inboxTasks.length} inbox tasks');

    final sw2 = Stopwatch()..start();
    final todayTasks = await tasksRepo.watchTodayTasks(timeService.todayLocalDate()).first;
    sw2.stop();
    final todayLoadMs = sw2.elapsedMilliseconds;
    print('2. watchTodayTasks().first took ${todayLoadMs}ms for ${todayTasks.length} today tasks');

    // 3. Create a task with tags, project, and subtasks to verify enrichment fidelity
    print('\n2. Testing enrichment fidelity (tags, projects, subtasks)...');
    final projects = await db.select(db.projects).get();
    final sampleProject = projects.first;

    final taggedTask = await tasksRepo.createTask(
      title: 'Deploy v1.0 release',
      projectId: sampleProject.id,
      tagNames: ['release', 'prod'],
    );
    final subtask = await tasksRepo.createTask(
      parentId: taggedTask.id,
      title: 'Verify health checks',
    );

    final inboxAfterCreation = await tasksRepo.watchInboxTasks().first;
    final enrichedSample = inboxAfterCreation.firstWhere((t) => t.task.id == taggedTask.id);

    expect(enrichedSample.project, isNotNull);
    expect(enrichedSample.project!.id, equals(sampleProject.id));
    print('   Verified Project: "${enrichedSample.project!.name}"');

    expect(enrichedSample.tags.length, equals(2));
    final tagNames = enrichedSample.tags.map((t) => t.name).toSet();
    expect(tagNames, containsAll(['release', 'prod']));
    print('   Verified Tags: ${tagNames.toList()}');

    expect(enrichedSample.subtasks.length, equals(1));
    expect(enrichedSample.subtasks.first.id, equals(subtask.id));
    print('   Verified Subtask: "${enrichedSample.subtasks.first.title}"');

    // 4. Tick a task complete and untick it — measure stream update speed
    final targetTask = inboxTasks.first.task;
    print('\n3. Testing tick complete & untick on task ${targetTask.id}...');
    final tickSw = Stopwatch()..start();
    await tasksRepo.completeTask(targetTask.id);
    // Wait for the stream update
    final inboxAfterTick = await tasksRepo.watchInboxTasks().first;
    tickSw.stop();
    print('   Tick complete + stream re-emission took ${tickSw.elapsedMilliseconds}ms');
    expect(inboxAfterTick.any((t) => t.task.id == targetTask.id), isFalse);

    final untickSw = Stopwatch()..start();
    await tasksRepo.uncompleteTask(targetTask.id);
    final inboxAfterUntick = await tasksRepo.watchInboxTasks().first;
    untickSw.stop();
    print('   Untick + stream re-emission took ${untickSw.elapsedMilliseconds}ms');
    expect(inboxAfterUntick.any((t) => t.task.id == targetTask.id), isTrue);

    // 5. Verify watchArchivedTasks ordering (newest-archived-first)
    print('\n4. Testing watchArchivedTasks ordering...');
    final taskToArchive1 = inboxTasks[1].task;
    final taskToArchive2 = inboxTasks[2].task;
    await tasksRepo.archiveTask(taskToArchive1.id);
    await tasksRepo.archiveTask(taskToArchive2.id);

    final archivedItems = await tasksRepo.watchArchivedTasks().first;
    print('   Archived tasks count: ${archivedItems.length}');
    expect(archivedItems.length, greaterThanOrEqualTo(2));
    for (var i = 0; i < archivedItems.length - 1; i++) {
      expect(archivedItems[i].archivedAtMs >= archivedItems[i + 1].archivedAtMs, isTrue,
          reason: 'Archived list must be sorted descending by archivedAtMs');
    }
    print('   Verified: All ${archivedItems.length} archived tasks are sorted newest-first.');

    await db.close();
  });
}
