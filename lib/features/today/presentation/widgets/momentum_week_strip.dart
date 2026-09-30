import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/stats/habit_statistics.dart';
import '../../../../core/time/time_service.dart';
import '../../../../core/widgets/cairn_glyph.dart';
import '../../../../data/providers/habit_providers.dart';
import '../../../../data/repositories/habit_analytics_repository.dart';
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
    required this.rate,
  });

  final String localDate;

  /// Single-letter weekday, Mon-first.
  final String label;

  final bool isToday;

  /// Days after today are unknowable rather than missed, so they render
  /// hollow-dashed instead of empty-filled.
  final bool isFuture;

  /// The share of this day's scheduled habits that are done, 0.0–1.0 — or null
  /// when nothing on the day could be scored: no habit was scheduled, every one
  /// was frozen, or the day has not happened.
  ///
  /// Null is not zero, exactly as on `WeeklyRecapDay.rate` and everywhere else
  /// in the app. 0.0 is "habits were due and none got done"; null is "nothing
  /// was asked of you", and the strip draws the two differently.
  ///
  /// Today's is progress through a day still open (see
  /// `HabitCompletionRate.ofToday`): a habit not yet done counts as "not yet",
  /// so one tick out of four reads 0.25.
  final double? rate;

  /// Every scheduled habit that day is done. The days the header counts as
  /// "kept" — a day with no rate is not one of them.
  bool get isFullyCompleted => rate != null && rate! >= 1.0;
}

/// The Mon-Sun momentum strip above the streak chips.
///
/// Geometry from the "Momentum hero" card in
/// `claude-outputs/designs/Today.dc.html`: 26x30 columns, 30x34 for today,
/// radii tighter on top than bottom — the same bar language as [CairnGlyph]'s
/// stones. Today's column wears [CairnGlyph.markerHalo], so "now" is marked
/// with the same ring-and-glow device in both places.
///
/// Every pip grades by how much of that day's habits got done, in the same
/// "darker means more" ramp as the Stats activity heatmap
/// (`AppTokens.heatmap`, via [completionTier]): a day where one habit in four
/// was done is a light tint, a fully completed day the darkest step. Today is
/// the exception on colour — it stays the brand primary with its halo whatever
/// its rate, because today is in progress rather than behind — and shows its
/// progress as a fill instead (see [_DayColumn]).
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

  /// The one-letter initial for [localDate]'s own weekday.
  ///
  /// Shared so the Habits weekly recap labels its bars the same way — the two
  /// strips show the same week and must not disagree about which letter sits
  /// over which date.
  static String weekdayLabel(String localDate) =>
      weekdayInitials[TimeService.parseLocalDate(localDate).weekday - 1];

  /// Indexed by `DateTime.weekday - 1`, so Monday is 0 and Sunday is 6.
  static const List<String> weekdayInitials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  /// The seven days of the week containing [weekOf], starting on
  /// [weekStart], each with its completion rate pooled from [snapshots].
  ///
  /// A day's rate is the share of that day's scheduled habits that are done,
  /// via [HabitCompletionRate.ofDay] — the same function, over the same
  /// `HabitStatsInput` mapping ([HabitSnapshotStatsInput.toStatsInput]), that
  /// draws the Habits screen's weekly recap, so the two cannot disagree about
  /// a day. For a settled day a frozen habit is left out of both sides; for
  /// today a habit still to do counts as "not yet", so progress shows before
  /// the day resolves. A day nothing could be scored on has a null rate.
  ///
  /// The start-of-week delta is the same `(weekday - weekStart + 7) % 7` that
  /// `TimeService.startOfWeek` uses, rather than a second way of saying it.
  /// Labels come from each date's own weekday, so a Sunday-start week reads
  /// S M T W T F S and still lines up with the dates underneath — a fixed
  /// positional array silently mislabelled every column the moment the
  /// setting was anything but Monday.
  static List<MomentumDay> daysFor({
    required String weekOf,
    required String todayLocalDate,
    required List<HabitSnapshot> snapshots,
    required int weekStart,
  }) {
    final weekday = TimeService.parseLocalDate(weekOf).weekday; // 1 = Mon
    final start = TimeService.addDays(weekOf, -((weekday - weekStart + 7) % 7));
    final habits = [for (final s in snapshots) s.toStatsInput()];

    return [
      for (var i = 0; i < 7; i++)
        () {
          final date = TimeService.addDays(start, i);
          return MomentumDay(
            localDate: date,
            label: weekdayLabel(date),
            isToday: date == todayLocalDate,
            isFuture: TimeService.daysBetween(todayLocalDate, date) > 0,
            rate: HabitCompletionRate.ofDay(
              habits,
              date,
              todayLocalDate: todayLocalDate,
            ).rate,
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
    // "Kept" is a day you fully kept — every scheduled habit done. Now that a
    // partly-done day shows as a partial fill rather than reading as a flat
    // yes, counting it here would let the header say "7 / 7" over a row of
    // half-filled pips. Full days keep the figure's old meaning ("a day you
    // kept"); the pips carry the partial credit.
    final kept = days.where((d) => d.isFullyCompleted).length;

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
              label: 'This week, $kept of 7 days fully completed',
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

  /// A settled day nothing could be scored on is drawn at this fraction of
  /// the empty-pip shade — recessive next to a day that was scored and came
  /// to nothing. See the fill choice in [build].
  static const double _noClaimAlpha = 0.4;

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

    final rate = day.rate;

    // Four different things a pip can say, and the app's governing rule is
    // that no two of them may collapse into one look:
    //   * today          — always the brand primary; its rate shows as a fill
    //   * a future day   — unknown, not missed: an empty pip with an outline
    //   * no rate        — nothing was asked of you: the empty shade, faint
    //   * a rate         — 0.0 is the empty shade at full strength ("asked,
    //                      and nothing done"); above it, the day's tier on the
    //                      heatmap ramp
    final Color fill;
    if (day.isToday) {
      // "Today is in progress, not behind": never faded to a lighter tier for
      // being unfinished. What is finished shows as the fill drawn over this.
      fill = colors.primary;
    } else if (day.isFuture) {
      fill = tokens.lineSoft;
    } else if (rate == null) {
      // The track shade, not a card shade — same token the heatmap's empty
      // cells sit on — dimmed so it recedes behind a real 0.0.
      fill = tokens.lineSoft.withValues(alpha: _noClaimAlpha);
    } else if (rate <= 0) {
      fill = tokens.lineSoft;
    } else {
      fill = tokens.heatmap[completionTier(rate)];
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
                border: !day.isToday && day.isFuture
                    ? Border.all(color: colors.outline, width: 1.5)
                    : null,
                boxShadow: day.isToday ? CairnGlyph.markerHalo(context) : null,
              ),
              child: day.isToday && !day.isFullyCompleted
                  ? _TodayUnfilled(rate: rate, radius: radius)
                  : null,
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
        label: '${day.localDate}, ${_spokenState()}'
            '${day.isToday ? ', today' : ''}',
        excludeSemantics: true,
        child: column,
      ),
    );
  }

  /// What the pip says, in words: the one place the three settled-day states
  /// (nothing scheduled / nothing done / some done) and the fully completed
  /// state are told apart for a screen reader.
  String _spokenState() {
    if (day.isFuture) return 'upcoming';
    final rate = day.rate;
    if (rate == null) return 'nothing scheduled';
    if (rate >= 1) return 'fully completed';
    if (rate <= 0) return 'nothing done';
    // Clamped so a barely-started day never reads "0 percent" and a nearly
    // finished one never reads "100 percent" beside the word "partially".
    final percent = (rate * 100).round().clamp(1, 99);
    return 'partially completed, $percent percent';
  }
}

/// The part of today's pip that is not done yet.
///
/// Today's pip is always the brand primary with its halo — see the fill choice
/// in [_DayColumn.build] — so it cannot show progress by shading. It shows it
/// as a level instead: this covers the top of the pip in a pale tint in
/// proportion to what is still to do, leaving the solid primary rising from
/// the bottom. All done draws no cover at all, so a finished today is exactly
/// the solid pip it always was.
///
/// Inset by [_ring] on every side so the primary reads as a deliberate outline
/// around the unfilled part — a vessel filling up — rather than as a fringe of
/// anti-aliasing where two shapes meet.
///
/// The cover's tint carries the null-vs-zero distinction for today, the same
/// way the empty shade does on the other days: a faint neutral when nothing
/// was scheduled, a primary tint when habits were due and none are done yet.
class _TodayUnfilled extends StatelessWidget {
  const _TodayUnfilled({required this.rate, required this.radius});

  /// Null when nothing today could be scored.
  final double? rate;

  /// The pip's own corner radii, so the cover's corners follow them inwards.
  final BorderRadius radius;

  static const double _ring = 1.5;

  /// Once today is strictly between nothing and everything, neither the filled
  /// nor the unfilled part may be thinner than this share of the pip. Without
  /// a floor, one tick out of twenty habits is a 1px sliver — indistinguishable
  /// from not having started — and 19 of 20 is indistinguishable from done. The
  /// spoken label and the header carry the exact figure; this only has to keep
  /// "started" and "nearly there" visible.
  static const double _minShare = 0.12;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tokens = context.tokens;

    // Opaque, blended over the card the strip sits on: the cover lies on top of
    // the solid primary pip, so any transparency in it would show through.
    final card = CardChrome.card(context);
    final color = rate == null
        ? Color.alphaBlend(tokens.lineSoft.withValues(alpha: 0.45), card)
        : Color.alphaBlend(colors.primary.withValues(alpha: 0.2), card);

    final r = rate;
    final unfilled = (r == null || r <= 0)
        ? 1.0
        : (1 - r).clamp(_minShare, 1 - _minShare);

    return Padding(
      padding: const EdgeInsets.all(_ring),
      child: Align(
        alignment: Alignment.topCenter,
        child: FractionallySizedBox(
          widthFactor: 1,
          heightFactor: unfilled,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(radius.topLeft.x - _ring),
                // Only a fully covered pip has a bottom edge that is the pip's
                // own; otherwise the cover ends in the middle of the pip.
                bottom: unfilled >= 1.0
                    ? Radius.circular(radius.bottomLeft.x - _ring)
                    : const Radius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
