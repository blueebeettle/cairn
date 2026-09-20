import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';

import '../../core/constants/event_types.dart';
import '../../core/ids.dart';
import '../../core/time/time_service.dart';
import '../database/app_database.dart';

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

    var eventCount = 0;
    var sessionCount = 0;

    // Written in chunks of a fortnight rather than one enormous batch: a single
    // batch of 12,000 statements holds every companion in memory at once, and
    // on a low-end phone that is where this falls over.
    const chunkDays = 14;
    for (var dayOffset = 0; dayOffset < days; dayOffset += chunkDays) {
      final events = <EventsCompanion>[];
      final sessions = <FocusSessionsCompanion>[];

      for (var d = dayOffset; d < dayOffset + chunkDays && d < days; d++) {
        final date = TimeService.addDays(startDate, d);
        final written = _buildDay(date, projectIds, events, sessions);
        sessionCount += written;
      }

      await _db.batch((batch) {
        batch.insertAll(_db.events, events);
        batch.insertAll(_db.focusSessions, sessions);
      });
      eventCount += events.length;
      onProgress?.call((dayOffset / days) * 0.8);
    }

    final taskEvents = await _insertTasks(
      count: taskCount,
      startDate: startDate,
      days: days,
      projectIds: projectIds,
      onProgress: (f) => onProgress?.call(0.8 + f * 0.2),
    );
    eventCount += taskEvents;

    onProgress?.call(1.0);
    stopwatch.stop();

    return SeedReport(
      days: days,
      events: eventCount,
      sessions: sessionCount,
      tasks: taskCount,
      projects: projectIds.length,
      elapsedMs: stopwatch.elapsedMilliseconds,
    );
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
  int _buildDay(
    String date,
    List<String> projectIds,
    List<EventsCompanion> events,
    List<FocusSessionsCompanion> sessions,
  ) {
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
      _buildSession(date, hour, minute, projectIds, events, sessions);
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

  void _buildSession(
    String date,
    int hour,
    int minute,
    List<String> projectIds,
    List<EventsCompanion> events,
    List<FocusSessionsCompanion> sessions,
  ) {
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
    final projectId = _rng.nextDouble() < 0.25
        ? null // §4.8's Unassigned bucket, which must never be empty in testing
        : projectIds[_rng.nextInt(projectIds.length)];

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
      updatedAt: endedAt,
      deviceId: _deviceId,
    ));

    events.add(_event(
      type: EventTypes.sessionStarted,
      occurredAt: startedAt,
      localDate: localDate,
      tzId: tzId,
      tzOffsetMin: tzOffsetMin,
      subjectType: SubjectTypes.session,
      subjectId: sessionId,
      payload: {
        'mode': isFlow ? SessionModes.flow : SessionModes.pomodoro,
        'planned_duration_s': plannedS,
        if (projectId != null) 'project_id': projectId,
      },
    ));

    for (var i = 0; i < internal + external; i++) {
      events.add(_event(
        type: EventTypes.sessionInterrupted,
        occurredAt: startedAt + (i + 1) * 60000,
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
      localDate: localDate,
      tzId: tzId,
      tzOffsetMin: tzOffsetMin,
      subjectType: SubjectTypes.session,
      subjectId: sessionId,
      payload: abandoned
          ? {
              'actual_duration_s': actualS,
              'reason': AbandonReasons.userStopped,
            }
          : {
              'actual_duration_s': actualS,
              if (rating != null) 'focus_rating': rating,
            },
    ));

    if (!abandoned) {
      const breakS = 300;
      events.add(_event(
        type: EventTypes.breakStarted,
        occurredAt: endedAt + 1000,
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

  Future<int> _insertTasks({
    required int count,
    required String startDate,
    required int days,
    required List<String> projectIds,
    void Function(double fraction)? onProgress,
  }) async {
    var eventCount = 0;
    const chunk = 200;

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

    return eventCount;
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
  }) {
    return EventsCompanion.insert(
      id: newId(),
      type: type,
      occurredAt: occurredAt,
      // Equal to occurredAt: this is not a manual entry (§6), it is a session
      // that was recorded as it happened.
      recordedAt: occurredAt,
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
  /// `settings` is left alone so the device id, theme and daily goal survive —
  /// losing those makes the app look broken rather than empty.
  Future<void> wipe() async {
    await _db.transaction(() async {
      await _db.delete(_db.events).go();
      await _db.delete(_db.focusSessions).go();
      await _db.delete(_db.taskTags).go();
      await _db.delete(_db.tasks).go();
      await _db.delete(_db.tags).go();
      await _db.delete(_db.projects).go();
      await _db.delete(_db.timerStates).go();
    });
  }
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
  });

  final int days;
  final int events;
  final int sessions;
  final int tasks;
  final int projects;
  final int elapsedMs;

  @override
  String toString() => '$events events, $sessions sessions, $tasks tasks, '
      '$projects projects across $days days in ${elapsedMs}ms';
}
