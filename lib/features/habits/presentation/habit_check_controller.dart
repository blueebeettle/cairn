import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/database/app_database.dart';
import '../../../data/providers/database_provider.dart';
import '../../../data/providers/habit_providers.dart';
import '../../../data/repositories/habits_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../reminders/reminder_service.dart';

/// Optimistic check-off state: habit id -> today's count as the UI should
/// show it, while the write is in flight.
///
/// A tap fills the circle *now*. Waiting for the transaction and the Drift
/// stream to round-trip is 30–80ms on a phone, which is long enough to feel
/// like the tap did not land — and a second tap then double-counts.
///
/// This holds only the count. The streak, the dots and the sections all read
/// the confirmed snapshot; they catch up a frame or two later. Nothing here
/// computes a streak.
class HabitCheckController extends StateNotifier<Map<String, int>> {
  HabitCheckController(this._ref) : super(const {}) {
    _ref.listen<AsyncValue<List<HabitSnapshot>>>(
      habitSnapshotsProvider,
      (_, next) {
        if (next.isLoading) return; // a reload carries the previous value
        final snapshots = next.value;
        if (snapshots == null) return;
        _confirmed = {for (final s in snapshots) s.habit.id: s.countToday};
        _reconcile(snapshots);
      },
    );
  }

  final Ref _ref;

  /// The freshest confirmed count per habit, straight from the provider.
  ///
  /// A widget's `snapshot` can be a frame older than the provider: the
  /// provider updates, this drops its override, and the button only gets the
  /// new snapshot on the next build. A tap inside that window would compute
  /// from the stale count — for a yes/no habit, turning an intended undo into
  /// a second check-off. So the base count comes from here, not the widget.
  Map<String, int> _confirmed = const {};

  /// Writes are serialised per habit. Five quick taps are five transactions
  /// that must land in order, or an uncheck can overtake the check it undoes.
  final Map<String, Future<void>> _chains = {};
  final Map<String, int> _inFlight = {};

  /// The count to draw: the optimistic value if a write is pending, else the
  /// confirmed one.
  int countFor(HabitSnapshot snapshot) =>
      state[snapshot.habit.id] ??
      _confirmed[snapshot.habit.id] ??
      snapshot.countToday;

  bool isDoneFor(HabitSnapshot snapshot) =>
      countFor(snapshot) >= _target(snapshot.habit);

  /// One tap on the check button.
  ///
  /// Below target: one more check-off. At or above target: undo one. No
  /// confirm dialog — putting a tick back must cost exactly one tap.
  ///
  /// A habit not scheduled today is a no-op; the UI does not offer the button
  /// at all, and this is the backstop.
  Future<void> tap(HabitSnapshot snapshot) {
    if (!snapshot.isScheduledToday) return Future.value();
    // Fire-and-forget: the circle must not wait on the vibrator, and a
    // platform without haptics must not turn a check-off into an error.
    unawaited(HapticFeedback.lightImpact().catchError((_) {}));

    final habit = snapshot.habit;
    final id = habit.id;
    final current = countFor(snapshot);
    final undo = current >= _target(habit);
    state = {...state, id: undo ? current - 1 : current + 1};
    _inFlight[id] = (_inFlight[id] ?? 0) + 1;

    final repo = _ref.read(habitsRepositoryProvider);
    final completer = Completer<void>();
    final prior = _chains[id] ?? Future<void>.value();
    final op = prior.then((_) => undo ? repo.uncheck(id) : repo.check(id));
    _chains[id] = op.then((_) {}, onError: (_) {});

    op.then((_) {
      _settle(id, failed: false);
      _rescheduleReminder(habit);
      completer.complete();
    }, onError: (Object e, StackTrace st) {
      _settle(id, failed: true);
      completer.completeError(e, st);
    });
    return completer.future;
  }

  void _settle(String id, {required bool failed}) {
    final left = (_inFlight[id] ?? 1) - 1;
    _inFlight[id] = left;
    if (left > 0 || !mounted) return;
    if (failed) {
      // Put the circle back the way the database says it is.
      state = {...state}..remove(id);
      return;
    }
    _reconcile(_ref.read(habitSnapshotsProvider).value);
    // Backstop: if the stream is slow to deliver — or a write from elsewhere
    // (the day sheet) means the counts never match — do not let the override
    // outlive the write by more than a moment.
    _backstops.remove(id)?.cancel();
    _backstops[id] = Timer(const Duration(seconds: 2), () {
      _backstops.remove(id);
      if (mounted && (_inFlight[id] ?? 0) == 0 && state.containsKey(id)) {
        state = {...state}..remove(id);
      }
    });
  }

  final Map<String, Timer> _backstops = {};

  @override
  void dispose() {
    for (final t in _backstops.values) {
      t.cancel();
    }
    _backstops.clear();
    super.dispose();
  }

  /// Drops an override once the confirmed snapshot agrees with it.
  void _reconcile(List<HabitSnapshot>? snapshots) {
    if (snapshots == null || state.isEmpty || !mounted) return;
    Map<String, int>? next;
    for (final s in snapshots) {
      final id = s.habit.id;
      final want = state[id];
      if (want == null || (_inFlight[id] ?? 0) > 0) continue;
      if (s.countToday == want) (next ??= {...state}).remove(id);
    }
    if (next != null) state = next;
  }

  /// A check-off can change which day the next reminder belongs to: a habit
  /// completed today should not nag this evening.
  ///
  /// No early-out on "does this habit have reminders configured" any more —
  /// `scheduleForHabit` reads the habit's `habit_reminder_times` rows itself
  /// and is a cheap no-op when there aren't any.
  void _rescheduleReminder(Habit habit) {
    unawaited(() async {
      try {
        await _ref.read(reminderServiceProvider).scheduleForHabit(habit);
      } catch (_) {
        // Notifications unavailable (desktop, tests). The check-off stands.
      }
    }());
  }

  static int _target(Habit habit) =>
      habit.targetCount < 1 ? 1 : habit.targetCount;
}

final habitCheckControllerProvider =
    StateNotifierProvider<HabitCheckController, Map<String, int>>(
  (ref) => HabitCheckController(ref),
);

// ─────────────────────────────────────────────────────────────────────────────
// View mode — persisted in settings as `habit_view_mode`
// ─────────────────────────────────────────────────────────────────────────────

enum HabitViewMode { streak, list }

class HabitViewModeNotifier extends StateNotifier<HabitViewMode> {
  HabitViewModeNotifier(this._settingsRepo) : super(HabitViewMode.streak) {
    _load();
  }

  static const settingsKey = 'habit_view_mode';

  final SettingsRepository _settingsRepo;
  bool _userModified = false;

  Future<void> _load() async {
    try {
      final saved = await _settingsRepo.getString(settingsKey);
      if (!_userModified && saved != null && mounted) {
        super.state = HabitViewMode.values.firstWhere(
          (m) => m.name == saved,
          orElse: () => HabitViewMode.streak,
        );
      }
    } catch (_) {}
  }

  @override
  set state(HabitViewMode value) {
    _userModified = true;
    super.state = value;
    _settingsRepo.setString(settingsKey, value.name);
  }

  void toggle() => state =
      state == HabitViewMode.streak ? HabitViewMode.list : HabitViewMode.streak;
}

final habitViewModeProvider =
    StateNotifierProvider<HabitViewModeNotifier, HabitViewMode>((ref) {
  return HabitViewModeNotifier(ref.watch(settingsRepositoryProvider));
});
