import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/habit_statistics.dart';
import '../../../core/stats/statistics.dart';
import '../../../core/time/time_service.dart';
import '../../../data/providers/analytics_providers.dart';
import '../../../data/providers/habit_analytics_providers.dart';
import '../../../data/repositories/analytics_repository.dart';
import '../../../features/habits/domain/habit_presentation.dart';
import '../../../features/habits/presentation/widgets/habit_marks.dart';
import '../../../theme/app_theme.dart';

/// Full implementation of the Stats screen per SPEC.md §4 and PROMPT-stats-screen.md.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(statsRangeProvider);
    final bundleAsync = ref.watch(statsBundleProvider);
    final heatmapAsync = ref.watch(heatmapProvider);
    final thresholdsAsync = ref.watch(heatmapThresholdsProvider);

    final habitBundleAsync = ref.watch(habitStatsBundleProvider);
    final habitHeatmapAsync = ref.watch(habitHeatmapProvider);
    final habitThresholdsAsync = ref.watch(habitHeatmapThresholdsProvider);

    // Whether the habits section has anything to show at all. Gated on
    // whether any habit currently exists (`activeHabitCount`, from the same
    // bundle the cards below render), not on whether the selected range has
    // habit data in it — a brand-new habit with no history yet still
    // deserves a section that reads em dashes, not one that is entirely
    // absent from the screen.
    final hasHabits = (habitBundleAsync.valueOrNull?.activeHabitCount ?? 0) > 0;

    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stats'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // Range picker
          _buildRangePicker(context, ref, range),
          const SizedBox(height: 12),

          // Body content based on stats bundle state
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
                  if (bundle.hasAnyData) ...[
                    // Card 1 — Summary
                    _buildSummaryCard(context, bundle),
                    const SizedBox(height: 12),

                    // Card 2 — Peak window
                    _buildPeakWindowCard(context, bundle),
                    const SizedBox(height: 12),

                    // Card 3 — Activity heatmap
                    _buildActivityHeatmapCard(
                      context,
                      heatmapAsync: heatmapAsync,
                      thresholdsAsync: thresholdsAsync,
                    ),
                    const SizedBox(height: 12),

                    // Card 4 — Day of week
                    _buildDayOfWeekCard(context, bundle),
                    const SizedBox(height: 12),

                    // Card 5 — Where the time went
                    _buildTimeAllocationCard(context, bundle),
                    const SizedBox(height: 12),

                    // Card 6 — Interruptions
                    _buildInterruptionsCard(context, bundle),
                    const SizedBox(height: 12),

                    // Card 7 — Focus rating
                    _buildFocusRatingCard(context, bundle),
                  ],

                  if (bundle.hasAnyData && hasHabits) const SizedBox(height: 12),

                  if (hasHabits) ...[
                    // Card 8 — Habits summary (SPEC §10.5)
                    _buildHabitsSummaryCard(context, habitBundleAsync),
                    const SizedBox(height: 12),

                    // Card 9 — Habit activity heatmap
                    _buildHabitActivityCard(
                      context,
                      heatmapAsync: habitHeatmapAsync,
                      thresholdsAsync: habitThresholdsAsync,
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Range Picker ───────────────────────────────────────────────────────────

  Widget _buildRangePicker(
    BuildContext context,
    WidgetRef ref,
    StatsRange selectedRange,
  ) {
    return SegmentedButton<StatsRange>(
      showSelectedIcon: false,
      selected: {selectedRange},
      onSelectionChanged: (newSelection) {
        if (newSelection.isNotEmpty) {
          ref.read(statsRangeProvider.notifier).state = newSelection.first;
        }
      },
      segments: const [
        ButtonSegment(
          value: StatsRange.week,
          label: Text('Week'),
        ),
        ButtonSegment(
          value: StatsRange.month,
          label: Text('30d'),
        ),
        ButtonSegment(
          value: StatsRange.quarter,
          label: Text('90d'),
        ),
        ButtonSegment(
          value: StatsRange.allTime,
          label: Text('All'),
        ),
      ],
    );
  }

  // ── Whole-Screen Empty State ───────────────────────────────────────────────

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

  // ── Card 1: Summary ────────────────────────────────────────────────────────

  Widget _buildSummaryCard(BuildContext context, StatsBundle bundle) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    final focusedStr = _formatMinutes(bundle.totalFocusMinutes);

    final completionRate = bundle.completionRate;
    final finishedStr = completionRate.rate != null
        ? '${(completionRate.rate! * 100).round()}%'
        : '—';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Focused column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    focusedStr,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Focused',
                    style: textTheme.bodySmall?.copyWith(
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // Finished column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    finishedStr,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Finished',
                    style: textTheme.bodySmall?.copyWith(
                      color: tokens.textSecondary,
                    ),
                  ),
                  if (completionRate.rate != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${completionRate.completed} of ${completionRate.total} sessions',
                      style: textTheme.bodySmall?.copyWith(
                        color: tokens.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Active days column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${bundle.activeDayCount}',
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Active days',
                    style: textTheme.bodySmall?.copyWith(
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Card 2: Peak Window (SPEC §4.4) ────────────────────────────────────────

  Widget _buildPeakWindowCard(BuildContext context, StatsBundle bundle) {
    final colors = context.colors;
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    final peak = bundle.peakWindow;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('When you focus best', style: textTheme.titleMedium),
            const SizedBox(height: 12),
            if (!peak.hasEnoughData) ...[
              Text(
                '—',
                style: textTheme.displaySmall,
              ),
              const SizedBox(height: 4),
              Text(
                'Needs 10 finished sessions. You have ${peak.totalCompletedSessions}.',
                style: textTheme.bodySmall?.copyWith(color: tokens.textSecondary),
              ),
            ] else ...[
              Semantics(
                label: 'Peak focus hour: ${_formatHourRangeSpoken(peak.peakHour!)}',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 120,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var h = 0; h < 24; h++)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 1),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final maxValue = peak.minutesByHour.reduce(max);
                                    final value = peak.minutesByHour[h];
                                    final barHeight = maxValue <= 0
                                        ? 3.0
                                        : (3.0 + 117.0 * (value / maxValue));

                                    return Container(
                                      height: barHeight,
                                      decoration: BoxDecoration(
                                        color: h == peak.peakHour
                                            ? colors.primary
                                            : colors.primary.withValues(alpha: 0.32),
                                        borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(4),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        for (var h = 0; h < 24; h++)
                          Expanded(
                            child: (h == 0 || h == 6 || h == 12 || h == 18)
                                ? Text(
                                    h == 0
                                        ? '12a'
                                        : h == 6
                                            ? '6a'
                                            : h == 12
                                                ? '12p'
                                                : '6p',
                                    textAlign: TextAlign.center,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: tokens.textMuted,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You focus most around ${_formatHourRange(peak.peakHour!)}.',
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Card 3: Activity Heatmap (SPEC §4.13) ──────────────────────────────────

  Widget _buildActivityHeatmapCard(
    BuildContext context, {
    required AsyncValue<List<HeatmapCell>> heatmapAsync,
    required AsyncValue<HeatmapThresholds> thresholdsAsync,
  }) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Activity', style: textTheme.titleMedium),
            const SizedBox(height: 12),
            heatmapAsync.when(
              loading: () => const SizedBox(
                height: 95,
                child: Center(child: CircularProgressIndicator.adaptive()),
              ),
              error: (err, _) => Text(
                'Could not load activity: $err',
                style: textTheme.bodySmall?.copyWith(color: tokens.textSecondary),
              ),
              data: (cells) {
                if (cells.isEmpty) {
                  return Text(
                    '—',
                    style: textTheme.displaySmall,
                  );
                }

                // Group cells by weekday into columns of 7
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
                      child: Row(
                        children: [
                          for (var colIdx = 0; colIdx < columns.length; colIdx++) ...[
                            if (colIdx > 0) const SizedBox(width: 3),
                            Column(
                              children: [
                                for (var rowIdx = 0; rowIdx < 7; rowIdx++) ...[
                                  if (rowIdx > 0) const SizedBox(height: 3),
                                  _buildHeatmapCell(
                                    columns[colIdx][rowIdx],
                                    tokens,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Legend
                    Row(
                      children: [
                        Text(
                          'Less',
                          style: textTheme.bodySmall?.copyWith(
                            color: tokens.textMuted,
                          ),
                        ),
                        const SizedBox(width: 6),
                        for (var i = 0; i < 5; i++) ...[
                          if (i > 0) const SizedBox(width: 3),
                          Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                              color: tokens.heatmap[i],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                        const SizedBox(width: 6),
                        Text(
                          'More',
                          style: textTheme.bodySmall?.copyWith(
                            color: tokens.textMuted,
                          ),
                        ),
                      ],
                    ),
                    thresholdsAsync.maybeWhen(
                      data: (thresholds) {
                        if (thresholds.provisional) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
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
      ),
    );
  }

  Widget _buildHeatmapCell(HeatmapCell? cell, AppTokens tokens) {
    if (cell == null) {
      return const SizedBox(width: 11, height: 11);
    }
    return Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        color: tokens.heatmap[cell.level],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  // ── Card 4: Day of Week (SPEC §4.5) ────────────────────────────────────────

  Widget _buildDayOfWeekCard(BuildContext context, StatsBundle bundle) {
    final colors = context.colors;
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    final bins = bundle.weekdayProfile.bins; // 7 entries, Monday first
    final maxMean = bins.map((b) => b.meanMinutes ?? 0.0).reduce(max);
    const weekdayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('By day of week', style: textTheme.titleMedium),
            const SizedBox(height: 12),
            if (maxMean <= 0) ...[
              Text('—', style: textTheme.displaySmall),
              const SizedBox(height: 4),
              Text(
                'Finish a focus session to see day of week patterns.',
                style: textTheme.bodySmall?.copyWith(color: tokens.textSecondary),
              ),
            ] else ...[
              SizedBox(
                height: 90,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final bin = bins[i];
                              final hasMean = bin.meanMinutes != null;

                              if (!hasMean) {
                                return Container(
                                  height: 3.0,
                                  decoration: BoxDecoration(
                                    color: tokens.lineSoft,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(4),
                                    ),
                                  ),
                                );
                              }

                              final barHeight = maxMean <= 0
                                  ? 3.0
                                  : (3.0 + 87.0 * (bin.meanMinutes! / maxMean));

                              return Container(
                                height: barHeight,
                                decoration: BoxDecoration(
                                  color: colors.primary.withValues(alpha: 0.55),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            weekdayLabels[i],
                            textAlign: TextAlign.center,
                            style: textTheme.bodySmall?.copyWith(
                              color: tokens.textSecondary,
                            ),
                          ),
                          Text(
                            bins[i].activeDays == 0 ? '—' : 'n=${bins[i].activeDays}',
                            textAlign: TextAlign.center,
                            style: textTheme.bodySmall?.copyWith(
                              color: tokens.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Card 5: Where the Time Went (SPEC §4.8) ────────────────────────────────

  Widget _buildTimeAllocationCard(BuildContext context, StatsBundle bundle) {
    final colors = context.colors;
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    final allocation = bundle.timeAllocation;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Where the time went', style: textTheme.titleMedium),
            const SizedBox(height: 12),
            if (!allocation.isDefined) ...[
              Text('—', style: textTheme.displaySmall),
              const SizedBox(height: 4),
              Text(
                'No finished sessions in this range.',
                style: textTheme.bodySmall?.copyWith(color: tokens.textSecondary),
              ),
            ] else ...[
              // Stacked horizontal bar
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 12,
                  child: Row(
                    children: [
                      for (var i = 0; i < allocation.slices.length; i++)
                        Expanded(
                          flex: max(1, allocation.slices[i].minutes),
                          child: Container(
                            color: allocation.slices[i].isUnassigned
                                ? colors.outlineVariant
                                : tokens.series[i % tokens.series.length],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // List of slices
              for (var i = 0; i < allocation.slices.length; i++) ...[
                SizedBox(
                  height: 28,
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: allocation.slices[i].isUnassigned
                              ? colors.outlineVariant
                              : tokens.series[i % tokens.series.length],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          allocation.slices[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatMinutesPadded(allocation.slices[i].minutes),
                        style: textTheme.bodyMedium?.copyWith(
                          color: tokens.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 40,
                        child: Text(
                          allocation.slices[i].share != null
                              ? '${(allocation.slices[i].share! * 100).round()}%'
                              : '—',
                          textAlign: TextAlign.right,
                          style: textTheme.bodyMedium?.copyWith(
                            color: tokens.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // ── Card 6: Interruptions (SPEC §4.6) ──────────────────────────────────────

  Widget _buildInterruptionsCard(BuildContext context, StatsBundle bundle) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    final interruptions = bundle.interruptions;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Interruptions', style: textTheme.titleMedium),
            const SizedBox(height: 12),
            if (interruptions.perHourTotal == null) ...[
              Text('—', style: textTheme.displaySmall),
              const SizedBox(height: 4),
              Text(
                'Finish a session to see this.',
                style: textTheme.bodySmall?.copyWith(color: tokens.textSecondary),
              ),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    interruptions.perHourTotal!.toStringAsFixed(1),
                    style: textTheme.displaySmall,
                  ),
                  Text(
                    ' per focused hour',
                    style: textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('My own thought', style: textTheme.bodyMedium),
                  Text(
                    '${interruptions.perHourInternal?.toStringAsFixed(1) ?? '—'}/hr',
                    style: textTheme.bodyMedium?.copyWith(
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Someone else', style: textTheme.bodyMedium),
                  Text(
                    '${interruptions.perHourExternal?.toStringAsFixed(1) ?? '—'}/hr',
                    style: textTheme.bodyMedium?.copyWith(
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
              if (interruptions.abandonedInternal + interruptions.abandonedExternal > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '${interruptions.abandonedInternal + interruptions.abandonedExternal} more on sessions you stopped, not counted above.',
                  style: textTheme.bodySmall?.copyWith(color: tokens.textMuted),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // ── Card 7: Focus Rating (SPEC §4.7) ───────────────────────────────────────

  Widget _buildFocusRatingCard(BuildContext context, StatsBundle bundle) {
    final colors = context.colors;
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    final rating = bundle.focusRating;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How focused you felt', style: textTheme.titleMedium),
            const SizedBox(height: 12),
            if (rating.mean == null) ...[
              Text('—', style: textTheme.displaySmall),
              const SizedBox(height: 4),
              Text(
                'Rate a session when it ends and this fills in.',
                style: textTheme.bodySmall?.copyWith(color: tokens.textSecondary),
              ),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    rating.mean!.toStringAsFixed(1),
                    style: textTheme.displaySmall,
                  ),
                  Text(
                    ' / 5',
                    style: textTheme.titleMedium?.copyWith(
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'from ${rating.n} rated sessions',
                style: textTheme.bodySmall?.copyWith(color: tokens.textMuted),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var r = 0; r < 5; r++) ...[
                      if (r > 0) const SizedBox(width: 2),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final maxCount = rating.distribution.reduce(max);
                            final count = rating.distribution[r];
                            final barHeight = maxCount <= 0
                                ? 3.0
                                : (3.0 + 37.0 * (count / maxCount));

                            return Container(
                              height: barHeight,
                              decoration: BoxDecoration(
                                color: colors.secondary.withValues(alpha: 0.5),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  for (var r = 0; r < 5; r++) ...[
                    if (r > 0) const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        '${r + 1}',
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(
                          color: tokens.textMuted,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Card 8: Habits summary (SPEC §10.5) ────────────────────────────────────

  Widget _buildHabitsSummaryCard(
    BuildContext context,
    AsyncValue<HabitStatsBundle> habitBundleAsync,
  ) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Habits', style: textTheme.titleMedium),
            const SizedBox(height: 12),
            habitBundleAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator.adaptive()),
              ),
              error: (err, stack) => Text(
                'Could not load habit statistics: $err',
                style: textTheme.bodySmall?.copyWith(color: tokens.textSecondary),
              ),
              data: (habitBundle) {
                final rateStr = formatHabitRate(habitBundle.completionRate.rate);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Completion column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rateStr,
                                style: textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Completion',
                                style: textTheme.bodySmall?.copyWith(
                                  color: tokens.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Check-offs column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${habitBundle.totalCheckOffs}',
                                style: textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Check-offs',
                                style: textTheme.bodySmall?.copyWith(
                                  color: tokens.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Active habits column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${habitBundle.activeHabitCount}',
                                style: textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Active habits',
                                style: textTheme.bodySmall?.copyWith(
                                  color: tokens.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (habitBundle.leaderboard.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Current streaks',
                        style: textTheme.labelLarge?.copyWith(
                          color: tokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final entry in habitBundle.leaderboard.take(5))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              ExcludeSemantics(
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundColor: HabitColors.of(context, entry.colorIndex)
                                      .withValues(alpha: 0.14),
                                  child: Icon(
                                    HabitIcons.of(entry.iconName),
                                    size: 14,
                                    color: HabitColors.of(context, entry.colorIndex),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  entry.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.bodyMedium,
                                ),
                              ),
                              const SizedBox(width: 8),
                              HabitStreakBadge(
                                streak: entry.currentStreak,
                                color: HabitColors.of(context, entry.colorIndex),
                                large: false,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Card 9: Habit activity heatmap ─────────────────────────────────────────

  Widget _buildHabitActivityCard(
    BuildContext context, {
    required AsyncValue<List<HabitHeatmapCell>> heatmapAsync,
    required AsyncValue<HeatmapThresholds> thresholdsAsync,
  }) {
    final tokens = context.tokens;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Habit activity', style: textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(
              'Distinct habits completed each day, over the last year.',
              style: textTheme.bodySmall?.copyWith(color: tokens.textSecondary),
            ),
            const SizedBox(height: 12),
            heatmapAsync.when(
              loading: () => const SizedBox(
                height: 95,
                child: Center(child: CircularProgressIndicator.adaptive()),
              ),
              error: (err, stack) => Text(
                'Could not load habit activity: $err',
                style: textTheme.bodySmall?.copyWith(color: tokens.textSecondary),
              ),
              data: (cells) {
                if (cells.isEmpty) {
                  return Text('—', style: textTheme.displaySmall);
                }

                // Grouped into weekday columns exactly as Card 3 groups
                // `HeatmapCell`s — duplicated rather than shared, since the
                // two heatmaps carry different cell types and this feature
                // is edited independently of the focus one.
                final columns = <List<HabitHeatmapCell?>>[];
                var currentColumn = List<HabitHeatmapCell?>.filled(7, null);
                var lastRowIndex = -1;

                for (final cell in cells) {
                  final parsed = TimeService.parseLocalDate(cell.date);
                  final rowIndex = parsed.weekday - 1;

                  if (currentColumn[rowIndex] != null || rowIndex < lastRowIndex) {
                    columns.add(currentColumn);
                    currentColumn = List<HabitHeatmapCell?>.filled(7, null);
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
                      child: Row(
                        children: [
                          for (var colIdx = 0; colIdx < columns.length; colIdx++) ...[
                            if (colIdx > 0) const SizedBox(width: 3),
                            Column(
                              children: [
                                for (var rowIdx = 0; rowIdx < 7; rowIdx++) ...[
                                  if (rowIdx > 0) const SizedBox(height: 3),
                                  _buildHabitHeatmapCell(
                                    columns[colIdx][rowIdx],
                                    tokens,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Legend — the same ramp as the focus heatmap (Card 3),
                    // just bucketed by SPEC's percentile rule over habit
                    // counts instead of focus minutes.
                    Row(
                      children: [
                        Text(
                          'Less',
                          style: textTheme.bodySmall?.copyWith(
                            color: tokens.textMuted,
                          ),
                        ),
                        const SizedBox(width: 6),
                        for (var i = 0; i < 5; i++) ...[
                          if (i > 0) const SizedBox(width: 3),
                          Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                              color: tokens.heatmap[i],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                        const SizedBox(width: 6),
                        Text(
                          'More',
                          style: textTheme.bodySmall?.copyWith(
                            color: tokens.textMuted,
                          ),
                        ),
                      ],
                    ),
                    thresholdsAsync.maybeWhen(
                      data: (thresholds) {
                        if (thresholds.provisional) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Provisional scale — ${thresholds.nonZeroDayCount} days of habit '
                              'activity so far. It becomes yours at 14.',
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
      ),
    );
  }

  Widget _buildHabitHeatmapCell(HabitHeatmapCell? cell, AppTokens tokens) {
    if (cell == null) {
      return const SizedBox(width: 11, height: 11);
    }
    return Container(
      width: 11,
      height: 11,
      decoration: BoxDecoration(
        color: tokens.heatmap[cell.level],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static String _formatMinutes(int minutes) {
    if (minutes == 0) return '0m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  static String _formatMinutesPadded(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    final mStr = m.toString().padLeft(2, '0');
    return '${h}h ${mStr}m';
  }

  static String _formatHourRange(int hour) {
    String formatH(int h) {
      final mod = h % 24;
      if (mod == 0) return '12';
      if (mod <= 12) return '$mod';
      return '${mod - 12}';
    }

    final startH = formatH(hour);
    final endH = formatH(hour + 1);
    final startAmPm = (hour % 24) < 12 ? 'am' : 'pm';
    final endHourMod = (hour + 1) % 24;
    final endAmPm = endHourMod < 12 && (hour + 1) != 12 ? 'am' : 'pm';

    if (startAmPm == endAmPm) {
      return '$startH–$endH$endAmPm';
    } else {
      return '$startH$startAmPm–$endH$endAmPm';
    }
  }

  static String _formatHourRangeSpoken(int hour) {
    String formatH(int h) {
      final mod = h % 24;
      if (mod == 0) return '12';
      if (mod <= 12) return '$mod';
      return '${mod - 12}';
    }

    final startH = formatH(hour);
    final endH = formatH(hour + 1);
    final amPm = (hour % 24) < 12 ? 'am' : 'pm';
    return '$startH to $endH $amPm';
  }
}
