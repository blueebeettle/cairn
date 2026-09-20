import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/stats/statistics.dart';
import '../repositories/analytics_repository.dart';
import 'database_provider.dart';

/// Riverpod wiring for the Stats screen — SPEC.md §4.2, §4.4–4.8 and §4.13.
///
/// Kept out of `database_provider.dart` so the Stats work and the Today work
/// can be edited without landing on top of each other.

/// Same guard as the private one in `database_provider.dart`: under
/// `flutter test`, Drift's StreamQueryStore schedules a zero-duration timer
/// when a stream is cancelled during teardown, and an un-pumped timer fails
/// the test. Duplicated rather than shared to keep this file independent; if
/// the two ever need to change, change both.
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

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(
    db: ref.watch(databaseProvider),
    timeService: ref.watch(timeServiceProvider),
    settings: ref.watch(settingsRepositoryProvider),
  );
});

/// The ranges the Stats screen offers.
///
/// Thirty days is the default rather than a week. Most of §4 needs more than
/// seven points to say anything — §4.5 averages per weekday, so a week gives
/// every bar an n of 1 — and a screen that opens on a range where half the
/// metrics read "not enough data yet" teaches the user the screen is empty.
enum StatsRange {
  week('This week'),
  month('Last 30 days'),
  quarter('Last 90 days'),
  allTime('All time');

  const StatsRange(this.label);

  final String label;
}

final statsRangeProvider =
    StateProvider<StatsRange>((ref) => StatsRange.month);

final statsPeriodProvider = Provider<StatsPeriod>((ref) {
  final time = ref.watch(timeServiceProvider);
  final today = time.todayLocalDate();
  return switch (ref.watch(statsRangeProvider)) {
    StatsRange.week => StatsPeriod.week(time, today),
    StatsRange.month => StatsPeriod.lastNDays(today, 30),
    StatsRange.quarter => StatsPeriod.lastNDays(today, 90),
    StatsRange.allTime => StatsPeriod.allTime,
  };
});

/// Every §4 metric for the selected range, from one consistent read.
final statsBundleProvider = StreamProvider<StatsBundle>((ref) {
  final repo = ref.watch(analyticsRepositoryProvider);
  final period = ref.watch(statsPeriodProvider);
  return _testSafeStream(repo.watch(period));
});

/// SPEC.md §4.13. Always the trailing 365 days, independent of the range
/// picker above — a contribution heatmap that changed length when you switched
/// tabs would not be a contribution heatmap.
final heatmapProvider = StreamProvider<List<HeatmapCell>>((ref) {
  final repo = ref.watch(analyticsRepositoryProvider);
  final time = ref.watch(timeServiceProvider);
  return _testSafeStream(
    repo.watchHeatmap(todayLocalDate: time.todayLocalDate()),
  );
});

/// The legend for the heatmap: the thresholds actually in force, including
/// whether they are still the provisional fixed ones.
final heatmapThresholdsProvider = FutureProvider<HeatmapThresholds>((ref) {
  final repo = ref.watch(analyticsRepositoryProvider);
  final time = ref.watch(timeServiceProvider);
  return repo.heatmapThresholds(todayLocalDate: time.todayLocalDate());
});
