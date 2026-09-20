import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../repositories/habits_repository.dart';
import 'database_provider.dart';

/// Habit providers (SPEC.md §10).
///
/// Kept in their own file rather than appended to `database_provider.dart`,
/// for the same reason `analytics_providers.dart` is separate: two features
/// being built at once should not be editing the same file.

/// Drift's `.watch()` stream is cancelled when the last listener goes away,
/// which under `flutter_test` can happen between a pump and an expect.
/// Duplicated from `analytics_providers.dart` deliberately — sharing it would
/// mean a common file both features have to touch.
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
      // Deliberately not cancelling the Drift stream under test.
    };
  };
  return controller.stream;
}

final habitsRepositoryProvider = Provider<HabitsRepository>((ref) {
  return HabitsRepository(
    db: ref.watch(databaseProvider),
    eventsRepository: ref.watch(eventsRepositoryProvider),
    timeService: ref.watch(timeServiceProvider),
    deviceId: ref.watch(deviceIdProvider),
  );
});

/// Raw habit rows, for pickers and reordering.
final activeHabitsProvider = StreamProvider<List<Habit>>((ref) {
  final repo = ref.watch(habitsRepositoryProvider);
  return _testSafeStream(repo.watchActiveHabits());
});

final archivedHabitsProvider = StreamProvider<List<Habit>>((ref) {
  final repo = ref.watch(habitsRepositoryProvider);
  return _testSafeStream(repo.watchArchivedHabits());
});

/// Ticks whenever any habit entry changes.
///
/// Exists only to be depended on. A check-off writes `habit_entries`, and a
/// Drift stream only fires for the tables it actually reads — so watching the
/// `habits` list alone would leave every streak on screen stale until
/// something happened to touch a habit row.
final _habitEntryTicksProvider = StreamProvider<List<HabitEntry>>((ref) {
  final db = ref.watch(databaseProvider);
  return _testSafeStream(db.select(db.habitEntries).watch());
});

/// Every active habit with its history and computed streaks.
///
/// Depends on both tables, so a check-off refreshes the streaks without the
/// UI having to invalidate anything by hand.
final habitSnapshotsProvider = FutureProvider<List<HabitSnapshot>>((ref) async {
  final repo = ref.watch(habitsRepositoryProvider);
  await ref.watch(activeHabitsProvider.future);
  await ref.watch(_habitEntryTicksProvider.future);
  return repo.loadActiveSnapshots();
});

/// One habit's snapshot, for the detail screen.
final habitSnapshotProvider =
    FutureProvider.family<HabitSnapshot?, String>((ref, habitId) async {
  final snapshots = await ref.watch(habitSnapshotsProvider.future);
  for (final snapshot in snapshots) {
    if (snapshot.habit.id == habitId) return snapshot;
  }
  // Archived habits are not in the active list but still have a detail screen.
  return ref.watch(habitsRepositoryProvider).loadSnapshot(habitId);
});

/// Day notes for one habit, newest first — the journal timeline.
final habitJournalProvider =
    FutureProvider.family<List<HabitEntry>, String>((ref, habitId) async {
  await ref.watch(habitSnapshotsProvider.future);
  return ref.watch(habitsRepositoryProvider).journalFor(habitId);
});

/// How many of today's scheduled habits are done — "3 of 5 today".
final habitsDoneTodayProvider = Provider<({int done, int due})>((ref) {
  final snapshots = ref.watch(habitSnapshotsProvider).value ?? const [];
  final dueToday = snapshots.where((s) => s.isScheduledToday).toList();
  return (
    done: dueToday.where((s) => s.isDoneToday).length,
    due: dueToday.length,
  );
});
