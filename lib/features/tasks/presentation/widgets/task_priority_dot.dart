import 'package:flutter/material.dart';

/// The 7px priority dot beside a task title, per the rows in
/// `claude-outputs/designs/Tasks.dc.html`.
///
/// Takes the colour rather than the priority: `_buildTaskCard` already owns
/// the `priority -> colour` switch, and two copies of that mapping would
/// eventually disagree.
///
/// Renders nothing when [color] is transparent — priority 4 and unset both
/// resolve that way, and the mockup's unprioritised rows have their title
/// flush left rather than indented past an invisible dot.
class TaskPriorityDot extends StatelessWidget {
  const TaskPriorityDot({super.key, required this.color, this.size = 7});

  final Color color;
  final double size;

  bool get isVisible => color.a > 0;

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(right: size * 0.86),
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
