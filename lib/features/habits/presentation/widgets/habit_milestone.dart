import 'package:flutter/material.dart';

import '../../../../data/repositories/habits_repository.dart';

/// Shared chrome for a habit that just hit a milestone.
///
/// Geometry from the milestone card in `claude-outputs/designs/HabitsList.dc.html`
/// — a 2px ring in the accent plus a soft drop glow, and a filled streak pill
/// in place of the ordinary flame badge. Kept here rather than inline in
/// `habits_screen.dart` so §4's celebration screen can reuse the same accent.
abstract final class MilestoneChrome {
  /// The milestone accent.
  ///
  /// Light leads with the lavender (`secondary` #BA7DD6) and dark with the
  /// lightened purple (`primary` #C08FE8), matching the two mockup boards.
  /// Fill and ring only — the lavender scores 2.74:1 on cream and must never
  /// carry text.
  static Color accent(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return scheme.brightness == Brightness.dark
        ? scheme.primary
        : scheme.secondary;
  }

  /// The glow cast under a milestone card: `0 10px 22px` in the accent.
  ///
  /// A CSS blur of r spreads over sigma = r / 2, and Flutter's BoxShadow
  /// converts blurRadius to sigma with a factor of 0.57735 — so 22px of CSS
  /// blur is a blurRadius of about 19.
  static List<BoxShadow> glow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: accent(context).withValues(alpha: isDark ? 0.30 : 0.35),
        blurRadius: 22 * 0.866,
        offset: const Offset(0, 10),
      ),
    ];
  }

  /// The 2px ring the milestone card wears instead of the usual hairline.
  static BorderSide ring(BuildContext context) =>
      BorderSide(color: accent(context), width: 2);
}

/// Rest days still available this month for one habit.
///
/// `skipAllowancePerMonth - excusedThisMonth`, floored at zero. The single
/// place this subtraction happens — [FreezesChip] on the Habits list sums it
/// across every habit in view via [totalFreezesRemaining], and §4's
/// celebration footer reads it for the one habit being celebrated. Neither
/// call site repeats the arithmetic.
int habitFreezesRemaining(HabitSnapshot snapshot) {
  final left = snapshot.habit.skipAllowancePerMonth - snapshot.excusedThisMonth;
  return left > 0 ? left : 0;
}

/// [habitFreezesRemaining], summed over every habit in view — what the
/// Habits-list header chip shows. The allowance is per habit, so this total
/// is necessarily a sum rather than a single habit's figure.
int totalFreezesRemaining(Iterable<HabitSnapshot> snapshots) {
  var total = 0;
  for (final s in snapshots) {
    total += habitFreezesRemaining(s);
  }
  return total;
}

/// The streak figure as a filled pill — the milestone row's answer to
/// `HabitStreakBadge`'s flame.
class MilestoneStreakPill extends StatelessWidget {
  const MilestoneStreakPill({super.key, required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      container: true,
      label: '$streak day streak, a milestone',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: scheme.onPrimary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '$streak',
              style: textTheme.labelLarge?.copyWith(
                color: scheme.onPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "N freezes" pill beside the Habits title.
///
/// Counts rest days still available this month — `skipAllowancePerMonth`
/// minus what has been excused — summed across the habits in view.
class FreezesChip extends StatelessWidget {
  const FreezesChip({super.key, required this.remaining});

  final int remaining;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final label = '$remaining ${remaining == 1 ? 'freeze' : 'freezes'}';

    return Tooltip(
      message: 'Rest days left this month across your habits',
      child: Semantics(
        label: '$label left this month',
        excludeSemantics: true,
        // The app bar already carries three actions; at a 200% font scale an
        // unbounded chip is what tips the row into an overflow. It scales down
        // instead of growing — the full wording still reaches a screen reader
        // through the label above, which text scale does not affect.
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 112),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.ac_unit_rounded,
                    size: 14,
                    color: scheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: textTheme.labelMedium?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
