import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/habits/habit_streak.dart';
import '../../../../data/providers/habit_providers.dart';
import '../../../../data/repositories/habits_repository.dart';
import '../../../../theme/app_theme.dart';
import '../../../reminders/reminder_service.dart';
import '../../domain/habit_presentation.dart';

/// What the rest-day row says, computed before the user commits.
///
/// SPEC §10.3: the UI must show what remains *before* the last rest day is
/// spent — "2 of 2 rest days used this month — skipping again will reset your
/// streak" — rather than reporting a broken streak afterwards.
({String text, bool warn}) restDayAllowanceText(
  HabitSnapshot snapshot,
  String localDate,
) {
  final allowance = snapshot.habit.skipAllowancePerMonth;
  final used = snapshot.excusedInMonth(localDate.substring(0, 7));
  if (allowance <= 0) {
    return (
      text: 'This habit allows no rest days — resting will reset your streak.',
      warn: true,
    );
  }
  if (used >= allowance) {
    return (
      text: '$used of $allowance rest days used this month — skipping again '
          'will reset your streak.',
      warn: true,
    );
  }
  final left = allowance - used;
  return (
    text: left == 1
        ? '1 of $allowance rest days left this month — this is the last one.'
        : '$left of $allowance rest days left this month.',
    warn: false,
  );
}

/// The sheet for one day of one habit: mark done, mark as rest day, note,
/// clear. This is how a missed day gets filled in, and the reason
/// `HabitsRepository.check` takes a `localDate`.
Future<void> showHabitDaySheet(
  BuildContext context,
  WidgetRef ref, {
  required HabitSnapshot snapshot,
  required String localDate,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _HabitDaySheet(
      snapshot: snapshot,
      localDate: localDate,
      hostContext: context,
    ),
  );
}

class _HabitDaySheet extends ConsumerWidget {
  const _HabitDaySheet({
    required this.snapshot,
    required this.localDate,
    required this.hostContext,
  });

  final HabitSnapshot snapshot;
  final String localDate;

  /// The screen underneath, for snack bars that outlive the sheet.
  final BuildContext hostContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.tokens;
    final habit = snapshot.habit;
    final record = snapshot.entries[localDate];
    final count = record?.count ?? 0;
    final skipped = record?.skipped ?? false;
    final target = habit.targetCount < 1 ? 1 : habit.targetCount;
    final outcome = snapshot.outcomeOn(localDate);
    final done = count >= target;
    final unit = habit.unitLabel;

    final journal = ref.watch(habitJournalProvider(habit.id)).value ?? const [];
    String? note;
    for (final e in journal) {
      if (e.localDate == localDate) note = e.note;
    }

    final allowance = restDayAllowanceText(snapshot, localDate);
    final status = target > 1
        ? '$count of $target${unit == null || unit.isEmpty ? '' : ' $unit'}'
            ' · ${HabitOutcomeText.of(outcome)}'
        : HabitOutcomeText.of(outcome);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  HabitDates.spoken(localDate),
                  style:
                      textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${habit.title} · $status',
                  style: textTheme.bodyMedium
                      ?.copyWith(color: tokens.textSecondary),
                ),
              ],
            ),
          ),
          if (!done)
            ListTile(
              leading: const Icon(Icons.check_circle_rounded),
              title: const Text('Mark done'),
              onTap: () => _run(context, ref, (repo) async {
                for (var i = count; i < target; i++) {
                  await repo.check(habit.id, localDate: localDate);
                }
              }),
            ),
          if (!skipped)
            ListTile(
              leading: Icon(
                Icons.bedtime_outlined,
                color: allowance.warn ? tokens.warning : null,
              ),
              title: const Text('Mark as rest day'),
              subtitle: Text(
                allowance.text,
                style: allowance.warn
                    ? textTheme.bodySmall?.copyWith(
                        color: tokens.warning,
                        fontWeight: FontWeight.w600,
                      )
                    : null,
              ),
              isThreeLine: allowance.text.length > 48,
              onTap: () => _run(context, ref, (repo) async {
                final excused =
                    await repo.setSkipped(habit.id, localDate: localDate);
                _snack(
                  excused
                      ? 'Rest day marked. Your streak is safe.'
                      : 'Rest day marked. This month\'s rest days were '
                          'already used, so it counts as missed.',
                );
              }),
            )
          else
            ListTile(
              leading: const Icon(Icons.bedtime_off_outlined),
              title: const Text('Remove rest day'),
              onTap: () => _run(context, ref, (repo) async {
                await repo.setSkipped(habit.id,
                    localDate: localDate, skipped: false);
              }),
            ),
          ListTile(
            leading: const Icon(Icons.edit_note_rounded),
            title: Text(note == null ? 'Add a note' : 'Edit note'),
            subtitle: note == null
                ? null
                : Text(note, maxLines: 2, overflow: TextOverflow.ellipsis),
            onTap: () async {
              final repo = ref.read(habitsRepositoryProvider);
              Navigator.of(context).pop();
              await editHabitNote(
                hostContext,
                repo,
                habitId: habit.id,
                localDate: localDate,
                initial: note,
              );
            },
          ),
          if (count > 0 || skipped)
            ListTile(
              leading: const Icon(Icons.remove_circle_outline_rounded),
              title: const Text('Clear'),
              subtitle: const Text('Remove check-offs and rest day. Keeps the note.'),
              onTap: () => _run(context, ref, (repo) async {
                for (var i = 0; i < count; i++) {
                  await repo.uncheck(habit.id, localDate: localDate);
                }
                if (skipped) {
                  await repo.setSkipped(
                    habit.id,
                    localDate: localDate,
                    skipped: false,
                  );
                }
              }),
            ),
        ],
      ),
    );
  }

  /// Reads everything it needs from [ref] BEFORE popping: once the sheet's
  /// route is gone its ref is disposed, and the write outlives it.
  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function(HabitsRepository repo) action,
  ) async {
    final repo = ref.read(habitsRepositoryProvider);
    final reminders = ref.read(reminderServiceProvider);
    Navigator.of(context).pop();
    try {
      await action(repo);
      if (localDate == snapshot.todayLocalDate) {
        try {
          await reminders.scheduleForHabit(snapshot.habit);
        } catch (_) {}
      }
    } catch (e) {
      _snack('That did not save: $e');
    }
  }

  void _snack(String message) {
    if (!hostContext.mounted) return;
    ScaffoldMessenger.maybeOf(hostContext)
        ?.showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Edits the journal note for one day. An empty note clears it.
Future<void> editHabitNote(
  BuildContext context,
  HabitsRepository repo, {
  required String habitId,
  required String localDate,
  String? initial,
}) async {
  final controller = TextEditingController(text: initial ?? '');
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(HabitDates.spoken(localDate)),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: 5,
        minLines: 2,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'How did it go?'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (result == null) return;
  if ((initial ?? '') == result.trim()) return;
  await repo.setNote(habitId, localDate: localDate, note: result);
}

/// Whether a day cell accepts a tap: a scheduled day, from the anchor up to
/// and including today. Future and unscheduled days have nothing to record.
bool isEditableDay(HabitSnapshot snapshot, String localDate) {
  final outcome = snapshot.outcomeOn(localDate);
  return outcome != null && outcome != HabitDayOutcome.future;
}
