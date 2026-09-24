import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../../core/constants/event_types.dart';
import '../../core/habits/habit_schedule.dart';
import '../../core/ids.dart';
import '../../core/recurrence/recurrence.dart';
import '../../core/time/time_service.dart';
import '../database/app_database.dart';
import '../repositories/settings_repository.dart';

/// Development-only data generator — POLISH.md §8.
///
/// *"Seed a test database with 10,000 events and 1,000 tasks. Everything below
/// is measured against that, not against your 50 rows."*
///
/// Two things this is for, and it is worth being clear that they are different:
///
/// **Measuring.** The event log grows forever by design (SPEC §0). That is the
/// right call, and it means query cost has to be measured rather than assumed.
/// Fifty rows will tell you nothing — every query is instant at fifty rows,
/// including the ones that will be unusable at fifty thousand.
///
/// **Seeing.** Until there are ten completed sessions the peak window will not
/// display at all (§4.4), and until there are fourteen non-zero days the
/// heatmap runs on provisional fixed thresholds (§4.13). A real history is the
/// only way to look at those features and judge whether they are any good.
///
/// The default span is two years, deliberately longer than the heatmap's
/// trailing-365 window, so the window has history *outside* it to ignore. A
/// query that quietly scans everything looks identical to a correct one until
/// there is data it is supposed to leave alone.
///
/// ## This is not a demo mode
///
/// Every row it writes is indistinguishable from a real one. There is no flag
/// that says "seeded". That is on purpose — a flag would let queries skip this
/// data, and then the measurement would be of a query that is not the one that
/// ships. It also means **this must never be reachable from the normal UI**,
/// only from the developer screen, and [wipe] must sit next to it.
class SeedData {
  SeedData({
    required AppDatabase db,
    required TimeService timeService,
    required String deviceId,
    int randomSeed = 20260914,
  })  : _db = db,
        _time = timeService,
        _deviceId = deviceId,
        _rng = Random(randomSeed);

  final AppDatabase _db;
  final TimeService _time;
  final String _deviceId;

  /// Seeded rather than `Random()`. If seeding ever produces data that breaks a
  /// query, you want to be able to produce exactly that data again.
  final Random _rng;

  static const defaultDays = 730;
  static const defaultTaskCount = 1000;

  /// Four projects plus unassigned — enough for §4.8's allocation chart to have
  /// something to say without every slice being a sliver.
  static const _projectNames = ['Cairn', 'Reading', 'Admin', 'Fitness'];

  static const _taskVerbs = [
    'Review', 'Draft', 'Fix', 'Read', 'Email', 'Plan', 'Refactor', 'Call',
    'Write up', 'Chase', 'Book', 'Renew', 'Tidy', 'Test', 'Sketch',
  ];
  static const _taskNouns = [
    'the spec', 'the release notes', 'the timer bug', 'chapter 4',
    'the landlord', 'next week', 'the stats query', 'the dentist',
    'the retro', 'the invoice', 'the flights', 'the domain', 'the desk',
    'the migration', 'the icon',
  ];

  static const _sessionNotes = [
    'Deep work on architecture design.',
    'Cleared inbox and pending reviews.',
    'Drafted implementation notes.',
    'Refactored legacy query logic.',
    'Focused sprint on critical bugfix.',
    'Good flow, wrapped up the prototype.',
    'Wrote unit tests and coverage benchmarks.',
    'Reviewed customer feedback and planned next iteration.',
  ];

  /// Generates a history ending today and returns what it wrote.
  ///
  /// [onProgress] is called with a 0.0–1.0 fraction; on a phone this takes a
  /// few seconds and a frozen screen looks like a crash.
  Future<SeedReport> generate({
    int days = defaultDays,
    int taskCount = defaultTaskCount,
    void Function(double fraction)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    final today = _time.todayLocalDate();
    final startDate = TimeService.addDays(today, -(days - 1));

    final projectIds = await _insertProjects();
    await _seedSettings();

    var eventCount = 0;
    var sessionCount = 0;

    // Generate tasks first so focus sessions can link to real active tasks
    final taskResult = await _insertTasks(
      count: taskCount,
      startDate: startDate,
      days: days,
      projectIds: projectIds,
      onProgress: (f) => onProgress?.call(0.1 + f * 0.25),
    );
    eventCount += taskResult.events;

    // Pre-index active tasks by day for O(1) task-attachment lookup
    final tasksByDay = List<List<_SeededTaskInfo>>.generate(days, (_) => []);
    for (final task in taskResult.tasks) {
      final startDay = task.createdDayOffset;
      final endDay = task.completedDayOffset ?? (days - 1);
      for (var d = startDay; d <= endDay && d < days; d++) {
        tasksByDay[d].add(task);
      }
    }

    // Written in chunks of a fortnight rather than one enormous batch: a single
    // batch of 12,000 statements holds every companion in memory at once, and
    // on a low-end phone that is where this falls over.
    const chunkDays = 14;
    for (var dayOffset = 0; dayOffset < days; dayOffset += chunkDays) {
      final events = <EventsCompanion>[];
      final sessions = <FocusSessionsCompanion>[];

      for (var d = dayOffset; d < dayOffset + chunkDays && d < days; d++) {
        final date = TimeService.addDays(startDate, d);
        final written = _buildDay(
          date: date,
          dayOffset: d,
          projectIds: projectIds,
          availableTasks: tasksByDay[d],
          events: events,
          sessions: sessions,
        );
        sessionCount += written;
      }

      await _db.batch((batch) {
        batch.insertAll(_db.events, events);
        batch.insertAll(_db.focusSessions, sessions);
      });
      eventCount += events.length;
      onProgress?.call(0.35 + (dayOffset / days) * 0.45);
    }

    final habitResult = await _insertHabits(
      startDate: startDate,
      today: today,
      days: days,
      onProgress: (f) => onProgress?.call(0.80 + f * 0.20),
    );
    eventCount += habitResult.events;

    onProgress?.call(1.0);
    stopwatch.stop();

    return SeedReport(
      days: days,
      events: eventCount,
      sessions: sessionCount,
      tasks: taskCount,
      projects: projectIds.length,
      habits: habitResult.habits,
      habitEntries: habitResult.entries,
      elapsedMs: stopwatch.elapsedMilliseconds,
    );
  }

  /// Seeds notification and digest settings per POLISH §11 / §10.4.
  Future<void> _seedSettings() async {
    final settingsRepo = SettingsRepository(db: _db);
    await settingsRepo.setBool('reminders_enabled', true);
    await settingsRepo.setBool('digest_enabled', true);
    await settingsRepo.set('digest_times_min', [540]); // 09:00
    await settingsRepo.setBool('habit_digest_enabled', true);
    await settingsRepo.setInt('habit_digest_time_min', 1200); // 20:00
  }

  Future<List<String>> _insertProjects() async {
    final now = _time.nowUtcMs();
    final ids = <String>[];
    final rows = <ProjectsCompanion>[];
    for (var i = 0; i < _projectNames.length; i++) {
      final id = newId();
      ids.add(id);
      rows.add(ProjectsCompanion.insert(
        id: id,
        name: _projectNames[i],
        colorIndex: Value(i),
        updatedAt: now,
        deviceId: _deviceId,
      ));
    }
    await _db.batch((batch) => batch.insertAll(_db.projects, rows));
    return ids;
  }

  /// Builds one day's sessions and their events. Returns the session count.
  int _buildDay({
    required String date,
    required int dayOffset,
    required List<String> projectIds,
    required List<_SeededTaskInfo> availableTasks,
    required List<EventsCompanion> events,
    required List<FocusSessionsCompanion> sessions,
  }) {
    // Roughly one day in eight with nothing at all — illness, travel, a week
    // off. §4.5 depends on these being genuinely absent rather than zero, and
    // §4.13 needs gaps or the heatmap is a solid block.
    if (_rng.nextDouble() < 0.12) return 0;

    final weekday = TimeService.parseLocalDate(date).weekday;
    final isWeekend =
        weekday == DateTime.saturday || weekday == DateTime.sunday;

    final count = isWeekend
        ? _rng.nextInt(3) // 0–2
        : 2 + _rng.nextInt(4); // 2–5
    if (count == 0) return 0;

    var written = 0;
    for (var i = 0; i < count; i++) {
      final hour = _pickHour(isWeekend: isWeekend, index: i);
      final minute = _rng.nextInt(60);
      _buildSession(
        date: date,
        dayOffset: dayOffset,
        hour: hour,
        minute: minute,
        projectIds: projectIds,
        availableTasks: availableTasks,
        events: events,
        sessions: sessions,
      );
      written++;
    }
    return written;
  }

  /// A working shape rather than a flat distribution: a morning block, an
  /// afternoon one, and a thinner evening tail. §4.4 has nothing to find in
  /// uniform noise, and a peak-window chart tested against uniform noise tells
  /// you nothing about whether it works.
  int _pickHour({required bool isWeekend, required int index}) {
    final r = _rng.nextDouble();
    if (isWeekend) {
      if (r < 0.5) return 10 + _rng.nextInt(3); // 10–12
      if (r < 0.8) return 15 + _rng.nextInt(3); // 15–17
      return 20 + _rng.nextInt(2); // 20–21
    }
    if (index == 0 || r < 0.45) return 8 + _rng.nextInt(3); // 8–10, the peak
    if (r < 0.8) return 14 + _rng.nextInt(3); // 14–16
    return 20 + _rng.nextInt(3); // 20–22
  }

  void _buildSession({
    required String date,
    required int dayOffset,
    required int hour,
    required int minute,
    required List<String> projectIds,
    required List<_SeededTaskInfo> availableTasks,
    required List<EventsCompanion> events,
    required List<FocusSessionsCompanion> sessions,
  }) {
    final parsed = TimeService.parseLocalDate(date);
    // The logical date is the anchor, so an hour before the 04:00 day start
    // belongs to the following calendar day. Nothing here generates those, but
    // building the instant from the date's own fields keeps it honest.
    final startedAt = _instantFor(parsed, hour, minute);

    // The offset in force at that instant, on this device. For a Canadian
    // device this puts a real DST change inside the history; for an Indian one
    // it is a constant +330. Either way it is what SPEC §2.3 wants stored.
    final tzOffsetMin = _time.currentTzOffsetMin(startedAt);
    final tzId = _time.currentTzId();
    final localDate = _time.computeLocalDate(startedAt);

    final sessionId = newId();

    // Link ~20% of sessions to a real active task, denormalizing its project ID
    final _SeededTaskInfo? attachedTask;
    final String? taskId;
    final String? projectId;

    if (availableTasks.isNotEmpty && _rng.nextDouble() < 0.20) {
      attachedTask = availableTasks[_rng.nextInt(availableTasks.length)];
      taskId = attachedTask.id;
      projectId = attachedTask.projectId;
    } else {
      attachedTask = null;
      taskId = null;
      projectId = _rng.nextDouble() < 0.25
          ? null // §4.8's Unassigned bucket, which must never be empty in testing
          : projectIds[_rng.nextInt(projectIds.length)];
    }

    // Roughly one session in twelve is open-ended (SPEC §3.1 flow mode), which
    // has no planned duration at all. Worth generating: a planned_duration_s of
    // 0 is exactly the value that breaks a naive progress calculation.
    final isFlow = _rng.nextDouble() < 0.08;
    final plannedS =
        isFlow ? 0 : const [1500, 1500, 1500, 3000, 900][_rng.nextInt(5)];
    final abandoned = !isFlow && _rng.nextDouble() < 0.15;
    final actualS = isFlow
        ? 1800 + _rng.nextInt(5400) // 30-120 minutes
        : (abandoned ? 120 + _rng.nextInt(plannedS - 120) : plannedS);

    // Wall-clock span exceeds focused time when a session was paused — that is
    // the gap §4.4 scales across, so some sessions need to have one.
    final pausedS = _rng.nextDouble() < 0.2 ? 60 + _rng.nextInt(600) : 0;
    final endedAt = startedAt + (actualS + pausedS) * 1000;

    final internal = _interruptions(hour, internal: true);
    final external = _interruptions(hour, internal: false);
    final rating = abandoned || _rng.nextDouble() > 0.6
        ? null
        : _pickRating(hour);

    // Retroactively logged session (~8% of sessions)
    final isManual = _rng.nextDouble() < 0.08;
    // Occasional realistic session note (~15% of sessions)
    final note = _rng.nextDouble() < 0.15
        ? _sessionNotes[_rng.nextInt(_sessionNotes.length)]
        : null;

    final nowMs = _time.nowUtcMs();
    final int recordedAt;
    if (isManual) {
      final manualRecorded = endedAt + (10 + _rng.nextInt(110)) * 60000;
      recordedAt = manualRecorded > nowMs ? nowMs : manualRecorded;
    } else {
      recordedAt = startedAt;
    }

    sessions.add(FocusSessionsCompanion.insert(
      id: sessionId,
      mode: isFlow ? SessionModes.flow : SessionModes.pomodoro,
      plannedDurationS: Value(plannedS),
      actualDurationS: Value(actualS),
      startedAt: startedAt,
      endedAt: endedAt,
      localDate: localDate,
      tzOffsetMin: tzOffsetMin,
      tzId: Value(tzId),
      outcome: abandoned
          ? SessionOutcomes.abandoned
          : SessionOutcomes.completed,
      interruptionsInternal: Value(internal),
      interruptionsExternal: Value(external),
      focusRating: Value(rating),
      projectId: Value(projectId),
      taskId: Value(taskId),
      isManual: Value(isManual),
      note: Value(note),
      updatedAt: endedAt,
      deviceId: _deviceId,
    ));

    events.add(_event(
      type: EventTypes.sessionStarted,
      occurredAt: startedAt,
      recordedAt: recordedAt,
      localDate: localDate,
      tzId: tzId,
      tzOffsetMin: tzOffsetMin,
      subjectType: SubjectTypes.session,
      subjectId: sessionId,
      payload: {
        'mode': isFlow ? SessionModes.flow : SessionModes.pomodoro,
        'planned_duration_s': plannedS,
        if (projectId != null) 'project_id': projectId,
        if (taskId != null) 'task_id': taskId,
        if (isManual) 'is_manual': true,
      },
    ));

    for (var i = 0; i < internal + external; i++) {
      events.add(_event(
        type: EventTypes.sessionInterrupted,
        occurredAt: startedAt + (i + 1) * 60000,
        recordedAt: recordedAt,
        localDate: localDate,
        tzId: tzId,
        tzOffsetMin: tzOffsetMin,
        subjectType: SubjectTypes.session,
        subjectId: sessionId,
        payload: {
          'kind': i < internal
              ? InterruptionKinds.internalKind
              : InterruptionKinds.externalKind,
        },
      ));
    }

    events.add(_event(
      type: abandoned
          ? EventTypes.sessionAbandoned
          : EventTypes.sessionCompleted,
      occurredAt: endedAt,
      recordedAt: isManual ? (recordedAt > endedAt ? recordedAt : endedAt) : endedAt,
      localDate: localDate,
      tzId: tzId,
      tzOffsetMin: tzOffsetMin,
      subjectType: SubjectTypes.session,
      subjectId: sessionId,
      payload: abandoned
          ? {
              'actual_duration_s': actualS,
              'reason': AbandonReasons.userStopped,
              if (taskId != null) 'task_id': taskId,
              if (note != null) 'note': note,
            }
          : {
              'actual_duration_s': actualS,
              if (rating != null) 'focus_rating': rating,
              if (taskId != null) 'task_id': taskId,
              if (note != null) 'note': note,
            },
    ));

    if (!abandoned) {
      const breakS = 300;
      final breakOccurred = endedAt + 1000;
      events.add(_event(
        type: EventTypes.breakStarted,
        occurredAt: breakOccurred,
        recordedAt: isManual ? (recordedAt > breakOccurred ? recordedAt : breakOccurred) : breakOccurred,
        localDate: localDate,
        tzId: tzId,
        tzOffsetMin: tzOffsetMin,
        payload: {'duration_s': breakS},
      ));
    }
  }

  /// More external interruptions during office hours, more internal at night.
  /// §4.6 reports them separately because they have different remedies, and
  /// data where the two move together would never show that.
  int _interruptions(int hour, {required bool internal}) {
    final r = _rng.nextDouble();
    if (internal) {
      final likely = hour >= 20 || hour <= 7;
      if (r < (likely ? 0.45 : 0.2)) return 1 + _rng.nextInt(2);
      return 0;
    }
    final likely = hour >= 9 && hour <= 17;
    if (r < (likely ? 0.4 : 0.12)) return 1 + _rng.nextInt(2);
    return 0;
  }

  /// Mornings rate a little higher than late evenings. Gives §4.7 a mean
  /// around 3.6 and something for a future cross-metric observation to find.
  int _pickRating(int hour) {
    final base = hour <= 11 ? 4 : (hour <= 17 ? 3 : 3);
    final jitter = _rng.nextDouble();
    var value = jitter < 0.25 ? base - 1 : (jitter > 0.8 ? base + 1 : base);
    if (value < 1) value = 1;
    if (value > 5) value = 5;
    return value;
  }

  Future<_TaskSeedResult> _insertTasks({
    required int count,
    required String startDate,
    required int days,
    required List<String> projectIds,
    void Function(double fraction)? onProgress,
  }) async {
    var eventCount = 0;
    const chunk = 200;
    final seededTasks = <_SeededTaskInfo>[];

    for (var offset = 0; offset < count; offset += chunk) {
      final tasks = <TasksCompanion>[];
      final events = <EventsCompanion>[];

      for (var i = offset; i < offset + chunk && i < count; i++) {
        final createdDayOffset = _rng.nextInt(days);
        final createdDate = TimeService.addDays(startDate, createdDayOffset);
        final createdAt = _instantFor(
          TimeService.parseLocalDate(createdDate),
          9 + _rng.nextInt(10),
          _rng.nextInt(60),
        );
        final tzOffsetMin = _time.currentTzOffsetMin(createdAt);
        final tzId = _time.currentTzId();
        final createdLocalDate = _time.computeLocalDate(createdAt);

        final taskId = newId();
        final title = '${_taskVerbs[_rng.nextInt(_taskVerbs.length)]} '
            '${_taskNouns[_rng.nextInt(_taskNouns.length)]}';
        final projectId = _rng.nextDouble() < 0.35
            ? null
            : projectIds[_rng.nextInt(projectIds.length)];
        final priority = 1 + _rng.nextInt(4);

        // Most tasks get done, some in a day, some after weeks. The long tail
        // is what §4.11 (task age) and §4.12 (procrastination) need.
        final done = _rng.nextDouble() < 0.72;
        final lagDays = done
            ? (_rng.nextDouble() < 0.7 ? _rng.nextInt(3) : _rng.nextInt(40))
            : 0;
        final completedDayOffset = createdDayOffset + lagDays;
        final isDone = done && completedDayOffset < days;

        seededTasks.add(_SeededTaskInfo(
          id: taskId,
          projectId: projectId,
          createdDayOffset: createdDayOffset,
          completedDayOffset: isDone ? completedDayOffset : null,
        ));

        final completedAt = isDone
            ? _instantFor(
                TimeService.parseLocalDate(
                    TimeService.addDays(startDate, completedDayOffset)),
                10 + _rng.nextInt(10),
                _rng.nextInt(60),
              )
            : null;
        final completedLocalDate =
            completedAt == null ? null : _time.computeLocalDate(completedAt);

        // Due dates matter more than they look. The Today and Upcoming views
        // both filter on `due_at IS NOT NULL`, and the Inbox is defined as
        // `due_at IS NULL` — so a generator that never sets one puts every
        // task it makes in the Inbox and leaves the other two screens empty no
        // matter how much data exists. §4.14 ("every task due that day was
        // completed") is also uncomputable without them.
        final int? dueDayOffset;
        if (isDone) {
          // Finished work was usually due around when it got done, a couple of
          // days either side.
          dueDayOffset = completedDayOffset - 2 + _rng.nextInt(5);
        } else if (_rng.nextDouble() < 0.6) {
          final live = _rng.nextDouble();
          dueDayOffset = _rng.nextDouble() < 0.55
              // A live window around today: this is what gives Today and
              // Upcoming something to show, and what makes overdue items exist.
              // Today itself gets an explicit share — spread evenly across a
              // 29-day window it would land on today about three times in a
              // thousand, and "due today" is the case most worth looking at.
              ? (live < 0.15 ? days - 1 : days - 15 + _rng.nextInt(29))
              // Or a long-overdue backlog, which is what §4.11 (task age) and
              // §4.12 (procrastination) are there to surface.
              : createdDayOffset + _rng.nextInt(10);
        } else {
          // The rest are genuine inbox items — captured, never dated.
          dueDayOffset = null;
        }

        final dueAt = dueDayOffset == null
            ? null
            : _instantFor(
                TimeService.parseLocalDate(
                    TimeService.addDays(startDate, dueDayOffset)),
                9,
                0,
              );

        // Only datable tasks can be rescheduled, so the count always has real
        // moves behind it — see the event loop below.
        final rescheduleCount = !isDone && dueAt != null && _rng.nextDouble() < 0.18
            ? 1 + _rng.nextInt(4)
            : 0;

        tasks.add(TasksCompanion.insert(
          id: taskId,
          title: title,
          projectId: Value(projectId),
          priority: Value(priority),
          dueAt: Value(dueAt),
          dueIsAllDay: const Value(true),
          estimatePomodoros:
              Value(_rng.nextDouble() < 0.4 ? 1 + _rng.nextInt(5) : null),
          status: Value(isDone ? TaskStatuses.done : TaskStatuses.open),
          createdAt: createdAt,
          createdLocalDate: createdLocalDate,
          completedAt: Value(completedAt),
          completedLocalDate: Value(completedLocalDate),
          rescheduleCount: Value(rescheduleCount),
          sortOrder: Value(i.toDouble()),
          updatedAt: completedAt ?? createdAt,
          deviceId: _deviceId,
        ));

        events.add(_event(
          type: EventTypes.taskCreated,
          occurredAt: createdAt,
          localDate: createdLocalDate,
          tzId: tzId,
          tzOffsetMin: tzOffsetMin,
          subjectType: SubjectTypes.task,
          subjectId: taskId,
          payload: {
            'title': title,
            'priority': priority,
            if (projectId != null) 'project_id': projectId,
          },
        ));

        // SPEC §0: the module tables are a read model derived from events. A
        // reschedule_count sitting in `tasks` with nothing in the log behind it
        // is state the event log cannot reproduce — it would silently vanish
        // the first time anything rebuilt the tables from events, which import
        // (POLISH §9.1) will do. So the moves are written out.
        //
        // §4.12 counts only reschedules that push a task LATER, so the chain is
        // reconstructed backwards from the final due date and then emitted
        // forwards, every step moving later.
        if (rescheduleCount > 0 && dueAt != null) {
          final chain = <int>[dueAt];
          for (var r = 0; r < rescheduleCount; r++) {
            chain.insert(0, chain.first - (1 + _rng.nextInt(5)) * 86400000);
          }
          final nowMs = _time.nowUtcMs();
          for (var r = 0; r < rescheduleCount; r++) {
            var occurredAt = createdAt + (r + 1) * 86400000;
            if (occurredAt > nowMs) occurredAt = nowMs;
            events.add(_event(
              type: EventTypes.taskRescheduled,
              occurredAt: occurredAt,
              localDate: _time.computeLocalDate(occurredAt),
              tzId: tzId,
              tzOffsetMin: _time.currentTzOffsetMin(occurredAt),
              subjectType: SubjectTypes.task,
              subjectId: taskId,
              payload: {
                'from_due_at': chain[r],
                'to_due_at': chain[r + 1],
              },
            ));
          }
        }

        if (isDone && completedAt != null && completedLocalDate != null) {
          events.add(_event(
            type: EventTypes.taskCompleted,
            occurredAt: completedAt,
            localDate: completedLocalDate,
            tzId: tzId,
            tzOffsetMin: _time.currentTzOffsetMin(completedAt),
            subjectType: SubjectTypes.task,
            subjectId: taskId,
            payload: const {},
          ));
        }
      }

      await _db.batch((batch) {
        batch.insertAll(_db.tasks, tasks);
        batch.insertAll(_db.events, events);
      });
      eventCount += events.length;
      onProgress?.call(offset / count);
    }

    return _TaskSeedResult(events: eventCount, tasks: seededTasks);
  }

  static const _habitSpecs = [
    _HabitSpec(
      title: 'Read 20 pages',
      scheduleRule: 'FREQ=DAILY',
      iconName: 'book',
      colorIndex: 0,
      targetCount: 1,
      notes: 'Daily non-fiction or literature reading',
      completionRate: 0.84,
      skipRate: 0.04,
      preferredHour: 21,
    ),
    _HabitSpec(
      title: 'Drink water',
      scheduleRule: 'FREQ=DAILY',
      iconName: 'water',
      colorIndex: 1,
      targetCount: 8,
      unitLabel: 'glasses',
      notes: 'Stay hydrated through the workday',
      completionRate: 0.88,
      skipRate: 0.03,
      preferredHour: 18,
    ),
    _HabitSpec(
      title: 'Morning workout',
      scheduleRule: 'FREQ=WEEKLY;BYDAY=MO,WE,FR',
      iconName: 'fitness',
      colorIndex: 2,
      targetCount: 1,
      notes: 'Gym or calisthenics routine',
      completionRate: 0.82,
      skipRate: 0.06,
      preferredHour: 7,
    ),
    _HabitSpec(
      title: 'Meditation',
      scheduleRule: 'FREQ=DAILY',
      iconName: 'meditate',
      colorIndex: 3,
      targetCount: 1,
      notes: '10 minutes mindfulness and breathwork',
      completionRate: 0.80,
      skipRate: 0.05,
      preferredHour: 8,
    ),
    _HabitSpec(
      title: 'Evening stretch',
      scheduleRule: 'FREQ=WEEKLY;BYDAY=TU,TH,SA',
      iconName: 'walk',
      colorIndex: 4,
      targetCount: 1,
      notes: 'Mobility and posture work',
      completionRate: 0.85,
      skipRate: 0.04,
      preferredHour: 20,
    ),
    _HabitSpec(
      title: 'Cold shower',
      scheduleRule: 'FREQ=DAILY',
      iconName: 'check',
      colorIndex: 5,
      targetCount: 1,
      isArchived: true,
      notes: 'Summer challenge',
      completionRate: 0.72,
      skipRate: 0.08,
      preferredHour: 7,
    ),
  ];

  static const _habitNotes = [
    'Felt great today and stayed focused.',
    'Quick session between meetings.',
    'Morning routine went smoothly.',
    'Tough start but glad I got it done.',
    'Solid session, felt strong.',
    'Read an extra chapter today.',
  ];

  Future<_HabitSeedResult> _insertHabits({
    required String startDate,
    required String today,
    required int days,
    void Function(double fraction)? onProgress,
  }) async {
    var habitCount = 0;
    var entryCount = 0;
    var eventCount = 0;

    final habitRows = <HabitsCompanion>[];
    final entryRows = <HabitEntriesCompanion>[];
    final eventRows = <EventsCompanion>[];

    final createdInstant = _instantFor(
      TimeService.parseLocalDate(startDate),
      8,
      0,
    );
    final tzOffsetMin = _time.currentTzOffsetMin(createdInstant);
    final tzId = _time.currentTzId();

    for (var i = 0; i < _habitSpecs.length; i++) {
      final spec = _habitSpecs[i];
      final habitId = newId();
      habitCount++;

      // If archived, archive roughly 85% into the seeded span so there is
      // plenty of active history before it was archived.
      final String? archivedLocalDate;
      final int? archivedAt;
      if (spec.isArchived) {
        final archivedOffset = (days * 0.85).round();
        archivedLocalDate = TimeService.addDays(startDate, archivedOffset);
        archivedAt = _instantFor(
          TimeService.parseLocalDate(archivedLocalDate),
          18,
          0,
        );
      } else {
        archivedLocalDate = null;
        archivedAt = null;
      }

      habitRows.add(HabitsCompanion.insert(
        id: habitId,
        title: spec.title,
        notes: Value(spec.notes),
        colorIndex: Value(spec.colorIndex),
        iconName: Value(spec.iconName),
        scheduleRule: spec.scheduleRule,
        anchorDate: startDate,
        targetCount: Value(spec.targetCount),
        unitLabel: Value(spec.unitLabel),
        skipAllowancePerMonth: Value(spec.skipAllowancePerMonth),
        status: Value(
          spec.isArchived ? HabitStatuses.archived : HabitStatuses.active,
        ),
        sortOrder: Value(i.toDouble()),
        createdAt: createdInstant,
        createdLocalDate: startDate,
        archivedAt: Value(archivedAt),
        updatedAt: archivedAt ?? createdInstant,
        deviceId: _deviceId,
      ));

      eventRows.add(_event(
        type: EventTypes.habitCreated,
        occurredAt: createdInstant,
        localDate: startDate,
        tzId: tzId,
        tzOffsetMin: tzOffsetMin,
        subjectType: SubjectTypes.habit,
        subjectId: habitId,
        payload: {
          'title': spec.title,
          'schedule_rule': spec.scheduleRule,
          'anchor_date': startDate,
          if (spec.notes != null) 'notes': spec.notes,
          'color_index': spec.colorIndex,
          'icon_name': spec.iconName,
          'target_count': spec.targetCount,
          if (spec.unitLabel != null) 'unit_label': spec.unitLabel,
          'skip_allowance_per_month': spec.skipAllowancePerMonth,
          'sort_order': i.toDouble(),
        },
      ));

      if (spec.isArchived && archivedAt != null && archivedLocalDate != null) {
        eventRows.add(_event(
          type: EventTypes.habitArchived,
          occurredAt: archivedAt,
          localDate: archivedLocalDate,
          tzId: tzId,
          tzOffsetMin: _time.currentTzOffsetMin(archivedAt),
          subjectType: SubjectTypes.habit,
          subjectId: habitId,
          payload: const {},
        ));
      }

      final rule = RecurrenceRule.parse(spec.scheduleRule);
      final lastDate = spec.isArchived ? archivedLocalDate! : today;
      final scheduledDates = HabitSchedule.scheduledBetween(
        rule: rule,
        anchorDate: startDate,
        start: startDate,
        end: lastDate,
      );

      final isMilestoneHabit = spec.title == 'Meditation';
      final milestoneThreshold = days >= 35 ? 30 : 7;
      final skipsThisMonth = <String, int>{};

      for (final date in scheduledDates) {
        final month = date.substring(0, 7);
        final daysFromToday = TimeService.daysBetween(date, today);

        var isCompleted = false;
        var isSkipped = false;
        var checkCount = 0;

        if (isMilestoneHabit) {
          // Guaranteed milestone streak (e.g. exactly 30 days) ending today.
          if (daysFromToday == 0) {
            // Today: completed to reach the milestone threshold
            isCompleted = true;
            checkCount = spec.targetCount;
          } else if (daysFromToday == 2 || daysFromToday == 4) {
            // Days 2 & 4: excused rest days (freeze used) in the current month.
            // These protect & extend the streak, while allowing the momentum strip
            // to show non-completed days.
            isSkipped = true;
            checkCount = 0;
          } else if (daysFromToday > 0 && daysFromToday < milestoneThreshold) {
            // All other days within the milestone window: completed
            isCompleted = true;
            checkCount = spec.targetCount;
          } else if (daysFromToday == milestoneThreshold) {
            // Milestone miss day: exactly breaks the streak at milestoneThreshold.
            // Absence is miss: no entry written.
            continue;
          } else {
            // Historical baseline before the milestone streak
            final r = _rng.nextDouble();
            if (r < spec.completionRate) {
              isCompleted = true;
              checkCount = spec.targetCount;
            } else if (r < spec.completionRate + spec.skipRate) {
              isSkipped = true;
              checkCount = 0;
            } else {
              continue;
            }
          }
        } else if (daysFromToday == 0) {
          // Today for all other habits:
          // "Drink water" gets a genuine partial progress state (3 of 8 glasses)
          // Other habits remain pending (0 of target) so Today shows partial cairn stones
          if (spec.targetCount > 1) {
            checkCount = 3;
            isCompleted = false;
            isSkipped = false;
          } else {
            // Pending for today: absence is pending
            continue;
          }
        } else if (daysFromToday == 2 || daysFromToday == 4) {
          // Days 2 and 4 ago: forced non-completion across all habits.
          // Combined with Meditation's rest days, this guarantees at least 1-2 days
          // in the current week show as NOT completed on Today's momentum strip.
          if (spec.targetCount > 1 && _rng.nextDouble() < 0.60) {
            // Count habit gets partial count (e.g. 2-7 glasses), which is still a miss
            checkCount = 1 + _rng.nextInt(spec.targetCount - 1);
          } else {
            // Miss: no row written
            continue;
          }
        } else if (daysFromToday <= 14) {
          // Recent 2 weeks: natural baseline (~78% completion, ~6% skip, ~16% miss)
          // instead of the old artificial 95% override, keeping Week/30D Stats realistic.
          final r = _rng.nextDouble();
          final recentRate = (spec.completionRate * 0.92).clamp(0.74, 0.82);
          if (r < recentRate) {
            isCompleted = true;
            checkCount = spec.targetCount;
          } else if (r < recentRate + spec.skipRate) {
            isSkipped = true;
            checkCount = 0;
          } else {
            // Missed! Count habits get partial progress 60% of the time
            if (spec.targetCount > 1 && _rng.nextDouble() < 0.60) {
              checkCount = 1 + _rng.nextInt(spec.targetCount - 1);
            } else {
              continue;
            }
          }
        } else {
          // Historical span (> 14 days ago)
          final r = _rng.nextDouble();
          if (r < spec.completionRate) {
            isCompleted = true;
            checkCount = spec.targetCount;
          } else if (r < spec.completionRate + spec.skipRate) {
            isSkipped = true;
            checkCount = 0;
          } else {
            // Missed! For count habits (water), 60% partial count
            if (spec.targetCount > 1 && _rng.nextDouble() < 0.60) {
              checkCount = 1 + _rng.nextInt(spec.targetCount - 1);
            } else {
              // Absence is miss (SPEC §10.1): no row written
              continue;
            }
          }
        }

        final parsedDate = TimeService.parseLocalDate(date);
        final minute = _rng.nextInt(60);
        final checkInstant = _instantFor(
          parsedDate,
          spec.preferredHour,
          minute,
        );
        final entryTzOffset = _time.currentTzOffsetMin(checkInstant);
        final entryTzId = _time.currentTzId();

        final note = (isCompleted && _rng.nextDouble() < 0.03)
            ? _habitNotes[_rng.nextInt(_habitNotes.length)]
            : null;

        final entryId = newId();
        entryRows.add(HabitEntriesCompanion.insert(
          id: entryId,
          habitId: habitId,
          localDate: date,
          checkCount: Value(checkCount),
          skipped: Value(isSkipped),
          note: Value(note),
          lastCheckedAt: Value(checkCount > 0 ? checkInstant : null),
          tzOffsetMin: entryTzOffset,
          createdAt: checkInstant,
          updatedAt: checkInstant,
          deviceId: _deviceId,
        ));
        entryCount++;

        if (isSkipped) {
          eventRows.add(_event(
            type: EventTypes.habitSkipped,
            occurredAt: checkInstant,
            localDate: date,
            tzId: entryTzId,
            tzOffsetMin: entryTzOffset,
            subjectType: SubjectTypes.habit,
            subjectId: habitId,
            payload: {'skipped': true},
          ));

          final used = skipsThisMonth[month] ?? 0;
          if (used < spec.skipAllowancePerMonth) {
            skipsThisMonth[month] = used + 1;
            eventRows.add(_event(
              type: EventTypes.habitFreezeUsed,
              occurredAt: checkInstant,
              localDate: date,
              tzId: entryTzId,
              tzOffsetMin: entryTzOffset,
              subjectType: SubjectTypes.habit,
              subjectId: habitId,
              payload: {'month': month},
            ));
          }
        } else if (checkCount > 0) {
          eventRows.add(_event(
            type: EventTypes.habitChecked,
            occurredAt: checkInstant,
            localDate: date,
            tzId: entryTzId,
            tzOffsetMin: entryTzOffset,
            subjectType: SubjectTypes.habit,
            subjectId: habitId,
            payload: {'count_after': checkCount},
          ));
        }

        if (note != null) {
          eventRows.add(_event(
            type: EventTypes.habitNoteSet,
            occurredAt: checkInstant,
            localDate: date,
            tzId: entryTzId,
            tzOffsetMin: entryTzOffset,
            subjectType: SubjectTypes.habit,
            subjectId: habitId,
            payload: {'note': note},
          ));
        }

        // Batch flush if rows are accumulating
        if (eventRows.length >= 500) {
          await _db.batch((batch) {
            if (habitRows.isNotEmpty) {
              batch.insertAll(_db.habits, habitRows);
              habitRows.clear();
            }
            if (entryRows.isNotEmpty) {
              batch.insertAll(_db.habitEntries, entryRows);
              entryRows.clear();
            }
            batch.insertAll(_db.events, eventRows);
            eventCount += eventRows.length;
            eventRows.clear();
          });
        }
      }

      onProgress?.call((i + 1) / _habitSpecs.length);
    }

    // Final flush of remaining rows
    if (habitRows.isNotEmpty || entryRows.isNotEmpty || eventRows.isNotEmpty) {
      await _db.batch((batch) {
        if (habitRows.isNotEmpty) {
          batch.insertAll(_db.habits, habitRows);
        }
        if (entryRows.isNotEmpty) {
          batch.insertAll(_db.habitEntries, entryRows);
        }
        if (eventRows.isNotEmpty) {
          batch.insertAll(_db.events, eventRows);
          eventCount += eventRows.length;
        }
      });
    }

    return _HabitSeedResult(
      habits: habitCount,
      entries: entryCount,
      events: eventCount,
    );
  }

  /// The UTC instant at which the local clock reads these fields on [date].
  ///
  /// Built by converting a naive local wall clock through the device's own
  /// offset at roughly that moment, then correcting once if the first guess
  /// landed on the wrong side of a DST change. Two passes is enough: offsets
  /// shift by an hour, and the second guess is computed from the offset that
  /// actually applies near the target.
  int _instantFor(DateTime date, int hour, int minute) {
    final naiveUtc = DateTime.utc(
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    ).millisecondsSinceEpoch;

    var guess = naiveUtc - _time.currentTzOffsetMin(naiveUtc) * 60000;
    final refined = naiveUtc - _time.currentTzOffsetMin(guess) * 60000;
    if (refined != guess) guess = refined;
    return guess;
  }

  EventsCompanion _event({
    required String type,
    required int occurredAt,
    required String localDate,
    required String tzId,
    required int tzOffsetMin,
    required Map<String, Object?> payload,
    String? subjectType,
    String? subjectId,
    int? recordedAt,
  }) {
    return EventsCompanion.insert(
      id: newId(),
      type: type,
      occurredAt: occurredAt,
      // Equal to occurredAt for real-time events; set later for retroactive/manual sessions.
      recordedAt: recordedAt ?? occurredAt,
      localDate: localDate,
      tzId: tzId,
      tzOffsetMin: tzOffsetMin,
      subjectType: Value(subjectType),
      subjectId: Value(subjectId),
      payload: jsonEncode(payload),
      deviceId: _deviceId,
    );
  }

  /// Deletes everything this generator writes, and everything else.
  ///
  /// Sits beside [generate] on purpose. A seeder without a one-tap way back is
  /// a seeder nobody dares run twice.
  ///
  /// `settings` is left alone so the device id, theme, daily goal, and
  /// reminder configurations survive — losing those makes the app look broken
  /// rather than empty.
  Future<void> wipe() async {
    await _db.transaction(() async {
      await _db.delete(_db.events).go();
      await _db.delete(_db.focusSessions).go();
      await _db.delete(_db.habitEntries).go();
      await _db.delete(_db.habitReminderTimes).go();
      await _db.delete(_db.habits).go();
      await _db.delete(_db.taskReminderOffsets).go();
      await _db.delete(_db.taskTags).go();
      await _db.delete(_db.tasks).go();
      await _db.delete(_db.tags).go();
      await _db.delete(_db.projects).go();
      await _db.delete(_db.timerStates).go();
    });
  }
}

class _TaskSeedResult {
  const _TaskSeedResult({
    required this.events,
    required this.tasks,
  });

  final int events;
  final List<_SeededTaskInfo> tasks;
}

class _SeededTaskInfo {
  const _SeededTaskInfo({
    required this.id,
    required this.projectId,
    required this.createdDayOffset,
    required this.completedDayOffset,
  });

  final String id;
  final String? projectId;
  final int createdDayOffset;
  final int? completedDayOffset;
}

/// What a [SeedData.generate] run produced.
class SeedReport {
  const SeedReport({
    required this.days,
    required this.events,
    required this.sessions,
    required this.tasks,
    required this.projects,
    required this.elapsedMs,
    this.habits = 0,
    this.habitEntries = 0,
  });

  final int days;
  final int events;
  final int sessions;
  final int tasks;
  final int projects;
  final int habits;
  final int habitEntries;
  final int elapsedMs;

  @override
  String toString() => '$events events, $sessions sessions, $tasks tasks, '
      '$projects projects, $habits habits ($habitEntries entries) across $days days in ${elapsedMs}ms';
}

class _HabitSpec {
  const _HabitSpec({
    required this.title,
    required this.scheduleRule,
    required this.iconName,
    required this.colorIndex,
    this.targetCount = 1,
    this.unitLabel,
    this.skipAllowancePerMonth = 2,
    this.notes,
    this.isArchived = false,
    this.completionRate = 0.85,
    this.skipRate = 0.05,
    this.preferredHour = 8,
  });

  final String title;
  final String scheduleRule;
  final String iconName;
  final int colorIndex;
  final int targetCount;
  final String? unitLabel;
  final int skipAllowancePerMonth;
  final String? notes;
  final bool isArchived;
  final double completionRate;
  final double skipRate;
  final int preferredHour;
}

class _HabitSeedResult {
  const _HabitSeedResult({
    required this.habits,
    required this.entries,
    required this.events,
  });

  final int habits;
  final int entries;
  final int events;
}
