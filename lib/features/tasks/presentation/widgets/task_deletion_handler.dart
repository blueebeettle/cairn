import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/database/app_database.dart';
import '../../../../data/providers/database_provider.dart';
import '../../../../data/repositories/tasks_repository.dart';
import '../../../../theme/app_theme.dart';

/// Shows a bottom sheet menu with Archive and Delete options when a task is long-pressed (§1).
Future<void> showTaskOptionsMenu({
  required BuildContext context,
  required WidgetRef ref,
  required TaskWithDetails taskDetails,
}) async {
  final tokens = context.tokens;
  final textTheme = Theme.of(context).textTheme;
  final repo = ref.read(tasksRepositoryProvider);
  final task = taskDetails.task;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  task.title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.archive_outlined, color: tokens.textSecondary),
                title: const Text('Archive'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await repo.archiveTask(task.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Archived "${task.title}".'),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: tokens.danger),
                title: Text(
                  'Delete',
                  style: TextStyle(color: tokens.danger, fontWeight: FontWeight.w600),
                ),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await handleTaskDeletion(
                    context: context,
                    ref: ref,
                    task: task,
                  );
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Primary task deletion entry point with history-dependent confirmation (§3, §4, §6).
Future<void> handleTaskDeletion({
  required BuildContext context,
  required WidgetRef ref,
  required Task task,
  VoidCallback? onDeleted,
}) async {
  final repo = ref.read(tasksRepositoryProvider);
  final history = await repo.checkTaskHistory(task.id);

  // 1. Recurring Series (§4)
  final isRecurring = task.recurrenceRule != null || task.recurrenceParentId != null;
  if (isRecurring) {
    if (!context.mounted) return;
    await _showRecurringDeleteDialog(
      context: context,
      ref: ref,
      task: task,
      history: history,
      onDeleted: onDeleted,
    );
    return;
  }

  // 2. Has History (§3)
  if (history.hasHistory) {
    if (!context.mounted) return;
    await _showHistoryConfirmationDialog(
      context: context,
      ref: ref,
      task: task,
      history: history,
      onDeleted: onDeleted,
    );
    return;
  }

  // 3. No History (§3, §6): delete immediately with 6-second in-memory undo window
  if (!context.mounted) return;
  await _executeStagedDeletion(
    context: context,
    ref: ref,
    task: task,
    onDeleted: onDeleted,
  );
}

/// Recurring series deletion dialog (§4).
/// Asks "Delete this one" or "Delete this and all future".
/// Explains that already-completed instances are separate rows and only removed if chosen.
Future<void> _showRecurringDeleteDialog({
  required BuildContext context,
  required WidgetRef ref,
  required Task task,
  required TaskHistoryInfo history,
  VoidCallback? onDeleted,
}) async {
  final repo = ref.read(tasksRepositoryProvider);
  final colors = context.colors;
  final tokens = context.tokens;
  final textTheme = Theme.of(context).textTheme;

  final hasCompletedSeries = history.completedSeriesInstancesCount > 0;
  var includeCompleted = false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Delete recurring task?'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Deleting the series stops new instances spawning.\n\n'
                    'Already-completed instances are separate rows and are only removed if you choose to delete them too.',
                    style: textTheme.bodyMedium,
                  ),
                  if (hasCompletedSeries) ...[
                    const SizedBox(height: 12),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: includeCompleted,
                      title: Text(
                        'Also delete ${history.completedSeriesInstancesCount} completed ${history.completedSeriesInstancesCount == 1 ? 'instance' : 'instances'}',
                        style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Past statistics for these instances will change.',
                        style: textTheme.labelSmall?.copyWith(color: tokens.textMuted),
                      ),
                      onChanged: (val) {
                        setDialogState(() {
                          includeCompleted = val ?? false;
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await repo.archiveTask(task.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Archived "${task.title}".'),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                  onDeleted?.call();
                },
                child: const Text('Archive'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              OutlinedButton(
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  // Delete only this one instance
                  if (task.status == 'done' || history.completionsCount > 0 || history.focusSessionsCount > 0) {
                    await repo.deleteTask(task.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Deleted "${task.title}".'),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  } else {
                    await _executeStagedDeletion(
                      context: context,
                      ref: ref,
                      task: task,
                      onDeleted: onDeleted,
                    );
                  }
                  onDeleted?.call();
                },
                child: const Text('Delete this one'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.error,
                  foregroundColor: colors.onError,
                ),
                onPressed: () async {
                  Navigator.of(dialogContext).pop();
                  await repo.deleteTask(
                    task.id,
                    deleteSeries: true,
                    deleteCompletedSeriesInstances: includeCompleted,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Deleted recurring series "${task.title}".'),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                  onDeleted?.call();
                },
                child: const Text('Delete series'),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Confirmation dialog when task has history (§3).
/// Names completions and focus sessions that will be removed.
/// Offers Archive as the safer alternative.
Future<void> _showHistoryConfirmationDialog({
  required BuildContext context,
  required WidgetRef ref,
  required Task task,
  required TaskHistoryInfo history,
  VoidCallback? onDeleted,
}) async {
  final repo = ref.read(tasksRepositoryProvider);
  final colors = context.colors;
  final textTheme = Theme.of(context).textTheme;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Delete task?'),
        content: Text(
          history.buildWarningMessage(task.title),
          style: textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await repo.archiveTask(task.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Archived "${task.title}".'),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
              onDeleted?.call();
            },
            child: const Text('Archive'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            ),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await repo.deleteTask(task.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Deleted "${task.title}".'),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
              onDeleted?.call();
            },
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );
}

/// Executes an in-memory staged deletion with a 6-second undo window (§6).
Future<void> _executeStagedDeletion({
  required BuildContext context,
  required WidgetRef ref,
  required Task task,
  VoidCallback? onDeleted,
}) async {
  final repo = ref.read(tasksRepositoryProvider);
  final pending = await repo.stageDeleteTask(task.id);
  onDeleted?.call();

  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();

  final controller = messenger.showSnackBar(
    SnackBar(
      content: Text('Deleted "${task.title}".'),
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () async {
          await pending.undo();
        },
      ),
    ),
  );

  controller.closed.then((reason) {
    if (reason != SnackBarClosedReason.action) {
      pending.commit();
    }
  });
}

/// Shows a confirmation dialog for "Delete all archived" (§1).
Future<void> confirmDeleteAllArchived({
  required BuildContext context,
  required WidgetRef ref,
  required int count,
}) async {
  final repo = ref.read(tasksRepositoryProvider);
  final colors = context.colors;
  final textTheme = Theme.of(context).textTheme;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Delete all archived?'),
        content: Text(
          'This will permanently delete all $count archived tasks, their subtasks, and associations. Past statistics will change.\n\nThis cannot be undone.',
          style: textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.error,
              foregroundColor: colors.onError,
            ),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final deletedCount = await repo.deleteAllArchived();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Deleted $deletedCount archived ${deletedCount == 1 ? 'task' : 'tasks'}.'),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
            child: const Text('Delete all'),
          ),
        ],
      );
    },
  );
}
