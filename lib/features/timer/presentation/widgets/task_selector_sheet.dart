import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/providers/database_provider.dart';
import '../../../../data/repositories/tasks_repository.dart';
import '../../../../theme/app_theme.dart';
import '../timer_controller.dart';

/// Modal sheet for selecting, switching, or detaching a task from the active/ready timer (§2.4).
class TaskSelectorSheet extends ConsumerWidget {
  const TaskSelectorSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const TaskSelectorSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final timerState = ref.watch(timerControllerProvider);
    final timeService = ref.watch(timeServiceProvider);
    final today = timeService.todayLocalDate();

    final todayTasksAsync = ref.watch(todayTasksStreamProvider(today));
    final inboxTasksAsync = ref.watch(inboxTasksStreamProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Attach Task',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colors.primary,
                    ),
                  ),
                  if (timerState.taskId != null)
                    TextButton.icon(
                      icon: const Icon(Icons.link_off_rounded, size: 18),
                      label: const Text('Detach'),
                      onPressed: () {
                        ref.read(timerControllerProvider.notifier).detachTask();
                        ref.read(activeTaskIdProvider.notifier).state = null;
                        Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Task lists
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  // Today's Open Tasks
                  Text(
                    'TODAY',
                    style: textTheme.labelSmall?.copyWith(
                      color: tokens.textMuted,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  todayTasksAsync.when(
                    data: (tasks) {
                      final openTasks = tasks.where((t) => t.task.status == 'open').toList();
                      if (openTasks.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No open tasks scheduled for today.',
                            style: textTheme.bodySmall?.copyWith(color: tokens.textMuted),
                          ),
                        );
                      }
                      return Column(
                        children: [
                          for (final td in openTasks)
                            _buildTaskTile(context, ref, td, timerState.taskId == td.task.id),
                        ],
                      );
                    },
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (err, _) => Text('Error: $err'),
                  ),

                  const SizedBox(height: 16),

                  // Inbox Tasks
                  Text(
                    'INBOX',
                    style: textTheme.labelSmall?.copyWith(
                      color: tokens.textMuted,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  inboxTasksAsync.when(
                    data: (tasks) {
                      if (tasks.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'No inbox tasks.',
                            style: textTheme.bodySmall?.copyWith(color: tokens.textMuted),
                          ),
                        );
                      }
                      return Column(
                        children: [
                          for (final td in tasks)
                            _buildTaskTile(context, ref, td, timerState.taskId == td.task.id),
                        ],
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (err, _) => Text('Error: $err'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTaskTile(
    BuildContext context,
    WidgetRef ref,
    TaskWithDetails td,
    bool isSelected,
  ) {
    final colors = context.colors;
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final task = td.task;

    final priorityColor = switch (task.priority) {
      1 => tokens.danger,
      2 => tokens.warning,
      3 => tokens.series[1],
      _ => Colors.transparent,
    };

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: isSelected ? colors.primaryContainer.withValues(alpha: 0.35) : colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? colors.primary
              : (task.priority <= 3
                  ? priorityColor.withValues(alpha: 0.4)
                  : colors.outlineVariant.withValues(alpha: 0.3)),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: () {
          ref.read(timerControllerProvider.notifier).attachTask(
                task.id,
                projectId: task.projectId,
              );
          ref.read(activeTaskIdProvider.notifier).state = task.id;
          Navigator.of(context).pop();
        },
        leading: Icon(
          isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          color: isSelected ? colors.primary : tokens.textMuted,
        ),
        title: Text(
          task.title,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: colors.onSurface,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Wrap(
          spacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (td.project != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 4,
                    backgroundColor:
                        tokens.series[td.project!.colorIndex % tokens.series.length],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    td.project!.name,
                    style: textTheme.labelSmall?.copyWith(color: tokens.textSecondary),
                  ),
                ],
              ),
            if (task.estimatePomodoros != null)
              Text(
                '${task.estimatePomodoros}p',
                style: textTheme.labelSmall?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
