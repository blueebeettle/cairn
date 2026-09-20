import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/habits/habit_streak.dart';
import '../../../../theme/app_theme.dart';

/// How one scheduled day is drawn, everywhere a day is drawn:
///
///   done     filled
///   missed   hollow ring
///   neutral  dashed ring       (an excused rest day)
///   pending  half-filled       (today, not yet met)
///   future   nothing           (NEVER drawn as missed)
///   null     nothing           (not a scheduled day)
///
/// One painter for the card dots and the month grid, so the two can never
/// disagree about what a hollow circle means.
class HabitDayMarkPainter extends CustomPainter {
  HabitDayMarkPainter({
    required this.outcome,
    required this.color,
    this.strokeWidth = 2,
  });

  final HabitDayOutcome? outcome;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - strokeWidth / 2;
    if (radius <= 0) return;

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (outcome) {
      case HabitDayOutcome.done:
        canvas.drawCircle(center, radius + strokeWidth / 2, fill);
      case HabitDayOutcome.missed:
        canvas.drawCircle(center, radius, stroke);
      case HabitDayOutcome.neutral:
        _dashedCircle(canvas, center, radius, stroke);
      case HabitDayOutcome.pending:
        canvas.drawCircle(center, radius, stroke);
        // Bottom half filled: the day is underway, not over.
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          0,
          math.pi,
          false,
          fill,
        );
      case HabitDayOutcome.future:
      case null:
        break;
    }
  }

  void _dashedCircle(Canvas canvas, Offset c, double r, Paint paint) {
    const dashes = 10;
    const sweep = 2 * math.pi / dashes;
    final rect = Rect.fromCircle(center: c, radius: r);
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * sweep, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(HabitDayMarkPainter old) =>
      old.outcome != outcome ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}

/// A single day mark with its screen-reader label.
class HabitDayMark extends StatelessWidget {
  const HabitDayMark({
    super.key,
    required this.outcome,
    required this.color,
    required this.semanticLabel,
    this.size = 14,
  });

  final HabitDayOutcome? outcome;
  final Color color;
  final String semanticLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: HabitDayMarkPainter(
            outcome: outcome,
            color: color,
            strokeWidth: size < 16 ? 1.6 : 2,
          ),
        ),
      ),
    );
  }
}

/// The streak number with a flame.
///
/// Zero is not a failure. A new habit has broken nothing, so 0 renders as a
/// muted dash with an outlined flame — never a red zero.
class HabitStreakBadge extends StatelessWidget {
  const HabitStreakBadge({
    super.key,
    required this.streak,
    required this.color,
    this.large = true,
  });

  final int streak;
  final Color color;
  final bool large;

  static String semanticLabel(int streak) =>
      streak == 0 ? 'No streak yet' : '$streak day streak';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = context.tokens.textMuted;
    final live = streak > 0;
    final style = (large ? textTheme.headlineSmall : textTheme.titleMedium)
        ?.copyWith(
      fontWeight: FontWeight.w800,
      color: live ? context.colors.onSurface : muted,
      height: 1.0,
    );

    return Semantics(
      container: true,
      label: semanticLabel(streak),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            live
                ? Icons.local_fire_department_rounded
                : Icons.local_fire_department_outlined,
            size: large ? 22 : 18,
            color: live ? color : muted,
          ),
          const SizedBox(width: 2),
          Text(live ? '$streak' : '—', style: style),
        ],
      ),
    );
  }
}

/// Ring progress for counted habits: "3 of 8" with the ring filling around.
class HabitProgressRingPainter extends CustomPainter {
  HabitProgressRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    this.strokeWidth = 4,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - strokeWidth / 2;
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, track);
    if (progress <= 0) return;
    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(HabitProgressRingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor;
}
