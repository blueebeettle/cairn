import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/habits/habit_schedule.dart';
import '../../../../core/habits/habit_streak.dart';
import '../../../../core/time/time_service.dart';
import '../../../../data/providers/database_provider.dart';
import '../../../../data/repositories/habits_repository.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/habit_presentation.dart';
import 'habit_day_sheet.dart';
import 'habit_marks.dart';

/// One month of one habit, one cell per calendar day.
///
/// Each cell's outcome is a LOOKUP, never a computation:
///
///   on or before today  -> `snapshot.streaks.outcomes[date]`
///                          (absent means the day was not scheduled)
///   after today         -> `future` if `HabitSchedule.occursOn`, else blank
///
/// The month runs past today, and those days are drawn plainly empty —
/// never as missed. A calendar that paints the rest of the month as failures
/// is the fastest way to make a working streak look broken.
///
/// Months before the habit's anchor are not rendered; the arrows stop there.
class HabitMonthGrid extends ConsumerStatefulWidget {
  const HabitMonthGrid({super.key, required this.snapshot});

  final HabitSnapshot snapshot;

  @override
  ConsumerState<HabitMonthGrid> createState() => _HabitMonthGridState();
}

class _HabitMonthGridState extends ConsumerState<HabitMonthGrid> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    final today = TimeService.parseLocalDate(widget.snapshot.todayLocalDate);
    _year = today.year;
    _month = today.month;
  }

  int _monthIndex(int y, int m) => y * 12 + (m - 1);

  bool get _canGoBack {
    final anchor = TimeService.parseLocalDate(widget.snapshot.habit.anchorDate);
    return _monthIndex(_year, _month) > _monthIndex(anchor.year, anchor.month);
  }

  bool get _canGoForward {
    final today = TimeService.parseLocalDate(widget.snapshot.todayLocalDate);
    return _monthIndex(_year, _month) < _monthIndex(today.year, today.month);
  }

  void _shift(int delta) {
    if (delta < 0 && !_canGoBack) return;
    if (delta > 0 && !_canGoForward) return;
    setState(() {
      final i = _monthIndex(_year, _month) + delta;
      _year = i ~/ 12;
      _month = i % 12 + 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.tokens;
    final colors = context.colors;
    final accent = HabitColors.of(context, snapshot.habit.colorIndex);
    final weekStart = ref.watch(weekStartProvider);
    final today = snapshot.todayLocalDate;
    final rule = snapshot.rule;

    final daysInMonth = DateTime.utc(_year, _month + 1, 0).day;
    final firstWeekday = DateTime.utc(_year, _month, 1).weekday;
    final leading = (firstWeekday - weekStart + 7) % 7;

    HabitDayOutcome? outcomeFor(String date) {
      if (TimeService.daysBetween(today, date) > 0) {
        return HabitSchedule.occursOn(
          rule: rule,
          anchorDate: snapshot.habit.anchorDate,
          localDate: date,
        )
            ? HabitDayOutcome.future
            : null;
      }
      return snapshot.outcomeOn(date);
    }

    final cells = <Widget>[
      for (var i = 0; i < leading; i++) const SizedBox.shrink(),
      for (var day = 1; day <= daysInMonth; day++)
        _DayCell(
          date: TimeService.formatIsoDate(_year, _month, day),
          day: day,
          outcome: outcomeFor(TimeService.formatIsoDate(_year, _month, day)),
          isToday: TimeService.formatIsoDate(_year, _month, day) == today,
          accent: accent,
          editable: isEditableDay(
            snapshot,
            TimeService.formatIsoDate(_year, _month, day),
          ),
          onOpen: (date) =>
              showHabitDaySheet(context, ref, snapshot: snapshot, localDate: date),
        ),
    ];

    return GestureDetector(
      // Swipe between months. Arrows do the same for anyone who cannot swipe.
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v > 250) _shift(-1);
        if (v < -250) _shift(1);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: _canGoBack ? () => _shift(-1) : null,
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Semantics(
                  header: true,
                  liveRegion: true,
                  child: Text(
                    HabitDates.monthTitle(_year, _month),
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: _canGoForward ? () => _shift(1) : null,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          ExcludeSemantics(
            child: Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Text(
                      HabitDates.weekdayLetter[(weekStart - 1 + i) % 7],
                      textAlign: TextAlign.center,
                      style: textTheme.labelSmall?.copyWith(
                        color: tokens.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, constraints) {
              // Square cells, a seventh of the width each. On a 360dp phone
              // with the screen's 12dp gutters that is exactly 48dp — the
              // touch-target floor.
              final cell = constraints.maxWidth / 7;
              return GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: cell < 48 ? cell / 48 : 1,
                children: cells,
              );
            },
          ),
          const SizedBox(height: 8),
          ExcludeSemantics(
            child: Wrap(
              spacing: 14,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (final (outcome, label) in const [
                  (HabitDayOutcome.done, 'Done'),
                  (HabitDayOutcome.missed, 'Missed'),
                  (HabitDayOutcome.neutral, 'Rest day'),
                  (HabitDayOutcome.pending, 'Today'),
                ])
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox.square(
                        dimension: 12,
                        child: CustomPaint(
                          painter: HabitDayMarkPainter(
                            outcome: outcome,
                            color: accent,
                            strokeWidth: 1.6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        label,
                        style: textTheme.labelSmall
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.day,
    required this.outcome,
    required this.isToday,
    required this.accent,
    required this.editable,
    required this.onOpen,
  });

  final String date;
  final int day;
  final HabitDayOutcome? outcome;
  final bool isToday;
  final Color accent;
  final bool editable;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.tokens;
    final colors = context.colors;
    final scheduled = outcome != null;

    final Color numberColor;
    if (outcome == HabitDayOutcome.done) {
      numberColor = ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
          ? Colors.white
          : Colors.black;
    } else if (!scheduled) {
      // Visibly not part of the grid.
      numberColor = tokens.textMuted.withValues(alpha: 0.45);
    } else {
      numberColor = colors.onSurface;
    }

    final content = Stack(
      alignment: Alignment.center,
      children: [
        FractionallySizedBox(
          widthFactor: 0.78,
          heightFactor: 0.78,
          child: CustomPaint(
            painter: HabitDayMarkPainter(outcome: outcome, color: accent),
          ),
        ),
        FractionallySizedBox(
          widthFactor: 0.5,
          heightFactor: 0.5,
          child: FittedBox(
            child: Text(
              '$day',
              style: textTheme.labelMedium?.copyWith(
                color: numberColor,
                fontWeight: isToday ? FontWeight.w900 : FontWeight.w600,
                decoration: isToday ? TextDecoration.underline : null,
              ),
            ),
          ),
        ),
      ],
    );

    return Semantics(
      container: true,
      label: HabitOutcomeText.cell(date, outcome) + (isToday ? ', today' : ''),
      button: editable,
      excludeSemantics: true,
      child: editable
          ? InkWell(
              customBorder: const CircleBorder(),
              onTap: () => onOpen(date),
              onLongPress: () => onOpen(date),
              child: content,
            )
          : content,
    );
  }
}
