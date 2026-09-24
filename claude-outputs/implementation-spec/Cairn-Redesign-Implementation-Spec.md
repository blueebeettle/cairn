# Cairn Redesign — Implementation Spec for Antigravity

Sep 23, 2026

## Overview

This is a paste-ready implementation spec for the Cairn motivation redesign, grounded in the real codebase (`D:\Dev\flutter\habit_tracker`) so each section can be pasted into Antigravity as a self-contained task. Every screen below references real files, classes and `AppTokens` already in the app — nothing here invents a new design system.

The approved visual reference is the mockup canvas: [Cairn Redesign Mockups](https://claude.ai/artifact/WGDmX4UN4GcNHU19BdLXZ9) (10 boards — 5 screens × light/dark). Open it alongside this doc; each section below points at the exact board to match pixel-for-pixel (spacing, radii, colors, copy).

**How to use this with Antigravity:** paste one screen's section (## heading through its file list) as a single task. Do the shared foundations section first — it creates the `CairnGlyph` widget everything else depends on — then screens in the rollout order at the end of this doc.

**What this is not:** a rewrite. Every section reuses existing providers, controllers and data (`focusStats`, `HabitSnapshot`, `HabitStats`, `stats_repository.dart`) — this is a visual and interaction layer on top of logic that mostly already exists (see §9 for the two things that don't).

## Shared foundations

### New widget: `CairnGlyph`

Create `lib/core/widgets/cairn_glyph.dart`. Every mockup's stone-stack (Today's "Grow your cairn", the Milestone celebration, the Habits list milestone card, and the Stats "Your journey" trail) is the same glyph at different scales — build it once as a parameterized widget, not copy-pasted markup per screen.

```dart
class CairnGlyph extends StatelessWidget {
  const CairnGlyph({
    super.key,
    required this.stoneCount, // 1-4, how many stones are "grown" so far
    this.scale = 1.0,          // 1.0 = the Today-card size (~76x86)
    this.showMarker = true,    // the glowing top disc — off for muted/faded trail stones
    this.opacity = 1.0,
  });

  final int stoneCount;
  final double scale;
  final bool showMarker;
  final double opacity;
}
```

- 4 stone layers, each a rounded-rect bar (`borderRadius` tighter on top than bottom, per the mockups: e.g. `BorderRadius.only(topLeft/topRight: 8, bottomLeft/bottomRight: 14)`), each rotated a few degrees off-axis (alternating sign) and offset slightly left/right — **never symmetric/continuous** (this is the fix for the earlier poop-emoji read: irregular offsets + gaps + a detached top marker, done with flat rounded bars to match the app's card language, not illustrated rocks).
- A thin drop-shadow bar between each stone (`Colors.black.withOpacity(0.08-0.12)` light / `withOpacity(0.28-0.35)` dark) sells the stacking without needing real shadows.
- The top marker: a small circle in the page background color with a ring (`BoxShadow` spread) in the tint color, plus a soft glow — this is the same visual device as the "today" indicator ring already used in the week-strip, so it reads as one system.
- Stone fill colors are fixed across light/dark (decorative, read fine on both): bottom-to-top `#40128B, #590D86, #8B3FAE, #BA7DD6`.
- `stoneCount` < 4 renders only that many layers (e.g. the Habits-list card uses a 3-stone simplified version); this is what makes the Stats "journey" trail possible — render the same widget at increasing `scale`/`opacity` per week.

Exact geometry to copy from: `Today.dc.html` (full 4-stone version, wrapper \~76×86) and `Stats.dc.html` (the "Your journey" trail's 7 mini instances) in the [mockup canvas](https://claude.ai/artifact/WGDmX4UN4GcNHU19BdLXZ9) — read the raw CSS pixel values off those files rather than re-deriving proportions.

### Tokens already available — use these, don't hardcode hex

All colors below already exist on `context.tokens` (`AppTokens` in `lib/theme/app_theme.dart`) or `Theme.of(context).colorScheme`; every screen section assumes these:

| Use | Token |
| --- | --- |
| Page background | `colorScheme.surface` (or `BrandColors.cream` / `darkGround` under the hood) |
| Card background | `colorScheme.surfaceContainerLow` / `context.tokens` surface roles |
| Primary accent (light `#590D86` / dark `#C08FE8`) | `colorScheme.primary` |
| Body / secondary / muted text | `colorScheme.onSurface`, `context.tokens.textSecondary`, `context.tokens.textMuted` |
| Success / warning / danger | `context.tokens.success` / `.warning` / `.danger` |
| Chart/series colors | `context.tokens.series[0..5]` |
| Heatmap ramp (5 steps) | `context.tokens.heatmap[0..4]` |

Do not introduce new colors for the redesign — every mockup's palette was built by mapping onto this exact token set (see the color table in the canvas notes), so the light/dark swap is automatic once widgets read tokens instead of literals.

## Today screen

Match: `Today.dc.html` / `Today.Dark.dc.html` in the canvas. File: `lib/features/today/presentation/today_screen.dart`.

1. **Momentum week-strip.** The existing streak chips (`streakFigure` from `focusStats.currentStreakDays`, "Best: Xd" from `focusStats.longestStreakDays`, around line 61 / 210-237) stay — the data is already there. Add a 7-day week strip above them: one dot/column per day (Mon–Sun), today's dot gets the glow ring (`BoxShadow` in `colorScheme.primary`, same device as the `CairnGlyph` marker so it reads as one system), days already past show filled vs. hollow by whether any habit was completed that day.
2. **"Grow your cairn" card.** New card below the streak chips: `CairnGlyph` at full scale, `stoneCount` driven by how many of today's habits are checked off so far (0–4 habits → 0–4 stones — for apps with more than 4 habits, scale `stoneCount` as `min(4, (checked / total * 4).ceil())`). This is the "variable reward" hook: the glyph visibly grows over the course of the day as habits get checked, not just at day-end.
3. **Habit rows.** Keep `TodayHabitsSection`/`habit_check_button.dart` structurally as-is, but the check-button needs the completion burst (small offset dots/flecks) currently missing — `habit_check_button.dart` today only does a color-fill swap + `HapticFeedback.lightImpact()`. Add a brief scale + 2-3 fleck-dot burst (150-200ms) on check, reusing `context.tokens.series` colors for the flecks. This is a pure animation addition, no state changes.

No new providers needed — `focusStats` and the habits list already carry everything this screen uses.

## Milestone celebration

Match: `Milestone.dc.html` / `Milestone.Dark.dc.html`. This is a **new** full-screen widget — there is currently no celebration surface in the app at all (confirmed: no `milestone`/`celebrat` hits anywhere in `lib/`).

1. New file `lib/features/habits/presentation/milestone_celebration_screen.dart` (or a modal route/dialog — Antigravity's call given the app's existing navigation shell in `lib/features/navigation/`). Full-bleed `colorScheme.primary` background, confetti-fleck decoration, a centered card with `CairnGlyph` at \~1.7× scale, streak count headline ("30 day streak"), the personal-best line ("You've never gone this far before. That's who you are now."), a primary "Keep going" action and a secondary "Share your cairn" action, and a small streak-freeze-remaining chip in the footer.
2. **Trigger logic (new — see §9):** fire when `focusStats.currentStreakDays` crosses a milestone threshold for the first time. Suggested thresholds: 7, 14, 30, 60, 100, then every 100. Needs a small persisted "last celebrated milestone per habit-set" flag (e.g. a key in shared prefs or a new column) so it fires once, not on every app open while the streak holds.
3. **Share action:** render the card (or just the `CairnGlyph` + streak number) to an image and hand off to the platform share sheet — `share_plus` or similar; check `pubspec.yaml` for an existing share dependency before adding one.

## Habits list

Match: `HabitsList.dc.html` / `HabitsList.Dark.dc.html`. File: `lib/features/habits/presentation/habits_screen.dart` (`_StreakCard`, `HabitStreakBadge` in `widgets/habit_marks.dart`).

**Good news: the freeze mechanic already exists in full — this section is UI only.** `lib/core/habits/habit_streak.dart` already tracks excused rest days (`HabitDayOutcome.neutral`) against a per-habit monthly allowance (`habit.skipAllowancePerMonth`, default 2), and `habits_repository.dart` already writes both a `habit_skipped` and a `habit_freeze_used` event when a skip lands inside the allowance (`EventTypes.habitFreezeUsed`). `excusedThisMonth` (line 51 of the repository) gives the count already used. Nothing here needs new data.

1. **"N freezes" header chip.** `habit.skipAllowancePerMonth - excusedThisMonth` for the habit(s) in view, shown as a chip next to the screen title, matching the mockup's pill style.
2. **Milestone glow card.** For any habit whose `snapshot.streaks.current` just crossed a round number (7/30/100…), render it with the 3-stone `CairnGlyph` (small scale) instead of the plain `HabitStreakBadge` flame icon, plus a soft glow border on the card. This reuses the same milestone-threshold check as §4's celebration trigger — factor it into one shared helper (e.g. `MilestoneThresholds.reached(streak)`) so both places agree.
3. **"Freeze used" forgiveness row.** For a habit whose most recent scheduled day resolved to `HabitDayOutcome.neutral`, show "Freeze used yesterday — streak safe" instead of a blank/missed-looking row. This is a direct read of `outcomes` from `HabitStats.resolveOutcomes`, already computed for the streak/month views.
4. Keep the existing List/Streak view-mode toggle and `HabitStreakBadge` for ordinary (non-milestone) rows — the redesign only touches the milestone and forgiveness states, not every row.

## Tasks screen

Match: `Tasks.dc.html` / `Tasks.Dark.dc.html`. Files: `lib/features/tasks/presentation/tasks_screen.dart`, `widgets/quick_capture_sheet.dart`.

**Correction vs. the mockup's placeholder copy:** the quick-capture legend chip that reads "\~15m estimate" in the mockup should say the real syntax — `~2p` (or `2p`) sets a **focus-session (pomodoro) count**, not a time estimate; there's no `!p1..!p4` typo either, it's genuinely priorities 1–4 ("Urgent"…). Use the exact legend strings already in `quick_capture_sheet.dart` line 317 (`'!p1–!p4 priority · #tag · ~2p focus sessions · "fri 5pm" due date/time'`) rather than the mockup's wording when building the real legend chips.

1. **"Today's progress" bar.** New summary card above quick-capture: completed/total tasks due today as a progress bar, same visual language as the Stats hero card's progress elements. Data: filter today's `TaskEntity`s already loaded for the screen.
2. **Quick-capture legend chips.** Break the existing single-line hint (line 317) into the 3 individual pill chips shown in the mockup, using the corrected copy above.
3. **Task row restyle.** Priority dot color already exists (`priorityColor` switch, `1=>tokens.danger, 2=>tokens.warning, 3=>tokens.series[1], _=>transparent`) — keep it, just move it to a small leading dot next to the title (mockup style) instead of however it currently renders. Completed rows get the same burst-fleck treatment as the Today screen's check button (share the animation, don't reimplement). Subtask rows keep the existing progress-bar + "N of M subtasks" pattern, restyled to match card spacing.
4. **"Done today" summary card**, same pattern as the progress bar, showing count cleared vs. remaining.

## Stats screen

Match: `Stats.dc.html` / `Stats.Dark.dc.html`. File: `lib/features/stats/presentation/stats_screen.dart` (currently \~9 stacked plain `Card`s — `_buildSummaryCard`, `_buildPeakWindowCard`, `_buildActivityHeatmapCard`, `_buildDayOfWeekCard`, `_buildTimeAllocationCard`, `_buildInterruptionsCard`, `_buildFocusRatingCard`, `_buildHabitsSummaryCard`, `_buildHabitActivityCard`). Data already comes from `lib/data/repositories/stats_repository.dart` / `habit_analytics_repository.dart` — this redesign restyles and reorders, it doesn't add new queries except the trend (§9).

1. **Range picker** — restyle the existing Week/30d/90d/All chips into the segmented-pill control shown in the mockup; same underlying state.
2. **Hero "This month" card** replaces `_buildSummaryCard`: big completion-rate number (from existing completion-rate data), a personal-best framing line comparing current streak to `focusStats.longestStreakDays` ("15 more takes you past your all-time best" — pure subtraction, no new data), and a trend chip (§9 — needs a prior-period comparison that doesn't exist yet).
3. **"Your journey" trail — new.** Horizontal row of `CairnGlyph` instances, one per week in the selected range, `scale`/`opacity` increasing left-to-right, last one at full scale with `showMarker: true` and a "Now" label. Feed `stoneCount`/scale per week from that week's completion rate (already computed for `_buildDayOfWeekCard` / weekly aggregates in the stats repository).
4. **Activity heatmap** — keep `_buildActivityHeatmapCard`'s data and `tokens.heatmap[cell.level]` coloring, just restyle: legend swatches, tighter grid, and a ring overlay on milestone days (days where a streak crossed a threshold) reusing the same `MilestoneThresholds` helper from §5.
5. **2×2 stat-tile grid** replaces the remaining stacked cards' headline numbers (best streak, strongest day from `_buildDayOfWeekCard`'s data, habits/day, freezes used from `excusedThisMonth` across habits) — the detailed breakdowns those cards showed (interruptions, focus rating, time allocation) can move to a "see more" / secondary view rather than being deleted, since that data has no equivalent in the mockup but is still real functionality.

## Notifications / weekly recap

Match: `WeeklyRecap.dc.html` / `WeeklyRecap.Dark.dc.html`. File: `lib/features/reminders/reminder_service.dart` (currently sends a generic `title: 'Today'` for every reminder — confirmed, no copy variation at all today).

1. **Varied notification copy pool.** Replace the single hardcoded title/body with a small rotation of templates per situation — the mockup shows three tones: an active-streak nudge ("12-day streak — keep it alive. Two habits are still open."), a fresh-week nudge ("New week, clean slate. 3 habits are waiting whenever you are."), and a freeze-used/forgiveness tone ("Missed yesterday — no big deal. A freeze kept your streak standing.", driven by the same `HabitDayOutcome.neutral` check from §5). Pick a template by state (streak active / week rollover / freeze used yesterday) plus a small random pick within that bucket so it's not the same line twice in a row — store "last template index used" to avoid immediate repeats.
2. **In-app weekly recap card.** New card (Habits or Stats screen, or a dedicated weekly summary surface — Antigravity's call): "This week" header with date range, a completion-rate line, a 7-bar mini bar chart (Mon–Sun, height = that day's completion, today's bar in the accent color vs. `tokens.series` for the rest), and 3 stat tiles (best streak, habits kept, freezes used) — all data already available from the stats/habits repositories, no new queries.

## New product logic required

Most of this redesign is UI on top of data that already exists — the streak-freeze mechanic in particular is fully built (see §5). Two things genuinely aren't there yet:

1. **Milestone detection + "celebrated once" state.** Nothing in the codebase currently checks whether a streak just crossed a round number, or remembers that it already showed the celebration for it. Needs: (a) a shared `MilestoneThresholds` helper (7/14/30/60/100/every 100 after) used by both the Habits-list glow card and the full-screen celebration trigger, and (b) a small persisted marker per habit (or per habit-set) recording the highest milestone already celebrated, so re-opening the app at day 31 of a 30-day streak doesn't re-fire the celebration. A new Drift column on `habits` (or a lightweight key-value table) is the natural place — Antigravity should check whether `app_database.dart` already has a settings/kv table before adding a new one.
2. **Period-over-period trend ("+12%")** on the Stats hero card. The current stats repository computes rates for a selected range, but not a comparison against the prior equivalent range. Needs one additional query: same-length window immediately before the selected range, same completion-rate calculation (`HabitStats.completionRate`, already pure and reusable), then a simple delta. Low risk — it's the same function called twice with different date bounds, not new aggregation logic.

Everything else in this spec (§2–§6, and the notification copy rotation in §8) is visual/interaction work over data and events that already exist.

## Suggested rollout order

1. **Shared foundations** (§2) — build `CairnGlyph` first; every other screen depends on it. Paste that section alone as the first Antigravity task.
2. **Today screen** (§3) — smallest, most self-contained, and the best place to sanity-check `CairnGlyph` at real size against the live theme before it's reused elsewhere.
3. **Habits list** (§5) — next, since it's UI-only (the freeze data already exists) and shares the milestone-threshold logic the celebration screen needs.
4. **Milestone logic + celebration screen** (§9 item 1, then §4) — build the shared `MilestoneThresholds` helper and persisted "last celebrated" marker, then the full-screen celebration UI on top of it.
5. **Tasks screen** (§6) — independent of the others, can be done any time; note the quick-capture legend copy correction before starting.
6. **Stats screen** (©7) — do last since the "Your journey" trail and trend chip reuse `CairnGlyph` and the milestone helper from steps 1 and 4.
7. **Notifications / weekly recap** (§8) — independent; can run in parallel with any of the above once the freeze-check pattern from §5 is in place.

Paste each numbered section's `##` heading through its file list as one Antigravity task, in this order, referencing the [mockup canvas](https://claude.ai/artifact/WGDmX4UN4GcNHU19BdLXZ9) for exact visuals at each step.
