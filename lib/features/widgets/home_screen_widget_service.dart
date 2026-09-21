import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../../core/constants/event_types.dart';
import '../../core/time/time_service.dart';
import '../../data/database/app_database.dart' hide TimerState;
import '../../data/providers/database_provider.dart';
import '../../data/providers/habit_providers.dart';
import '../../data/repositories/events_repository.dart';
import '../../data/repositories/habits_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/tasks_repository.dart';
import '../../data/repositories/timer_repository.dart';
import '../timer/domain/timer_state.dart';
import '../timer/presentation/timer_controller.dart';
import '../timer/services/timer_foreground_service.dart';

class HomeScreenWidgetService {
  HomeScreenWidgetService({
    @visibleForTesting this.isPlatformSupported = true,
  });

  final bool isPlatformSupported;

  static const habitsWidgetName = 'CairnHabitsWidgetProvider';
  static const todayWidgetName = 'CairnTodayWidgetProvider';
  static const tasksWidgetName = 'CairnTasksWidgetProvider';
  static const timerWidgetName = 'CairnTimerWidgetProvider';

  /// Number of habit rows the Habits widget layout defines. The provider
  /// shows as many of these as the launcher's height allows.
  static const habitsWidgetRowCount = 8;

  /// Number of task rows the Tasks widget layout defines.
  static const tasksWidgetRowCount = 5;

  bool get canUpdate =>
      isPlatformSupported &&
      !kIsWeb &&
      (Platform.isAndroid || Platform.isIOS);

  /// Formats date display for the widget header, e.g. "Sun, Sep 20".
  static String formatDate(String localDate) {
    try {
      final parts = localDate.split('-');
      if (parts.length != 3) return localDate;
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);
      final dt = DateTime.utc(year, month, day);

      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];

      final weekday = weekdays[dt.weekday - 1];
      final monthName = months[month - 1];
      return '$weekday, $monthName $day';
    } catch (_) {
      return localDate;
    }
  }

  /// Parses a deep-link URI from widget click and returns the target [NavTabs] index,
  /// or null if unknown.
  static int? parseWidgetUri(Uri uri) {
    if (uri.scheme != 'cairn') return null;
    final combined = '${uri.host}${uri.path}'.toLowerCase();
    if (combined.contains('habit')) return NavTabs.habits;
    if (combined.contains('timer')) return NavTabs.timer;
    if (combined.contains('task')) return NavTabs.tasks;
    if (combined.contains('stat')) return NavTabs.stats;
    if (combined.contains('today')) return NavTabs.today;
    return NavTabs.today;
  }

  /// Pushes updated habits data to the Cairn Habits widget.
  Future<void> updateHabitsWidget({
    required List<HabitSnapshot> habits,
    required String todayLocalDate,
  }) async {
    if (!canUpdate) return;

    try {
      final scheduledHabits = habits.where((h) => h.isScheduledToday).toList();
      var doneCount = 0;
      for (final h in scheduledHabits) {
        if (h.isDoneToday) {
          doneCount++;
        }
      }

      final totalCount = scheduledHabits.length;
      final percent = totalCount > 0 ? (doneCount * 100 ~/ totalCount) : 0;
      final dateStr = formatDate(todayLocalDate);
      final summaryStr = totalCount > 0
          ? '$doneCount / $totalCount Done'
          : 'No habits today';

      // Sort: pending habits first so user sees what is left to do, then done
      final sorted = List<HabitSnapshot>.from(scheduledHabits)
        ..sort((a, b) {
          if (a.isDoneToday != b.isDoneToday) {
            return a.isDoneToday ? 1 : -1;
          }
          return a.habit.sortOrder.compareTo(b.habit.sortOrder);
        });

      await HomeWidget.saveWidgetData<String>('habits_date', dateStr);
      await HomeWidget.saveWidgetData<String>('habits_summary', summaryStr);
      await HomeWidget.saveWidgetData<int>('habits_percent', percent);
      await HomeWidget.saveWidgetData<int>('habits_total_count', totalCount);

      // JSON array for the scrollable ListView factory
      final habitsJsonList = sorted.map((h) {
        final streak = h.streaks.current;
        final streakStr = streak > 0 ? '🔥 $streak' : '';
        return {
          'id': h.habit.id,
          'title': h.habit.title,
          'done': h.isDoneToday,
          'streak': streakStr,
          'count': h.countToday,
          'target': h.habit.targetCount > 0 ? h.habit.targetCount : 1,
        };
      }).toList();
      await HomeWidget.saveWidgetData<String>(
        'habits_json',
        jsonEncode(habitsJsonList),
      );

      for (var i = 0; i < habitsWidgetRowCount; i++) {
        if (i < sorted.length) {
          final h = sorted[i];
          final streak = h.streaks.current;
          final streakStr = streak > 0 ? '🔥 $streak' : '';

          await HomeWidget.saveWidgetData<String>(
            'habit_${i + 1}_id',
            h.habit.id,
          );
          await HomeWidget.saveWidgetData<String>(
            'habit_${i + 1}_title',
            h.habit.title,
          );
          await HomeWidget.saveWidgetData<bool>(
            'habit_${i + 1}_done',
            h.isDoneToday,
          );
          await HomeWidget.saveWidgetData<String>(
            'habit_${i + 1}_streak',
            streakStr,
          );
          await HomeWidget.saveWidgetData<int>(
            'habit_${i + 1}_count',
            h.countToday,
          );
          await HomeWidget.saveWidgetData<int>(
            'habit_${i + 1}_target',
            h.habit.targetCount > 0 ? h.habit.targetCount : 1,
          );
        } else {
          await HomeWidget.saveWidgetData<String?>(
            'habit_${i + 1}_id',
            null,
          );
          await HomeWidget.saveWidgetData<String?>(
            'habit_${i + 1}_title',
            null,
          );
          await HomeWidget.saveWidgetData<bool>(
            'habit_${i + 1}_done',
            false,
          );
          await HomeWidget.saveWidgetData<String>(
            'habit_${i + 1}_streak',
            '',
          );
          await HomeWidget.saveWidgetData<int>('habit_${i + 1}_count', 0);
          await HomeWidget.saveWidgetData<int>('habit_${i + 1}_target', 1);
        }
      }

      await HomeWidget.updateWidget(
        name: habitsWidgetName,
        androidName: habitsWidgetName,
      );
    } catch (e, st) {
      debugPrint('HomeScreenWidgetService: failed to update habits widget: $e\n$st');
    }
  }

  /// Pushes updated metrics to the Cairn Today Glance widget.
  Future<void> updateTodayWidget({
    required int focusMinutesToday,
    required int habitsDone,
    required int habitsTotal,
    required int tasksDueCount,
  }) async {
    if (!canUpdate) return;

    try {
      final focusStr = '${focusMinutesToday}m';
      final habitsStr = '$habitsDone / $habitsTotal';
      final tasksStr = '$tasksDueCount';

      await HomeWidget.saveWidgetData<String>('today_focus_mins', focusStr);
      await HomeWidget.saveWidgetData<String>('today_habits_summary', habitsStr);
      await HomeWidget.saveWidgetData<String>('today_tasks_due', tasksStr);

      await HomeWidget.updateWidget(
        name: todayWidgetName,
        androidName: todayWidgetName,
      );
    } catch (e, st) {
      debugPrint('HomeScreenWidgetService: failed to update today widget: $e\n$st');
    }
  }

  /// Pushes today's open tasks to the Cairn Tasks widget, highest priority first.
  Future<void> updateTasksWidget({
    required List<TaskWithDetails> todayTasks,
  }) async {
    if (!canUpdate) return;

    try {
      final openTasks = sortTasksForWidget(todayTasks);

      final totalCount = openTasks.length;
      await HomeWidget.saveWidgetData<int>('tasks_total_count', totalCount);
      await HomeWidget.saveWidgetData<String>(
        'tasks_summary',
        totalCount > 0 ? '$totalCount due today' : 'All clear',
      );

      // JSON array for the scrollable ListView factory
      final tasksJsonList = openTasks.map((t) {
        return {
          'id': t.id,
          'title': t.title,
          'priority': t.priority,
        };
      }).toList();
      await HomeWidget.saveWidgetData<String>(
        'tasks_json',
        jsonEncode(tasksJsonList),
      );

      for (var i = 0; i < tasksWidgetRowCount; i++) {
        if (i < openTasks.length) {
          final t = openTasks[i];
          await HomeWidget.saveWidgetData<String>('task_${i + 1}_id', t.id);
          await HomeWidget.saveWidgetData<String>('task_${i + 1}_title', t.title);
          await HomeWidget.saveWidgetData<int>(
            'task_${i + 1}_priority',
            t.priority,
          );
        } else {
          await HomeWidget.saveWidgetData<String?>('task_${i + 1}_id', null);
          await HomeWidget.saveWidgetData<String?>('task_${i + 1}_title', null);
          await HomeWidget.saveWidgetData<int>('task_${i + 1}_priority', 4);
        }
      }

      await HomeWidget.updateWidget(
        name: tasksWidgetName,
        androidName: tasksWidgetName,
      );
    } catch (e, st) {
      debugPrint('HomeScreenWidgetService: failed to update tasks widget: $e\n$st');
    }
  }

  /// Open tasks only, ordered by priority (1 = highest) then manual sort order.
  @visibleForTesting
  static List<TaskWithDetails> sortTasksForWidget(
    List<TaskWithDetails> todayTasks,
  ) {
    return todayTasks.where((t) => t.isOpen).toList()
      ..sort((a, b) {
        final byPriority = a.priority.compareTo(b.priority);
        if (byPriority != 0) return byPriority;
        return a.task.sortOrder.compareTo(b.task.sortOrder);
      });
  }

  /// Pushes updated focus-timer status to the Cairn Timer widget.
  Future<void> updateTimerWidget(TimerState timerState, {int? nowUtcMs}) async {
    if (!canUpdate) return;

    try {
      final now = nowUtcMs ?? DateTime.now().toUtc().millisecondsSinceEpoch;
      final (status, timeText) = describeTimerForWidget(timerState, now);

      await HomeWidget.saveWidgetData<String>('timer_status', status);
      await HomeWidget.saveWidgetData<String>('timer_time_text', timeText);

      // A widget only redraws when something pushes it, and we deliberately do
      // not push on every tick. So hand the widget an absolute instant plus a
      // direction and let its Chronometer run the clock itself — free, exact,
      // and it keeps ticking while the app is dead.
      // Write null rather than a 0 sentinel when nothing is ticking: the
      // plugin picks putInt/putLong from the value's magnitude, so a 0 here
      // would land as an Int and make the widget's getLong throw.
      final anchor = timerAnchorUtcMs(timerState, now);
      await HomeWidget.saveWidgetData<int?>('timer_anchor_utc_ms', anchor);
      await HomeWidget.saveWidgetData<bool>(
        'timer_counts_down',
        !timerState.isFlow,
      );
      await HomeWidget.saveWidgetData<bool>('timer_ticking', anchor != null);

      await HomeWidget.updateWidget(
        name: timerWidgetName,
        androidName: timerWidgetName,
      );
    } catch (e, st) {
      debugPrint('HomeScreenWidgetService: failed to update timer widget: $e\n$st');
    }
  }

  /// Reduces a [TimerState] to the (status, mm:ss) pair the widget renders.
  ///
  /// Flow sessions count up (there is no planned end), everything else counts
  /// down; an idle widget previews the length the next session would run for.
  @visibleForTesting
  static (String, String) describeTimerForWidget(TimerState state, int nowUtcMs) {
    if (state.isRunning || state.isPaused) {
      final seconds = state.isFlow
          ? state.computeElapsedSeconds(nowUtcMs)
          : state.computeRemainingSeconds(nowUtcMs);
      return (state.isPaused ? 'paused' : 'running', formatMmSs(seconds));
    }
    if (state.isBreakRunning) {
      return ('break', formatMmSs(state.computeBreakRemainingSeconds(nowUtcMs)));
    }
    final planned = state.plannedDurationS > 0 ? state.plannedDurationS : 1500;
    return ('idle', formatMmSs(planned));
  }

  /// The instant a self-running widget clock should be anchored to, or null
  /// when nothing is ticking (idle, paused, or finished).
  ///
  /// Counting down, that is the moment the timer reaches zero; counting up
  /// (Flow), the moment it started.
  @visibleForTesting
  static int? timerAnchorUtcMs(TimerState state, int nowUtcMs) {
    if (state.isPaused) return null;
    if (state.isBreakRunning) {
      final startedAt = state.breakStartedAtUtc;
      if (startedAt == null) return null;
      return startedAt + state.breakDurationS * 1000;
    }
    if (!state.isRunning) return null;
    final startedAt = state.startedAtUtc;
    if (startedAt == null) return null;
    if (state.isFlow) {
      // Count up from the start, discounting time spent paused.
      return startedAt + state.pausedAccumulatedS * 1000;
    }
    return startedAt +
        (state.plannedDurationS + state.pausedAccumulatedS) * 1000;
  }

  /// Formats whole seconds as mm:ss, clamping negatives to zero.
  static String formatMmSs(int seconds) {
    final s = seconds < 0 ? 0 : seconds;
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final r = (s % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }

  Future<void>? _inFlightSync;
  bool _syncAgain = false;

  /// Syncs current app state to widgets from Riverpod WidgetRef.
  ///
  /// Several providers can fire their listeners within the same frame, and one
  /// full sync is ~20 awaited platform writes. Left unserialised those calls
  /// interleave and the *stalest* one finishes last, so the widgets end up
  /// showing whatever the earliest invocation happened to read — which at
  /// startup is an empty list. Run one pass at a time and coalesce everything
  /// that arrives meanwhile into a single trailing pass that re-reads fresh.
  Future<void> syncAllWidgets(WidgetRef ref) {
    if (!canUpdate) return Future<void>.value();
    final inFlight = _inFlightSync;
    if (inFlight != null) {
      _syncAgain = true;
      return inFlight;
    }
    final future = _syncUntilSettled(ref);
    _inFlightSync = future;
    return future;
  }

  Future<void> _syncUntilSettled(WidgetRef ref) async {
    try {
      do {
        _syncAgain = false;
        await _syncOnce(ref);
      } while (_syncAgain);
    } finally {
      _inFlightSync = null;
    }
  }

  Future<void> _syncOnce(WidgetRef ref) async {
    try {
      final timeService = ref.read(timeServiceProvider);
      final today = timeService.todayLocalDate();
      final habits = ref.read(habitSnapshotsProvider).value ?? const [];
      final focusStats = ref.read(focusStatsStreamProvider).value;
      final tasks = ref.read(todayTasksStreamProvider(today)).value ?? const [];

      await updateHabitsWidget(
        habits: habits,
        todayLocalDate: today,
      );

      final scheduledHabits = habits.where((h) => h.isScheduledToday).toList();
      final habitsDone = scheduledHabits.where((h) => h.isDoneToday).length;
      final openTasksDue = tasks.where((t) => t.task.status != TaskStatuses.done).length;
      final focusMins = focusStats?.focusMinutesToday ?? 0;

      await updateTodayWidget(
        focusMinutesToday: focusMins,
        habitsDone: habitsDone,
        habitsTotal: scheduledHabits.length,
        tasksDueCount: openTasksDue,
      );

      await updateTasksWidget(todayTasks: tasks);

      await updateTimerWidget(
        ref.read(timerControllerProvider),
        nowUtcMs: timeService.nowUtcMs(),
      );
    } catch (e, st) {
      debugPrint('HomeScreenWidgetService: failed to sync all widgets: $e\n$st');
    }
  }
}

final homeScreenWidgetServiceProvider = Provider<HomeScreenWidgetService>((ref) {
  return HomeScreenWidgetService();
});

/// Top-level callback invoked by Android/iOS background receiver when a home widget
/// action is triggered (e.g. checking off a habit, completing a task, or
/// driving the focus timer).
///
/// This runs in its own background isolate with no access to the app's
/// Riverpod container, so every handler builds throwaway repositories over a
/// fresh [AppDatabase] and writes to the same tables the in-app controllers
/// write to. The database is the shared source of truth; the app re-reads it
/// on resume (see `TimerController.reconcileOnResume`).
@pragma('vm:entry-point')
Future<void> homeWidgetBackgroundCallback(Uri? uri) async {
  if (uri == null || uri.scheme != 'cairn') return;

  switch (uri.host) {
    case 'toggle_habit':
      await _handleToggleHabit(uri.queryParameters['id']);
    case 'toggle_task':
      await _handleToggleTask(uri.queryParameters['id']);
    case 'timer_action':
      await _handleTimerAction(uri.queryParameters['action']);
  }
}

Future<void> _handleToggleHabit(String? habitId) async {
  if (habitId == null || habitId.isEmpty) return;

  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  try {
    final settingsRepo = SettingsRepository(db: db);
    final deviceId = await settingsRepo.getOrCreateDeviceId();
    final timeService = TimeService(
      dayStartOffsetMinutes:
          await settingsRepo.getInt('day_start_offset') ?? 240,
    );
    final eventsRepo = EventsRepository(
      db: db,
      timeService: timeService,
      deviceId: deviceId,
    );
    final habitsRepo = HabitsRepository(
      db: db,
      eventsRepository: eventsRepo,
      timeService: timeService,
      deviceId: deviceId,
    );

    final today = timeService.todayLocalDate();
    final snapshot = await habitsRepo.loadSnapshot(habitId);
    if (snapshot != null) {
      if (snapshot.isDoneToday) {
        await habitsRepo.resetChecks(habitId, localDate: today);
      } else {
        await habitsRepo.check(habitId, localDate: today);
      }

      final updatedSnapshots = await habitsRepo.loadActiveSnapshots();
      final widgetService = HomeScreenWidgetService();
      await widgetService.updateHabitsWidget(
        habits: updatedSnapshots,
        todayLocalDate: today,
      );

      final scheduled = updatedSnapshots.where((h) => h.isScheduledToday).toList();
      final done = scheduled.where((h) => h.isDoneToday).length;
      await HomeWidget.saveWidgetData<String>(
        'today_habits_summary',
        '$done / ${scheduled.length}',
      );
      await HomeWidget.updateWidget(
        name: HomeScreenWidgetService.todayWidgetName,
        androidName: HomeScreenWidgetService.todayWidgetName,
      );
    }
  } catch (e, st) {
    debugPrint('HomeScreenWidgetService: background callback error: $e\n$st');
  } finally {
    await db.close();
  }
}

Future<void> _handleToggleTask(String? taskId) async {
  if (taskId == null || taskId.isEmpty) return;

  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  try {
    final settingsRepo = SettingsRepository(db: db);
    final deviceId = await settingsRepo.getOrCreateDeviceId();
    final timeService = TimeService(
      dayStartOffsetMinutes:
          await settingsRepo.getInt('day_start_offset') ?? 240,
    );
    final eventsRepo = EventsRepository(
      db: db,
      timeService: timeService,
      deviceId: deviceId,
    );
    // No ReminderService here on purpose: it owns a notification plugin that
    // is not safely constructible in a headless isolate, and TasksRepository
    // already treats it as optional (`reminderService?.cancelFor(...)`). The
    // cost is a completed task keeping its scheduled reminder until the app
    // next reconciles; booting notifications in a short-lived isolate is a
    // far worse trade.
    final tasksRepo = TasksRepository(
      db: db,
      eventsRepository: eventsRepo,
      timeService: timeService,
      deviceId: deviceId,
    );

    final today = timeService.todayLocalDate();
    final task = await tasksRepo.watchTaskWithDetails(taskId).first;
    if (task != null) {
      if (task.isOpen) {
        await tasksRepo.completeTask(taskId);
      } else if (task.isDone) {
        await tasksRepo.uncompleteTask(taskId);
      }

      final updatedTasks = await tasksRepo.watchTodayTasks(today).first;
      final widgetService = HomeScreenWidgetService();
      await widgetService.updateTasksWidget(todayTasks: updatedTasks);

      // The Today glance counts the same open tasks; keep it in step.
      final openCount = updatedTasks.where((t) => t.isOpen).length;
      await HomeWidget.saveWidgetData<String>('today_tasks_due', '$openCount');
      await HomeWidget.updateWidget(
        name: HomeScreenWidgetService.todayWidgetName,
        androidName: HomeScreenWidgetService.todayWidgetName,
      );
    }
  } catch (e, st) {
    debugPrint('HomeScreenWidgetService: background task-toggle error: $e\n$st');
  } finally {
    await db.close();
  }
}

/// Builds the domain [TimerState] a persisted `timer_states` row represents.
TimerState _timerStateFromRow({
  required String? sessionId,
  required int startedAtUtc,
  required int plannedDurationS,
  required String mode,
  required int pausedAccumulatedS,
  required int? pausedAtUtc,
  required String? taskId,
  required String? projectId,
}) {
  return TimerState(
    status: pausedAtUtc != null ? TimerStatus.paused : TimerStatus.running,
    mode: TimerMode.fromDbValue(mode),
    sessionId: sessionId,
    startedAtUtc: startedAtUtc,
    plannedDurationS: plannedDurationS,
    pausedAccumulatedS: pausedAccumulatedS,
    pausedAtUtc: pausedAtUtc,
    taskId: taskId,
    projectId: projectId,
  );
}

/// Mirrors `TimerController._updateForegroundNotification` so a widget-driven
/// transition leaves the notification reading exactly as an in-app one would.
(String, String) _notificationTextFor(TimerState state, int nowUtcMs) {
  if (state.isFlow) {
    final title =
        state.isPaused ? 'Open-ended Session (Paused)' : 'Open-ended Session';
    final elapsed = state.computeElapsedSeconds(nowUtcMs);
    return (title, 'Elapsed: ${HomeScreenWidgetService.formatMmSs(elapsed)}');
  }
  final title = state.isPaused ? 'Focus Session (Paused)' : 'Focus Session';
  final remaining = state.computeRemainingSeconds(nowUtcMs);
  return (title, 'Remaining: ${HomeScreenWidgetService.formatMmSs(remaining)}');
}

/// Applies a timer action straight to the database from a background isolate.
///
/// Shared by the home-screen widget's buttons and the foreground-service
/// notification's Pause/Resume/Skip buttons. Both can be pressed while no
/// main isolate exists, so neither can route through [TimerController] — the
/// database is the source of truth and the app re-derives from it via
/// `TimerController.reconcileOnResume()` on next resume.
///
/// Accepts the same action names as the widget: 'start', 'pause', 'resume',
/// 'stop'.
@pragma('vm:entry-point')
Future<void> applyTimerActionFromBackground(String action) =>
    _handleTimerAction(action);

Future<void> _handleTimerAction(String? action) async {
  if (action == null || action.isEmpty) return;

  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  try {
    final settingsRepo = SettingsRepository(db: db);
    final deviceId = await settingsRepo.getOrCreateDeviceId();
    final timeService = TimeService(
      dayStartOffsetMinutes:
          await settingsRepo.getInt('day_start_offset') ?? 240,
    );
    final eventsRepo = EventsRepository(
      db: db,
      timeService: timeService,
      deviceId: deviceId,
    );
    final timerRepo = TimerRepository(db: db, deviceId: deviceId);
    final foregroundService = TimerForegroundService();
    final widgetService = HomeScreenWidgetService();

    final row = await timerRepo.loadTimerState();
    final now = timeService.nowUtcMs();

    final isActive = row != null && row.startedAtUtc != null;
    // A running break is in-app territory (Skip already covers it); the widget
    // shows the countdown but offers no buttons, so never mutate it from here.
    if (isActive && row.mode == 'break') return;

    final isPaused = isActive && row.pausedAtUtc != null;
    final isRunning = isActive && row.pausedAtUtc == null;

    switch (action) {
      case 'start':
        if (isActive) return;
        final plannedDurationS =
            await settingsRepo.getInt('session_length_s') ?? 1500;
        final localDate = timeService.computeLocalDate(now);
        final sessionId = await timerRepo.createFocusSession(
          mode: 'pomodoro',
          plannedDurationS: plannedDurationS,
          startedAt: now,
          localDate: localDate,
          tzOffsetMin: timeService.currentTzOffsetMin(now),
          tzId: timeService.currentTzId(),
        );
        await eventsRepo.logEvent(
          type: EventTypes.sessionStarted,
          occurredAtUtcMs: now,
          subjectType: SubjectTypes.session,
          subjectId: sessionId,
          payload: {
            'mode': 'pomodoro',
            'planned_duration_s': plannedDurationS,
          },
        );
        await timerRepo.persistTimerState(
          sessionId: sessionId,
          startedAtUtc: now,
          plannedDurationS: plannedDurationS,
          mode: 'pomodoro',
          pausedAccumulatedS: 0,
          pausedAtUtc: null,
        );

        final started = TimerState(
          status: TimerStatus.running,
          mode: TimerMode.pomodoro,
          sessionId: sessionId,
          startedAtUtc: now,
          plannedDurationS: plannedDurationS,
        );
        await foregroundService.startService(
          title: 'Focus Session',
          text: HomeScreenWidgetService.formatMmSs(plannedDurationS),
          isPaused: false,
        );
        await widgetService.updateTimerWidget(started, nowUtcMs: now);

      case 'pause':
        if (!isRunning) return;
        await timerRepo.persistTimerState(
          sessionId: row.sessionId,
          startedAtUtc: row.startedAtUtc,
          plannedDurationS: row.plannedDurationS,
          mode: row.mode,
          pausedAccumulatedS: row.pausedAccumulatedS,
          pausedAtUtc: now,
          taskId: row.taskId,
          projectId: row.projectId,
        );

        final paused = _timerStateFromRow(
          sessionId: row.sessionId,
          startedAtUtc: row.startedAtUtc!,
          plannedDurationS: row.plannedDurationS,
          mode: row.mode,
          pausedAccumulatedS: row.pausedAccumulatedS,
          pausedAtUtc: now,
          taskId: row.taskId,
          projectId: row.projectId,
        );
        final (pausedTitle, pausedText) = _notificationTextFor(paused, now);
        await foregroundService.updateService(
          title: pausedTitle,
          text: pausedText,
          isPaused: true,
        );
        await widgetService.updateTimerWidget(paused, nowUtcMs: now);

      case 'resume':
        if (!isPaused) return;
        final additionalPausedS = (now - row.pausedAtUtc!) ~/ 1000;
        final totalPausedAccumulated = row.pausedAccumulatedS +
            (additionalPausedS > 0 ? additionalPausedS : 0);
        await timerRepo.persistTimerState(
          sessionId: row.sessionId,
          startedAtUtc: row.startedAtUtc,
          plannedDurationS: row.plannedDurationS,
          mode: row.mode,
          pausedAccumulatedS: totalPausedAccumulated,
          pausedAtUtc: null,
          taskId: row.taskId,
          projectId: row.projectId,
        );

        final resumed = _timerStateFromRow(
          sessionId: row.sessionId,
          startedAtUtc: row.startedAtUtc!,
          plannedDurationS: row.plannedDurationS,
          mode: row.mode,
          pausedAccumulatedS: totalPausedAccumulated,
          pausedAtUtc: null,
          taskId: row.taskId,
          projectId: row.projectId,
        );
        final (resumedTitle, resumedText) = _notificationTextFor(resumed, now);
        await foregroundService.updateService(
          title: resumedTitle,
          text: resumedText,
          isPaused: false,
        );
        await widgetService.updateTimerWidget(resumed, nowUtcMs: now);

      case 'stop':
        if (!isActive) return;
        final active = _timerStateFromRow(
          sessionId: row.sessionId,
          startedAtUtc: row.startedAtUtc!,
          plannedDurationS: row.plannedDurationS,
          mode: row.mode,
          pausedAccumulatedS: row.pausedAccumulatedS,
          pausedAtUtc: row.pausedAtUtc,
          taskId: row.taskId,
          projectId: row.projectId,
        );
        final actualDurationS = active.computeElapsedSeconds(now);
        final sessionRow = row.sessionId != null
            ? await timerRepo.getFocusSession(row.sessionId!)
            : null;

        // A widget Stop is an early, user-initiated bail-out — the same thing
        // "Skip" means mid-session in the app — so it abandons, never completes.
        await eventsRepo.logEvent(
          type: EventTypes.sessionAbandoned,
          occurredAtUtcMs: now,
          localDateOverride: sessionRow?.localDate,
          subjectType: SubjectTypes.session,
          subjectId: row.sessionId,
          payload: {
            'actual_duration_s': actualDurationS,
            'reason': AbandonReasons.userStopped,
          },
        );
        if (row.sessionId != null) {
          await timerRepo.finalizeSession(
            row.sessionId!,
            endedAt: now,
            actualDurationS: actualDurationS,
            outcome: SessionOutcomes.abandoned,
          );
        }
        await timerRepo.clearTimerState();
        await foregroundService.stopService();

        final idleDurationS =
            await settingsRepo.getInt('session_length_s') ?? 1500;
        await widgetService.updateTimerWidget(
          TimerState(plannedDurationS: idleDurationS),
          nowUtcMs: now,
        );
    }
  } catch (e, st) {
    debugPrint('HomeScreenWidgetService: background timer-action error: $e\n$st');
  } finally {
    await db.close();
  }
}
