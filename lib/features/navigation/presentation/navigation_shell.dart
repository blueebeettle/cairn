import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:home_widget/home_widget.dart';

import '../../../data/providers/database_provider.dart';
import '../../../data/providers/habit_providers.dart';
import '../../habits/domain/milestone_celebration_controller.dart';
import '../../habits/presentation/habit_detail_screen.dart';
import '../../habits/presentation/habits_screen.dart';
import '../../habits/presentation/milestone_celebration_screen.dart';
import '../../reminders/reminder_service.dart';
import '../../stats/presentation/stats_screen.dart';
import '../../tasks/presentation/tasks_screen.dart';
import '../../timer/presentation/timer_controller.dart';
import '../../timer/presentation/timer_screen.dart';
import '../../today/presentation/today_screen.dart';
import '../../widgets/home_screen_widget_service.dart';

/// Root navigation shell with Material 3 NavigationBar per SPEC.md Phase 01.
///
/// Five destinations — the Material 3 maximum. Nothing else can be added to
/// this bar without rethinking the navigation.
class NavigationShell extends ConsumerStatefulWidget {
  const NavigationShell({super.key});

  @override
  ConsumerState<NavigationShell> createState() => _NavigationShellState();
}

class _NavigationShellState extends ConsumerState<NavigationShell>
    with WidgetsBindingObserver {
  // Order must match [NavTabs].
  static const List<Widget> _screens = [
    TodayScreen(),
    TimerScreen(),
    TasksScreen(),
    HabitsScreen(),
    StatsScreen(),
  ];

  Timer? _dayWatch;
  String? _lastLogicalDay;
  StreamSubscription<Uri?>? _widgetClickSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastLogicalDay = ref.read(timeServiceProvider).todayLocalDate();
    // Habit snapshots resolve outcomes against "today". Nothing in the
    // database changes when the logical day rolls over, so no stream fires —
    // without this, an app left open overnight shows yesterday's pending day
    // as still pending, and a missed day never registers as missed.
    _dayWatch = Timer.periodic(const Duration(minutes: 1), (_) => _checkDay());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openPendingHabit();
      _initWidgetDeepLinks();
      ref.read(homeScreenWidgetServiceProvider).syncAllWidgets(ref);
    });
  }

  void _initWidgetDeepLinks() {
    try {
      HomeWidget.initiallyLaunchedFromHomeWidget().then((uri) {
        if (uri != null) _handleWidgetClick(uri);
      });
      _widgetClickSub = HomeWidget.widgetClicked.listen((uri) {
        if (uri != null) _handleWidgetClick(uri);
      });
    } catch (_) {}
  }

  void _handleWidgetClick(Uri uri) {
    final tab = HomeScreenWidgetService.parseWidgetUri(uri);
    if (tab == null || !mounted) return;
    ref.read(navigationIndexProvider.notifier).state = tab;

    // A task row carries its id so the Tasks tab can open straight onto it,
    // the same way a tapped task reminder does.
    if (tab == NavTabs.tasks) {
      final taskId = uri.queryParameters['id'];
      if (taskId != null && taskId.isNotEmpty) {
        ref.read(activeTaskIdProvider.notifier).state = taskId;
      }
    }
  }

  @override
  void dispose() {
    _widgetClickSub?.cancel();
    _dayWatch?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkDay(onResume: true);
      // Widget taps mutate timer_states from a background isolate, so re-read
      // the DB before pushing anything back out — otherwise the outbound sync
      // would overwrite the widget with this controller's stale view.
      unawaited(() async {
        await ref.read(timerControllerProvider.notifier).reconcileOnResume();
        if (!mounted) return;
        await ref.read(homeScreenWidgetServiceProvider).syncAllWidgets(ref);
      }());
    }
  }

  void _checkDay({bool onResume = false}) {
    if (!mounted) return;
    final today = ref.read(timeServiceProvider).todayLocalDate();
    final rolledOver = today != _lastLogicalDay;
    _lastLogicalDay = today;
    if (!rolledOver && !onResume) return;

    ref.invalidate(habitSnapshotsProvider);
    // Habit reminders are one-shot (next scheduled day only). Re-plan them
    // when the day turns or the app comes back, so the chain never runs dry.
    final reminders = ref.read(reminderServiceProvider);
    unawaited(() async {
      try {
        await reminders.reconcileHabits();
      } catch (_) {}
    }());
  }

  void _openPendingHabit() {
    final habitId = ref.read(pendingHabitDetailProvider);
    if (habitId == null || !mounted) return;
    ref.read(pendingHabitDetailProvider.notifier).state = null;
    ref.read(navigationIndexProvider.notifier).state = NavTabs.habits;
    HabitDetailScreen.open(context, habitId);
  }

  /// Opens §4's full-screen celebration for a milestone
  /// `MilestoneCelebrationController` just detected, the same
  /// consume-then-navigate shape as [_openPendingHabit] above.
  void _openMilestoneCelebration(PendingMilestoneCelebration pending) {
    ref.read(milestoneCelebrationControllerProvider.notifier).consume();
    if (!mounted) return;
    MilestoneCelebrationScreen.open(
      context,
      habitId: pending.habitId,
      streak: pending.streak,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navigationIndexProvider);
    ref.listen<String?>(pendingHabitDetailProvider, (_, next) {
      if (next != null) _openPendingHabit();
    });
    ref.listen<PendingMilestoneCelebration?>(
      milestoneCelebrationControllerProvider,
      (_, next) {
        if (next != null) _openMilestoneCelebration(next);
      },
    );

    // Automatically synchronize home screen widgets on data updates
    ref.listen(habitSnapshotsProvider, (_, next) {
      ref.read(homeScreenWidgetServiceProvider).syncAllWidgets(ref);
    });
    ref.listen(focusStatsStreamProvider, (_, next) {
      ref.read(homeScreenWidgetServiceProvider).syncAllWidgets(ref);
    });
    final todayDate = ref.watch(timeServiceProvider).todayLocalDate();
    ref.listen(todayTasksStreamProvider(todayDate), (_, next) {
      ref.read(homeScreenWidgetServiceProvider).syncAllWidgets(ref);
    });
    // Status only, never the whole state: the 500ms ticker re-emits state on
    // every tick, and pushing a widget update that often is wasted battery
    // (Android throttles rapid updateWidget calls anyway).
    ref.listen(timerControllerProvider.select((s) => s.status), (_, _) {
      ref.read(homeScreenWidgetServiceProvider).syncAllWidgets(ref);
    });

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          ref.read(navigationIndexProvider.notifier).state = index;
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today_rounded),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer_rounded),
            label: 'Focus',
          ),
          NavigationDestination(
            icon: Icon(Icons.check_circle_outline_rounded),
            selectedIcon: Icon(Icons.check_circle_rounded),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_fire_department_outlined),
            selectedIcon: Icon(Icons.local_fire_department_rounded),
            label: 'Habits',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'Stats',
          ),
        ],
      ),
    );
  }
}
