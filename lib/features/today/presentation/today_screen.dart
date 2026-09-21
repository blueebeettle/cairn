import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/time_service.dart';
import '../../../core/widgets/focus_ring.dart';
import '../../../data/database/app_database.dart';
import '../../../data/providers/database_provider.dart';
import '../../../data/repositories/stats_repository.dart';
import '../../../data/repositories/tasks_repository.dart';
import '../../../theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import '../../../core/widgets/feature_info.dart';
import '../../../core/widgets/feature_info_content.dart';
import '../../developer/presentation/developer_events_screen.dart';
import '../../habits/presentation/widgets/today_habits_section.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../tasks/presentation/tasks_screen.dart';
import '../../tasks/presentation/widgets/quick_capture_sheet.dart';
import '../../tasks/presentation/widgets/task_deletion_handler.dart';
import '../../tasks/presentation/widgets/task_detail_sheet.dart';
import '../../timer/presentation/timer_controller.dart';

/// The Today screen rebuild per SPEC.md and M3 component theming.
///
/// Features:
/// - One date inline with ‹ › (forward arrow disables on today).
/// - Small chips for Streak and Best ever.
/// - 7-day bar strip powered by [StatsRepository.watchLast7DaysSummary].
/// - Primary circular focus-progress ring (today's minutes against goal, tap to start session).
/// - Readable session list from [focus_sessions] (duration, mode, start-end, interruptions, de-emphasized abandoned).
class TodayScreen extends ConsumerStatefulWidget {
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  bool _isCompletedExpanded = false;
  bool _isOverdueExpanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    final timeService = ref.watch(timeServiceProvider);
    final todayLocalDate = timeService.todayLocalDate();
    final selectedDate = ref.watch(selectedDateProvider);
    final currentViewDate = selectedDate ?? todayLocalDate;
    final isToday = currentViewDate == todayLocalDate;

    final focusStatsAsync = ref.watch(focusStatsStreamProvider);
    final focusStats = focusStatsAsync.value ?? FocusStats.empty;

    final last7DaysAsync = ref.watch(last7DaysSummaryStreamProvider);
    final sessionsAsync = ref.watch(sessionsForDateStreamProvider(currentViewDate));
    final tasksAsync = ref.watch(todayTasksStreamProvider(currentViewDate));

    final streakFigure =
        '${focusStats.currentStreakDays} ${focusStats.currentStreakDays == 1 ? 'day' : 'days'}';

    final goalProgress = focusStats.dailyGoalMinutes > 0
        ? (focusStats.focusMinutesToday / focusStats.dailyGoalMinutes).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Today',
          style: textTheme.headlineSmall?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          const FeatureInfoButton(info: FeatureInfoContent.today),
          // Settings screen action per POLISH §4
          IconButton(
            tooltip: 'Settings',
            icon: Semantics(
              label: 'Settings',
              button: true,
              child: const Icon(Icons.settings_outlined),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
          // Developer screen action to inspect raw immutable event stream
          if (!kReleaseMode)
          IconButton(
            tooltip: 'Developer Event Stream',
            icon: Semantics(
              label: 'Developer Event Stream',
              button: true,
              child: const Icon(Icons.developer_mode_outlined),
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DeveloperEventsScreen(),
                ),
              );
            },
          ),
          // Quick theme mode toggle button
          IconButton(
            tooltip: 'Toggle Theme',
            icon: Semantics(
              label: 'Toggle Theme',
              button: true,
              child: Icon(
                Theme.of(context).brightness == Brightness.dark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                color: colors.primary,
              ),
            ),
            onPressed: () {
              final current = ref.read(themeModeProvider);
              final next = current == ThemeMode.dark
                  ? ThemeMode.light
                  : current == ThemeMode.light
                      ? ThemeMode.system
                      : ThemeMode.dark;
              ref.read(themeModeProvider.notifier).state = next;
            },
          ),
          // Today button (enabled when not on today to quickly return).
          // Compact padding: this bar carries five actions, and at a 200%
          // font scale the default TextButton padding is what tips the row
          // into an overflow.
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: isToday
                ? null
                : () {
                    ref.read(selectedDateProvider.notifier).state = null;
                  },
            child: const Text('Today'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
          children: [
            // ── 1. Inline Date Navigation ────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Semantics(
                    label: 'Previous day',
                    button: true,
                    child: const Icon(Icons.chevron_left_rounded),
                  ),
                  tooltip: 'Previous day',
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  onPressed: () {
                    ref.read(selectedDateProvider.notifier).state =
                        TimeService.addDays(currentViewDate, -1);
                  },
                ),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      _formatFriendlyDate(currentViewDate),
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                IconButton(
                  icon: Semantics(
                    label: 'Next day',
                    button: true,
                    child: const Icon(Icons.chevron_right_rounded),
                  ),
                  tooltip: 'Next day',
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  // Forward arrow disables on today per requirement
                  onPressed: isToday
                      ? null
                      : () {
                          ref.read(selectedDateProvider.notifier).state =
                              TimeService.addDays(currentViewDate, 1);
                        },
                ),
              ],
            ),
            const SizedBox(height: 2),

            // ── 2. Small Chips: Streak & Best Ever ───────────────────────────
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Chip(
                  avatar: Icon(
                    Icons.local_fire_department_rounded,
                    size: 16,
                    color: colors.primary,
                  ),
                  label: Text(
                    streakFigure,
                    overflow: TextOverflow.ellipsis,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  labelPadding: const EdgeInsets.only(left: 4, right: 8),
                ),
                Chip(
                  avatar: Icon(
                    Icons.emoji_events_outlined,
                    size: 16,
                    color: tokens.warning,
                  ),
                  label: Text(
                    'Best: ${focusStats.longestStreakDays}d',
                    overflow: TextOverflow.ellipsis,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  labelPadding: const EdgeInsets.only(left: 4, right: 8),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // ── 3. 7-Day Bar Strip (StatsRepository Query) ───────────────────
            last7DaysAsync.when(
              data: (days) => _build7DayBarStrip(context, ref, days, currentViewDate),
              loading: () => const SizedBox(height: 36),
              error: (err, stack) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 20), // week strip -> ring 20dp

            // ── 4. Primary Element: FocusRing (0.58 factor on Today) ─────────
            Center(
              child: FocusRing(
                widthFactor: 0.58,
                progress: goalProgress,
                figure: _formatFocusTime(focusStats.focusMinutesToday),
                label: 'TODAY',
                semanticsAnnouncement:
                    '${focusStats.focusMinutesToday} of ${focusStats.dailyGoalMinutes} minutes, TODAY',
                onTap: () {
                  // Primary action: tap to start a session in Timer tab
                  ref.read(navigationIndexProvider.notifier).state = 1;
                },
              ),
            ),
            const SizedBox(height: 16), // ring -> caption text 16dp

            // Caption text
            Center(
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  ref.read(navigationIndexProvider.notifier).state = 1;
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Goal: ${focusStats.dailyGoalMinutes} min',
                          style: textTheme.titleSmall?.copyWith(
                            color: tokens.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '•',
                          style: textTheme.titleSmall?.copyWith(
                            color: tokens.textMuted,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Ready to focus',
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28), // caption -> TASKS 28dp

            // ── 5. Tasks for Date ────────────────────────────────────────────
            _buildTasksSection(context, ref, tasksAsync, currentViewDate, isToday),
            const SizedBox(height: 28), // TASKS -> HABITS/SESSIONS 28dp

            // ── 5b. Habits due today ─────────────────────────────────────────
            // Today only: the section is today's check-offs, and showing them
            // under a past date would invite checking off the wrong day.
            // Renders nothing (and carries its own bottom gap) when no habit
            // is scheduled today.
            if (isToday) const TodayHabitsSection(),

            // ── 6. Focus Sessions List ───────────────────────────────────────
            Text(
              'SESSIONS',
              style: textTheme.labelSmall?.copyWith(
                color: tokens.textMuted,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),

            sessionsAsync.when(
              data: (sessions) {
                if (sessions.isEmpty) {
                  final emptyMessage = isToday
                      ? 'No sessions yet today.'
                      : 'No sessions on ${_formatFriendlyDate(currentViewDate)}.';

                  return Card(
                    color: colors.surfaceContainerLow,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      child: Center(
                        child: Text(
                          emptyMessage,
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall?.copyWith(
                            color: tokens.textMuted,
                          ),
                        ),
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    for (final session in sessions)
                      _buildSessionCard(context, timeService, session),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (err, _) => Card(
                color: colors.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Error loading sessions: $err',
                    style: TextStyle(color: colors.onErrorContainer),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 7-Day Bar Strip ────────────────────────────────────────────────────────

  Widget _build7DayBarStrip(
    BuildContext context,
    WidgetRef ref,
    List<DayFocusSummary> days,
    String currentViewDate,
  ) {
    final colors = context.colors;
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    final maxMinutes = days.fold<int>(25, (max, d) => d.minutes > max ? d.minutes : max);

    return Card(
      color: colors.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (final day in days)
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    ref.read(selectedDateProvider.notifier).state = day.date;
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Mini bar representation
                      SizedBox(
                        height: 38,
                        width: 14,
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            Container(
                              height: 38,
                              decoration: BoxDecoration(
                                color: colors.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            Container(
                              height: (day.minutes / maxMinutes * 38).clamp(0.0, 38.0),
                              decoration: BoxDecoration(
                                color: day.goalMet
                                    ? colors.primary
                                    : (day.minutes > 0
                                        ? colors.secondary
                                        : Colors.transparent),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        day.label,
                        style: textTheme.labelSmall?.copyWith(
                          color: day.date == currentViewDate
                              ? colors.primary
                              : tokens.textSecondary,
                          fontWeight: day.date == currentViewDate || day.isToday
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Session Card ───────────────────────────────────────────────────────────

  Widget _buildSessionCard(
    BuildContext context,
    TimeService timeService,
    FocusSession session,
  ) {
    final colors = context.colors;
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    final isAbandoned = session.outcome == 'abandoned';
    final durationMinutes = session.actualDurationS ~/ 60;
    final durationStr = durationMinutes > 0
        ? '${durationMinutes}m'
        : '${session.actualDurationS}s';

    final startTimeStr = _formatTimeOfDay(session.startedAt, timeService);
    final endTimeStr = _formatTimeOfDay(session.endedAt, timeService);
    final totalInterruptions =
        session.interruptionsInternal + session.interruptionsExternal;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isAbandoned ? colors.surfaceContainerLow : colors.surfaceContainerLowest,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isAbandoned
                ? colors.surfaceContainerHighest
                : colors.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isAbandoned
                ? Icons.stop_rounded
                : (session.mode == 'flow'
                    ? Icons.all_inclusive_rounded
                    : Icons.timer_outlined),
            size: 20,
            color: isAbandoned
                ? tokens.textMuted
                : colors.onPrimaryContainer,
          ),
        ),
        title: Row(
          children: [
            Text(
              durationStr,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: isAbandoned ? tokens.textMuted : colors.onSurface,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              session.mode == 'flow' ? 'Open-ended' : 'Pomodoro',
              style: textTheme.bodySmall?.copyWith(
                color: tokens.textSecondary,
              ),
            ),
            if (isAbandoned) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Stopped',
                  style: textTheme.labelSmall?.copyWith(
                    color: tokens.textMuted,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              '$startTimeStr – $endTimeStr',
              style: textTheme.bodySmall?.copyWith(color: tokens.textMuted),
            ),
            if (totalInterruptions > 0) ...[
              const SizedBox(height: 2),
              Text(
                '$totalInterruptions ${totalInterruptions == 1 ? 'interruption' : 'interruptions'}',
                style: textTheme.bodySmall?.copyWith(
                  color: tokens.warning,
                  fontSize: 11,
                ),
              ),
            ],
            if (session.note != null && session.note!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                session.note!,
                style: textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: tokens.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: session.focusRating != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded, size: 16, color: tokens.warning),
                  const SizedBox(width: 2),
                  Text(
                    '${session.focusRating}',
                    style: textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              )
            : null,
      ),
    );
  }

  static String _formatFocusTime(int minutes) {
    if (minutes <= 0) return '0m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  static String _formatFriendlyDate(String localDate) {
    try {
      final parts = localDate.split('-');
      if (parts.length != 3) return localDate;
      final dt = DateTime.utc(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
      const weekdays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ];
      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December'
      ];
      final weekday = weekdays[dt.weekday - 1];
      final month = months[dt.month - 1];
      return '$weekday, $month ${dt.day}';
    } catch (_) {
      return localDate;
    }
  }

  static String _formatTimeOfDay(int utcMs, TimeService timeService) {
    final local = timeService.toLocal(utcMs);
    final hour = local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:$minute $period';
  }

  Widget _buildTasksSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<TaskWithDetails>> tasksAsync,
    String currentViewDate,
    bool isToday,
  ) {
    final colors = context.colors;
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              'TASKS',
              style: textTheme.labelSmall?.copyWith(
                color: tokens.textMuted,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            TextButton.icon(
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text(
                'Add Task',
                overflow: TextOverflow.ellipsis,
              ),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: () {
                QuickCaptureSheet.show(context, initialDate: currentViewDate);
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        tasksAsync.when(
          data: (tasks) {
            final timeService = ref.watch(timeServiceProvider);
            final allOpenTasks = tasks.where((t) => t.status == 'open').toList();
            final doneTasks = tasks.where((t) => t.status == 'done').toList();

            final dueTodayTasks = <TaskWithDetails>[];
            final overdueTasks = <TaskWithDetails>[];

            for (final td in allOpenTasks) {
              if (td.task.dueAt != null) {
                final taskLocalDate = timeService.computeLocalDate(td.task.dueAt!);
                if (taskLocalDate.compareTo(currentViewDate) < 0) {
                  overdueTasks.add(td);
                } else {
                  dueTodayTasks.add(td);
                }
              } else {
                dueTodayTasks.add(td);
              }
            }

            dueTodayTasks.sort((a, b) => compareTasks(a.task, b.task, timeService, currentViewDate));
            overdueTasks.sort((a, b) => compareTasks(a.task, b.task, timeService, currentViewDate));

            // Empty state handling
            if (allOpenTasks.isEmpty && doneTasks.isEmpty) {
              final emptyMessage = isToday
                  ? 'Nothing due today.'
                  : 'No tasks on ${_formatFriendlyDate(currentViewDate)}.';

              return Card(
                color: colors.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          emptyMessage,
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall?.copyWith(color: tokens.textMuted),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Add a task'),
                          onPressed: () {
                            QuickCaptureSheet.show(context, initialDate: currentViewDate);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final visibleDueTodayTasks = dueTodayTasks.take(5).toList();
            final hasMoreDueToday = dueTodayTasks.length > 5;
            final visibleOverdueTasks = _isOverdueExpanded
                ? overdueTasks
                : overdueTasks.take(3).toList();
            final hasMoreOverdue = overdueTasks.length > 3;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Due Today Tasks (Always first, top 5 with View all row if > 5)
                if (dueTodayTasks.isNotEmpty) ...[
                  for (final td in visibleDueTodayTasks)
                    _buildTodayTaskCard(context, ref, td, currentViewDate, timeService),
                  if (hasMoreDueToday) ...[
                    const SizedBox(height: 2),
                    Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      color: colors.surfaceContainerLow,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          ref.read(taskViewTabProvider.notifier).state = TaskViewTab.today;
                          ref.read(navigationIndexProvider.notifier).state = 2; // Tasks screen
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'View all ${dueTodayTasks.length} tasks',
                                style: textTheme.labelLarge?.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                                color: colors.primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ] else if (overdueTasks.isNotEmpty) ...[
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: colors.surfaceContainerLow,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Text(
                        isToday ? 'Nothing due today.' : 'No tasks due on this date.',
                        style: textTheme.bodySmall?.copyWith(color: tokens.textMuted),
                      ),
                    ),
                  ),
                ],

                // 2. Overdue Group (Collapsed below, count header, max 3 rows with See all)
                if (overdueTasks.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'OVERDUE (${overdueTasks.length})',
                          style: textTheme.labelSmall?.copyWith(
                            color: tokens.warning,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (hasMoreOverdue)
                          TextButton(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            onPressed: () {
                              setState(() => _isOverdueExpanded = !_isOverdueExpanded);
                            },
                            child: Text(
                              _isOverdueExpanded
                                  ? 'Show fewer'
                                  : 'See all (${overdueTasks.length})',
                            ),
                          ),
                      ],
                    ),
                  ),
                  for (final td in visibleOverdueTasks)
                    _buildTodayTaskCard(context, ref, td, currentViewDate, timeService),
                ],

                // 3. Completed tasks collapsible summary row (§1.2)
                if (doneTasks.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  _buildCompletedSummaryRow(
                    context,
                    count: doneTasks.length,
                    label: '${doneTasks.length} done today',
                    isExpanded: _isCompletedExpanded,
                    onTap: () => setState(() => _isCompletedExpanded = !_isCompletedExpanded),
                  ),
                  if (_isCompletedExpanded)
                    for (final td in doneTasks)
                      _buildTodayTaskCard(context, ref, td, currentViewDate, timeService),
                ],
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (err, _) => Card(
            color: colors.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Error loading tasks: $err',
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTodayTaskCard(
    BuildContext context,
    WidgetRef ref,
    TaskWithDetails taskDetails,
    String currentViewDate,
    TimeService timeService,
  ) {
    final colors = context.colors;
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final repo = ref.read(tasksRepositoryProvider);
    final task = taskDetails.task;

    final priorityColor = switch (task.priority) {
      1 => tokens.danger,
      2 => tokens.warning,
      3 => tokens.series[1],
      _ => Colors.transparent,
    };

    final isDone = task.status == 'done';
    final isOverdue = task.dueAt != null &&
        !isDone &&
        timeService.computeLocalDate(task.dueAt!).compareTo(currentViewDate) < 0;
    final subtasksDone =
        taskDetails.subtasks.where((st) => st.status == 'done').length;
    final totalSubtasks = taskDetails.subtasks.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: isDone ? colors.surfaceContainerLowest : colors.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: task.priority <= 3 && !isDone
              ? priorityColor.withValues(alpha: 0.5)
              : colors.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => TaskDetailSheet.show(context, taskDetails: taskDetails),
        onLongPress: () => showTaskOptionsMenu(
          context: context,
          ref: ref,
          taskDetails: taskDetails,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Semantics(
                label: isDone
                    ? 'Mark "${task.title}" incomplete'
                    : 'Mark "${task.title}" complete',
                checked: isDone,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: Checkbox(
                      value: isDone,
                      onChanged: (val) async {
                        if (val == true) {
                          await repo.completeTask(task.id);
                        } else {
                          await repo.uncompleteTask(task.id);
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: textTheme.bodyMedium?.copyWith(
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        color: isDone ? tokens.textMuted : colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Overdue date badge in error color (§1.1)
                        if (isOverdue)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.event_outlined, size: 12, color: tokens.danger),
                              const SizedBox(width: 3),
                              Text(
                                _formatDueText(task.dueAt!, task.dueIsAllDay, timeService),
                                style: textTheme.labelSmall?.copyWith(
                                  color: tokens.danger,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        if (taskDetails.project != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 4,
                                backgroundColor: tokens.series[
                                    taskDetails.project!.colorIndex %
                                        tokens.series.length],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                taskDetails.project!.name,
                                style: textTheme.labelSmall?.copyWith(
                                  color: tokens.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        if (task.estimatePomodoros != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.timer_outlined,
                                  size: 12, color: colors.primary),
                              const SizedBox(width: 3),
                              Text(
                                '${task.estimatePomodoros}p',
                                style: textTheme.labelSmall?.copyWith(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        if (totalSubtasks > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.checklist_rounded,
                                  size: 12, color: tokens.textMuted),
                              const SizedBox(width: 3),
                              Text(
                                '$subtasksDone/$totalSubtasks',
                                style: textTheme.labelSmall
                                    ?.copyWith(color: tokens.textMuted),
                              ),
                            ],
                          ),
                        if (taskDetails.isRecurring)
                          Icon(Icons.repeat_rounded,
                              size: 13, color: colors.primary),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Start focus on "${task.title}"',
                icon: Semantics(
                  label: 'Start focus on "${task.title}"',
                  button: true,
                  child: Icon(Icons.play_circle_outline_rounded,
                      color: colors.primary),
                ),
                onPressed: () {
                  ref.read(timerControllerProvider.notifier).attachTask(
                        task.id,
                        projectId: task.projectId,
                      );
                  ref.read(activeTaskIdProvider.notifier).state = task.id;
                  ref.read(navigationIndexProvider.notifier).state = 1;
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedSummaryRow(
    BuildContext context, {
    required int count,
    required String label,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    final colors = context.colors;
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: colors.surfaceContainerLowest,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colors.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 20,
                color: tokens.success,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
              ),
              Icon(
                isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                size: 20,
                color: tokens.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDueText(int dueAtUtcMs, bool isAllDay, TimeService timeService) {
    final local = timeService.toLocal(dueAtUtcMs);
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dateStr = '${months[local.month - 1]} ${local.day}';
    if (isAllDay) return dateStr;
    final hour = local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$dateStr $displayHour:$minute $period';
  }
}

