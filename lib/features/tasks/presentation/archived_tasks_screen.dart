import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/time/time_service.dart';
import '../../../data/providers/database_provider.dart';
import '../../../data/repositories/tasks_repository.dart';
import '../../../theme/app_theme.dart';
import 'widgets/task_deletion_handler.dart';

/// Screen displaying archived tasks per SPEC.md and §2.1–§2.4.
///
/// Features:
/// - Lists all `status='archived'` tasks, most recently archived first, grouped by month.
/// - Muted styling relative to live lists (history, not work).
/// - Empty state: "Nothing archived yet."
/// - Restore via swipe right or per-row menu, setting status back to 'open'.
/// - Shows SnackBar: "Restored to Today." (or Inbox / Upcoming).
/// - Non-destructive: rows are never removed from the database (§2.4).
class ArchivedTasksScreen extends ConsumerWidget {
  const ArchivedTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final timeService = ref.watch(timeServiceProvider);
    final archivedAsync = ref.watch(archivedTasksStreamProvider);

    final archivedItems = archivedAsync.asData?.value ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Archived',
          style: textTheme.headlineSmall?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (archivedItems.isNotEmpty)
            TextButton.icon(
              icon: Icon(Icons.delete_sweep_outlined, size: 18, color: tokens.danger),
              label: Text(
                'Delete all archived',
                style: textTheme.labelMedium?.copyWith(
                  color: tokens.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () => confirmDeleteAllArchived(
                context: context,
                ref: ref,
                count: archivedItems.length,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: archivedAsync.when(
          data: (items) {
            if (items.isEmpty) {
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
                        child: Icon(
                          Icons.archive_outlined,
                          size: 36,
                          color: tokens.textMuted,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nothing archived yet.',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: tokens.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Group tasks by month (e.g. "September 2026")
            final groups = <String, List<ArchivedTaskItem>>{};
            for (final item in items) {
              final monthKey = _formatMonthYear(item.archivedAtMs, timeService);
              groups.putIfAbsent(monthKey, () => []).add(item);
            }

            return ListView.builder(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 32),
              itemCount: groups.length,
              itemBuilder: (context, groupIndex) {
                final monthKey = groups.keys.elementAt(groupIndex);
                final monthItems = groups[monthKey]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, top: 12, bottom: 8),
                      child: Text(
                        monthKey,
                        style: textTheme.labelMedium?.copyWith(
                          color: tokens.textMuted,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    for (final item in monthItems)
                      _buildArchivedTaskRow(context, ref, item, timeService),
                  ],
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
        ),
      ),
    );
  }

  Widget _buildArchivedTaskRow(
    BuildContext context,
    WidgetRef ref,
    ArchivedTaskItem item,
    TimeService timeService,
  ) {
    final colors = context.colors;
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final repo = ref.read(tasksRepositoryProvider);
    final task = item.task;

    return Dismissible(
      key: ValueKey('archived-${task.id}'),
      direction: DismissDirection.startToEnd,
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
            Icon(Icons.restore_rounded, color: Colors.white, size: 24),
            SizedBox(width: 8),
            Text(
              'Restore',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          final destination = await repo.restoreTask(task.id);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Restored to $destination.'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
          return true;
        }
        return false;
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        color: colors.surfaceContainerLowest,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Muted archive icon indicator
              Icon(
                Icons.archive_outlined,
                size: 20,
                color: tokens.textMuted.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 12),

              // Title and metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: textTheme.bodyMedium?.copyWith(
                        color: tokens.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Date archived
                        Text(
                          'Archived ${_formatShortDate(item.archivedAtMs, timeService)}',
                          style: textTheme.labelSmall?.copyWith(
                            color: tokens.textMuted.withValues(alpha: 0.8),
                          ),
                        ),

                        // Priority badge (muted)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'P${task.priority}',
                            style: textTheme.labelSmall?.copyWith(
                              color: tokens.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        // Project pill
                        if (item.project != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 4,
                                backgroundColor: tokens.series[
                                    item.project!.colorIndex % tokens.series.length]
                                    .withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                item.project!.name,
                                style: textTheme.labelSmall?.copyWith(
                                  color: tokens.textMuted,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Per-row menu with Restore and Delete action (§1, §2.3)
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, size: 20, color: tokens.textMuted),
                tooltip: 'Task options',
                onSelected: (action) async {
                  if (action == 'restore') {
                    final destination = await repo.restoreTask(task.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Restored to $destination.'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  } else if (action == 'delete') {
                    await handleTaskDeletion(
                      context: context,
                      ref: ref,
                      task: task,
                    );
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'restore',
                    child: Row(
                      children: [
                        Icon(Icons.restore_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Restore'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 18, color: tokens.danger),
                        const SizedBox(width: 8),
                        Text(
                          'Delete',
                          style: TextStyle(color: tokens.danger),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatMonthYear(int epochMs, TimeService timeService) {
    final local = timeService.toLocal(epochMs);
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
    return '${months[local.month - 1]} ${local.year}';
  }

  static String _formatShortDate(int epochMs, TimeService timeService) {
    final local = timeService.toLocal(epochMs);
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
      'Dec'
    ];
    return '${months[local.month - 1]} ${local.day}';
  }
}
