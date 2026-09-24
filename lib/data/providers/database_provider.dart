import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/time_service.dart';
import '../database/app_database.dart';
import '../dev/seed_data.dart';
import '../repositories/events_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/stats_repository.dart';
import '../repositories/tasks_repository.dart';
import '../repositories/timer_repository.dart';
import '../../features/reminders/reminder_service.dart';

/// Function type for clock provider to enable test clock injection without DateTime.now().
typedef Clock = int Function();

/// Provides the current UTC epoch milliseconds. Default implementation reads from [TimeService].
final clockProvider = Provider<Clock>((ref) {
  final timeService = ref.watch(timeServiceProvider);
  return () => timeService.nowUtcMs();
});

/// Wraps a Drift query stream under Flutter test environments to avoid StreamQueryStore
/// scheduling a pending zero-duration timer during test unmount.
Stream<T> _testSafeStream<T>(Stream<T> source) {
  if (!Platform.environment.containsKey('FLUTTER_TEST')) {
    return source;
  }
  final controller = StreamController<T>();
  controller.onListen = () {
    source.listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.onCancel = () {
      // Intentionally do not cancel Drift stream under test to prevent
      // StreamQueryStore.markAsClosed from scheduling an un-pumped Timer(Duration.zero).
    };
  };
  return controller.stream;
}

/// StateNotifier for logical day start offset in minutes after midnight (default: 240 / 04:00 AM).
/// Loads from the `settings` table at startup and writes on every change per SPEC.md §1.2 and §2.5.
class DayStartOffsetNotifier extends StateNotifier<int> {
  DayStartOffsetNotifier(this._settingsRepo, [int initial = 240])
      : super(initial) {
    _load();
  }

  final SettingsRepository _settingsRepo;
  bool _userModified = false;

  Future<void> _load() async {
    try {
      final saved = await _settingsRepo.getInt('day_start_offset');
      if (!_userModified && saved != null && mounted) {
        super.state = saved;
      }
    } catch (_) {}
  }

  @override
  set state(int value) {
    _userModified = true;
    super.state = value;
    _settingsRepo.setInt('day_start_offset', value);
  }

  void setOffset(int value) {
    state = value;
  }

  void update(int Function(int state) cb) {
    state = cb(state);
  }
}

/// User setting for logical day start offset in minutes after midnight (default: 240 / 04:00 AM).
/// Per SPEC.md §1.2: Changing this applies to new events only.
final dayStartOffsetProvider =
    StateNotifierProvider<DayStartOffsetNotifier, int>((ref) {
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  return DayStartOffsetNotifier(settingsRepo);
});

/// StateNotifier for daily focus goal in minutes per SPEC.md §4.3 (default: 25, min: 5, max: 480).
class DailyGoalMinutesNotifier extends StateNotifier<int> {
  DailyGoalMinutesNotifier(this._settingsRepo,
      [int initial = FocusStats.defaultDailyGoalMinutes])
      : super(initial.clamp(5, 480)) {
    _load();
  }

  final SettingsRepository _settingsRepo;
  bool _userModified = false;

  Future<void> _load() async {
    try {
      final saved = await _settingsRepo.getInt('daily_goal_minutes');
      if (!_userModified && saved != null && mounted) {
        super.state = saved.clamp(5, 480);
      }
    } catch (_) {}
  }

  @override
  set state(int value) {
    _userModified = true;
    final clamped = value.clamp(5, 480);
    super.state = clamped;
    _settingsRepo.setInt('daily_goal_minutes', clamped);
  }

  void setGoal(int value) {
    state = value;
  }

  void update(int Function(int state) cb) {
    state = cb(state);
  }
}

/// User setting for daily focus goal in minutes per SPEC.md §4.3 (default: 25, range: 5..480).
final dailyGoalMinutesProvider =
    StateNotifierProvider<DailyGoalMinutesNotifier, int>((ref) {
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  return DailyGoalMinutesNotifier(settingsRepo);
});

/// StateNotifier for Pomodoro session length in seconds (default: 1500, range: 300..7200).
class SessionLengthSecondsNotifier extends StateNotifier<int> {
  SessionLengthSecondsNotifier(this._settingsRepo, [int initial = 1500])
      : super(initial.clamp(300, 7200)) {
    _load();
  }

  final SettingsRepository _settingsRepo;
  bool _userModified = false;

  Future<void> _load() async {
    try {
      final saved = await _settingsRepo.getInt('session_length_s');
      if (!_userModified && saved != null && mounted) {
        super.state = saved.clamp(300, 7200);
      }
    } catch (_) {}
  }

  @override
  set state(int value) {
    _userModified = true;
    final clamped = value.clamp(300, 7200);
    super.state = clamped;
    _settingsRepo.setInt('session_length_s', clamped);
  }

  void setDuration(int value) {
    state = value;
  }

  void update(int Function(int state) cb) {
    state = cb(state);
  }
}

/// User setting for Pomodoro session length in seconds (default: 1500 / 25 min, range: 300..7200).
final sessionLengthSecondsProvider =
    StateNotifierProvider<SessionLengthSecondsNotifier, int>((ref) {
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  return SessionLengthSecondsNotifier(settingsRepo);
});

/// StateNotifier for short break length in seconds (default: 300, range: 60..1800).
class BreakLengthSecondsNotifier extends StateNotifier<int> {
  BreakLengthSecondsNotifier(this._settingsRepo, [int initial = 300])
      : super(initial.clamp(60, 1800)) {
    _load();
  }

  final SettingsRepository _settingsRepo;
  bool _userModified = false;

  Future<void> _load() async {
    try {
      final saved = await _settingsRepo.getInt('break_length_s');
      if (!_userModified && saved != null && mounted) {
        super.state = saved.clamp(60, 1800);
      }
    } catch (_) {}
  }

  @override
  set state(int value) {
    _userModified = true;
    final clamped = value.clamp(60, 1800);
    super.state = clamped;
    _settingsRepo.setInt('break_length_s', clamped);
  }

  void setDuration(int value) {
    state = value;
  }

  void update(int Function(int state) cb) {
    state = cb(state);
  }
}

/// User setting for short break length in seconds (default: 300 / 5 min, range: 60..1800).
final breakLengthSecondsProvider =
    StateNotifierProvider<BreakLengthSecondsNotifier, int>((ref) {
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  return BreakLengthSecondsNotifier(settingsRepo);
});

/// StateNotifier for long break length in seconds (default: 900, range: 60..3600).
class LongBreakLengthSecondsNotifier extends StateNotifier<int> {
  LongBreakLengthSecondsNotifier(this._settingsRepo, [int initial = 900])
      : super(initial.clamp(60, 3600)) {
    _load();
  }

  final SettingsRepository _settingsRepo;
  bool _userModified = false;

  Future<void> _load() async {
    try {
      final saved = await _settingsRepo.getInt('long_break_length_s');
      if (!_userModified && saved != null && mounted) {
        super.state = saved.clamp(60, 3600);
      }
    } catch (_) {}
  }

  @override
  set state(int value) {
    _userModified = true;
    final clamped = value.clamp(60, 3600);
    super.state = clamped;
    _settingsRepo.setInt('long_break_length_s', clamped);
  }

  void setDuration(int value) {
    state = value;
  }

  void update(int Function(int state) cb) {
    state = cb(state);
  }
}

/// User setting for long break length in seconds (default: 900 / 15 min, range: 60..3600).
final longBreakLengthSecondsProvider =
    StateNotifierProvider<LongBreakLengthSecondsNotifier, int>((ref) {
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  return LongBreakLengthSecondsNotifier(settingsRepo);
});

/// StateNotifier for sessions before a long break (default: 4, range: 2..10).
class SessionsBeforeLongBreakNotifier extends StateNotifier<int> {
  SessionsBeforeLongBreakNotifier(this._settingsRepo, [int initial = 4])
      : super(initial.clamp(2, 10)) {
    _load();
  }

  final SettingsRepository _settingsRepo;
  bool _userModified = false;

  Future<void> _load() async {
    try {
      final saved = await _settingsRepo.getInt('sessions_before_long_break');
      if (!_userModified && saved != null && mounted) {
        super.state = saved.clamp(2, 10);
      }
    } catch (_) {}
  }

  @override
  set state(int value) {
    _userModified = true;
    final clamped = value.clamp(2, 10);
    super.state = clamped;
    _settingsRepo.setInt('sessions_before_long_break', clamped);
  }

  void setCount(int value) {
    state = value;
  }

  void update(int Function(int state) cb) {
    state = cb(state);
  }
}

/// User setting for sessions before a long break (default: 4, range: 2..10).
final sessionsBeforeLongBreakProvider =
    StateNotifierProvider<SessionsBeforeLongBreakNotifier, int>((ref) {
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  return SessionsBeforeLongBreakNotifier(settingsRepo);
});

/// StateNotifier for first day of week (default: DateTime.monday = 1, range: 1..7).
class WeekStartNotifier extends StateNotifier<int> {
  WeekStartNotifier(this._settingsRepo, [int initial = DateTime.monday])
      : super(initial.clamp(1, 7)) {
    _load();
  }

  final SettingsRepository _settingsRepo;
  bool _userModified = false;

  Future<void> _load() async {
    try {
      final saved = await _settingsRepo.getInt('week_start');
      if (!_userModified && saved != null && mounted) {
        super.state = saved.clamp(1, 7);
      }
    } catch (_) {}
  }

  @override
  set state(int value) {
    _userModified = true;
    final clamped = value.clamp(1, 7);
    super.state = clamped;
    _settingsRepo.setInt('week_start', clamped);
  }

  void setWeekStart(int value) {
    state = value;
  }

  void update(int Function(int state) cb) {
    state = cb(state);
  }
}

/// User setting for first day of week (default: DateTime.monday = 1, range: 1..7).
final weekStartProvider =
    StateNotifierProvider<WeekStartNotifier, int>((ref) {
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  return WeekStartNotifier(settingsRepo);
});

/// StateNotifier for master task reminders setting (default: true).
class RemindersEnabledNotifier extends StateNotifier<bool> {
  RemindersEnabledNotifier(this._settingsRepo, [bool initial = true])
      : super(initial) {
    _load();
  }

  final SettingsRepository _settingsRepo;
  bool _userModified = false;

  Future<void> _load() async {
    try {
      final saved = await _settingsRepo.getBool('reminders_enabled');
      if (!_userModified && saved != null && mounted) {
        super.state = saved;
      }
    } catch (_) {}
  }

  @override
  set state(bool value) {
    _userModified = true;
    super.state = value;
    _settingsRepo.setBool('reminders_enabled', value);
  }

  void setEnabled(bool value) {
    state = value;
  }
}

final remindersEnabledProvider =
    StateNotifierProvider<RemindersEnabledNotifier, bool>((ref) {
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  return RemindersEnabledNotifier(settingsRepo);
});

/// StateNotifier for a new timed task's starting set of countdown offsets —
/// minutes before the due time, e.g. `[10, 60]` for "10 min before" and
/// "1 hour before" (default: `[10]`). A per-task override lives in
/// `task_reminder_offsets` once the task exists; this is only where a new
/// task's reminders start out (see `ReminderConfigRepository.
/// seedDefaultTaskReminderOffsets`).
class DefaultTaskReminderOffsetsMinNotifier extends StateNotifier<List<int>> {
  DefaultTaskReminderOffsetsMinNotifier(this._settingsRepo,
      [List<int>? initial])
      : super(_clean(initial ?? const [10])) {
    _load();
  }

  final SettingsRepository _settingsRepo;
  bool _userModified = false;

  static const int maxOffsets = 5;

  static List<int> _clean(List<int> values) {
    final cleaned = values.where((v) => v >= 0).toSet().toList()..sort();
    if (cleaned.isEmpty) return const [10];
    return cleaned.take(maxOffsets).toList();
  }

  Future<void> _load() async {
    try {
      final saved = await _settingsRepo.get('default_reminder_offsets_min');
      if (!_userModified && saved is List && mounted) {
        super.state = _clean(saved.map((e) => (e as num).toInt()).toList());
      }
    } catch (_) {}
  }

  @override
  set state(List<int> value) {
    _userModified = true;
    final cleaned = _clean(value);
    super.state = cleaned;
    _settingsRepo.set('default_reminder_offsets_min', cleaned);
  }

  void setOffsets(List<int> value) {
    state = value;
  }
}

final defaultTaskReminderOffsetsMinProvider =
    StateNotifierProvider<DefaultTaskReminderOffsetsMinNotifier, List<int>>((ref) {
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  return DefaultTaskReminderOffsetsMinNotifier(settingsRepo);
});

/// StateNotifier for the daily due-list digest's on/off switch (default:
/// off). Replaces the old single "all-day task reminder time" — an all-day
/// task has no time to remind at on its own, so it is covered by this
/// digest instead (SPEC §11).
class DigestEnabledNotifier extends StateNotifier<bool> {
  DigestEnabledNotifier(this._settingsRepo, [bool initial = false])
      : super(initial) {
    _load();
  }

  final SettingsRepository _settingsRepo;
  bool _userModified = false;

  Future<void> _load() async {
    try {
      final saved = await _settingsRepo.getBool('digest_enabled');
      if (!_userModified && saved != null && mounted) {
        super.state = saved;
      }
    } catch (_) {}
  }

  @override
  set state(bool value) {
    _userModified = true;
    super.state = value;
    _settingsRepo.setBool('digest_enabled', value);
  }

  void setEnabled(bool value) {
    state = value;
  }
}

final digestEnabledProvider = StateNotifierProvider<DigestEnabledNotifier, bool>((ref) {
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  return DigestEnabledNotifier(settingsRepo);
});

/// StateNotifier for the digest's times of day, minutes from midnight,
/// ascending (default: `[540]` = 09:00). Up to
/// [DigestTimesMinNotifier.maxTimes] slots.
class DigestTimesMinNotifier extends StateNotifier<List<int>> {
  DigestTimesMinNotifier(this._settingsRepo, [List<int>? initial])
      : super(_clean(initial ?? const [540])) {
    _load();
  }

  final SettingsRepository _settingsRepo;
  bool _userModified = false;

  static const int maxTimes = 6;

  static List<int> _clean(List<int> values) {
    final cleaned =
        values.where((v) => v >= 0 && v < 24 * 60).toSet().toList()..sort();
    if (cleaned.isEmpty) return const [540];
    return cleaned.take(maxTimes).toList();
  }

  Future<void> _load() async {
    try {
      final saved = await _settingsRepo.get('digest_times_min');
      if (!_userModified && saved is List && mounted) {
        super.state = _clean(saved.map((e) => (e as num).toInt()).toList());
      }
    } catch (_) {}
  }

  @override
  set state(List<int> value) {
    _userModified = true;
    final cleaned = _clean(value);
    super.state = cleaned;
    _settingsRepo.set('digest_times_min', cleaned);
  }

  void setTimes(List<int> value) {
    state = value;
  }
}

final digestTimesMinProvider =
    StateNotifierProvider<DigestTimesMinNotifier, List<int>>((ref) {
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  return DigestTimesMinNotifier(settingsRepo);
});

/// StateNotifier for whether the once-daily habit check-in fires
/// (`habit_digest_enabled`, default off).
///
/// Off by default for the same reason [DigestEnabledNotifier] is: a fresh
/// install sends no notification nobody asked for. Read by
/// `ReminderService.reconcileHabitDigest`.
class HabitDigestEnabledNotifier extends StateNotifier<bool> {
  HabitDigestEnabledNotifier(this._settingsRepo, [bool initial = false])
      : super(initial) {
    _load();
  }

  final SettingsRepository _settingsRepo;
  bool _userModified = false;

  Future<void> _load() async {
    try {
      final saved = await _settingsRepo.getBool('habit_digest_enabled');
      if (!_userModified && saved != null && mounted) {
        super.state = saved;
      }
    } catch (_) {}
  }

  @override
  set state(bool value) {
    _userModified = true;
    super.state = value;
    _settingsRepo.setBool('habit_digest_enabled', value);
  }

  void setEnabled(bool value) {
    state = value;
  }
}

final habitDigestEnabledProvider =
    StateNotifierProvider<HabitDigestEnabledNotifier, bool>((ref) {
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  return HabitDigestEnabledNotifier(settingsRepo);
});

/// StateNotifier for the habit check-in's time of day, in minutes from
/// midnight (`habit_digest_time_min`, default 20:00).
///
/// One time, not a list like [DigestTimesMinNotifier]: the check-in is a
/// single daily prompt, and `reconcileHabitDigest` reads exactly one value.
class HabitDigestTimeMinNotifier extends StateNotifier<int> {
  HabitDigestTimeMinNotifier(this._settingsRepo, [int? initial])
      : super(_clean(initial ?? ReminderService.defaultHabitDigestTimeMin)) {
    _load();
  }

  final SettingsRepository _settingsRepo;
  bool _userModified = false;

  /// Anything outside a day falls back to the default rather than scheduling
  /// a notification at hour 47 — same defensive shape as
  /// [DigestTimesMinNotifier._clean].
  static int _clean(int value) =>
      (value >= 0 && value < 24 * 60) ? value : ReminderService.defaultHabitDigestTimeMin;

  Future<void> _load() async {
    try {
      final saved = await _settingsRepo.getInt('habit_digest_time_min');
      if (!_userModified && saved != null && mounted) {
        super.state = _clean(saved);
      }
    } catch (_) {}
  }

  @override
  set state(int value) {
    _userModified = true;
    final cleaned = _clean(value);
    super.state = cleaned;
    _settingsRepo.setInt('habit_digest_time_min', cleaned);
  }

  void setTime(int value) {
    state = value;
  }
}

final habitDigestTimeMinProvider =
    StateNotifierProvider<HabitDigestTimeMinNotifier, int>((ref) {
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  return HabitDigestTimeMinNotifier(settingsRepo);
});

/// The device's IANA zone id, resolved once at startup in main() (SPEC §1.2).
/// Empty when the platform would not say.
final deviceTzIdProvider = Provider<String>((ref) => '');

/// Provides the [TimeService] configured with the current day start offset, week start, and IANA timezone ID.
final timeServiceProvider = Provider<TimeService>((ref) {
  final dayStartOffset = ref.watch(dayStartOffsetProvider);
  final weekStart = ref.watch(weekStartProvider);
  final tzId = ref.watch(deviceTzIdProvider);
  return TimeService(
    dayStartOffsetMinutes: dayStartOffset,
    weekStart: weekStart,
    tzIdProvider: tzId.isEmpty ? null : () => tzId,
  );
});

/// Provides the singleton [AppDatabase] instance.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Unique device ID generated once on first launch and held in memory (§5).
final deviceIdProvider = Provider<String>((ref) {
  return 'default-device-id';
});

/// Provides the [SettingsRepository] for key/value storage over the `settings` table.
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return SettingsRepository(db: db);
});

/// Provides the append-only [EventsRepository].
final eventsRepositoryProvider = Provider<EventsRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final timeService = ref.watch(timeServiceProvider);
  final deviceId = ref.watch(deviceIdProvider);
  return EventsRepository(db: db, timeService: timeService, deviceId: deviceId);
});

/// Provides the [StatsRepository] for calculating live focus statistics.
final statsRepositoryProvider = Provider<StatsRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final timeService = ref.watch(timeServiceProvider);
  return StatsRepository(db: db, timeService: timeService);
});

/// Stream of live [FocusStats] recomputed whenever focus sessions change.
final focusStatsStreamProvider = StreamProvider<FocusStats>((ref) {
  final statsRepo = ref.watch(statsRepositoryProvider);
  final dailyGoal = ref.watch(dailyGoalMinutesProvider);
  return _testSafeStream(statsRepo.watchFocusStats(dailyGoalMinutes: dailyGoal));
});

/// Alias for [focusStatsStreamProvider].
final focusStatsProvider = focusStatsStreamProvider;

/// Stream of 7-day focus summary for the bar strip on Today screen.
final last7DaysSummaryStreamProvider =
    StreamProvider<List<DayFocusSummary>>((ref) {
  final statsRepo = ref.watch(statsRepositoryProvider);
  final dailyGoal = ref.watch(dailyGoalMinutesProvider);
  return _testSafeStream(
      statsRepo.watchLast7DaysSummary(dailyGoalMinutes: dailyGoal));
});

/// Provides the [TimerRepository] for managing `timer_states` and `focus_sessions`.
final timerRepositoryProvider = Provider<TimerRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final deviceId = ref.watch(deviceIdProvider);
  return TimerRepository(db: db, deviceId: deviceId);
});

/// Stream of events logged on the current logical date.
final todayEventsStreamProvider = StreamProvider<List<Event>>((ref) {
  final repo = ref.watch(eventsRepositoryProvider);
  final timeService = ref.watch(timeServiceProvider);
  final today = timeService.todayLocalDate();
  return _testSafeStream(repo.watchEventsForDate(today));
});

/// Selected logical date for the Today screen (null = current logical today).
final selectedDateProvider = StateProvider<String?>((ref) => null);

/// Stream of events logged on a specific logical date.
final eventsForDateStreamProvider =
    StreamProvider.family<List<Event>, String>((ref, date) {
  final repo = ref.watch(eventsRepositoryProvider);
  return _testSafeStream(repo.watchEventsForDate(date));
});

/// Stream of focus sessions recorded on a specific logical date.
final sessionsForDateStreamProvider =
    StreamProvider.family<List<FocusSession>, String>((ref, date) {
  final repo = ref.watch(timerRepositoryProvider);
  return _testSafeStream(repo.watchSessionsForDate(date));
});

/// Provides the [TasksRepository] for managing tasks, projects, and tags.
final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final eventsRepo = ref.watch(eventsRepositoryProvider);
  final timeService = ref.watch(timeServiceProvider);
  final deviceId = ref.watch(deviceIdProvider);
  final reminderService = ref.watch(reminderServiceProvider);
  return TasksRepository(
    db: db,
    eventsRepository: eventsRepo,
    timeService: timeService,
    deviceId: deviceId,
    reminderService: reminderService,
  );
});

/// Stream of tasks for the Today view on a specific logical date.
final todayTasksStreamProvider =
    StreamProvider.family<List<TaskWithDetails>, String>((ref, date) {
  final repo = ref.watch(tasksRepositoryProvider);
  return _testSafeStream(repo.watchTodayTasks(date));
});

/// Stream of upcoming tasks strictly after [todayLocalDate].
final upcomingTasksStreamProvider =
    StreamProvider.family<List<TaskWithDetails>, String>((ref, todayDate) {
  final repo = ref.watch(tasksRepositoryProvider);
  return _testSafeStream(repo.watchUpcomingTasks(todayDate));
});

/// Stream of inbox tasks (open, no due date).
final inboxTasksStreamProvider = StreamProvider<List<TaskWithDetails>>((ref) {
  final repo = ref.watch(tasksRepositoryProvider);
  return _testSafeStream(repo.watchInboxTasks());
});

/// Stream of active non-archived projects.
final projectsStreamProvider = StreamProvider<List<Project>>((ref) {
  final repo = ref.watch(tasksRepositoryProvider);
  return _testSafeStream(repo.watchProjects());
});

/// Stream of archived tasks per §2.2.
final archivedTasksStreamProvider = StreamProvider<List<ArchivedTaskItem>>((ref) {
  final repo = ref.watch(tasksRepositoryProvider);
  return _testSafeStream(repo.watchArchivedTasks());
});

/// Stream of all tags.
final tagsStreamProvider = StreamProvider<List<Tag>>((ref) {
  final repo = ref.watch(tasksRepositoryProvider);
  return _testSafeStream(repo.watchTags());
});

/// Stream of a single task with its details.
final taskDetailsStreamProvider =
    StreamProvider.family<TaskWithDetails?, String>((ref, taskId) {
  final repo = ref.watch(tasksRepositoryProvider);
  return _testSafeStream(repo.watchTaskWithDetails(taskId));
});

/// Active task ID attached to the timer (null = unassigned).
final activeTaskIdProvider = StateProvider<String?>((ref) => null);


/// StateNotifier for theme mode (system, light, dark).
/// Loads from `settings` table at startup and writes on every change per §2.5.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this._settingsRepo, [ThemeMode initial = ThemeMode.system])
      : super(initial) {
    _load();
  }

  final SettingsRepository _settingsRepo;
  bool _userModified = false;

  Future<void> _load() async {
    try {
      final saved = await _settingsRepo.getString('theme_mode');
      if (!_userModified && saved != null && mounted) {
        final mode = ThemeMode.values.firstWhere(
          (m) => m.name == saved,
          orElse: () => ThemeMode.system,
        );
        super.state = mode;
      }
    } catch (_) {}
  }

  @override
  set state(ThemeMode value) {
    _userModified = true;
    super.state = value;
    _settingsRepo.setString('theme_mode', value.name);
  }

  void setThemeMode(ThemeMode mode) {
    state = mode;
  }

  void update(ThemeMode Function(ThemeMode state) cb) {
    state = cb(state);
  }
}

/// Current theme mode (system, light, dark).
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  return ThemeModeNotifier(settingsRepo);
});

/// Active bottom navigation index.
final navigationIndexProvider = StateProvider<int>((ref) => 0);

/// Tab indices in `NavigationShell`. Five is the Material 3 maximum.
abstract final class NavTabs {
  static const today = 0;
  static const timer = 1;
  static const tasks = 2;
  static const habits = 3;
  static const stats = 4;
}

/// A habit whose detail screen should open — set by a tapped `habit:<id>`
/// reminder, consumed and cleared by the navigation shell.
final pendingHabitDetailProvider = StateProvider<String?>((ref) => null);

/// Provider for generating and wiping test data (POLISH §8).
final seedDataProvider = Provider<SeedData>((ref) => SeedData(
      db: ref.watch(databaseProvider),
      timeService: ref.watch(timeServiceProvider),
      deviceId: ref.watch(deviceIdProvider),
    ));
