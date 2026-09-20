import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../../core/constants/event_types.dart';
import '../../data/providers/database_provider.dart';
import '../../data/providers/habit_providers.dart';
import '../../data/repositories/habits_repository.dart';

class HomeScreenWidgetService {
  HomeScreenWidgetService({
    @visibleForTesting this.isPlatformSupported = true,
  });

  final bool isPlatformSupported;

  static const habitsWidgetName = 'CairnHabitsWidgetProvider';
  static const todayWidgetName = 'CairnTodayWidgetProvider';

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

      for (var i = 0; i < 4; i++) {
        if (i < sorted.length) {
          final h = sorted[i];
          final streak = h.streaks.current;
          final streakStr = streak > 0 ? '🔥 $streak' : '';

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
        } else {
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

  /// Syncs current app state to widgets from Riverpod WidgetRef.
  Future<void> syncAllWidgets(WidgetRef ref) async {
    if (!canUpdate) return;
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
    } catch (e, st) {
      debugPrint('HomeScreenWidgetService: failed to sync all widgets: $e\n$st');
    }
  }
}

final homeScreenWidgetServiceProvider = Provider<HomeScreenWidgetService>((ref) {
  return HomeScreenWidgetService();
});
