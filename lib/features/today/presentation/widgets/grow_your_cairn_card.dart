import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/cairn_card.dart';
import '../../../../core/widgets/cairn_glyph.dart';
import '../../../../data/providers/habit_providers.dart';
import '../../../../theme/app_theme.dart';

/// How many cairn stones today's check-offs have earned.
///
/// Four stones over however many habits are due: `min(4, ceil(checked / total
/// * 4))`. With four or fewer habits this is one stone per habit; with more,
/// each stone stands for a quarter of the day's list. Nothing due means no
/// cairn at all rather than a full one.
int cairnStoneCount({required int checked, required int total}) {
  if (total <= 0 || checked <= 0) return 0;
  final capped = checked > total ? total : checked;
  return math.min(4, (capped / total * 4).ceil());
}

/// The "Grow your cairn" card: the glyph grows as today's habits get checked.
///
/// Layout from `claude-outputs/designs/Today.dc.html` — 22 radius, 18/18/18/16
/// padding, a 16 gap between the glyph and the text, outlined card on
/// `surfaceContainerLow`.
///
/// Renders nothing when no habit is due today, the same way
/// `TodayHabitsSection` does: an empty cairn with no way to grow it is just a
/// reminder that the screen has nothing to say.
class GrowYourCairnCard extends ConsumerWidget {
  const GrowYourCairnCard({
    super.key,
    required this.currentStreakDays,
  });

  final int currentStreakDays;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(habitsDoneTodayProvider);
    if (counts.due == 0) return const SizedBox.shrink();

    final colors = context.colors;
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    final stones = cairnStoneCount(checked: counts.done, total: counts.due);
    final remaining = counts.due - counts.done;

    final caption = remaining <= 0
        ? 'All ${counts.due} done — your cairn is standing.'
        : '$remaining more ${remaining == 1 ? 'habit' : 'habits'} today '
            'adds to your cairn';

    return Semantics(
      container: true,
      label: '$currentStreakDays day streak. '
          '${counts.done} of ${counts.due} habits done today. $caption',
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          // Shadow-led like every other card, rather than the flat outlined
          // panel this used to be — it sat directly above the focus card and
          // the two read as different systems.
          color: CardChrome.card(context),
          borderRadius: BorderRadius.circular(22),
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Animates so a check-off is seen to add a stone, rather than the
            // card silently being different on the next build.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
                  alignment: Alignment.bottomCenter,
                  child: child,
                ),
              ),
              child: CairnGlyph(
                key: ValueKey(stones),
                stoneCount: stones,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(
                          '$currentStreakDays',
                          style: statFigure(context).copyWith(
                            fontSize: 30,
                            color: colors.primary,
                            height: 1,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'day streak',
                          style: textTheme.titleSmall?.copyWith(
                            color: tokens.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    caption,
                    style: textTheme.bodySmall?.copyWith(
                      color: tokens.textMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
