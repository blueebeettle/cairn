import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/habits/habit_streak.dart';
import '../../../core/widgets/cairn_glyph.dart';
import '../../../data/providers/habit_providers.dart';
import '../../../data/repositories/habits_repository.dart';
import '../../../core/widgets/feature_info.dart';
import '../../../core/widgets/feature_info_content.dart';
import '../../../theme/app_theme.dart';
import '../domain/habit_presentation.dart';
import 'archived_habits_screen.dart';
import 'habit_check_controller.dart';
import 'habit_detail_screen.dart';
import 'habit_edit_sheet.dart';
import 'widgets/habit_check_button.dart';
import 'widgets/habit_marks.dart';
import 'widgets/habit_milestone.dart';
import 'widgets/weekly_recap_card.dart';

/// The Habits tab.
///
/// Grouped so nobody scrolls past finished work: **Today** (due, not done),
/// **Done today** (collapsed to a count), **Not scheduled today** (collapsed).
///
/// Grouping reads the *confirmed* snapshot, not the optimistic count. A tap
/// fills the circle instantly; the card then moves to "Done today" a frame or
/// two later, once the write lands — rather than vanishing under the finger.
class HabitsScreen extends ConsumerStatefulWidget {
  const HabitsScreen({super.key});

  @override
  ConsumerState<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends ConsumerState<HabitsScreen> {
  bool _doneExpanded = false;
  bool _restExpanded = false;

  @override
  Widget build(BuildContext context) {
    final snapshotsAsync = ref.watch(habitSnapshotsProvider);
    final mode = ref.watch(habitViewModeProvider);
    final textTheme = Theme.of(context).textTheme;
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Habits',
          style: textTheme.headlineSmall?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          // Forgiveness up front: the allowance already exists in the data,
          // it was just never shown anywhere.
          if (snapshotsAsync.value case final snapshots?
              when snapshots.isNotEmpty)
            FreezesChip(remaining: totalFreezesRemaining(snapshots)),
          const FeatureInfoButton(info: FeatureInfoContent.habits),
          IconButton(
            tooltip: mode == HabitViewMode.streak
                ? 'Switch to list view'
                : 'Switch to streak view',
            icon: Icon(
              mode == HabitViewMode.streak
                  ? Icons.view_list_rounded
                  : Icons.view_agenda_outlined,
            ),
            onPressed: () => ref.read(habitViewModeProvider.notifier).toggle(),
          ),
          PopupMenuButton<String>(
            tooltip: 'More options',
            onSelected: (value) {
              if (value == 'archived') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ArchivedHabitsScreen(),
                  ),
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'archived', child: Text('Archived habits')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        // See the matching comment in tasks_screen.dart — this and the Tasks
        // FAB are both permanently mounted via IndexedStack, so both need an
        // explicit, distinct hero tag.
        heroTag: 'habits_screen_fab',
        tooltip: 'Add a habit',
        onPressed: () => HabitEditSheet.show(context),
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const FeatureInfoCard(info: FeatureInfoContent.habits),
            Expanded(
              child: snapshotsAsync.when(
                // Every check-off writes habit_entries, which makes the snapshots
                // provider RELOAD (a dependency changed) — not refresh. Without
                // this the whole list flashes to a spinner on every tap.
                skipLoadingOnReload: true,
                skipLoadingOnRefresh: true,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Could not load habits: $e')),
                data: (snapshots) => snapshots.isEmpty
                    ? const _EmptyHabits()
                    : _buildList(context, snapshots, mode),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<HabitSnapshot> snapshots,
    HabitViewMode mode,
  ) {
    final due = <HabitSnapshot>[];
    final finished = <HabitSnapshot>[];
    final notToday = <HabitSnapshot>[];
    for (final s in snapshots) {
      if (!s.isScheduledToday) {
        notToday.add(s);
      } else if (s.isDoneToday || s.todayOutcome == HabitDayOutcome.neutral) {
        // A rest day marked today is finished business too.
        finished.add(s);
      } else {
        due.add(s);
      }
    }

    Widget row(HabitSnapshot s) => mode == HabitViewMode.streak
        ? _StreakCard(snapshot: s)
        : _CompactRow(snapshot: s);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
      children: [
        // Above the list, below the header — and inside the ListView rather
        // than pinned over it, so it scrolls away instead of eating a third
        // of the screen on a phone with a dozen habits. It renders nothing
        // when there are no active habits, which `_buildList` already
        // guarantees, but the card re-checks for itself rather than relying
        // on this one caller.
        const WeeklyRecapCard(),
        if (due.isNotEmpty) ...[
          const _SectionHeader('Today'),
          for (final s in due) row(s),
        ] else if (finished.isNotEmpty)
          const _AllDoneBanner(),
        if (finished.isNotEmpty) ...[
          _CollapsedHeader(
            label: '${finished.length} done today',
            expanded: _doneExpanded,
            onTap: () => setState(() => _doneExpanded = !_doneExpanded),
          ),
          if (_doneExpanded)
            for (final s in finished) row(s),
        ],
        if (notToday.isNotEmpty) ...[
          _CollapsedHeader(
            label: '${notToday.length} not scheduled today',
            expanded: _restExpanded,
            onTap: () => setState(() => _restExpanded = !_restExpanded),
          ),
          if (_restExpanded)
            for (final s in notToday) row(s),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Streak view card
// ─────────────────────────────────────────────────────────────────────────────

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.snapshot});

  final HabitSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final habit = snapshot.habit;
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.tokens;
    final accent = HabitColors.of(context, habit.colorIndex);
    final muted = !snapshot.isScheduledToday;
    final days = snapshot.lastScheduledDays(7);
    final milestone = snapshot.milestoneToday;
    final frozenOn = snapshot.freezeUsedOn;

    // The subtitle says the one thing that matters most about this row today:
    // a milestone, then a freeze that saved the streak, then the schedule.
    final (String subtitle, Color subtitleColor) = switch ((
      milestone,
      frozenOn,
    )) {
      (final int days, _) => (
        '$days-day milestone today',
        context.colors.primary,
      ),
      (_, final String date) => (
        HabitDates.freezeUsedLabel(date, snapshot.todayLocalDate),
        tokens.textSecondary,
      ),
      _ => (
        HabitScheduleText.describe(habit.scheduleRule),
        tokens.textSecondary,
      ),
    };

    return Opacity(
      opacity: muted ? 0.62 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: milestone == null ? null : MilestoneChrome.glow(context),
        ),
        child: Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: milestone == null
              ? null
              : RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: MilestoneChrome.ring(context),
                ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => HabitDetailScreen.open(context, habit.id),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  ExcludeSemantics(
                    // 0.6 is the mockup's 46x50 milestone glyph exactly.
                    child: milestone == null
                        ? CircleAvatar(
                            radius: 20,
                            backgroundColor: accent.withValues(alpha: 0.14),
                            child: Icon(
                              HabitIcons.of(habit.iconName),
                              color: accent,
                              size: 22,
                            ),
                          )
                        : const CairnGlyph(stoneCount: 3, scale: 0.6),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habit.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: textTheme.bodySmall?.copyWith(
                            color: subtitleColor,
                            fontWeight: milestone == null
                                ? null
                                : FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (milestone == null)
                              HabitStreakBadge(
                                streak: snapshot.streaks.current,
                                color: accent,
                              )
                            else
                              MilestoneStreakPill(streak: milestone),
                            _RecentDots(
                              snapshot: snapshot,
                              days: days,
                              color: accent,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  HabitCheckButton(snapshot: snapshot, diameter: 56),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The last seven SCHEDULED days, oldest to newest. Calendar days the habit
/// does not run on are not drawn — for a Mon/Wed/Fri habit, seven dots span
/// about two and a half weeks.
class _RecentDots extends StatelessWidget {
  const _RecentDots({
    required this.snapshot,
    required this.days,
    required this.color,
  });

  final HabitSnapshot snapshot;
  final List<String> days;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();
    return Semantics(
      container: true,
      label:
          'Last ${days.length} scheduled '
          '${days.length == 1 ? 'day' : 'days'}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final date in days)
            Padding(
              padding: const EdgeInsets.only(right: 5),
              child: HabitDayMark(
                outcome: snapshot.outcomeOn(date),
                color: color,
                size: 14,
                semanticLabel: HabitOutcomeText.cell(
                  date,
                  snapshot.outcomeOn(date),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// List view row — check button, title, streak number. Nothing else.
// ─────────────────────────────────────────────────────────────────────────────

class _CompactRow extends StatelessWidget {
  const _CompactRow({required this.snapshot});

  final HabitSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final habit = snapshot.habit;
    final accent = HabitColors.of(context, habit.colorIndex);
    return Opacity(
      opacity: snapshot.isScheduledToday ? 1 : 0.62,
      child: InkWell(
        onTap: () => HabitDetailScreen.open(context, habit.id),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                HabitCheckButton(snapshot: snapshot, diameter: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    habit.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                const SizedBox(width: 8),
                // Compact rows are one line by design, so a milestone shows
                // as the filled pill and nothing else — the glow card and the
                // forgiveness line belong to the streak view.
                if (snapshot.milestoneToday case final int milestone)
                  MilestoneStreakPill(streak: milestone)
                else
                  HabitStreakBadge(
                    streak: snapshot.streaks.current,
                    color: accent,
                    large: false,
                  ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section chrome and empty states
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: context.tokens.textMuted,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _CollapsedHeader extends StatelessWidget {
  const _CollapsedHeader({
    required this.label,
    required this.expanded,
    required this.onTap,
  });

  final String label;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      expanded: expanded,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: context.tokens.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AllDoneBanner extends StatelessWidget {
  const _AllDoneBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
      child: Text(
        'Everything due today is done.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: context.tokens.textSecondary),
      ),
    );
  }
}

/// No active habits: either the first run, or everything is archived. The
/// two need different words — "no habits yet" to someone with twelve
/// archived ones reads as data loss.
class _EmptyHabits extends ConsumerWidget {
  const _EmptyHabits();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archived = ref.watch(archivedHabitsProvider).value ?? const [];
    final textTheme = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_fire_department_outlined,
              size: 48,
              color: tokens.textMuted,
            ),
            const SizedBox(height: 12),
            if (archived.isEmpty) ...[
              Text(
                'No habits yet.',
                textAlign: TextAlign.center,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'A habit is something you want to keep doing. Cairn tracks '
                'the streak.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: tokens.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add a habit'),
                onPressed: () => HabitEditSheet.show(context),
              ),
            ] else
              Text(
                'Nothing active. Your archived habits are in the overflow menu.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: tokens.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
