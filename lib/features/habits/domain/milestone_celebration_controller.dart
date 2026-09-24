import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/providers/database_provider.dart';
import '../../../data/providers/habit_providers.dart';
import '../../../data/repositories/habits_repository.dart';
import 'habit_presentation.dart';

/// A milestone that just fired and is waiting for the celebration screen to
/// open and consume it.
@immutable
class PendingMilestoneCelebration {
  const PendingMilestoneCelebration({
    required this.habitId,
    required this.streak,
  });

  final String habitId;

  /// The threshold just crossed (`MilestoneThresholds.reached(streak)` is
  /// true) — not necessarily the habit's live current streak by the time the
  /// screen opens, though in practice nothing moves it in that gap.
  final int streak;
}

/// Detects a habit's streak crossing a `MilestoneThresholds` round number for
/// the first time, and holds the one-shot event a UI layer consumes to open
/// the full-screen celebration.
///
/// This is the "celebrated once" half of §9. `MilestoneThresholds.reached`
/// (§5) already keeps day 31 of a 30-day streak from looking like a
/// milestone; what it does not do is stop day 30 itself from being seen more
/// than once — a resumed app, a second habit's snapshot recomputing the same
/// tick, a stream replay. That is what the persisted highest-celebrated
/// marker below is for.
///
/// Persisted in the existing `settings` key-value table as one JSON map
/// (habit id -> highest streak celebrated), rather than a new Drift column —
/// §9 asks to check for something that already fits before adding schema,
/// and `settings` already holds exactly this shape of flag (see
/// `habit_view_mode`, `theme_mode` and friends in `database_provider.dart`).
class MilestoneCelebrationController
    extends StateNotifier<PendingMilestoneCelebration?> {
  MilestoneCelebrationController(this._ref) : super(null) {
    _ref.listen<AsyncValue<List<HabitSnapshot>>>(
      habitSnapshotsProvider,
      (_, next) {
        if (next.isLoading) return; // a reload carries the previous value
        final snapshots = next.value;
        if (snapshots != null && _loaded) _checkForNewMilestones(snapshots);
      },
    );
    _initialized = _load();
  }

  /// Settings key. Versioned in case the stored shape ever needs to change —
  /// an unrecognised value is treated as "nothing celebrated yet", never as
  /// a crash.
  static const String settingsKey = 'milestone_celebrated_v1';

  final Ref _ref;
  Map<String, int> _celebrated = const {};
  bool _loaded = false;
  late final Future<void> _initialized;

  /// Resolves once the persisted record has loaded and the snapshot on hand
  /// at that moment has been checked against it. Exposed so tests can await
  /// startup instead of racing the settings read.
  Future<void> get initialized => _initialized;

  Future<void> _load() async {
    try {
      final raw = await _ref.read(settingsRepositoryProvider).get(settingsKey);
      if (raw is Map) {
        _celebrated = raw.map(
          (key, value) => MapEntry(key as String, (value as num).toInt()),
        );
      }
    } catch (_) {
      // A fresh install (nothing stored yet) or a settings read that failed
      // both leave `_celebrated` empty. The safe direction for that error is
      // "a milestone celebrates a second time", never "stops celebrating".
    }
    _loaded = true;
    if (!mounted) return;

    // The provider may already have resolved while the settings read was in
    // flight. `ref.listen` below only fires on the *next* change, so without
    // this check a milestone reached before this controller finished loading
    // — the common case, since habits load before settings round-trip — would
    // never be seen.
    final current = _ref.read(habitSnapshotsProvider).value;
    if (current != null) _checkForNewMilestones(current);
  }

  void _checkForNewMilestones(List<HabitSnapshot> snapshots) {
    if (!mounted) return;
    for (final snapshot in snapshots) {
      final milestone = snapshot.milestoneToday;
      if (milestone == null) continue;
      final already = _celebrated[snapshot.habit.id] ?? 0;
      if (milestone <= already) continue;

      _celebrated = {..._celebrated, snapshot.habit.id: milestone};
      unawaited(
        _ref.read(settingsRepositoryProvider).set(settingsKey, _celebrated),
      );
      state = PendingMilestoneCelebration(
        habitId: snapshot.habit.id,
        streak: milestone,
      );
      // One at a time. A second habit crossing a threshold on the same
      // snapshot gets its turn on the next recomputation, once this one is
      // consumed — piling two full-screen celebrations back to back would
      // just mean tapping through the second to get back to the app.
      return;
    }
  }

  /// Clears the pending celebration once the UI has opened it. Does not
  /// touch `_celebrated` — that record is what stops the *next* recomputation
  /// from re-firing the same milestone, independent of when this is called.
  void consume() {
    if (mounted) state = null;
  }
}

final milestoneCelebrationControllerProvider = StateNotifierProvider<
    MilestoneCelebrationController, PendingMilestoneCelebration?>(
  (ref) => MilestoneCelebrationController(ref),
);
