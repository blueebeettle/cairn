import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Single shared FocusRing widget used by BOTH the Today and Timer screens.
///
/// Implements exact geometry:
/// - ringBox     = (screenWidth * widthFactor).clamp(200.0, 260.0) dp
/// - stroke      = ringBox * 0.07 (~14-18dp)
/// - trackStroke = stroke (same, not thinner)
/// - strokeCap   = StrokeCap.round
/// - start angle = -90 degrees (12 o'clock), sweeping clockwise
///
/// Colors:
/// - track    = colorScheme.primaryContainer
/// - progress = colorScheme.primary
/// - paused   = colorScheme.secondary (the lighter lavender)
/// - Ready state draws the TRACK ONLY, no progress arc
///
/// Center text:
/// - figure   = (screenWidth * 0.13).clamp(44.0, 56.0) dp, Bricolage Grotesque,
///               w700, tabular figures, height 1.0
/// - label    = labelSmall, letterSpacing 1.4, uppercase, onSurfaceVariant
/// - gap between figure and label = 4dp
class FocusRing extends StatelessWidget {
  const FocusRing({
    super.key,
    required this.progress,
    required this.figure,
    this.label,
    this.widthFactor = 0.60,
    this.isPaused = false,
    this.drawProgress = true,
    this.trackColor,
    this.progressColor,
    this.figureColor,
    this.semanticsAnnouncement,
    this.onTap,
  });

  /// Progress fraction from 0.0 to 1.0.
  final double progress;

  /// Main text figure in the center of the ring.
  final String figure;

  /// Optional label below the figure (e.g. PLANNED, REMAINING, PAUSED, LOGGED, TODAY).
  final String? label;

  /// Optional spoken semantic announcement (e.g. "15 of 25 minutes, REMAINING").
  final String? semanticsAnnouncement;

  /// Screen width multiplier (0.60 for Timer screen, 0.58 for Today screen).
  final double widthFactor;

  /// Whether the session is paused (switches progress arc to colorScheme.secondary and dims figure).
  final bool isPaused;

  /// If false, draws the TRACK ONLY with no progress arc (used in Ready state).
  final bool drawProgress;

  /// Optional override for track color (defaults to colorScheme.primaryContainer).
  final Color? trackColor;

  /// Optional override for progress color (defaults to isPaused ? colorScheme.secondary : colorScheme.primary).
  final Color? progressColor;

  /// Optional override for figure color (defaults to isPaused ? onSurface with 0.38 alpha : onSurface).
  final Color? figureColor;

  /// Optional tap callback (e.g. on Today screen to navigate to Timer).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final ringBox = (screenWidth * widthFactor).clamp(200.0, 260.0);
    final stroke = ringBox * 0.07;
    final trackStroke = stroke;

    final actualTrackColor = trackColor ?? colorScheme.primaryContainer;
    final actualProgressColor = progressColor ??
        (isPaused ? colorScheme.secondary : colorScheme.primary);

    final figureFontSize = (screenWidth * 0.13).clamp(44.0, 56.0);
    final actualFigureColor = figureColor ??
        (isPaused
            ? colorScheme.onSurface.withValues(alpha: 0.38)
            : colorScheme.onSurface);

    final figureStyle = statFigure(context).copyWith(
      fontSize: figureFontSize,
      height: 1.0,
      color: actualFigureColor,
    );

    final labelStyle = textTheme.labelSmall?.copyWith(
      letterSpacing: 1.4,
      color: colorScheme.onSurfaceVariant,
    );

    Widget content = SizedBox(
      width: ringBox,
      height: ringBox,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(ringBox, ringBox),
            painter: _FocusRingPainter(
              progress: drawProgress ? progress : 0.0,
              trackColor: actualTrackColor,
              progressColor: actualProgressColor,
              stroke: stroke,
              trackStroke: trackStroke,
            ),
          ),
          Padding(
            padding: EdgeInsets.all(stroke + 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    figure,
                    style: figureStyle,
                  ),
                ),
                if (label != null && label!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label!.toUpperCase(),
                      style: labelStyle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      content = InkResponse(
        onTap: onTap,
        customBorder: const CircleBorder(),
        highlightShape: BoxShape.circle,
        splashColor: colorScheme.primary.withValues(alpha: 0.12),
        child: content,
      );
    }

    final spokenLabel = semanticsAnnouncement ??
        (label != null && label!.isNotEmpty ? '$figure, $label' : figure);

    return Semantics(
      label: spokenLabel,
      value: drawProgress ? '${(progress * 100).round()}%' : null,
      button: onTap != null,
      enabled: true,
      excludeSemantics: true,
      child: content,
    );
  }
}

class _FocusRingPainter extends CustomPainter {
  const _FocusRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.stroke,
    required this.trackStroke,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double stroke;
  final double trackStroke;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - stroke) / 2;

    // Background track
    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = trackStroke
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, trackPaint);

    // Foreground progress arc: start at -90 deg (12 o'clock), sweep clockwise
    if (progress > 0.0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..strokeWidth = stroke
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FocusRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.stroke != stroke ||
        oldDelegate.trackStroke != trackStroke;
  }
}
