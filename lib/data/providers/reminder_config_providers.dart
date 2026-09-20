import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../repositories/reminder_config_repository.dart';
import 'database_provider.dart';

/// Reminder-config providers (SPEC.md §10.4/§11).
///
/// Kept in their own file rather than appended to `database_provider.dart`,
/// for the same reason `habit_providers.dart` is separate: a feature that
/// touches many screens should not be sharing a file with everything else
/// that does too.

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

final reminderConfigRepositoryProvider = Provider<ReminderConfigRepository>((ref) {
  return ReminderConfigRepository(
    db: ref.watch(databaseProvider),
    eventsRepository: ref.watch(eventsRepositoryProvider),
    settingsRepo: ref.watch(settingsRepositoryProvider),
    timeService: ref.watch(timeServiceProvider),
    deviceId: ref.watch(deviceIdProvider),
  );
});

/// One task's configured countdown reminders, ascending by offset.
final taskReminderOffsetsProvider =
    StreamProvider.family<List<TaskReminderOffset>, String>((ref, taskId) {
  final repo = ref.watch(reminderConfigRepositoryProvider);
  return _testSafeStream(repo.watchTaskReminderOffsets(taskId));
});

/// One habit's configured time-of-day reminders, ascending.
final habitReminderTimesProvider =
    StreamProvider.family<List<HabitReminderTime>, String>((ref, habitId) {
  final repo = ref.watch(reminderConfigRepositoryProvider);
  return _testSafeStream(repo.watchHabitReminderTimes(habitId));
});
