import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/habits/habit_streak.dart';
import '../../../../core/time/time_service.dart';
import '../../../../core/widgets/cairn_glyph.dart';
import '../../../../data/providers/habit_providers.dart';
import '../../../../data/repositories/habits_repository.dart';
import '../../../../core/widgets/cairn_card.dart';
import '../../../../theme/app_theme.dart';

/// One day in the momentum strip.
@immutable
class MomentumDay {
  const MomentumDay({
    required this.localDate,
    required this.label,
    required this.isToday,
    required this.isFuture,
    required this.completed,
  });

  final String localDate;

  /// Single-letter weekday, Mon-first.
  final String label;

  final bool isToday;

  /// Days after today are unknowable rather than missed, so they render
  /// hollow-dashed instead of empty-filled.
  final bool isFuture;

  /// At least one habit was completed on this day.
  final bool completed;
}

/// The Mon-Sun momentum strip above the streak chips.
///
/// Geometry from the "Momentum hero" card in
/// `claude-outputs/designs/Today.dc.html`: 26x30 columns, 30x34 for today,
/// radii tighter on top than bottom — the same bar language as [CairnGlyph]'s
/// stones. Today's column wears [CairnGlyph.markerHalo], so "now" is marked
/// with the same ring-and-glow device in both places.
///
/// Reads [habitSnapshotsProvider] directly — the per-day completion is already
/// in each snapshot's resolved outcomes, so this needs no provider of its own.
class MomentumWeekStrip extends ConsumerWidget {
  const MomentumWeekStrip({
    super.key,
    required this.weekOf,
    required this.todayLocalDate,
    required this.weekStart,
    this.onDayTap,
  });

  /// Any date in the week to show; the strip renders that date's week.
  final String weekOf;

  /// Which weekday the week begins on, from the user's setting —
  /// `DateTime.monday` / `.sunday` / `.saturday`, as `TimeService.weekStart`
  /// holds it.
  final int weekStart;

  final String todayLocalDate;

  final ValueChanged<String>? onDayTap;

  /// The seven days of the week containing [weekOf], starting on
  /// [weekStart], with completion resolved from [snapshots]. A day counts as
  /// completed when any habit was done on it.
  ///
  /// The start-of-week delta is the same `(weekday - weekStart + 7) % 7` that
  /// `TimeService.startOfWeek` uses, rather than a second way of saying it.
  /// Labels come from each date's own weekday, so a Sunday-start week reads
  /// S M T W T F S and still lines up with the dates underneath — a fixed
  /// positional array silently mislabelled every column the moment the
  /// setting was anything but Monday.
  /// The one-letter initial for [localDate]'s own weekday.
  ///
  /// Shared so the Habits weekly recap labels its bars the same way — the two
  /// strips show the same week and must not disagree about which letter sits
  /// over which date.
  static String weekdayLabel(String localDate) =>
      weekdayInitials[TimeService.parseLocalDate(localDate).weekday - 1];

  /// Indexed by `DateTime.weekday - 1`, so Monday is 0 and Sunday is 6.
  static const List<String> weekdayInitials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  static List<MomentumDay> daysFor({
    required String weekOf,
    required String todayLocalDate,
    required List<HabitSnapshot> snapshots,
    required int weekStart,
  }) {
    final weekday = TimeService.parseLocalDate(weekOf).weekday; // 1 = Mon
    final start = TimeService.addDays(weekOf, -((weekday - weekStart + 7) % 7));

    return [
      for (var i = 0; i < 7; i++)
        () {
          final date = TimeService.addDays(start, i);
          return MomentumDay(
            localDate: date,
            label: weekdayLabel(date),
            isToday: date == todayLocalDate,
            isFuture: TimeService.daysBetween(todayLocalDate, date) > 0,
            completed: snapshots.any(
              (s) => s.streaks.outcomes[date] == HabitDayOutcome.done,
            ),
          );
        }(),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    final snapshots = ref.watch(habitSnapshotsProvider).value ?? const [];
    final days = daysFor(
      weekOf: weekOf,
      todayLocalDate: todayLocalDate,
      snapshots: snapshots,
      weekStart: weekStart,
    );
    final kept = days.where((d) => d.completed).length;

    return Card(
      color: CardChrome.card(context),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Both sides give way rather than overflow: at a 200% font scale
            // this header is wider than a 360dp phone.
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    'THIS WEEK',
                    style: textTheme.labelSmall?.copyWith(
                      color: tokens.textMuted,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '$kept / 7 days',
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
            const SizedBox(height: 12),
            Semantics(
              container: true,
              label: 'This week, $kept of 7 days with a habit completed',
              excludeSemantics: onDayTap == null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final day in days)
                    Expanded(child: _DayColumn(day: day, onTap: onDayTap)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({required this.day, this.onTap});

  final MomentumDay day;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    // Today is drawn slightly larger, per the mockup.
    final width = day.isToday ? 30.0 : 26.0;
    final height = day.isToday ? 34.0 : 30.0;
    final radius = BorderRadius.vertical(
      top: Radius.circular(day.isToday ? 9 : 8),
      bottom: Radius.circular(day.isToday ? 11 : 10),
    );

    final Color fill;
    if (day.isToday) {
      fill = colors.primary;
    } else if (day.completed) {
      fill = tokens.heatmap[3];
    } else {
      // The track shade, not a card shade — same token the heatmap's empty
      // cells sit on.
      fill = tokens.lineSoft;
    }

    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The halo is painted outside the bar, so it needs room either side
        // to avoid being clipped by the neighbouring columns.
        SizedBox(
          height: 34,
          child: Center(
            child: Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: radius,
                // Future days are unknown, not missed — dashes, not a fill.
                border: !day.isToday && !day.completed && day.isFuture
                    ? Border.all(color: colors.outline, width: 1.5)
                    : null,
                boxShadow: day.isToday ? CairnGlyph.markerHalo(context) : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          day.label,
          style: textTheme.labelSmall?.copyWith(
            color: day.isToday ? colors.primary : tokens.textMuted,
            fontWeight: day.isToday ? FontWeight.w800 : FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
      ],
    );

    if (onTap == null) return column;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => onTap!(day.localDate),
      child: Semantics(
        button: true,
        label: '${day.localDate}, '
            '${day.completed ? 'habit completed' : 'nothing completed'}'
            '${day.isToday ? ', today' : ''}',
        excludeSemantics: true,
        child: column,
      ),
    );
  }
}
