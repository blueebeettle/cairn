import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/event_types.dart';
import '../../../data/providers/habit_providers.dart';
import '../../../data/providers/reminder_config_providers.dart';
import '../../../data/repositories/habits_repository.dart';
import '../../../theme/app_theme.dart';
import '../../reminders/reminder_service.dart';
import '../domain/habit_presentation.dart';
import 'habit_edit_sheet.dart';
import 'widgets/habit_check_button.dart';
import 'widgets/habit_day_sheet.dart';
import 'widgets/habit_marks.dart';
import 'widgets/habit_month_grid.dart';

/// One habit: header, month grid, stats, journal.
///
/// Every number on this screen comes from the same [HabitSnapshot] the list
/// card reads, so the card and the detail cannot disagree about a streak.
class HabitDetailScreen extends ConsumerWidget {
  const HabitDetailScreen({super.key, required this.habitId});

  final String habitId;

  static Future<void> open(BuildContext context, String habitId) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HabitDetailScreen(habitId: habitId)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(habitSnapshotProvider(habitId));
    final snapshot = snapshotAsync.value;

    if (snapshot == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: snapshotAsync.isLoading
              ? const CircularProgressIndicator()
              : const Text('This habit no longer exists.'),
        ),
      );
    }

    final habit = snapshot.habit;
    final archived = habit.status == HabitStatuses.archived;

    return Scaffold(
      appBar: AppBar(
        title: Text(habit.title, overflow: TextOverflow.ellipsis),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'More options',
            onSelected: (value) => _onMenu(context, ref, snapshot, value),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(
                value: archived ? 'restore' : 'archive',
                child: Text(archived ? 'Restore' : 'Archive'),
              ),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
          children: [
            _Header(snapshot: snapshot, archived: archived),
            const SizedBox(height: 16),
            // No card margin and no horizontal padding: on a 360dp phone the
            // grid then gets 336dp, a seventh of which is exactly the 48dp
            // touch-target floor for each day cell.
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
                child: HabitMonthGrid(snapshot: snapshot),
              ),
            ),
            const SizedBox(height: 16),
            _StatsRow(snapshot: snapshot),
            const SizedBox(height: 24),
            _Journal(snapshot: snapshot),
          ],
        ),
      ),
    );
  }

  Future<void> _onMenu(
    BuildContext context,
    WidgetRef ref,
    HabitSnapshot snapshot,
    String value,
  ) async {
    final repo = ref.read(habitsRepositoryProvider);
    final reminders = ref.read(reminderServiceProvider);
    final habit = snapshot.habit;
    switch (value) {
      case 'edit':
        await HabitEditSheet.show(context, habit: habit);
      case 'archive':
        await repo.archiveHabit(habit.id);
        try {
          await reminders.cancelForHabit(habit);
        } catch (_) {}
        if (!context.mounted) return;
        final messenger = ScaffoldMessenger.maybeOf(context);
        Navigator.of(context).pop();
        messenger?.showSnackBar(
          SnackBar(
            content: Text('Archived "${habit.title}".'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                await repo.restoreHabit(habit.id);
                final restored = await repo.habitById(habit.id);
                if (restored != null) {
                  try {
                    await reminders.scheduleForHabit(restored);
                  } catch (_) {}
                }
              },
            ),
          ),
        );
      case 'restore':
        await repo.restoreHabit(habit.id);
        final restored = await repo.habitById(habit.id);
        if (restored != null) {
          try {
            await reminders.scheduleForHabit(restored);
          } catch (_) {}
        }
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete this habit?'),
            content: Text(
              'This removes "${habit.title}" and its history from every '
              'list. This cannot be undone from the app.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        try {
          await reminders.cancelForHabit(habit);
        } catch (_) {}
        await repo.deleteHabit(habit.id);
        if (context.mounted) Navigator.of(context).pop();
    }
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.snapshot, required this.archived});

  final HabitSnapshot snapshot;
  final bool archived;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habit = snapshot.habit;
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.tokens;
    final accent = HabitColors.of(context, habit.colorIndex);
    final reminderTimes =
        ref.watch(habitReminderTimesProvider(habit.id)).value ?? const [];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(
          child: CircleAvatar(
            radius: 26,
            backgroundColor: accent.withValues(alpha: 0.14),
            child: Icon(HabitIcons.of(habit.iconName), color: accent, size: 28),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                habit.title,
                style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                [
                  HabitScheduleText.describe(habit.scheduleRule),
                  if (habit.targetCount > 1)
                    '${habit.targetCount}${habit.unitLabel == null ? '' : ' ${habit.unitLabel}'} a day',
                  if (reminderTimes.isNotEmpty)
                    '${reminderTimes.length == 1 ? 'Reminder' : 'Reminders'} '
                    '${reminderTimes.map((r) => HabitDates.timeOfDay(r.minutesPastMidnight)).join(', ')}',
                ].join(' · '),
                style: textTheme.bodyMedium?.copyWith(color: tokens.textSecondary),
              ),
              if (archived)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Archived',
                    style: textTheme.labelMedium?.copyWith(color: tokens.warning),
                  ),
                ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  HabitStreakBadge(
                    streak: snapshot.streaks.current,
                    color: accent,
                  ),
                  Semantics(
                    container: true,
                    label: 'Best streak ${snapshot.streaks.longest} days',
                    excludeSemantics: true,
                    child: Text(
                      'Best: ${snapshot.streaks.longest}',
                      style: textTheme.titleSmall?.copyWith(
                        color: tokens.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (!archived) ...[
          const SizedBox(width: 8),
          HabitCheckButton(snapshot: snapshot, diameter: 56),
        ],
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.snapshot});

  final HabitSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final best = snapshot.bestWeekday;
    final allowance = restDayAllowanceText(snapshot, snapshot.todayLocalDate);
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatTile(
              label: 'Completion',
              value: formatHabitRate(snapshot.completionRate),
              spoken: snapshot.completionRate == null
                  ? 'Completion rate not available yet'
                  : 'Completion rate ${formatHabitRate(snapshot.completionRate)}',
            ),
            _StatTile(
              label: 'Check-offs',
              value: '${snapshot.totalCheckOffs}',
              spoken: '${snapshot.totalCheckOffs} check-offs in total',
            ),
            _StatTile(
              label: 'Best day',
              value: best == null
                  ? '—'
                  : HabitDates.weekdayShort[best.weekday - 1],
              spoken: best == null
                  ? 'Best day not available yet'
                  : 'Best day ${HabitDates.weekdayNames[best.weekday - 1]}, '
                      '${formatHabitRate(best.rate)}',
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          allowance.text,
          style: textTheme.bodySmall?.copyWith(
            color: allowance.warn ? tokens.warning : tokens.textMuted,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.spoken,
  });

  final String label;
  final String value;
  final String spoken;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // container: without it the three tiles' labels merge into one node and
    // TalkBack reads them as a single run-on sentence.
    return Semantics(
      container: true,
      label: spoken,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 104),
        child: Card(
          margin: EdgeInsets.zero,
          color: context.colors.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  label,
                  style: textTheme.labelMedium
                      ?.copyWith(color: context.tokens.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Journal extends ConsumerWidget {
  const _Journal({required this.snapshot});

  final HabitSnapshot snapshot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.tokens;
    final entries =
        ref.watch(habitJournalProvider(snapshot.habit.id)).value ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            'JOURNAL',
            style: textTheme.labelSmall?.copyWith(
              color: tokens.textMuted,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          Card(
            color: context.colors.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'No notes yet. Tap a day to write one.',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(color: tokens.textMuted),
              ),
            ),
          )
        else
          for (final entry in entries)
            Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                title: Text(
                  HabitDates.short(entry.localDate),
                  style: textTheme.labelLarge
                      ?.copyWith(color: tokens.textSecondary),
                ),
                subtitle: Text(
                  entry.note ?? '',
                  style: textTheme.bodyMedium,
                ),
                onTap: () => editHabitNote(
                  context,
                  ref.read(habitsRepositoryProvider),
                  habitId: snapshot.habit.id,
                  localDate: entry.localDate,
                  initial: entry.note,
                ),
              ),
            ),
      ],
    );
  }
}
