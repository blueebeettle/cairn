import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/providers/habit_providers.dart';
import '../../../../theme/app_theme.dart';
import '../habit_detail_screen.dart';
import 'habit_check_button.dart';

/// The Habits row on the Today screen: today's scheduled habits as check
/// circles, checkable in place.
///
/// Renders nothing — not an empty box — when no habit is due today.
class TodayHabitsSection extends ConsumerWidget {
  const TodayHabitsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshots = ref.watch(habitSnapshotsProvider).value ?? const [];
    final due = snapshots.where((s) => s.isScheduledToday).toList();
    if (due.isEmpty) return const SizedBox.shrink();

    final counts = ref.watch(habitsDoneTodayProvider);
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            header: true,
            label: 'Habits, ${counts.done} of ${counts.due} done',
            excludeSemantics: true,
            child: Text(
              'HABITS — ${counts.done} OF ${counts.due}',
              style: textTheme.labelSmall?.copyWith(
                color: tokens.textMuted,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in due)
                  SizedBox(
                    width: 84,
                    child: Column(
                      children: [
                        HabitCheckButton(snapshot: s, diameter: 52),
                        const SizedBox(height: 4),
                        // The title opens the detail; the circle checks off.
                        // Two targets, because a long-press to open detail is
                        // undiscoverable and TalkBack has no long-press.
                        InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () => HabitDetailScreen.open(context, s.habit.id),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 48),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: Text(
                                s.habit.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: textTheme.labelMedium,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
