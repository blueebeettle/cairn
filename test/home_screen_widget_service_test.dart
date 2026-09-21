import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/data/database/app_database.dart' hide TimerState;
import 'package:habit_tracker/data/providers/database_provider.dart';
import 'package:habit_tracker/data/repositories/tasks_repository.dart';
import 'package:habit_tracker/features/timer/domain/timer_state.dart';
import 'package:habit_tracker/features/widgets/home_screen_widget_service.dart';

void main() {
  group('HomeScreenWidgetService', () {
    test('formatDate correctly formats YYYY-MM-DD to readable weekday and month', () {
      expect(HomeScreenWidgetService.formatDate('2026-09-20'), equals('Sun, Sep 20'));
      expect(HomeScreenWidgetService.formatDate('2026-01-01'), equals('Thu, Jan 1'));
      expect(HomeScreenWidgetService.formatDate('2026-12-25'), equals('Fri, Dec 25'));
      expect(HomeScreenWidgetService.formatDate('invalid-date'), equals('invalid-date'));
    });

    test('parseWidgetUri correctly resolves deep-link targets', () {
      expect(
        HomeScreenWidgetService.parseWidgetUri(Uri.parse('cairn://widget/habits')),
        equals(NavTabs.habits),
      );
      expect(
        HomeScreenWidgetService.parseWidgetUri(Uri.parse('cairn://widget/timer')),
        equals(NavTabs.timer),
      );
      expect(
        HomeScreenWidgetService.parseWidgetUri(Uri.parse('cairn://widget/today')),
        equals(NavTabs.today),
      );
      expect(
        HomeScreenWidgetService.parseWidgetUri(Uri.parse('cairn://widget/tasks')),
        equals(NavTabs.tasks),
      );
      expect(
        HomeScreenWidgetService.parseWidgetUri(Uri.parse('cairn://widget/stats')),
        equals(NavTabs.stats),
      );
      expect(
        HomeScreenWidgetService.parseWidgetUri(Uri.parse('https://example.com/habits')),
        isNull,
      );
    });

    test('canUpdate is false when platform is not supported', () {
      final service = HomeScreenWidgetService(isPlatformSupported: false);
      expect(service.canUpdate, isFalse);
    });

    test('updateHabitsWidget and updateTodayWidget are safe no-ops when platform is unsupported', () async {
      final service = HomeScreenWidgetService(isPlatformSupported: false);
      await expectLater(
        service.updateHabitsWidget(habits: const [], todayLocalDate: '2026-09-20'),
        completes,
      );
      await expectLater(
        service.updateTodayWidget(
          focusMinutesToday: 45,
          habitsDone: 3,
          habitsTotal: 5,
          tasksDueCount: 2,
        ),
        completes,
      );
    });

    test('updateTasksWidget and updateTimerWidget are safe no-ops when platform is unsupported', () async {
      final service = HomeScreenWidgetService(isPlatformSupported: false);
      await expectLater(
        service.updateTasksWidget(todayTasks: const []),
        completes,
      );
      await expectLater(
        service.updateTimerWidget(const TimerState()),
        completes,
      );
    });
  });

  group('HomeScreenWidgetService — tasks widget ordering', () {
    TaskWithDetails task(String id, int priority, double sortOrder, String status) {
      return TaskWithDetails(
        task: Task(
          id: id,
          title: 'Task $id',
          status: status,
          priority: priority,
          sortOrder: sortOrder,
          dueIsAllDay: false,
          rescheduleCount: 0,
          createdAt: 0,
          createdLocalDate: '2026-09-21',
          updatedAt: 0,
          deviceId: 'test-device',
        ),
      );
    }

    test('drops non-open tasks and sorts by priority, then sort order', () {
      final sorted = HomeScreenWidgetService.sortTasksForWidget([
        task('c', 2, 0.0, 'open'),
        task('done', 1, 0.0, 'done'),
        task('a', 1, 5.0, 'open'),
        task('archived', 1, 1.0, 'archived'),
        task('b', 1, 9.0, 'open'),
        task('d', 4, 0.0, 'open'),
      ]);

      expect(sorted.map((t) => t.id).toList(), equals(['a', 'b', 'c', 'd']));
    });

    test('keeps an already-ordered list stable', () {
      final sorted = HomeScreenWidgetService.sortTasksForWidget([
        task('a', 1, 0.0, 'open'),
        task('b', 2, 0.0, 'open'),
        task('c', 3, 0.0, 'open'),
      ]);
      expect(sorted.map((t) => t.id).toList(), equals(['a', 'b', 'c']));
    });
  });

  group('HomeScreenWidgetService — timer widget rendering', () {
    const t0 = 1788948000000;

    test('formatMmSs pads and clamps negatives', () {
      expect(HomeScreenWidgetService.formatMmSs(0), equals('00:00'));
      expect(HomeScreenWidgetService.formatMmSs(65), equals('01:05'));
      expect(HomeScreenWidgetService.formatMmSs(1500), equals('25:00'));
      expect(HomeScreenWidgetService.formatMmSs(-30), equals('00:00'));
    });

    test('idle previews the configured session length', () {
      final (status, text) = HomeScreenWidgetService.describeTimerForWidget(
        const TimerState(plannedDurationS: 3000),
        t0,
      );
      expect(status, equals('idle'));
      expect(text, equals('50:00'));
    });

    test('running counts down from the planned duration', () {
      final (status, text) = HomeScreenWidgetService.describeTimerForWidget(
        const TimerState(
          status: TimerStatus.running,
          sessionId: 's1',
          startedAtUtc: t0,
          plannedDurationS: 1500,
        ),
        t0 + 300000,
      );
      expect(status, equals('running'));
      expect(text, equals('20:00'));
    });

    test('paused freezes remaining time as the clock keeps moving', () {
      const state = TimerState(
        status: TimerStatus.paused,
        sessionId: 's1',
        startedAtUtc: t0,
        plannedDurationS: 1500,
        pausedAtUtc: t0 + 300000,
      );
      final (status, text) =
          HomeScreenWidgetService.describeTimerForWidget(state, t0 + 900000);
      expect(status, equals('paused'));
      expect(text, equals('20:00'));
    });

    test('flow counts up, since it has no planned end', () {
      final (status, text) = HomeScreenWidgetService.describeTimerForWidget(
        const TimerState(
          status: TimerStatus.running,
          mode: TimerMode.flow,
          sessionId: 's1',
          startedAtUtc: t0,
          plannedDurationS: 0,
        ),
        t0 + 300000,
      );
      expect(status, equals('running'));
      expect(text, equals('05:00'));
    });

    test('anchor is the zero instant while counting down', () {
      const state = TimerState(
        status: TimerStatus.running,
        sessionId: 's1',
        startedAtUtc: t0,
        plannedDurationS: 1500,
        pausedAccumulatedS: 60,
      );
      // Paused time pushes the finish line back by exactly that much.
      expect(
        HomeScreenWidgetService.timerAnchorUtcMs(state, t0 + 1000),
        equals(t0 + (1500 + 60) * 1000),
      );
    });

    test('anchor is the start instant while counting up (Flow)', () {
      const state = TimerState(
        status: TimerStatus.running,
        mode: TimerMode.flow,
        sessionId: 's1',
        startedAtUtc: t0,
        plannedDurationS: 0,
        pausedAccumulatedS: 30,
      );
      expect(
        HomeScreenWidgetService.timerAnchorUtcMs(state, t0 + 1000),
        equals(t0 + 30 * 1000),
      );
    });

    test('anchor is null when nothing is ticking', () {
      // Paused: the widget must show a frozen value, not a running clock.
      expect(
        HomeScreenWidgetService.timerAnchorUtcMs(
          const TimerState(
            status: TimerStatus.paused,
            sessionId: 's1',
            startedAtUtc: t0,
            plannedDurationS: 1500,
            pausedAtUtc: t0 + 60000,
          ),
          t0 + 120000,
        ),
        isNull,
      );
      expect(
        HomeScreenWidgetService.timerAnchorUtcMs(const TimerState(), t0),
        isNull,
      );
    });

    test('anchor follows the break to its end', () {
      const state = TimerState(
        status: TimerStatus.breakRunning,
        breakDurationS: 300,
        breakStartedAtUtc: t0,
      );
      expect(
        HomeScreenWidgetService.timerAnchorUtcMs(state, t0 + 1000),
        equals(t0 + 300 * 1000),
      );
    });

    test('break reports its own remaining time', () {
      final (status, text) = HomeScreenWidgetService.describeTimerForWidget(
        const TimerState(
          status: TimerStatus.breakRunning,
          breakDurationS: 300,
          breakStartedAtUtc: t0,
        ),
        t0 + 60000,
      );
      expect(status, equals('break'));
      expect(text, equals('04:00'));
    });
  });
}
