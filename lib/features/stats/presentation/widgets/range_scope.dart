import 'package:flutter/material.dart';

import '../../../../core/widgets/cairn_card.dart';
import '../../../../theme/app_theme.dart';

/// The wording for "does this move with the range picker", in one place so the
/// Stats screen and its "More stats" screen say it identically.
abstract final class RangeScope {
  /// For numbers that are recomputed when the picker moves.
  static const follows = 'Follows the range';

  /// For numbers that are deliberately not: a trailing year, an all-time best,
  /// this calendar month. Says what it *does* (stays the same) rather than only
  /// what it does not, so it reads as a promise and not as an apology.
  static const fixed = 'Same for every range';
}

/// A small heading that says which side of the range picker the group of
/// numbers under it sits on.
///
/// The Stats screen mixes the two kinds, and a qualifier in an 11px tile label
/// plus a long-press tooltip both read, at a glance, as "I tapped Week and half
/// of this didn't change". So the two groups are separated and headed, visibly
/// and permanently, with no interaction needed.
class RangeScopeHeading extends StatelessWidget {
  /// The numbers under this move when the range picker does.
  const RangeScopeHeading.follows({super.key})
      : icon = Icons.date_range_rounded,
        label = RangeScope.follows,
        spoken = 'These numbers follow the range picker';

  /// The numbers under this do not: they read the same at every range.
  const RangeScopeHeading.fixed({super.key})
      : icon = Icons.push_pin_outlined,
        label = RangeScope.fixed,
        spoken = 'These numbers are not affected by the range picker';

  final IconData icon;
  final String label;

  /// What a screen reader says: the uppercase, tracked-out label is a
  /// styling choice and reads worse aloud than a sentence.
  final String spoken;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Semantics(
      header: true,
      label: spoken,
      excludeSemantics: true,
      child: Row(
        children: [
          Icon(icon, size: 14, color: tokens.textMuted),
          const SizedBox(width: 6),
          // A Flexible, so the label gives way rather than overflowing at a
          // large font scale.
          Flexible(child: CardChrome.sectionLabel(context, label)),
        ],
      ),
    );
  }
}

/// A small persistent badge for a card that does not move with the range picker
/// above it: the activity heatmaps and the streak list on "More stats". A pill
/// rather than more subheading text, because a filled shape with an icon is
/// what makes the eye stop where a "last 365 days" line was easy to read past.
/// Always visible; never depends on a tooltip.
class FixedRangePill extends StatelessWidget {
  const FixedRangePill({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: 'Not affected by the range picker',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: colors.secondaryContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.push_pin_outlined,
              size: 12,
              color: colors.onSecondaryContainer,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                RangeScope.fixed,
                style: textTheme.labelSmall?.copyWith(
                  fontSize: 11,
                  letterSpacing: 0,
                  fontWeight: FontWeight.w700,
                  color: colors.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
