import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../theme/app_theme.dart';

/// The check-off flourish: a short pop plus three flecks thrown clear of the
/// circle.
///
/// Purely decorative — it reacts to [done] going true and holds no state of
/// its own. The flecks take their colours from `context.tokens.series`, and
/// the whole thing is inside 200ms, so it lands with the tap rather than
/// asking to be watched.
class HabitCheckBurst extends StatefulWidget {
  const HabitCheckBurst({
    super.key,
    required this.done,
    required this.diameter,
    required this.child,
  });

  /// Whether the habit reads as complete. A false -> true flip fires the
  /// burst; an undo does not.
  final bool done;

  final double diameter;

  final Widget child;

  static const Duration duration = Duration(milliseconds: 180);

  /// Where each fleck flies, as (angle from 12 o'clock, travel, radius).
  /// Off-axis and unequal, matching the burst in `Today.dc.html` — three even
  /// dots would read as a loading spinner.
  static const List<({double turns, double travel, double radius})> _flecks = [
    (turns: -0.08, travel: 0.66, radius: 3.0),
    (turns: 0.12, travel: 0.60, radius: 2.5),
    (turns: 0.30, travel: 0.72, radius: 2.0),
  ];

  @override
  State<HabitCheckBurst> createState() => _HabitCheckBurstState();
}

class _HabitCheckBurstState extends State<HabitCheckBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: HabitCheckBurst.duration,
  );

  late final Animation<double> _pop = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.14,
      ).chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 40,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.14,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 60,
    ),
  ]).animate(_controller);

  late final Animation<double> _fling = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void didUpdateWidget(covariant HabitCheckBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.done && !oldWidget.done) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final series = context.tokens.series;
    final radius = widget.diameter / 2;

    // Sized here rather than relying on the caller's constraints: the flecks
    // are loose Stack children, so an unsized Stack would collapse to a dot.
    return SizedBox.square(
      dimension: widget.diameter,
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          final t = _fling.value;
          // Flecks fade out over the back half of the throw.
          final fade = (1 - t) < 0.5 ? ((1 - t) * 2).clamp(0.0, 1.0) : 1.0;

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (_controller.isAnimating)
                for (var i = 0; i < HabitCheckBurst._flecks.length; i++)
                  () {
                    final fleck = HabitCheckBurst._flecks[i];
                    final angle = fleck.turns * 2 * math.pi;
                    final distance = radius * (0.9 + fleck.travel * t);
                    return Transform.translate(
                      offset: Offset(
                        math.sin(angle) * distance,
                        -math.cos(angle) * distance,
                      ),
                      child: Opacity(
                        opacity: fade,
                        child: Container(
                          width: fleck.radius * 2,
                          height: fleck.radius * 2,
                          decoration: BoxDecoration(
                            color: series[i % series.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }(),
              // Positioned.fill so the circle keeps the full tap target: the
              // flecks are loose children and must not be what sizes the Stack.
              Positioned.fill(
                child: Transform.scale(scale: _pop.value, child: child),
              ),
            ],
          );
        },
      ),
    );
  }
}
