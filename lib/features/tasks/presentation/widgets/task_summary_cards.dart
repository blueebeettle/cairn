import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';

/// "Today's progress" — how much of today's list is cleared.
///
/// Layout from `claude-outputs/designs/Tasks.dc.html`: an uppercase muted
/// label, the count on the trailing edge in the accent, and a 10px rounded
/// track under both. The bar fills as tasks get cleared, so it reads as
/// progress rather than as a backlog.
class TodayProgressCard extends StatelessWidget {
  const TodayProgressCard({
    super.key,
    required this.open,
    required this.done,
  });

  /// Tasks still to do today.
  final int open;

  /// Tasks cleared today.
  final int done;

  int get total => open + done;

  /// Share of today's list cleared, 0 when there is nothing to clear.
  double get fraction => total == 0 ? 0 : (done / total).clamp(0.0, 1.0);

  /// The trailing figure — "4 / 7 cleared".
  String get label => '$done / $total cleared';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      container: true,
      label: "Today's progress, $done of $total cleared",
      excludeSemantics: true,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Both sides give way rather than overflow at a large font scale.
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      "TODAY'S PROGRESS",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelSmall?.copyWith(
                        color: tokens.textMuted,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: textTheme.labelLarge?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 10,
                  backgroundColor: tokens.lineSoft,
                  valueColor: AlwaysStoppedAnimation(colors.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Done today" — the tally at the foot of the list.
///
/// Separate from the expand/collapse row above it: that one is a control,
/// this is the day's score.
class DoneTodayCard extends StatelessWidget {
  const DoneTodayCard({
    super.key,
    required this.done,
    required this.remaining,
  });

  final int done;
  final int remaining;

  String get clearedLabel => done == 0
      ? 'Nothing cleared yet'
      : '$done ${done == 1 ? 'task' : 'tasks'} cleared';

  String get remainingLabel => remaining == 0 ? 'All clear' : '$remaining to go';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      container: true,
      label: '$clearedLabel, $remainingLabel',
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          border: Border.all(color: colors.outline),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                clearedLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall?.copyWith(
                  color: tokens.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  remainingLabel,
                  maxLines: 1,
                  style: textTheme.bodySmall?.copyWith(
                    color: tokens.textMuted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
