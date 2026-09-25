import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/time_service.dart';
import '../../../data/providers/database_provider.dart';
import '../../../data/repositories/tasks_repository.dart';
import '../../../core/widgets/feature_info.dart';
import '../../../core/widgets/feature_info_content.dart';
import '../../../core/widgets/cairn_card.dart';
import '../../../theme/app_theme.dart';
import '../../timer/presentation/timer_controller.dart';
import 'archived_tasks_screen.dart';
import '../../habits/presentation/widgets/habit_check_burst.dart';
import 'widgets/quick_capture_sheet.dart';
import 'widgets/task_priority_dot.dart';
import 'widgets/task_summary_cards.dart';
import 'widgets/task_deletion_handler.dart';
import 'widgets/task_detail_sheet.dart';

enum TaskViewTab { today, upcoming, inbox }

/// State provider for the active task tab, allowing other screens (e.g. Today screen)
/// to switch to the Tasks screen on its Today view.
final taskViewTabProvider = StateProvider<TaskViewTab>(
  (ref) => TaskViewTab.today,
);

/// Memoized open/done split and sorted tasks for the Today view.
/// Moves sorting out of build() into a Riverpod provider layer.
typedef TodaySortedTasks = ({
  List<TaskWithDetails> open,
  List<TaskWithDetails> done,
});

final todaySortedTasksProvider = Provider.family<
    AsyncValue<TodaySortedTasks>,
    ({String todayLocalDate, String? selectedProjectId})>((ref, params) {
  final tasksAsync = ref.watch(todayTasksStreamProvider(params.todayLocalDate));
  final timeService = ref.watch(timeServiceProvider);

  return tasksAsync.whenData((tasks) {
    final filtered = params.selectedProjectId == null
        ? tasks
        : tasks.where((t) => t.task.projectId == params.selectedProjectId).toList();

    final openTasks = filtered.where((t) => t.status == 'open').toList()
      ..sort(
        (a, b) => compareTasks(a.task, b.task, timeService, params.todayLocalDate),
      );
    final doneTasks = filtered.where((t) => t.status == 'done').toList();

    return (open: openTasks, done: doneTasks);
  });
});

/// Primary Tasks management screen per SPEC.md §2.4, §2.5, §2.6.
///
/// Features:
/// - Three views: Today, Upcoming, Inbox.
/// - Dismissible gestures:
///   - Swipe right to complete.
///   - Swipe left to defer to tomorrow (increments reschedule_count if later).
/// - Quick capture with natural-language parsing.
/// - Projects with AppTokens.series color palette.
/// - Session-to-task launcher.
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  String? _selectedProjectId;
  bool _isCompletedExpanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final timeService = ref.watch(timeServiceProvider);
    final todayLocalDate = timeService.todayLocalDate();
    final activeTab = ref.watch(taskViewTabProvider);
    final archivedTasksAsync = ref.watch(archivedTasksStreamProvider);
    final archivedCount = archivedTasksAsync.value?.length ?? 0;

    final projectsAsync = ref.watch(projectsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Tasks',
          style: textTheme.headlineSmall?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          const FeatureInfoButton(info: FeatureInfoContent.tasks),
          // Project filter or add project button
          IconButton(
            tooltip: 'New Project',
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: () => _showAddProjectDialog(context),
          ),
          // Overflow menu with live archived count (§2.1)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            tooltip: 'More options',
            onSelected: (action) {
              if (action == 'archived') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ArchivedTasksScreen(),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'archived',
                child: Row(
                  children: [
                    const Icon(Icons.archive_outlined, size: 20),
                    const SizedBox(width: 8),
                    Text('Archived ($archivedCount)'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: _TaskViewPicker(
              selected: activeTab,
              onSelected: (s) =>
                  ref.read(taskViewTabProvider.notifier).state = s,
            ),
          ),
        ),
      ),
      floatingActionButton: GestureDetector(
        onLongPress: () => TaskDetailSheet.show(
          context,
          initialDate: activeTab == TaskViewTab.today ? todayLocalDate : null,
        ),
        child: FloatingActionButton.extended(
          // Tasks and Habits are both alive at once inside the navigation
          // shell's IndexedStack (§ NavigationShell). Two FABs with no
          // explicit tag share Flutter's single default hero tag, which
          // throws "multiple heroes share the same tag" the first time any
          // route pushes while both are mounted — which is always, since
          // IndexedStack never tears a tab down.
          heroTag: 'tasks_screen_fab',
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Task'),
          onPressed: () => QuickCaptureSheet.show(
            context,
            initialDate: activeTab == TaskViewTab.today ? todayLocalDate : null,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const FeatureInfoCard(info: FeatureInfoContent.tasks),
            // Project Filter Bar (if projects exist)
            projectsAsync.when(
              data: (projects) {
                if (projects.isEmpty) return const SizedBox.shrink();
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      FilterChip(
                        shape: const StadiumBorder(),
                        label: const Text('All Projects'),
                        selected: _selectedProjectId == null,
                        onSelected: (_) =>
                            setState(() => _selectedProjectId = null),
                      ),
                      const SizedBox(width: 8),
                      for (final p in projects) ...[
                        FilterChip(
                          shape: const StadiumBorder(),
                          avatar: CircleAvatar(
                            radius: 5,
                            backgroundColor: tokens
                                .series[p.colorIndex % tokens.series.length],
                          ),
                          label: Text(p.name),
                          selected: _selectedProjectId == p.id,
                          onSelected: (selected) {
                            setState(() {
                              _selectedProjectId = selected ? p.id : null;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),

            // Active Tab Task List
            Expanded(
              child: switch (activeTab) {
                TaskViewTab.today => _buildTodayView(
                  context,
                  ref,
                  todayLocalDate,
                ),
                TaskViewTab.upcoming => _buildUpcomingView(
                  context,
                  ref,
                  todayLocalDate,
                ),
                TaskViewTab.inbox => _buildInboxView(context, ref),
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Views ─────────────────────────────────────────────────────────────────

  Widget _buildTodayView(
    BuildContext context,
    WidgetRef ref,
    String todayLocalDate,
  ) {
    final sortedAsync = ref.watch(
      todaySortedTasksProvider((
        todayLocalDate: todayLocalDate,
        selectedProjectId: _selectedProjectId,
      )),
    );

    return sortedAsync.when(
      data: (sorted) {
        final openTasks = sorted.open;
        final doneTasks = sorted.done;

        // Empty state per §1.4 & Part E
        if (openTasks.isEmpty && doneTasks.isEmpty) {
          return _buildEmptyState(
            icon: Icons.check_circle_outline_rounded,
            title: 'Nothing due today.',
            subtitle:
                'Tap + to capture a task, or long-press for the full form.',
          );
        }

        final showDoneSection = doneTasks.isNotEmpty;
        final showDoneCards = showDoneSection && _isCompletedExpanded;
        final doneCardsCount = showDoneCards ? doneTasks.length : 0;

        // Total items:
        // Index 0: TodayProgressCard
        // Index 1..openTasks.length: open tasks
        // Index openTasks.length + 1 (if showDoneSection): completed summary row
        // Index openTasks.length + 2 .. (if showDoneCards): done tasks
        // Last index: DoneTodayCard
        final totalCount = 1 +
            openTasks.length +
            (showDoneSection ? 1 : 0) +
            doneCardsCount +
            1;

        return ListView.builder(
          padding: const EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            // Clears the extended FAB at the end of the list; matches the
            // Habits list's reserve so the two tabs scroll to the same stop.
            bottom: 96,
          ),
          itemCount: totalCount,
          itemBuilder: (context, index) {
            if (index == 0) {
              return TodayProgressCard(
                open: openTasks.length,
                done: doneTasks.length,
              );
            }

            final openIndex = index - 1;
            if (openIndex < openTasks.length) {
              return _buildDismissibleTaskCard(context, ref, openTasks[openIndex]);
            }

            if (showDoneSection) {
              final doneHeaderIndex = openTasks.length + 1;
              if (index == doneHeaderIndex) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _buildCompletedSummaryRow(
                    context,
                    count: doneTasks.length,
                    label: '${doneTasks.length} done',
                    isExpanded: _isCompletedExpanded,
                    onTap: () => setState(
                      () => _isCompletedExpanded = !_isCompletedExpanded,
                    ),
                  ),
                );
              }

              if (showDoneCards) {
                final doneTaskIndex = index - (doneHeaderIndex + 1);
                if (doneTaskIndex < doneTasks.length) {
                  return _buildDismissibleTaskCard(context, ref, doneTasks[doneTaskIndex]);
                }
              }
            }

            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: DoneTodayCard(
                done: doneTasks.length,
                remaining: openTasks.length,
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildUpcomingView(
    BuildContext context,
    WidgetRef ref,
    String todayLocalDate,
  ) {
    final tasksAsync = ref.watch(upcomingTasksStreamProvider(todayLocalDate));

    return tasksAsync.when(
      data: (tasks) {
        final filtered = _filterByProject(tasks);
        if (filtered.isEmpty) {
          return _buildEmptyState(
            icon: Icons.calendar_month_outlined,
            title: 'No upcoming tasks',
            subtitle: 'Tasks scheduled for future days will appear here.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            // Clears the extended FAB at the end of the list; matches the
            // Habits list's reserve so the two tabs scroll to the same stop.
            bottom: 96,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final taskDetails = filtered[index];
            return _buildDismissibleTaskCard(context, ref, taskDetails);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildInboxView(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(inboxTasksStreamProvider);

    return tasksAsync.when(
      data: (tasks) {
        final filtered = _filterByProject(tasks);
        if (filtered.isEmpty) {
          return _buildEmptyState(
            icon: Icons.all_inbox_rounded,
            title: 'Inbox is empty',
            subtitle: 'Tasks without a due date appear here.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            // Clears the extended FAB at the end of the list; matches the
            // Habits list's reserve so the two tabs scroll to the same stop.
            bottom: 96,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final taskDetails = filtered[index];
            return _buildDismissibleTaskCard(context, ref, taskDetails);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }

  List<TaskWithDetails> _filterByProject(List<TaskWithDetails> tasks) {
    if (_selectedProjectId == null) return tasks;
    return tasks.where((t) => t.task.projectId == _selectedProjectId).toList();
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
      // Radius, fill and shadow all come from `cardTheme` now.
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
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
                isExpanded
                    ? Icons.expand_less_rounded
                    : Icons.expand_more_rounded,
                size: 20,
                color: tokens.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Dismissible Task Card ──────────────────────────────────────────────────

  Widget _buildDismissibleTaskCard(
    BuildContext context,
    WidgetRef ref,
    TaskWithDetails taskDetails,
  ) {
    final colors = context.colors;
    final tokens = context.tokens;
    final repo = ref.read(tasksRepositoryProvider);
    final task = taskDetails.task;

    return Dismissible(
      key: ValueKey('task-${task.id}'),
      // Swipe Right -> Complete (§6)
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: tokens.success,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_rounded, color: Colors.white, size: 28),
            SizedBox(width: 8),
            Text(
              'Complete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      // Swipe Left -> Defer to tomorrow (§6, §4.12)
      secondaryBackground: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: colors.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Tomorrow',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.next_plan_outlined, color: Colors.white, size: 28),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Complete
          unawaited(HapticFeedback.lightImpact().catchError((_) {}));
          await repo.completeTask(task.id);
          return true;
        } else if (direction == DismissDirection.endToStart) {
          // Defer to tomorrow
          await repo.deferToTomorrow(task.id);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Deferred "${task.title}" to tomorrow'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
          return true;
        }
        return false;
      },
      child: _buildTaskCard(context, ref, taskDetails),
    );
  }

  Widget _buildTaskCard(
    BuildContext context,
    WidgetRef ref,
    TaskWithDetails taskDetails,
  ) {
    final colors = context.colors;
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final timeService = ref.watch(timeServiceProvider);
    final repo = ref.read(tasksRepositoryProvider);
    final task = taskDetails.task;

    final priorityColor = switch (task.priority) {
      1 => tokens.danger,
      2 => tokens.warning,
      3 => tokens.series[1],
      _ => Colors.transparent,
    };

    final isDone = task.status == 'done';
    final subtasksDone = taskDetails.subtasks
        .where((st) => st.status == 'done')
        .length;
    final totalSubtasks = taskDetails.subtasks.length;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      // Fill and shadow come from `cardTheme`. The only thing kept local is
      // the priority outline, which carries meaning rather than style — a
      // high-priority task still wears its tint.
      shape: task.priority <= 3 && !isDone
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: priorityColor.withValues(alpha: 0.5)),
            )
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => TaskDetailSheet.show(context, taskDetails: taskDetails),
        onLongPress: () => showTaskOptionsMenu(
          context: context,
          ref: ref,
          taskDetails: taskDetails,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Complete checkbox with 48x48 min touch target
              Semantics(
                label: isDone
                    ? 'Mark "${task.title}" incomplete'
                    : 'Mark "${task.title}" complete',
                checked: isDone,
                // The same flourish as the habit check circle, reused rather
                // than reimplemented: it fires on false -> true only.
                child: HabitCheckBurst(
                  done: isDone,
                  diameter: 48,
                  child: Center(
                    child: Checkbox(
                      value: isDone,
                      onChanged: (val) async {
                        unawaited(HapticFeedback.lightImpact().catchError((_) {}));
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

              // Title and metadata column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Second use of the same priority colour the card
                        // border already carries.
                        TaskPriorityDot(
                          color: isDone ? Colors.transparent : priorityColor,
                        ),
                        Expanded(
                          child: Text(
                            task.title,
                            style: textTheme.bodyLarge?.copyWith(
                              decoration: isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: isDone
                                  ? tokens.textMuted
                                  : colors.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Badges row
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Project pill
                        if (taskDetails.project != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 4,
                                backgroundColor:
                                    tokens.series[taskDetails
                                            .project!
                                            .colorIndex %
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

                        // Due date indicator
                        if (task.dueAt != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.event_outlined,
                                size: 12,
                                color: tokens.textMuted,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                _formatDueText(
                                  task.dueAt!,
                                  task.dueIsAllDay,
                                  timeService,
                                ),
                                style: textTheme.labelSmall?.copyWith(
                                  color:
                                      _isOverdue(task.dueAt!, timeService) &&
                                          !isDone
                                      ? tokens.danger
                                      : tokens.textMuted,
                                ),
                              ),
                            ],
                          ),

                        // Estimate Pomodoros
                        if (task.estimatePomodoros != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 12,
                                color: colors.primary,
                              ),
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

                        // Subtasks progress - the mockup's 60x5 inline bar.
                        if (totalSubtasks > 0)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(2.5),
                                child: SizedBox(
                                  width: 60,
                                  child: LinearProgressIndicator(
                                    value: subtasksDone / totalSubtasks,
                                    minHeight: 5,
                                    backgroundColor: tokens.lineSoft,
                                    valueColor: AlwaysStoppedAnimation(
                                      colors.primary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Flexible so a wide font or a large text scale
                              // shortens the label instead of overflowing the
                              // badge row.
                              Flexible(
                                child: Text(
                                  '$subtasksDone of $totalSubtasks subtasks',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.labelSmall?.copyWith(
                                    color: tokens.textMuted,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),

                        // Recurrence indicator
                        if (taskDetails.isRecurring)
                          Icon(
                            Icons.repeat_rounded,
                            size: 13,
                            color: colors.primary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Quick Focus Button (start or attach to timer)
              IconButton(
                tooltip: 'Start focus on "${task.title}"',
                icon: Semantics(
                  label: 'Start focus on "${task.title}"',
                  button: true,
                  child: Icon(
                    Icons.play_circle_outline_rounded,
                    color: colors.primary,
                  ),
                ),
                onPressed: () {
                  ref
                      .read(timerControllerProvider.notifier)
                      .attachTask(task.id, projectId: task.projectId);
                  ref.read(activeTaskIdProvider.notifier).state = task.id;
                  ref.read(navigationIndexProvider.notifier).state =
                      1; // Timer tab
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final colors = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<AppTokens>() ?? AppTokens.light;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: colors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(color: tokens.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  bool _isOverdue(int dueAtUtcMs, TimeService timeService) {
    final taskLocalDate = timeService.computeLocalDate(dueAtUtcMs);
    final today = timeService.todayLocalDate();
    return taskLocalDate.compareTo(today) < 0;
  }

  String _formatDueText(
    int dueAtUtcMs,
    bool isAllDay,
    TimeService timeService,
  ) {
    final local = timeService.toLocal(dueAtUtcMs);
    final today = timeService.todayLocalDate();
    final taskLocalDate = timeService.computeLocalDate(dueAtUtcMs);

    String dateStr;
    if (taskLocalDate == today) {
      dateStr = 'Today';
    } else if (taskLocalDate == TimeService.addDays(today, 1)) {
      dateStr = 'Tomorrow';
    } else {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      dateStr = '${months[local.month - 1]} ${local.day}';
    }

    if (isAllDay) return dateStr;

    final hour = local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$dateStr $displayHour:$minute $period';
  }

  void _showAddProjectDialog(BuildContext context) {
    final textController = TextEditingController();
    var colorIndex = 0;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final tokens = context.tokens;
          return AlertDialog(
            title: const Text('New Project'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: textController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Project Name',
                    hintText: 'e.g. Work, Health, Personal',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(6, (i) {
                    final color = tokens.series[i];
                    final isSelected = colorIndex == i;
                    return InkWell(
                      onTap: () => setDialogState(() => colorIndex = i),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.black, width: 3)
                              : null,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final name = textController.text.trim();
                  if (name.isNotEmpty) {
                    await ref
                        .read(tasksRepositoryProvider)
                        .createProject(name: name, colorIndex: colorIndex);
                  }
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Today / Upcoming / Inbox, as a tinted track with one filled pill.
///
/// The same control the Stats range picker and the Focus mode picker use.
/// It was a `SegmentedButton` — three joined outlines with a pale selected
/// fill — which is a third look for what is the same kind of choice.
class _TaskViewPicker extends StatelessWidget {
  const _TaskViewPicker({required this.selected, required this.onSelected});

  final TaskViewTab selected;
  final ValueChanged<TaskViewTab> onSelected;

  static const _labels = {
    TaskViewTab.today: 'Today',
    TaskViewTab.upcoming: 'Upcoming',
    TaskViewTab.inbox: 'Inbox',
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tokens = context.tokens;

    return Container(
      decoration: BoxDecoration(
        color: CardChrome.pickerTrack(context),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          for (final tab in TaskViewTab.values) ...[
            if (tab != TaskViewTab.values.first) const SizedBox(width: 2),
            Expanded(
              child: Semantics(
                button: true,
                selected: tab == selected,
                inMutuallyExclusiveGroup: true,
                label: _labels[tab]!,
                excludeSemantics: true,
                child: Material(
                  color: tab == selected ? colors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(9),
                    onTap: () => onSelected(tab),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      child: Text(
                        _labels[tab]!,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontSize: 11.5,
                              letterSpacing: 0,
                              fontWeight: tab == selected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: tab == selected
                                  ? colors.onPrimary
                                  : tokens.textMuted,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
