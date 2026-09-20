import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/habits/habit_streak.dart';
import '../../../../data/repositories/habits_repository.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/habit_presentation.dart';
import '../habit_check_controller.dart';
import 'habit_marks.dart';

/// The check-off control for one habit, or — when the habit is not due
/// today — a greyed "Next: Wednesday" in its place.
///
/// A habit that is not scheduled today gets no circle at all. An unchecked
/// circle invites a tap, and a tap on a day the habit does not run would be
/// someone breaking their own data.
class HabitCheckButton extends ConsumerWidget {
  const HabitCheckButton({
    super.key,
    required this.snapshot,
    this.diameter = 56,
  });

  final HabitSnapshot snapshot;

  /// Visual size. The touch target is never below 48×48dp regardless.
  final double diameter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habit = snapshot.habit;
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    if (!snapshot.isScheduledToday) {
      final next = HabitDates.nextLabel(
        snapshot.nextDueDate,
        snapshot.todayLocalDate,
      );
      return Semantics(
        container: true,
        label: '${habit.title}, not scheduled today. $next',
        excludeSemantics: true,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: 48, maxWidth: diameter * 1.9),
          child: Center(
            child: Text(
              next,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelSmall?.copyWith(color: tokens.textMuted),
            ),
          ),
        ),
      );
    }

    // Watching the whole map is deliberate: the override for this habit can
    // appear or disappear, and both must rebuild the circle.
    ref.watch(habitCheckControllerProvider);
    final controller = ref.read(habitCheckControllerProvider.notifier);
    final count = controller.countFor(snapshot);
    final target = habit.targetCount < 1 ? 1 : habit.targetCount;
    final done = count >= target;
    final resting = snapshot.isRestingToday && count == 0;
    final color = HabitColors.of(context, habit.colorIndex);
    final size = diameter < 48 ? 48.0 : diameter;
    final unit = habit.unitLabel;

    Widget face;
    if (done) {
      face = Container(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Icon(
          Icons.check_rounded,
          color: ThemeData.estimateBrightnessForColor(color) == Brightness.dark
              ? Colors.white
              : Colors.black,
          size: size * 0.5,
        ),
      );
    } else if (target > 1) {
      face = CustomPaint(
        painter: HabitProgressRingPainter(
          progress: count / target,
          color: color,
          trackColor: tokens.lineSoft,
          strokeWidth: size < 52 ? 3.5 : 4.5,
        ),
        child: Padding(
          padding: EdgeInsets.all(size * 0.16),
          child: FittedBox(
            child: Text(
              '$count of $target',
              style: textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: context.colors.onSurface,
              ),
            ),
          ),
        ),
      );
    } else {
      // Hollow ring; dashed when today is a marked rest day.
      face = CustomPaint(
        painter: HabitDayMarkPainter(
          outcome: resting ? HabitDayOutcome.neutral : HabitDayOutcome.missed,
          color: color,
          strokeWidth: 2.5,
        ),
        child: const SizedBox.expand(),
      );
    }

    final spokenCount = target > 1
        ? '$count of $target${unit == null || unit.isEmpty ? '' : ' $unit'}'
        : null;

    return Semantics(
      container: true,
      label: '${habit.title}, ${done ? 'done' : 'not done'} today',
      value: spokenCount,
      hint: done ? 'Double tap to undo one check-off' : null,
      button: true,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () async {
              try {
                await controller.tap(snapshot);
              } catch (_) {
                if (!context.mounted) return;
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  const SnackBar(content: Text('That check-off did not save.')),
                );
              }
            },
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 140),
              child: KeyedSubtree(
                key: ValueKey('$done-$count-$resting'),
                child: face,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
