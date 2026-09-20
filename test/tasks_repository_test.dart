import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/time/time_service.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/data/repositories/events_repository.dart';
import 'package:habit_tracker/data/repositories/stats_repository.dart';
import 'package:habit_tracker/data/repositories/tasks_repository.dart';

void main() {
  late AppDatabase db;
  late TimeService timeService;
  late EventsRepository eventsRepo;
  late TasksRepository tasksRepo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    timeService = TimeService(
      dayStartOffsetMinutes: 240, // 04:00 AM
      localize: (utcMs) => DateTime.fromMillisecondsSinceEpoch(utcMs, isUtc: true),
      offsetMinutesAt: (_) => 0,
      tzIdProvider: () => 'UTC',
      nowProvider: () => DateTime.utc(2026, 9, 13, 12, 0).millisecondsSinceEpoch,
    );
    eventsRepo = EventsRepository(db: db, timeService: timeService);
    tasksRepo = TasksRepository(
      db: db,
      eventsRepository: eventsRepo,
      timeService: timeService,
    );
  });

  tearDown(() async {
    await db.close();
  });

  group('TasksRepository — Event-Sourced Lifecycle (§2.2, §2.4)', () {
    test('createTask inserts tasks row and logs task_created event', () async {
      final task = await tasksRepo.createTask(
        title: 'Review PR #42',
        priority: 1,
        dueAt: 1726200000000,
        dueIsAllDay: false,
        estimatePomodoros: 2,
        tagNames: ['work', 'dev'],
      );

      expect(task.id, isNotNull);
      expect(task.title, equals('Review PR #42'));
      expect(task.priority, equals(1));
      expect(task.status, equals('open'));
      expect(task.estimatePomodoros, equals(2));

      // Assert immutable event written. A timed task also gets a
      // `task_reminder_offsets_set` event (SPEC §11): the default reminder
      // offsets a new timed task starts with are themselves an event-sourced
      // fact, not something bolted on after the fact.
      final events = await (db.select(db.events)..where((e) => e.subjectId.equals(task.id))).get();
      expect(events.map((e) => e.type),
          containsAll(['task_created', 'task_reminder_offsets_set']));
      expect(events.first.type, equals('task_created'));
      expect(events.first.subjectType, equals('task'));

      // Assert tags linked
      final tags = await tasksRepo.getTagsForTask(task.id);
      expect(tags.map((t) => t.name).toList(), containsAll(['work', 'dev']));
    });

    test('completeTask updates status to done and logs task_completed event', () async {
      final task = await tasksRepo.createTask(title: 'Water plants');
      await tasksRepo.completeTask(task.id);

      final updated = await tasksRepo.getTask(task.id);
      expect(updated?.status, equals('done'));
      expect(updated?.completedAt, isNotNull);
      expect(updated?.completedLocalDate, equals(timeService.todayLocalDate()));

      final events = await (db.select(db.events)..where((e) => e.subjectId.equals(task.id))).get();
      expect(events.map((e) => e.type), containsAll(['task_created', 'task_completed']));
    });

    test('uncompleteTask reverts status to open and logs task_uncompleted event', () async {
      final task = await tasksRepo.createTask(title: 'Inbox zero');
      await tasksRepo.completeTask(task.id);
      await tasksRepo.uncompleteTask(task.id);

      final updated = await tasksRepo.getTask(task.id);
      expect(updated?.status, equals('open'));
      expect(updated?.completedAt, isNull);
      expect(updated?.completedLocalDate, isNull);

      final events = await (db.select(db.events)..where((e) => e.subjectId.equals(task.id))).get();
      expect(events.map((e) => e.type), containsAll(['task_created', 'task_completed', 'task_uncompleted']));
    });

    test('archiveTask sets status to archived and logs task_archived event', () async {
      final task = await tasksRepo.createTask(title: 'Tidy desk');
      await tasksRepo.archiveTask(task.id);

      final updated = await tasksRepo.getTask(task.id);
      expect(updated?.status, equals('archived'));

      final events = await (db.select(db.events)..where((e) => e.subjectId.equals(task.id))).get();
      expect(events.last.type, equals('task_archived'));
    });
  });

  group('TasksRepository — Rescheduling & Procrastination (§4.12)', () {
    test('increments reschedule_count ONLY when new due date is later', () async {
      final task = await tasksRepo.createTask(
        title: 'File taxes',
        dueAt: 1726200000000, // t0
      );
      expect(task.rescheduleCount, equals(0));

      // Reschedule to LATER date -> count increments to 1
      await tasksRepo.rescheduleTask(task.id, newDueAt: 1726300000000);
      final updated1 = await tasksRepo.getTask(task.id);
      expect(updated1?.rescheduleCount, equals(1));

      // Reschedule to EARLIER date -> count does NOT increment (still 1)
      await tasksRepo.rescheduleTask(task.id, newDueAt: 1726250000000);
      final updated2 = await tasksRepo.getTask(task.id);
      expect(updated2?.rescheduleCount, equals(1));
    });

    test('deferToTomorrow defers to tomorrow and increments count if originally due today', () async {
      final nowUtc = timeService.nowUtcMs();
      final task = await tasksRepo.createTask(title: 'Daily review', dueAt: nowUtc);

      await tasksRepo.deferToTomorrow(task.id);
      final updated = await tasksRepo.getTask(task.id);
      expect(updated?.rescheduleCount, equals(1));
      expect(updated?.dueIsAllDay, isTrue);
    });
  });

  group('TasksRepository — Subtask One-Level Nesting (§2.4)', () {
    test('allows creating child subtask under root task', () async {
      final parent = await tasksRepo.createTask(title: 'Project launch');
      final child = await tasksRepo.createTask(
        title: 'Prepare press release',
        parentId: parent.id,
      );

      expect(child.parentId, equals(parent.id));

      final subtasks = await tasksRepo.watchSubtasks(parent.id).first;
      expect(subtasks, hasLength(1));
      expect(subtasks.first.title, equals('Prepare press release'));
    });

    test('prohibits nesting deeper than one level', () async {
      final root = await tasksRepo.createTask(title: 'Root task');
      final subtask1 = await tasksRepo.createTask(title: 'Level 1', parentId: root.id);

      // Attempting to add subtask under subtask1 must throw
      expect(
        () => tasksRepo.createTask(title: 'Level 2', parentId: subtask1.id),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('TasksRepository — Recurrence (§2.6)', () {
    test('completing a recurring task spawns the next instance linked by recurrence_parent_id', () async {
      // Due on 2026-09-13, daily rule
      final dueAt = DateTime.utc(2026, 9, 13, 12, 0).millisecondsSinceEpoch;
      final task = await tasksRepo.createTask(
        title: 'Take vitamins',
        dueAt: dueAt,
        dueIsAllDay: true,
        recurrenceRule: 'FREQ=DAILY;INTERVAL=1',
        recurrenceMode: 'on_schedule',
      );

      await tasksRepo.completeTask(task.id);

      // Original task marked done
      final finished = await tasksRepo.getTask(task.id);
      expect(finished?.status, equals('done'));

      // New instance spawned
      final allTasks = await (db.select(db.tasks)..where((t) => t.title.equals('Take vitamins'))).get();
      expect(allTasks, hasLength(2));

      final nextInstance = allTasks.firstWhere((t) => t.id != task.id);
      expect(nextInstance.status, equals('open'));
      expect(nextInstance.recurrenceParentId, equals(task.id));
      expect(nextInstance.recurrenceRule, equals('FREQ=DAILY;INTERVAL=1'));
      expect(nextInstance.recurrenceMode, equals('on_schedule'));

      // Next due date is 2026-09-14
      final nextDt = DateTime.fromMillisecondsSinceEpoch(nextInstance.dueAt!, isUtc: true);
      expect(nextDt.year, equals(2026));
      expect(nextDt.month, equals(9));
      expect(nextDt.day, equals(14));
    });

    test('complete a daily recurring task twice in succession and assert exactly one open instance exists per due date', () async {
      // Due on 2026-09-13, daily rule
      final dueAt = DateTime.utc(2026, 9, 13, 12, 0).millisecondsSinceEpoch;
      final task = await tasksRepo.createTask(
        title: 'Take Meds',
        dueAt: dueAt,
        dueIsAllDay: true,
        recurrenceRule: 'FREQ=DAILY;INTERVAL=1',
        recurrenceMode: 'on_schedule',
      );

      // First completion: marks done and spawns next instance for 2026-09-14
      await tasksRepo.completeTask(task.id);

      // Second completion in succession on the same task or uncomplete + re-complete
      // Even if completeTask is triggered again:
      await tasksRepo.completeTask(task.id);

      // Or if uncompleted and completed again:
      await tasksRepo.uncompleteTask(task.id);
      await tasksRepo.completeTask(task.id);

      // Query all tasks in this recurrence series
      final seriesTasks = await (db.select(db.tasks)
            ..where((t) =>
                t.id.equals(task.id) |
                t.recurrenceParentId.equals(task.id)))
          .get();

      // Filter only open tasks
      final openTasks = seriesTasks.where((t) => t.status == 'open').toList();

      // Assert exactly one open instance exists per due date
      final openDueDates = openTasks.map((t) => timeService.computeLocalDate(t.dueAt!)).toList();
      final uniqueDueDates = openDueDates.toSet();

      expect(openDueDates.length, equals(uniqueDueDates.length),
          reason: 'Duplicate open instances found for the same due date in recurrence series!');
      expect(openTasks, hasLength(1));
      expect(openDueDates.first, equals('2026-09-14'));
    });

    test('restoring an instance of an active series spawns nothing', () async {
      final dueAt = DateTime.utc(2026, 9, 13, 12, 0).millisecondsSinceEpoch;
      final task = await tasksRepo.createTask(
        title: 'Daily Workout',
        dueAt: dueAt,
        dueIsAllDay: true,
        recurrenceRule: 'FREQ=DAILY;INTERVAL=1',
        recurrenceMode: 'on_schedule',
      );

      // Complete task -> spawns instance 2 for 2026-09-14
      await tasksRepo.completeTask(task.id);
      final tasksAfterSpawn = await (db.select(db.tasks)).get();
      expect(tasksAfterSpawn, hasLength(2));

      // Archive instance 1
      await tasksRepo.archiveTask(task.id);
      final taskArchived = await tasksRepo.getTask(task.id);
      expect(taskArchived?.status, equals('archived'));

      // Restore instance 1
      final destination = await tasksRepo.restoreTask(task.id);
      expect(destination, equals('Today'));

      // Assert restoring spawns NOTHING: total tasks count must still be 2 (no new instances spawned)
      final tasksAfterRestore = await (db.select(db.tasks)).get();
      expect(tasksAfterRestore, hasLength(2));
      final restoredTask = await tasksRepo.getTask(task.id);
      expect(restoredTask?.status, equals('open'));
    });
  });

  group('TasksRepository — Archive & Restore (§2.2, §2.3, §2.4)', () {
    test('restoring an archived task returns it to the correct list', () async {
      // 1. Task due today -> restores to Today
      final todayMs = DateTime.utc(2026, 9, 13, 10, 0).millisecondsSinceEpoch;
      final todayTask = await tasksRepo.createTask(title: 'Today Task', dueAt: todayMs);
      await tasksRepo.archiveTask(todayTask.id);
      final destToday = await tasksRepo.restoreTask(todayTask.id);
      expect(destToday, equals('Today'));

      // 2. Task due in future -> restores to Upcoming
      final futureMs = DateTime.utc(2026, 9, 20, 10, 0).millisecondsSinceEpoch;
      final futureTask = await tasksRepo.createTask(title: 'Future Task', dueAt: futureMs);
      await tasksRepo.archiveTask(futureTask.id);
      final destUpcoming = await tasksRepo.restoreTask(futureTask.id);
      expect(destUpcoming, equals('Upcoming'));

      // 3. Task with no due date -> restores to Inbox
      final inboxTask = await tasksRepo.createTask(title: 'Inbox Task');
      await tasksRepo.archiveTask(inboxTask.id);
      final destInbox = await tasksRepo.restoreTask(inboxTask.id);
      expect(destInbox, equals('Inbox'));
    });

    test('restoring a completed task writes task_uncompleted event and sets status to open', () async {
      final task = await tasksRepo.createTask(title: 'Finish report');
      await tasksRepo.completeTask(task.id);
      await tasksRepo.archiveTask(task.id);

      await tasksRepo.restoreTask(task.id);

      final restored = await tasksRepo.getTask(task.id);
      expect(restored?.status, equals('open'));
      expect(restored?.completedAt, isNull);

      final events = await (db.select(db.events)..where((e) => e.subjectId.equals(task.id))).get();
      expect(events.map((e) => e.type), contains('task_uncompleted'));
    });

    test('never permanently deletes rows from the database on archive or restore (§2.4)', () async {
      final task = await tasksRepo.createTask(title: 'Eternal record');
      await tasksRepo.archiveTask(task.id);

      final row = await (db.select(db.tasks)..where((t) => t.id.equals(task.id))).getSingleOrNull();
      expect(row, isNotNull);
      expect(row?.status, equals('archived'));

      await tasksRepo.restoreTask(task.id);
      final restoredRow = await (db.select(db.tasks)..where((t) => t.id.equals(task.id))).getSingleOrNull();
      expect(restoredRow, isNotNull);
      expect(restoredRow?.status, equals('open'));
    });
  });

  group('TasksRepository — Ordering & Priority (§1.1)', () {
    test('priority ordering puts p1 above p4', () {
      final p1Task = Task(
        id: 'task-1',
        title: 'High priority',
        priority: 1,
        status: 'open',
        createdAt: 1000,
        createdLocalDate: '2026-09-13',
        rescheduleCount: 0,
        sortOrder: 0.0,
        dueIsAllDay: false,
        updatedAt: 1000,
        deviceId: 'device-1',
      );
      final p4Task = Task(
        id: 'task-2',
        title: 'Low priority',
        priority: 4,
        status: 'open',
        createdAt: 500, // even though created earlier
        createdLocalDate: '2026-09-13',
        rescheduleCount: 0,
        sortOrder: 0.0,
        dueIsAllDay: false,
        updatedAt: 500,
        deviceId: 'device-1',
      );

      expect(compareTasks(p1Task, p4Task, timeService), lessThan(0));
      expect(compareTasks(p4Task, p1Task, timeService), greaterThan(0));
    });

    test('overdue task sorts above today task of same priority', () {
      final overdueTask = Task(
        id: 'task-1',
        title: 'Overdue task',
        priority: 2,
        status: 'open',
        createdAt: 1000,
        createdLocalDate: '2026-09-12',
        dueAt: DateTime.utc(2026, 9, 12, 10, 0).millisecondsSinceEpoch,
        rescheduleCount: 0,
        sortOrder: 0.0,
        dueIsAllDay: false,
        updatedAt: 1000,
        deviceId: 'device-1',
      );
      final todayTask = Task(
        id: 'task-2',
        title: 'Today task',
        priority: 2,
        status: 'open',
        createdAt: 500,
        createdLocalDate: '2026-09-13',
        dueAt: DateTime.utc(2026, 9, 13, 9, 0).millisecondsSinceEpoch,
        rescheduleCount: 0,
        sortOrder: 0.0,
        dueIsAllDay: false,
        updatedAt: 500,
        deviceId: 'device-1',
      );

      expect(compareTasks(overdueTask, todayTask, timeService, '2026-09-13'), lessThan(0));
      expect(compareTasks(todayTask, overdueTask, timeService, '2026-09-13'), greaterThan(0));
    });

    test('open tasks sort above completed tasks', () {
      final openTask = Task(
        id: 'task-1',
        title: 'Open task',
        priority: 4,
        status: 'open',
        createdAt: 2000,
        createdLocalDate: '2026-09-13',
        rescheduleCount: 0,
        sortOrder: 0.0,
        dueIsAllDay: false,
        updatedAt: 2000,
        deviceId: 'device-1',
      );
      final doneTask = Task(
        id: 'task-2',
        title: 'Done task',
        priority: 1, // higher priority, but completed
        status: 'done',
        createdAt: 1000,
        createdLocalDate: '2026-09-13',
        completedAt: 1500,
        completedLocalDate: '2026-09-13',
        rescheduleCount: 0,
        sortOrder: 0.0,
        dueIsAllDay: false,
        updatedAt: 1500,
        deviceId: 'device-1',
      );

      expect(compareTasks(openTask, doneTask, timeService), lessThan(0));
      expect(compareTasks(doneTask, openTask, timeService), greaterThan(0));
    });
  });

  group('TasksRepository — Projects (§2.5)', () {
    test('creates and retrieves projects with series color index', () async {
      await tasksRepo.createProject(name: 'Work', colorIndex: 0);
      await tasksRepo.createProject(name: 'Personal', colorIndex: 3);

      final projects = await tasksRepo.getProjects();
      expect(projects, hasLength(2));
      expect(projects.map((p) => p.name), containsAll(['Work', 'Personal']));
      final pWork = projects.firstWhere((p) => p.name == 'Work');
      expect(pWork.colorIndex, equals(0));
      final pPersonal = projects.firstWhere((p) => p.name == 'Personal');
      expect(pPersonal.colorIndex, equals(3));
    });
  });

  group('TasksRepository — Deletion & Honest Statistics (§2, §3, §4, §4.10, §6)', () {
    test('deleting a task with no history removes it and writes task_deleted', () async {
      final task = await tasksRepo.createTask(
        title: 'Accidental task',
        tagNames: ['work'],
      );
      final subtask = await tasksRepo.createTask(
        title: 'Accidental subtask',
        parentId: task.id,
      );

      final history = await tasksRepo.checkTaskHistory(task.id);
      expect(history.hasHistory, isFalse);

      await tasksRepo.deleteTask(task.id);

      // Verify task row is removed
      expect(await tasksRepo.getTask(task.id), isNull);
      // Verify subtask row is removed
      expect(await tasksRepo.getTask(subtask.id), isNull);
      // Verify tags association is removed
      expect(await tasksRepo.getTagsForTask(task.id), isEmpty);

      // Verify task_deleted event was logged first
      final events = await (db.select(db.events)
            ..where((e) => e.subjectId.equals(task.id) & e.type.equals('task_deleted')))
          .get();
      expect(events, hasLength(1));
      expect(events.first.type, equals('task_deleted'));
      expect(events.first.subjectType, equals('task'));
    });

    test('undo within the window restores the task and its subtasks', () async {
      final task = await tasksRepo.createTask(title: 'Staged task');
      final subtask = await tasksRepo.createTask(
        title: 'Staged subtask',
        parentId: task.id,
      );

      final pending = await tasksRepo.stageDeleteTask(task.id);
      expect(tasksRepo.isPendingDeletion(task.id), isTrue);
      expect(tasksRepo.isPendingDeletion(subtask.id), isTrue);

      // Active streams filter it out
      final tasksBeforeUndo = await tasksRepo.watchInboxTasks().first;
      expect(tasksBeforeUndo.any((t) => t.id == task.id), isFalse);

      // Undo before commit
      await pending.undo();
      expect(tasksRepo.isPendingDeletion(task.id), isFalse);
      expect(tasksRepo.isPendingDeletion(subtask.id), isFalse);

      // Task is restored in active streams and database
      final tasksAfterUndo = await tasksRepo.watchInboxTasks().first;
      expect(tasksAfterUndo.any((t) => t.id == task.id), isTrue);
      expect(await tasksRepo.getTask(task.id), isNotNull);
      expect(await tasksRepo.getTask(subtask.id), isNotNull);
    });

    test('throughput for a created-then-deleted task nets to zero', () async {
      final statsRepo = StatsRepository(db: db, timeService: timeService);

      final task = await tasksRepo.createTask(title: 'Quick delete task');

      // Before delete: created=1, completed=0, net=1
      var throughput = await statsRepo.getThroughput();
      expect(throughput.created, equals(1));
      expect(throughput.completed, equals(0));
      expect(throughput.net, equals(1));

      // Delete without completing
      await tasksRepo.deleteTask(task.id);

      // After delete: created=0, completed=0, net=0
      throughput = await statsRepo.getThroughput();
      expect(throughput.created, equals(0));
      expect(throughput.completed, equals(0));
      expect(throughput.net, equals(0));

      // Now verify a task that WAS completed retains historical count
      final completedTask = await tasksRepo.createTask(title: 'Done task');
      await tasksRepo.completeTask(completedTask.id);
      await tasksRepo.deleteTask(completedTask.id);

      throughput = await statsRepo.getThroughput();
      expect(throughput.created, equals(1));
      expect(throughput.completed, equals(1));
      expect(throughput.net, equals(0));
    });

    test('deleting a task with completions requires confirmation', () async {
      final task = await tasksRepo.createTask(title: 'Take Meds');

      var history = await tasksRepo.checkTaskHistory(task.id);
      expect(history.hasHistory, isFalse);

      await tasksRepo.completeTask(task.id);

      // Attach 2 focus sessions
      await db.into(db.focusSessions).insert(
        FocusSessionsCompanion.insert(
          id: 'session-1',
          taskId: Value(task.id),
          mode: 'pomodoro',
          outcome: 'completed',
          plannedDurationS: const Value(1500),
          actualDurationS: const Value(1500),
          startedAt: 1000,
          endedAt: 2500,
          localDate: '2026-09-13',
          tzOffsetMin: -360,
          updatedAt: 1000,
          deviceId: 'device-1',
        ),
      );
      await db.into(db.focusSessions).insert(
        FocusSessionsCompanion.insert(
          id: 'session-2',
          taskId: Value(task.id),
          mode: 'pomodoro',
          outcome: 'completed',
          plannedDurationS: const Value(1500),
          actualDurationS: const Value(1500),
          startedAt: 3000,
          endedAt: 4500,
          localDate: '2026-09-13',
          tzOffsetMin: -360,
          updatedAt: 3000,
          deviceId: 'device-1',
        ),
      );

      history = await tasksRepo.checkTaskHistory(task.id);
      expect(history.hasHistory, isTrue);
      expect(history.completionsCount, equals(1));
      expect(history.focusSessionsCount, equals(2));

      final warning = history.buildWarningMessage(task.title);
      expect(warning, contains('Take Meds has 1 completion and 2 focus sessions. Deleting removes it from your history and past statistics will change.'));
    });

    test('deleting a series stops future instances spawning', () async {
      final task = await tasksRepo.createTask(
        title: 'Daily Standup',
        recurrenceRule: 'FREQ=DAILY',
        dueAt: DateTime.utc(2026, 9, 13, 9, 0).millisecondsSinceEpoch,
      );

      // Complete this instance -> next instance spawns
      await tasksRepo.completeTask(task.id);

      final openInstances = await (db.select(db.tasks)
            ..where((t) =>
                t.recurrenceParentId.equals(task.id) &
                t.status.equals('open') &
                t.deletedAt.isNull()))
          .get();
      expect(openInstances, hasLength(1));

      // Delete series
      await tasksRepo.deleteTask(task.id, deleteSeries: true);

      // Series rule is cleared
      final parentTask = await tasksRepo.getTask(task.id);
      expect(parentTask, isNull); // deleted this instance

      // Future open instances are removed
      final remainingOpen = await (db.select(db.tasks)
            ..where((t) =>
                t.recurrenceParentId.equals(task.id) &
                t.status.equals('open') &
                t.deletedAt.isNull()))
          .get();
      expect(remainingOpen, isEmpty);
    });

    test('no stats query breaks when a task row is missing', () async {
      final statsRepo = StatsRepository(db: db, timeService: timeService);
      final task = await tasksRepo.createTask(title: 'Ghost task');

      // Log completed session attached to this task
      await db.into(db.focusSessions).insert(
        FocusSessionsCompanion.insert(
          id: 'session-ghost',
          taskId: Value(task.id),
          mode: 'pomodoro',
          outcome: 'completed',
          plannedDurationS: const Value(1500),
          actualDurationS: const Value(1500),
          startedAt: 1000,
          endedAt: 2500,
          localDate: timeService.todayLocalDate(),
          tzOffsetMin: -360,
          updatedAt: 1000,
          deviceId: 'device-1',
        ),
      );

      // Delete the task row completely
      await tasksRepo.deleteTask(task.id);
      expect(await tasksRepo.getTask(task.id), isNull);

      // All stats queries must succeed without throws
      final focusStats = await statsRepo.getFocusStats();
      expect(focusStats.focusMinutesToday, equals(25));

      final last7Days = await statsRepo.watchLast7DaysSummary().first;
      expect(last7Days, hasLength(7));

      final throughput = await statsRepo.getThroughput();
      expect(throughput.created, equals(0)); // never completed task nets to 0
    });
  });
}
