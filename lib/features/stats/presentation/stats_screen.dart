import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/habit_statistics.dart';
import '../../../core/stats/statistics.dart';
import '../../../core/time/time_service.dart';
import '../../../core/widgets/cairn_card.dart';
import '../../../core/widgets/cairn_glyph.dart';
import '../../../core/widgets/feature_info.dart';
import '../../../core/widgets/feature_info_content.dart';
import '../../../data/providers/analytics_providers.dart';
import '../../../data/providers/database_provider.dart';
import '../../../data/providers/habit_analytics_providers.dart';
import '../../../data/providers/habit_providers.dart';
import '../../../data/repositories/analytics_repository.dart';
import '../../../data/repositories/habits_repository.dart';
import '../../../data/repositories/stats_repository.dart';
import '../../../features/habits/presentation/widgets/habit_milestone.dart';
import '../../../theme/app_theme.dart';
import 'stats_detail_screen.dart';

/// The Stats screen, redesigned against `claude-outputs/designs/Stats.dc.html`
/// and `Stats.Dark.dc.html`.
///
/// Five things, in order: the range picker, a hero card for the selected
/// period's completion rate, the "Your journey" cairn trail, the focus
/// activity heatmap, and a 2×2 grid of single-number tiles. Everything the
/// pre-redesign screen showed below those — the peak window, the day-of-week
/// profile, the time allocation, interruptions, the focus rating, the habit
/// leaderboard and the habit heatmap — moved to [StatsDetailScreen] behind the
/// "See more" row at the bottom. No metric was dropped in the move.
///
/// One departure from the boards: they headline the hero with "Your best month
/// yet". Nothing in this app tracks month-over-month history, so that claim
/// could not be checked before making it. The streak-versus-personal-best line
/// takes its place — same encouraging role, and true.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(statsRangeProvider);
    final bundleAsync = ref.watch(statsBundleProvider);
    final heatmapAsync = ref.watch(heatmapProvider);
    final thresholdsAsync = ref.watch(heatmapThresholdsProvider);
    final milestoneDatesAsync = ref.watch(focusMilestoneDatesProvider);
    final trendAsync = ref.watch(statsTrendProvider);
    final focusStatsAsync = ref.watch(focusStatsProvider);

    final habitBundleAsync = ref.watch(habitStatsBundleProvider);
    final habitSnapshotsAsync = ref.watch(habitSnapshotsProvider);

    final time = ref.watch(timeServiceProvider);
    // The journey trail scores each week against seven days of this.
    final dailyGoalMinutes = ref.watch(dailyGoalMinutesProvider);

    // Whether the habits half has anything to show at all. Gated on whether
    // any habit currently exists (`activeHabitCount`), not on whether the
    // selected range has habit data in it — a brand-new habit with no history
    // yet still deserves tiles that read em dashes, not a screen that decides
    // it has nothing to say.
    final hasHabits = (habitBundleAsync.valueOrNull?.activeHabitCount ?? 0) > 0;

    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stats'),
        actions: const [
          FeatureInfoButton(info: FeatureInfoContent.stats),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const FeatureInfoCard(
            info: FeatureInfoContent.stats,
            padding: EdgeInsets.only(bottom: 12),
          ),
          _buildRangePicker(context, ref, range),
          const SizedBox(height: 14),

          bundleAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
            error: (err, stack) => Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Could not load statistics: $err',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(color: colors.error),
                ),
              ),
            ),
            data: (bundle) {
              if (!bundle.hasAnyData && !hasHabits) {
                return _buildWholeScreenEmptyState(context);
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Renders even with no focus sessions in the period: the
                  // rate falls to an em dash and the streak line still reads
                  // correctly off a zero streak.
                  _buildHeroCard(
                    context,
                    range: range,
                    bundle: bundle,
                    trendAsync: trendAsync,
                    focusStatsAsync: focusStatsAsync,
                  ),

                  // The trail is genuinely period-scoped — it draws one
                  // column per week of the selected range — so an empty
                  // period means an empty trail, and it stays out of the way.
                  if (bundle.hasAnyData) ...[
                    const SizedBox(height: 14),
                    _buildJourneyCard(
                      context,
                      bundle: bundle,
                      time: time,
                      dailyGoalMinutes: dailyGoalMinutes,
                    ),
                  ],

                  // The heatmap is NOT period-scoped: `heatmapProvider` is
                  // fixed to the trailing 365 days on purpose, independent of
                  // the picker. Gating it on `bundle.hasAnyData` meant picking
                  // "Week" during a quiet week hid a whole year of history
                  // that had nothing to do with the selection. It carries its
                  // own empty state for the genuinely-empty case, so it can
                  // simply always render.
                  const SizedBox(height: 14),
                  _buildActivityHeatmapCard(
                    context,
                    heatmapAsync: heatmapAsync,
                    thresholdsAsync: thresholdsAsync,
                    milestoneDatesAsync: milestoneDatesAsync,
                  ),

                  const SizedBox(height: 14),
                  _buildTileGrid(
                    context,
                    range: range,
                    bundle: bundle,
                    focusStatsAsync: focusStatsAsync,
                    habitBundleAsync: habitBundleAsync,
                    habitSnapshotsAsync: habitSnapshotsAsync,
                  ),

                  const SizedBox(height: 14),
                  _buildSeeMoreRow(context),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Range picker ───────────────────────────────────────────────────────────

  /// The boards' pill: a tinted track with one filled segment, not Material's
  /// outlined `SegmentedButton`.
  ///
  /// `Semantics(inMutuallyExclusiveGroup)` is what keeps this readable to a
  /// screen reader now that it is four plain tap targets rather than a real
  /// radio group.
  Widget _buildRangePicker(
    BuildContext context,
    WidgetRef ref,
    StatsRange selectedRange,
  ) {
    const labels = {
      StatsRange.week: 'Week',
      StatsRange.month: '30d',
      StatsRange.quarter: '90d',
      StatsRange.allTime: 'All',
    };

    return Container(
      decoration: BoxDecoration(
        color: CardChrome.pickerTrack(context),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          for (final range in StatsRange.values) ...[
            if (range != StatsRange.values.first) const SizedBox(width: 2),
            Expanded(
              child: _RangeSegment(
                label: labels[range]!,
                spokenLabel: range.label,
                selected: range == selectedRange,
                onTap: () =>
                    ref.read(statsRangeProvider.notifier).state = range,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Whole-screen empty state ───────────────────────────────────────────────

  Widget _buildWholeScreenEmptyState(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Nothing logged yet',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Finish a focus session and this screen fills in.',
            style: textTheme.bodyMedium?.copyWith(color: tokens.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Hero card ──────────────────────────────────────────────────────────────

  Widget _buildHeroCard(
    BuildContext context, {
    required StatsRange range,
    required StatsBundle bundle,
    required AsyncValue<double?> trendAsync,
    required AsyncValue<FocusStats> focusStatsAsync,
  }) {
    final colors = context.colors;
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    final rate = bundle.completionRate.rate;
    // §4's rule: a zero denominator is an em dash. Ten sessions all abandoned
    // is a defined 0%, and must not be swallowed by the same branch.
    final rateStr = rate == null ? '—' : '${(rate * 100).round()}%';

    final trend = trendAsync.valueOrNull;
    final focusStats = focusStatsAsync.valueOrNull ?? FocusStats.empty;

    return Container(
      decoration: BoxDecoration(
        color: CardChrome.card(context),
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The boards say "This month" because 30d is the default range.
              // The real label follows the picker, so switching to Week does
              // not leave a card claiming to be about a month.
              Expanded(child: CardChrome.sectionLabel(context, range.label)),
              if (trend != null) ...[
                const SizedBox(width: 8),
                _TrendChip(delta: trend),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  rateStr,
                  style: statFigure(context).copyWith(
                    fontSize: 46,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    color: colors.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'completion rate',
                  style: textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: tokens.textSecondary,
                    height: 1.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _streakLine(focusStats),
            style: textTheme.bodySmall?.copyWith(
              fontSize: 12.5,
              color: tokens.textMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// The hero's closing line: how the live streak sits against the all-time
  /// best.
  ///
  /// Once the current run has caught the record there is no gap left to name,
  /// so the "X more days" sentence would read as "0 more takes you past your
  /// best". Deliberately not the milestone celebration's wording — the two
  /// screens should not sound like the same paragraph twice.
  static String _streakLine(FocusStats stats) {
    if (stats.currentStreakDays >= stats.longestStreakDays) {
      return "You're on your best streak yet.";
    }
    final gap = stats.longestStreakDays - stats.currentStreakDays;
    return 'Longest streak: ${stats.longestStreakDays} days — $gap more '
        'takes you past your all-time best.';
  }

  // ── "Your journey" trail ───────────────────────────────────────────────────

  Widget _buildJourneyCard(
    BuildContext context, {
    required StatsBundle bundle,
    required TimeService time,
    required int dailyGoalMinutes,
  }) {
    final colors = context.colors;
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    final weeks = journeyWeeks(
      minutesByDate: bundle.minutesByDate,
      periodStart: bundle.period.start,
      todayLocalDate: time.todayLocalDate(),
      startOfWeek: time.startOfWeek,
      dailyGoalMinutes: dailyGoalMinutes,
    );

    return Container(
      decoration: BoxDecoration(
        color: CardChrome.panel(context),
        border: Border.all(color: colors.outline),
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CardChrome.sectionLabel(context, 'Your journey'),
          const SizedBox(height: 14),
          Semantics(
            container: true,
            label: 'Your journey: ${weeks.length} '
                '${weeks.length == 1 ? 'week' : 'weeks'} of focus, oldest '
                'first, ending with this week.',
            excludeSemantics: true,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // The dotted rail the stones sit on, behind them and inset so
                // it stops short of the outer glyphs.
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 11,
                  child: CustomPaint(
                    painter: _DottedRailPainter(color: colors.outline),
                    size: const Size.fromHeight(2),
                  ),
                ),
                Row(
                  // Right-aligned so "Now" is always the last column, however
                  // few weeks the range covers.
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < weeks.length; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CairnGlyph(
                              stoneCount: weeks[i].stones,
                              scale: weeks[i].scale,
                              opacity: weeks[i].opacity,
                              showMarker: weeks[i].isNow,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              weeks[i].isNow ? 'Now' : 'W${i + 1}',
                              maxLines: 1,
                              overflow: TextOverflow.clip,
                              style: textTheme.labelSmall?.copyWith(
                                fontSize: 9,
                                letterSpacing: 0,
                                fontWeight: weeks[i].isNow
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: weeks[i].isNow
                                    ? colors.primary
                                    : tokens.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Activity heatmap ───────────────────────────────────────────────────────

  Widget _buildActivityHeatmapCard(
    BuildContext context, {
    required AsyncValue<List<HeatmapCell>> heatmapAsync,
    required AsyncValue<HeatmapThresholds> thresholdsAsync,
    required AsyncValue<Set<String>> milestoneDatesAsync,
  }) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    final milestoneDates = milestoneDatesAsync.valueOrNull ?? const <String>{};

    return Container(
      decoration: BoxDecoration(
        color: CardChrome.card(context),
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: CardChrome.sectionLabel(context, 'Activity')),
              const SizedBox(width: 8),
              _buildHeatmapLegend(context),
            ],
          ),
          const SizedBox(height: 4),
          // What the squares actually measure, and over what window. Neither
          // was discoverable before: "Activity" alone reads as though it
          // might be habit check-offs, and the 365-day window is fixed rather
          // than following the range picker directly above it.
          Text(
            'Focus minutes · last 365 days',
            style: textTheme.bodySmall?.copyWith(color: tokens.textMuted),
          ),
          const SizedBox(height: 12),
          heatmapAsync.when(
            loading: () => const SizedBox(
              height: 102,
              child: Center(child: CircularProgressIndicator.adaptive()),
            ),
            error: (err, _) => Text(
              'Could not load activity: $err',
              style: textTheme.bodySmall?.copyWith(color: tokens.textSecondary),
            ),
            data: (cells) {
              if (cells.isEmpty) {
                return Text('—', style: textTheme.displaySmall);
              }

              // Group cells by weekday into columns of 7.
              final columns = <List<HeatmapCell?>>[];
              var currentColumn = List<HeatmapCell?>.filled(7, null);
              var lastRowIndex = -1;

              for (final cell in cells) {
                final parsed = TimeService.parseLocalDate(cell.date);
                // Dart weekday: Monday = 1 ... Sunday = 7 -> row 0..6
                final rowIndex = parsed.weekday - 1;

                if (currentColumn[rowIndex] != null || rowIndex < lastRowIndex) {
                  columns.add(currentColumn);
                  currentColumn = List<HeatmapCell?>.filled(7, null);
                }

                currentColumn[rowIndex] = cell;
                lastRowIndex = rowIndex;
              }

              if (currentColumn.any((c) => c != null)) {
                columns.add(currentColumn);
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true, // Opens showing today
                    // Two pixels of slack inside the viewport, which is
                    // exactly what a milestone ring overhangs its cell by.
                    // `Clip.none` would give the rings room too, but it also
                    // lets the whole scrolled grid paint outside the card and
                    // off the screen edge.
                    padding: const EdgeInsets.all(2),
                    child: Row(
                      children: [
                        for (var colIdx = 0; colIdx < columns.length; colIdx++) ...[
                          if (colIdx > 0) const SizedBox(width: 3),
                          Column(
                            children: [
                              for (var rowIdx = 0; rowIdx < 7; rowIdx++) ...[
                                if (rowIdx > 0) const SizedBox(height: 3),
                                _buildHeatmapCell(
                                  context,
                                  columns[colIdx][rowIdx],
                                  tokens,
                                  milestoneDates,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  thresholdsAsync.maybeWhen(
                    data: (thresholds) {
                      if (thresholds.provisional) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            'Provisional scale — ${thresholds.nonZeroDayCount} days of focus so far. It becomes yours at 14.',
                            style: textTheme.bodySmall?.copyWith(
                              color: tokens.textMuted,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapLegend(BuildContext context) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;
    final legendText = textTheme.bodySmall?.copyWith(
      fontSize: 10,
      color: tokens.textMuted,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Less', style: legendText),
        const SizedBox(width: 4),
        for (var i = 0; i < 5; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: tokens.heatmap[i],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
        const SizedBox(width: 4),
        Text('More', style: legendText),
      ],
    );
  }

  /// One heatmap square, with the milestone ring when the focus streak landed
  /// exactly on a `MilestoneThresholds` value that day.
  ///
  /// Known limitation, inherited rather than introduced: the squares only go
  /// back as far as the heatmap's own 365-day window, so a milestone the user
  /// crossed two years ago has no square to be drawn on. The ring dates
  /// themselves are computed over all history
  /// ([StatsRepository.watchMilestoneDates]), so nothing inside the window is
  /// mis-numbered by the window's edge — it is only the display that is
  /// bounded.
  Widget _buildHeatmapCell(
    BuildContext context,
    HeatmapCell? cell,
    AppTokens tokens,
    Set<String> milestoneDates,
  ) {
    const size = 12.0;
    if (cell == null) {
      return const SizedBox(width: size, height: size);
    }

    final square = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tokens.heatmap[cell.level],
        borderRadius: BorderRadius.circular(3),
      ),
    );

    // A tooltip rather than a label: 365 squares cannot each carry their
    // number on screen, but any one of them can be asked.
    Widget withTooltip(Widget child) => Tooltip(
          message: heatmapCellTooltip(cell),
          child: child,
        );

    if (!milestoneDates.contains(cell.date)) return withTooltip(square);

    return withTooltip(Stack(
      clipBehavior: Clip.none,
      children: [
        square,
        // The boards' `inset:-2px; box-shadow: 0 0 0 1.5px` — a ring drawn
        // just outside the square, in the milestone accent rather than a
        // literal hex so it tracks the rest of the milestone system.
        Positioned(
          left: -2,
          top: -2,
          right: -2,
          bottom: -2,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                border: Border.all(
                  color: MilestoneChrome.accent(context),
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
      ],
    ));
  }

  // ── 2×2 tile grid ──────────────────────────────────────────────────────────

  Widget _buildTileGrid(
    BuildContext context, {
    required StatsRange range,
    required StatsBundle bundle,
    required AsyncValue<FocusStats> focusStatsAsync,
    required AsyncValue<HabitStatsBundle> habitBundleAsync,
    required AsyncValue<List<HabitSnapshot>> habitSnapshotsAsync,
  }) {
    final focusStats = focusStatsAsync.valueOrNull ?? FocusStats.empty;
    final habitBundle = habitBundleAsync.valueOrNull;
    final snapshots = habitSnapshotsAsync.valueOrNull ?? const <HabitSnapshot>[];

    final freezesUsed =
        snapshots.fold<int>(0, (sum, s) => sum + s.excusedThisMonth);

    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatTile(
                  figure: '${focusStats.longestStreakDays}',
                  // "ever" in the visible label, not only the tooltip: this
                  // is the one tile in the grid that ignores the range
                  // picker, and a tooltip only reaches someone who thinks to
                  // long-press it.
                  label: 'best streak ever (days)',
                  tooltip: 'Your all-time longest streak, not limited to the '
                      'range above.',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  figure: strongestWeekdayLabel(bundle.weekdayProfile),
                  // A mean, not a total — "strongest day" on its own invites
                  // reading it as the day with the most focus time banked.
                  label: 'strongest day (avg)',
                  tooltip: 'The weekday with your highest average focus '
                      'time, not your highest total.',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatTile(
                  figure: habitsKeptPerDay(
                    range: range,
                    period: bundle.period,
                    habitBundle: habitBundle,
                  ),
                  label: 'habits kept / day',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  figure: '$freezesUsed',
                  // The qualifier is in the visible label as well as the
                  // tooltip below, for the same reason as the streak tile.
                  label: 'freezes used (this month)',
                  // Deliberately not range-scoped: `excusedThisMonth` is a
                  // calendar-month figure everywhere else in the app
                  // (`FreezesChip`), and re-cutting it to the picker here
                  // would make the same word mean two things. Said out loud
                  // so the tile is not read as following the picker.
                  tooltip: 'Rest days used across your habits this calendar '
                      'month. Not affected by the range above.',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── "See more" ─────────────────────────────────────────────────────────────

  Widget _buildSeeMoreRow(BuildContext context) {
    final colors = context.colors;
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: CardChrome.card(context),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => StatsDetailScreen.open(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'See more',
                      style: textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Peak hours, weekdays, projects, interruptions, habits',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 11.5,
                        color: tokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: colors.primary),
            ],
          ),
        ),
      ),
    );
  }

  // ── Shared bits ────────────────────────────────────────────────────────────

}

// ─────────────────────────────────────────────────────────────────────────────
// Pure helpers — no widgets, so the tile arithmetic can be tested directly
// ─────────────────────────────────────────────────────────────────────────────

/// One column of the "Your journey" trail.
class JourneyWeek {
  const JourneyWeek({
    required this.weekStart,
    required this.minutes,
    required this.stones,
    required this.scale,
    required this.opacity,
    required this.isNow,
  });

  final String weekStart;
  final int minutes;

  /// 0–4, what [CairnGlyph] draws.
  final int stones;
  final double scale;
  final double opacity;

  /// The rightmost column — this week. Drawn largest, fully opaque, with the
  /// marker, and labelled "Now".
  final bool isNow;
}

/// At most this many columns in the trail.
///
/// A 90-day range spans thirteen weeks and All time can span years. Drawn on a
/// 390-wide phone those are either an overflowing row or three dozen glyphs too
/// small to read, so the trail shows the most recent eight and stops.
const int journeyMaxWeeks = 8;

/// The smallest and largest [CairnGlyph] scales in the trail.
///
/// [CairnGlyph]'s natural size is 76×86, which is the Today card's glyph; the
/// boards draw the trail's stones at 18–26px wide, so the whole row lives
/// between roughly a quarter and a third of natural size.
const double journeyMinScale = 0.24;
const double journeyMaxScale = 0.34;

/// The trail's columns, oldest first, for the selected range.
///
/// Weekly buckets come straight off [StatsBundle.minutesByDate] — the days are
/// already period-limited, so no second query is needed to aggregate them. Each
/// week's stone count is its focus minutes against the *daily goal*, seven days
/// of it: clearing the goal every day is a full four-stone cairn, and a week
/// with no focus at all draws an empty base rather than a stone.
///
/// The yardstick is absolute on purpose. Scoring each week against the best
/// week in the trail would hand the tallest cairn to whatever week happened to
/// be least bad, so a quiet stretch whose best week was twenty minutes would
/// draw the same fully grown cairn as a genuinely strong one. [CairnGlyph]'s
/// stone count means something fixed everywhere else it appears — Today, the
/// Habits list, the milestone celebration — and it has to mean the same thing
/// here, or two trails with identical weeks would disagree about them.
///
/// Weeks are generated off the calendar grid rather than off the keys present
/// in [minutesByDate], so a week the user skipped entirely still takes up its
/// column instead of silently closing the gap.
List<JourneyWeek> journeyWeeks({
  required Map<String, int> minutesByDate,
  required String periodStart,
  required String todayLocalDate,
  required String Function(String localDate) startOfWeek,
  required int dailyGoalMinutes,
}) {
  final thisWeek = startOfWeek(todayLocalDate);

  // All time has a sentinel start (`0000-01-01`), so the trail anchors on the
  // oldest day that actually has focus minutes whenever that is later than the
  // period start. With no focus minutes at all there is nothing to anchor on
  // and the period start stands, which keeps a quiet 30-day range at its six
  // empty columns instead of collapsing it to one.
  final earliest = minutesByDate.keys.isEmpty
      ? null
      : minutesByDate.keys.reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
  final anchor = (earliest != null && periodStart.compareTo(earliest) < 0)
      ? earliest
      : periodStart;

  // Floored before any date arithmetic runs on it. The cap makes anything
  // older than eight weeks unreachable anyway, and `startOfWeek` on the
  // all-time sentinel would otherwise walk back past year zero and throw.
  final oldestDrawn =
      TimeService.addDays(thisWeek, -7 * (journeyMaxWeeks - 1));
  final firstWeek = startOfWeek(
    anchor.compareTo(oldestDrawn) < 0 ? oldestDrawn : anchor,
  );
  final spanned = TimeService.daysBetween(firstWeek, thisWeek) ~/ 7 + 1;
  final count = spanned.clamp(1, journeyMaxWeeks);

  final totals = <String, int>{};
  for (var i = count - 1; i >= 0; i--) {
    final weekStart = TimeService.addDays(thisWeek, -7 * i);
    var sum = 0;
    for (var d = 0; d < 7; d++) {
      sum += minutesByDate[TimeService.addDays(weekStart, d)] ?? 0;
    }
    totals[weekStart] = sum;
  }

  final starts = totals.keys.toList();

  return [
    for (var i = 0; i < starts.length; i++)
      JourneyWeek(
        weekStart: starts[i],
        minutes: totals[starts[i]]!,
        stones: _journeyStones(totals[starts[i]]!, dailyGoalMinutes),
        // A single-column trail is drawn at full trail size rather than at the
        // bottom of the ramp — there is nothing for it to be smaller than.
        scale: starts.length == 1
            ? journeyMaxScale
            : journeyMinScale +
                (journeyMaxScale - journeyMinScale) * (i / (starts.length - 1)),
        opacity: starts.length == 1
            ? 1.0
            : 0.4 + 0.6 * (i / (starts.length - 1)),
        isNow: i == starts.length - 1,
      ),
  ];
}

/// Stones for one week: its focus minutes against seven days of the daily
/// goal, capped at the glyph's four.
///
/// The guard covers a zero or negative goal as well as an empty week — the
/// setting is user-configurable, and a divide by zero here would take the whole
/// screen down.
int _journeyStones(int minutes, int dailyGoalMinutes) {
  if (minutes <= 0 || dailyGoalMinutes <= 0) return 0;
  final weeklyGoalMinutes = dailyGoalMinutes * 7;
  return (minutes / weeklyGoalMinutes * 4).ceil().clamp(1, 4);
}

/// One heatmap square's tooltip: the day, and what was focused on it.
///
/// A zero day reads "no sessions" rather than "0m focused" — the squares
/// already show emptiness as colour, and the sentence should say what happened
/// rather than quantify what did not.
String heatmapCellTooltip(HeatmapCell cell) {
  final date = TimeService.parseLocalDate(cell.date);
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final day = '${months[date.month - 1]} ${date.day}';
  if (cell.minutes <= 0) return '$day · no sessions';
  return '$day · ${_formatTooltipMinutes(cell.minutes)} focused';
}

/// `45m`, `1h`, `1h 20m` — the same shape the detail screen's durations use.
String _formatTooltipMinutes(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

/// The three-letter weekday with the highest mean focus minutes, or an em dash
/// when no weekday has a mean at all.
String strongestWeekdayLabel(WeekdayProfile profile) {
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  int? bestIndex;
  var bestMean = 0.0;
  for (var i = 0; i < profile.bins.length; i++) {
    final mean = profile.bins[i].meanMinutes;
    if (mean == null) continue;
    if (bestIndex == null || mean > bestMean) {
      bestIndex = i;
      bestMean = mean;
    }
  }
  return bestIndex == null ? '—' : names[bestIndex];
}

/// Check-offs per day over the selected period, to one decimal.
///
/// An em dash for All time: that range's period is an open sentinel, so there
/// is no honest denominator to divide by, and inventing one ("days since the
/// first habit"?) would be a new concept this app does not have anywhere else.
/// Also an em dash when no habit exists — a ratio with nothing on either side
/// is not zero, it is undefined, the same rule the habits card already follows.
String habitsKeptPerDay({
  required StatsRange range,
  required StatsPeriod period,
  required HabitStatsBundle? habitBundle,
}) {
  if (range == StatsRange.allTime) return '—';
  if (habitBundle == null || habitBundle.activeHabitCount == 0) return '—';
  final dayCount = TimeService.daysBetween(period.start, period.end) + 1;
  if (dayCount <= 0) return '—';
  return (habitBundle.totalCheckOffs / dayCount).toStringAsFixed(1);
}

// ─────────────────────────────────────────────────────────────────────────────
// Private widgets
// ─────────────────────────────────────────────────────────────────────────────
/// One segment of the pill range picker.
class _RangeSegment extends StatelessWidget {
  const _RangeSegment({
    required this.label,
    required this.spokenLabel,
    required this.selected,
    required this.onTap,
  });

  final String label;

  /// What a screen reader says instead of "30d" — `StatsRange.label`.
  final String spokenLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tokens = context.tokens;

    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: spokenLabel,
      excludeSemantics: true,
      child: Material(
        color: selected ? colors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontSize: 11.5,
                    letterSpacing: 0,
                    fontWeight:
                        selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? colors.onPrimary : tokens.textMuted,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The hero's "+12%" badge.
///
/// [delta] is a difference of two rates, so it is read out in percentage
/// *points*. Nothing in this app rendered a signed delta before this chip, so
/// the three states are set here: a gain is the success green the boards use,
/// a loss is the danger token rather than a second green, and an exactly flat
/// period gets no sign and a neutral fill — "0%" in green would read as good
/// news about nothing having changed.
class _TrendChip extends StatelessWidget {
  const _TrendChip({required this.delta});

  final double delta;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tokens = context.tokens;

    final points = (delta * 100).round();
    final (Color tint, IconData icon, String text) = switch (points) {
      > 0 => (tokens.success, Icons.trending_up_rounded, '+$points%'),
      < 0 => (tokens.danger, Icons.trending_down_rounded, '$points%'),
      _ => (tokens.textSecondary, Icons.trending_flat_rounded, '0%'),
    };

    return Semantics(
      label: switch (points) {
        > 0 => '$points percentage points up on the previous period',
        < 0 => '${-points} percentage points down on the previous period',
        _ => 'Unchanged from the previous period',
      },
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          // The boards' #E1F2EC / #1B3329 as a tint of the state colour, so a
          // theme change carries it rather than leaving two stranded hexes.
          color: points == 0
              ? colors.surfaceContainerHighest
              : tint.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: tint),
            const SizedBox(width: 3),
            Text(
              text,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    letterSpacing: 0,
                    fontWeight: FontWeight.w800,
                    color: tint,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One cell of the 2×2 grid: a big figure over a small caption.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.figure,
    required this.label,
    this.tooltip,
  });

  final String figure;
  final String label;

  /// Mirrors `FreezesChip`'s pattern — a tooltip is how this codebase already
  /// explains a number whose scope is not obvious from its caption.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    final tile = Container(
      decoration: BoxDecoration(
        color: CardChrome.card(context),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              figure,
              maxLines: 1,
              style: statFigure(context).copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: colors.primary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: tokens.textMuted,
              height: 1.25,
            ),
          ),
        ],
      ),
    );

    if (tooltip == null) {
      return Semantics(
        container: true,
        label: '$figure $label',
        excludeSemantics: true,
        child: tile,
      );
    }
    return Tooltip(
      message: tooltip!,
      child: Semantics(
        container: true,
        label: '$figure $label. $tooltip',
        excludeSemantics: true,
        child: tile,
      ),
    );
  }
}

/// The trail's 2px dotted rail (`border-top:2px dotted`).
class _DottedRailPainter extends CustomPainter {
  const _DottedRailPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    // CSS `dotted` on a 2px border draws 2px dots on a 2px gap.
    for (var x = 0.0; x < size.width; x += 4) {
      canvas.drawLine(Offset(x, 1), Offset(min(x + 2, size.width), 1), paint);
    }
  }

  @override
  bool shouldRepaint(_DottedRailPainter oldDelegate) =>
      oldDelegate.color != color;
}
