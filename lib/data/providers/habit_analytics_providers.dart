import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/stats/habit_statistics.dart';
import '../../core/stats/statistics.dart' show HeatmapThresholds;
import '../repositories/habit_analytics_repository.dart';
import 'analytics_providers.dart' show statsPeriodProvider;
import 'database_provider.dart';
import 'habit_providers.dart';

/// Riverpod wiring for the habit half of the Stats screen (SPEC.md §10.5).
///
/// Kept out of both `analytics_providers.dart` and `habit_providers.dart` so
/// the Stats-screen habit work can be edited without landing on top of either
/// the focus-session stats work or the Habits-screen work.
///
/// Reuses `statsRangeProvider`/`statsPeriodProvider` from
/// `analytics_providers.dart` rather than defining a second range picker —
/// one range picker on the Stats screen driving both halves is the whole
/// point of putting habits on the same screen.

/// Duplicated from `analytics_providers.dart` / `habit_providers.dart`
/// deliberately — see either file's copy for why.
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

final habitAnalyticsRepositoryProvider = Provider<HabitAnalyticsRepository>((ref) {
  return HabitAnalyticsRepository(
    db: ref.watch(databaseProvider),
    timeService: ref.watch(timeServiceProvider),
    settings: ref.watch(settingsRepositoryProvider),
    habitsRepository: ref.watch(habitsRepositoryProvider),
  );
});

/// Every §10.5 habit metric for the selected range, from one consistent read.
final habitStatsBundleProvider = StreamProvider<HabitStatsBundle>((ref) {
  final repo = ref.watch(habitAnalyticsRepositoryProvider);
  final period = ref.watch(statsPeriodProvider);
  return _testSafeStream(repo.watch(period));
});

/// The trailing 365 days, independent of the range picker — same reasoning
/// as `heatmapProvider` in `analytics_providers.dart`.
final habitHeatmapProvider = StreamProvider<List<HabitHeatmapCell>>((ref) {
  final repo = ref.watch(habitAnalyticsRepositoryProvider);
  final time = ref.watch(timeServiceProvider);
  return _testSafeStream(
    repo.watchHeatmap(todayLocalDate: time.todayLocalDate()),
  );
});

/// The legend for the habit heatmap: the thresholds actually in force.
final habitHeatmapThresholdsProvider = FutureProvider<HeatmapThresholds>((ref) {
  final repo = ref.watch(habitAnalyticsRepositoryProvider);
  final time = ref.watch(timeServiceProvider);
  return repo.heatmapThresholds(todayLocalDate: time.todayLocalDate());
});
