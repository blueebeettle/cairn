import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/stats/habit_statistics.dart';
import '../../../../core/widgets/cairn_card.dart';
import '../../../today/presentation/widgets/momentum_week_strip.dart';
import '../../../../core/time/time_service.dart';
import '../../../../data/providers/habit_analytics_providers.dart';
import '../../../../theme/app_theme.dart';

/// The "This week" card at the top of the Habits screen.
///
/// Match: `claude-outputs/designs/WeeklyRecap.dc.html` /
/// `WeeklyRecap.Dark.dc.html` — 22 radius, 20/20/22/20 padding, a Mon–Sun bar
/// strip over three stat tiles.
///
/// One departure from those boards: they close the completion line with "your
/// best week this month". Nothing in this app keeps week-over-week history, so
/// that superlative could not be checked before being printed — the same
/// objection that removed "Your best month yet" from the Stats hero. The line
/// carries a real comparison against last week instead, and drops the
/// comparison entirely when there is no last week to compare with.
///
/// Renders nothing when there are no active habits, matching
/// `HabitStatsBundle.hasAnyData`'s gate: a card of em dashes is not a useful
/// first impression.
class WeeklyRecapCard extends ConsumerWidget {
  const WeeklyRecapCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recap = ref.watch(weeklyRecapBundleProvider).valueOrNull;
    // No card while it loads and no card on error: this sits above the habit
    // list, and a spinner or an error strip there would push the list around
    // on every check-off for something that is decoration, not the screen's
    // job. The list below reports its own failures.
    if (recap == null || !recap.hasAnyData) return const SizedBox.shrink();

    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(4, 8, 4, 12),
      decoration: BoxDecoration(
        color: CardChrome.card(context),
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              // The same uppercase eyebrow every other card heading uses.
              // The boards drew this one as an 18px Bricolage title, but
              // Today already labels the identical words "THIS WEEK" as an
              // eyebrow a tab away, and two casings for one phrase is the
              // kind of thing you only notice as sloppiness.
              Expanded(child: CardChrome.sectionLabel(context, 'This week')),
              const SizedBox(width: 8),
              Text(
                formatWeekRange(recap.weekStart, recap.weekEnd),
                style: textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: tokens.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            weeklyRecapSummaryLine(recap),
            style: textTheme.bodyMedium?.copyWith(
              fontSize: 13.5,
              color: tokens.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          _DayBars(recap: recap),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _RecapTile(
                  figure: '${recap.bestStreak}',
                  label: 'best streak',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RecapTile(
                  figure: '${recap.habitsKept}',
                  label: 'habits kept',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RecapTile(
                  figure: '${recap.freezesUsed}',
                  label: recap.freezesUsed == 1 ? 'freeze used' : 'freezes used',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Sep 17 – 23", or "Sep 28 – Oct 4" when the week straddles two months.
///
/// Written here rather than pulled in with `intl`: this is the only date range
/// the app formats, and one three-line function is a smaller thing to own than
/// a dependency and its locale data. English month abbreviations only, which
/// is what every other piece of copy in this app already assumes.
String formatWeekRange(String startLocalDate, String endLocalDate) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final start = TimeService.parseLocalDate(startLocalDate);
  final end = TimeService.parseLocalDate(endLocalDate);
  final startStr = '${months[start.month - 1]} ${start.day}';
  final endStr = start.month == end.month
      ? '${end.day}'
      : '${months[end.month - 1]} ${end.day}';
  return '$startStr – $endStr';
}

/// The line under the heading: this week's rate, and how it moved.
///
/// Three shapes, in order of how much can honestly be said:
///  * no scorable day this week — an em dash, never "0% completion", the same
///    zero-versus-undefined rule the rest of the app follows;
///  * a rate but no last week to compare against (a first-ever week) — the
///    plain rate, with no comparison invented from an assumed zero;
///  * both — the rate and the signed move, in percentage points.
String weeklyRecapSummaryLine(WeeklyRecap recap) {
  final rate = recap.completionRate;
  if (rate == null) return '— completion. Check something off and this fills in.';

  final pct = (rate * 100).round();
  final delta = recap.rateDelta;
  if (delta == null) return '$pct% completion so far.';

  final points = (delta * 100).round();
  if (points == 0) return '$pct% completion — level with last week.';
  final direction = points > 0 ? 'up' : 'down';
  return '$pct% completion — ${points.abs()} '
      '${points.abs() == 1 ? 'point' : 'points'} $direction from last week.';
}

/// The Mon–Sun strip.
class _DayBars extends StatelessWidget {
  const _DayBars({required this.recap});

  final WeeklyRecap recap;

  /// Bar track from the boards: 64 tall, 20 wide, 6 radius, and a 16px stub
  /// for a day with nothing on it (their Friday) so an empty day still reads
  /// as a day rather than as a gap.
  static const double _maxHeight = 64;
  static const double _minHeight = 16;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < recap.days.length; i++)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: _maxHeight,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: _Bar(day: recap.days[i]),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                // From the date itself, not the column index: `recap.days` is
                // already anchored to the user's week start, so a fixed
                // Monday-first array put the wrong letter over every bar as
                // soon as that setting was not Monday.
                MomentumWeekStrip.weekdayLabel(recap.days[i].date),
                style: textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: tokens.textMuted,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// One day's bar.
///
/// Three states, and the difference between the last two is the point:
///  * a scored day — [AppTokens.heatmap]'s mid purple, or the brand primary
///    when it is today, which is the same "today is the emphasized one"
///    convention the Stats journey trail's `Now` column uses;
///  * a day that happened with nothing to score — a full-strength stub in
///    `lineSoft`, the boards' empty Friday;
///  * a day still to come — the same stub at reduced opacity, because a
///    Thursday that has not arrived is not a Thursday you missed, and drawing
///    them identically would accuse the user of a miss on a Tuesday.
class _Bar extends StatelessWidget {
  const _Bar({required this.day});

  final WeeklyRecapDay day;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tokens = context.tokens;

    final rate = day.rate;
    final height = rate == null
        ? _DayBars._minHeight
        : _DayBars._minHeight +
            (_DayBars._maxHeight - _DayBars._minHeight) * rate.clamp(0.0, 1.0);

    final Color color;
    if (day.isFuture) {
      color = tokens.lineSoft.withValues(alpha: 0.45);
    } else if (rate == null) {
      color = tokens.lineSoft;
    } else if (day.isToday) {
      color = colors.primary;
    } else {
      color = tokens.heatmap[3];
    }

    return Semantics(
      label: _spokenLabel(),
      excludeSemantics: true,
      child: Container(
        width: 20,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }

  String _spokenLabel() {
    final weekday = TimeService.parseLocalDate(day.date).weekday;
    const names = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', //
      'Friday', 'Saturday', 'Sunday',
    ];
    final name = names[weekday - 1];
    if (day.isFuture) return '$name, still to come';
    final rate = day.rate;
    if (rate == null) return '$name, nothing scored';
    final today = day.isToday ? ' (today)' : '';
    return '$name$today, ${(rate * 100).round()} percent';
  }
}

/// One of the three figures under the chart.
class _RecapTile extends StatelessWidget {
  const _RecapTile({required this.figure, required this.label});

  final String figure;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      container: true,
      label: '$figure $label',
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          color: CardChrome.panel(context),
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                figure,
                maxLines: 1,
                style: statFigure(context).copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: colors.primary,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: tokens.textMuted,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
