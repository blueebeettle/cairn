# Focus Stack — Build Specification v1

**Status:** contract for implementation. An agent building this app should treat every
definition here as binding and ask before deviating.

**v1 scope:** focus timer + tasks + habits. Habits were deferred at first draft; §10
implements them against the schema reserved here, and they ship in v1.

**Platforms:** Android (primary), Flutter desktop (companion, no sync in v1).

**Theme:** see `app_theme.dart`. Do not invent colours; every colour comes from
`ColorScheme` or `AppTokens`.

---

## 0. The one architectural rule

Every user action writes an **immutable row to `events`**. The module tables
(`focus_sessions`, `tasks`) are a read model derived from those events.

Events are never updated and never deleted. A correction is a new compensating event.

This is not ceremony. It buys three things: statistics that cannot disagree with the
lists, new metrics computable over old data without a migration, and an export that is
one query. If an implementation shortcuts this, every statistic below becomes unreliable
the first time a user edits history.

---

## 1. Time semantics

This section is the most important in the document. Most bugs in this category of app
are time bugs, and they are invisible for weeks.

### 1.1 Storage

- All instants are **UTC epoch milliseconds**, stored as `INTEGER`.
- Never store local wall-clock strings as the source of truth for an instant.

### 1.2 Logical day

Every event additionally stores `local_date` as `TEXT` in `YYYY-MM-DD`, **computed once
at write time and never recomputed**.

```
day_start_offset  := user setting, minutes after midnight, default 240 (04:00)
local_datetime    := occurred_at converted to the device's timezone at that moment
local_date        := (local_datetime − day_start_offset).date
```

Consequences, all intended:

- A session at 01:30 with a 04:00 day start belongs to the **previous** day. Night owls
  do not lose streaks at midnight. This is the single most common complaint about
  habit trackers.
- A session logged at 23:00 in Edmonton stays on that date forever, even if the user
  later flies to Kolkata. History does not shift under the user.
- DST cannot corrupt history, because the local date was resolved when it was
  unambiguous. A logical day may be 23 or 25 wall-clock hours; all *durations* are
  computed from UTC deltas, so they stay correct regardless.

**Changing `day_start_offset` applies to new events only.** Historical `local_date`
values are never rewritten. Retroactively mutating streaks is worse than the
inconsistency.

Also store on each event, for auditability: `tz_id` (IANA, e.g. `America/Edmonton`) and
`tz_offset_min` at write time.

**`tz_id` must be a real IANA identifier.** Dart's `DateTime.timeZoneName` is not one — it
returns a platform abbreviation on Android (`IST`, `MDT`) and a Windows display name on
desktop (`India Standard Time`). `IST` is the worst case available: it is India Standard
Time, Irish Standard Time and Israel Standard Time, three zones that do not share an
offset. Use `flutter_timezone` and pass its id through `TimeService.tzIdProvider`.

Nothing depends on `tz_id` for correctness — `tz_offset_min` carries every calculation —
which is exactly why it is easy to leave wrong until the day it is needed.

### 1.3 Week

- `week_start` := user setting, default Monday.
- A week is the seven logical days beginning on `week_start`.
- Week grouping is done on `local_date` strings, never by re-deriving from UTC.

### 1.4 Session spanning midnight

A session belongs **entirely to the logical day on which it started**. Never split a
session across days. A 90-minute flow session starting at 03:30 with a 04:00 day start
counts wholly toward the previous day.

### 1.5 Clock skew

If `now < started_at` (user moved the device clock backwards), treat elapsed as `0`
rather than negative, and set `payload.clock_anomaly = true` on the completing event.
Never write a negative duration.

---

## 2. Data model

### 2.1 `events` — append-only

| column | type | notes |
|---|---|---|
| `id` | INTEGER PK | autoincrement |
| `type` | TEXT | see 2.2 |
| `occurred_at` | INTEGER | UTC ms — when it happened |
| `recorded_at` | INTEGER | UTC ms — when it was written (differs for manual entry) |
| `local_date` | TEXT | `YYYY-MM-DD`, per §1.2 |
| `tz_id` | TEXT | IANA zone at write time |
| `tz_offset_min` | INTEGER | offset at write time |
| `subject_type` | TEXT | `session` \| `task` \| `habit` \| null |
| `subject_id` | INTEGER | null for events with no subject |
| `payload` | TEXT | JSON, type-specific |

Index on `(local_date)`, `(type, local_date)`, `(subject_type, subject_id)`.

### 2.2 Event types

**v1 — sessions**

| type | payload |
|---|---|
| `session_started` | `{mode, planned_duration_s, task_id?, project_id?}` |
| `session_completed` | `{actual_duration_s, focus_rating?, note?, manual?}` |
| `session_abandoned` | `{actual_duration_s, reason}` — `reason` ∈ `user_stopped`, `strict_mode_forfeit` |
| `session_interrupted` | `{kind}` — `kind` ∈ `internal`, `external` |
| `break_started` / `break_completed` | `{duration_s}` |

**v1 — tasks**

| type | payload |
|---|---|
| `task_created` | `{title, project_id?, priority, due_at?, estimate_pomodoros?}` |
| `task_completed` | `{}` |
| `task_uncompleted` | `{}` — undo; does not delete the completion event |
| `task_rescheduled` | `{from_due_at, to_due_at}` |
| `task_archived` | `{}` |

**Phase 04 — habits** (schema reserved, not implemented in v1)

`habit_checked`, `habit_skipped`, `habit_unchecked`, `habit_freeze_used`.

### 2.3 `focus_sessions` — read model

| column | type | notes |
|---|---|---|
| `id` | INTEGER PK | |
| `task_id` | INTEGER NULL | |
| `project_id` | INTEGER NULL | denormalised from task at start, so later reassignment doesn't rewrite history |
| `mode` | TEXT | `pomodoro` \| `flow` |
| `planned_duration_s` | INTEGER | 0 for flow mode |
| `actual_duration_s` | INTEGER | excludes paused time |
| `started_at` / `ended_at` | INTEGER | UTC ms |
| `local_date` | TEXT | |
| `tz_offset_min` | INTEGER | minutes east of UTC **at session start** — see below |
| `tz_id` | TEXT | IANA zone at session start, e.g. `Asia/Kolkata` |
| `outcome` | TEXT | `completed` \| `abandoned` |
| `interruptions_internal` | INTEGER | default 0 |
| `interruptions_external` | INTEGER | default 0 |
| `focus_rating` | INTEGER NULL | 1–5 |
| `note` | TEXT NULL | |
| `is_manual` | INTEGER | 0/1 — logged retroactively |

`tz_offset_min` is not redundant with the same column on `events`. §4.4 bins sessions by
local hour, and it must bin them by the hour **where the session happened**, not by
whatever the device believes its zone to be when the chart is drawn.

Expected users are in India or in Canada — in one zone or the other, not moving between
them. Permanent relocation is not the case this is for. What it is for is narrower and
likelier: a trip with the phone's timezone changed, or a device whose zone is simply set
wrong. In either case, reading history through the device's current idea of local time
redraws every session the user has ever recorded, and then redraws it back afterwards.
The offset belongs to the session. Denormalise it, like `project_id` above and for the
same reason.

One cost, recorded so it is not rediscovered as a bug: looking the zone up per instant
would handle a session that *spans* a DST change correctly, and binning by the stored
start offset does not — such a session is an hour out. That needs a focus session running
through 02:00 on one Sunday a year, so it is close to never; but it is a real thing
traded away, not a free win.

`tz_id` is never used in a calculation — `tz_offset_min` carries that. It is for showing
"09:00, Kolkata time" beside a session, and for diagnosing a timezone bug later when the
offset alone will not tell you what happened.

### 2.4 `tasks`

| column | type | notes |
|---|---|---|
| `id` | INTEGER PK | |
| `title` | TEXT | |
| `notes` | TEXT NULL | |
| `project_id` | INTEGER NULL | |
| `parent_id` | INTEGER NULL | one level of subtask only |
| `priority` | INTEGER | 1–4, 1 = highest |
| `due_at` | INTEGER NULL | UTC ms |
| `due_is_all_day` | INTEGER | 0/1 |
| `estimate_pomodoros` | INTEGER NULL | |
| `status` | TEXT | `open` \| `done` \| `archived` |
| `created_at` / `created_local_date` | INTEGER / TEXT | |
| `completed_at` / `completed_local_date` | INTEGER NULL / TEXT NULL | |
| `reschedule_count` | INTEGER | default 0, see §4.12 |
| `recurrence_rule` | TEXT NULL | RRULE subset, see 2.6 |
| `recurrence_mode` | TEXT NULL | `on_schedule` \| `after_completion` |
| `recurrence_parent_id` | INTEGER NULL | links instances of a series |
| `sort_order` | REAL | fractional ordering for drag-and-drop |

No reminder columns here — reminder configuration for both tasks and habits is its own
schema, §11.

### 2.5 Supporting tables

- `projects` — `id, name, color_index, archived`
- `tags` — `id, name`
- `task_tags` — `task_id, tag_id`
- `settings` — `key, value` (JSON-encoded)
- `timer_state` — single row, see §3.2

### 2.6 Recurrence

Supported rules: daily, every N days, specific weekdays, every N weeks on weekdays,
monthly on day-of-month, monthly on nth weekday.

Two modes, and getting this wrong is a common bug:

- **`on_schedule`** — the next due date is the next occurrence after the *scheduled*
  due date. Missing one does not shift the series. *"Pay rent on the 1st."*
- **`after_completion`** — the next due date is the completion date + interval.
  *"Water the plants every 3 days"* — from when you actually did it.

Completing a recurring task writes `task_completed` for **that instance** and inserts a
new row for the next instance, linked by `recurrence_parent_id`. History is preserved
per instance; a series is never a single mutating row.

---

## 3. Timer

### 3.1 State machine

```
idle ──start──▶ running ──┬──pause──▶ paused ──resume──▶ running
                          ├──complete──▶ completed ──▶ break_running ──▶ idle
                          └──stop──────▶ abandoned  ──▶ idle
```

Flow mode has no `planned_duration_s`; it counts up and can only be completed or
abandoned by the user.

### 3.2 Persistence — the critical rule

**Remaining time is always computed, never decremented.** A ticking counter in memory is
lost the moment the process dies, and reconstructing it from a "last tick" timestamp
drifts.

Persist to `timer_state` on every transition:

```
session_id, started_at_utc, planned_duration_s, mode,
paused_accumulated_s, paused_at_utc (null when running)
```

```
elapsed   = (now − started_at) − paused_accumulated
            − (paused_at ? now − paused_at : 0)
remaining = planned_duration_s − elapsed
```

### 3.3 Recovery

On app start (including after reboot), if `timer_state` holds an active session:

- **`now < expected_end`** → resume the running timer at the correct remaining value.
- **`now >= expected_end`** → the session finished while the app was dead. Write
  `session_completed` with `ended_at = expected_end`, **not** `now`, and
  `actual_duration_s = planned_duration_s`. Show the break screen.

A session is abandoned only when the user explicitly stops it, or — in strict mode —
when the app has been in the background beyond the grace period (default 30 s).

### 3.4 Android requirements

- Foreground service (`flutter_foreground_task`) with a notification carrying **Pause**
  and **Skip** actions, and a live remaining-time display.
- Runtime `POST_NOTIFICATIONS` permission (Android 13+), requested with an explanation,
  and a graceful degraded mode if denied.
- `SCHEDULE_EXACT_ALARM` handling for Android 14+ if exact end-of-session alarms are
  used; prefer the foreground service as the primary mechanism and treat alarms as a
  backstop.
- Survive battery optimisation: detect when the app is restricted and surface a one-time
  prompt pointing at the OEM setting.

### 3.5 Desktop

Desktop has no foreground service. Implement the same computed-remaining logic against a
plain `Timer.periodic` for the UI plus system tray state. Desktop and Android do **not**
share data in v1.

---

## 4. Statistics

Every definition below must be implemented exactly. Where a metric is undefined, display
an em dash and an explanatory line — **never `0`, never `0%`, never an imputed value.**
A zero that means "no data" is a lie the user will act on.

Notation: `P` is the period being reported (a set of logical dates).

### 4.1 Focus minutes
Sum of `actual_duration_s / 60` over `focus_sessions` where `outcome = 'completed'`
and `local_date ∈ P`. Abandoned sessions contribute **zero** focus minutes.

### 4.2 Session completion rate
`completed / (completed + abandoned)` over sessions **started** in `P`.
Undefined when the denominator is 0.

### 4.3 Current focus streak
Let `met(d)` := focus minutes on day `d` ≥ `daily_goal_minutes` (default 25).

Walk backwards from today. If `met(today)` is false, **start from yesterday** — today is
still in progress and must not break a streak. Count consecutive days where `met(d)` is
true. Stop at the first false.

**Longest streak** is the maximum such run over all history.

### 4.4 Peak window
Twenty-four bins by local hour. A session spanning bins is apportioned to each bin by its
**actual overlap in minutes**, not assigned wholly to its start hour. Peak = argmax.

Require ≥ 10 completed sessions in total before displaying; otherwise show
"not enough data yet". A peak computed from four sessions is noise presented as insight.
The threshold counts sessions over **all history**, not over `P` — the question is whether
enough is known about this user to name their peak hour, not whether last week was busy.

**Bins hold focus minutes, not wall-clock minutes.** A session's overlap with each hour is
scaled by `actual_duration_s / (ended_at − started_at)`, so paused time is spread across
the span rather than inflating whichever bin it fell in. Summed over a period the bins
equal total focused seconds ÷ 60 exactly, which §4.1 then floors. Without this the peak
chart and the focus-minutes figure beside it on the same screen would disagree.

**The hours are the session's own.** Binning runs off the session's stored
`tz_offset_min` (§2.3), never off the device's current zone, so the answer does not change
when the user travels. This is the single most important property of this metric for an
app used in both India and Canada.

The cost, stated so nobody "fixes" it later: a session that *spans* a DST transition is
binned entirely by the offset it started under, so minutes after the change land one hour
off. That is at most two sessions a year, one bin out, in a 24-bin histogram that will not
display below ten sessions. Computing it exactly would mean consulting a live timezone
database at read time — which is precisely the thing that makes the chart follow the
reader around the world. It is not a close call.

Ties go to the earlier hour, so the answer does not depend on iteration order.

### 4.5 Day-of-week profile
Mean focus minutes per weekday, averaged over days that contain **at least one event of
any type**. Days where the phone was untouched are excluded rather than counted as zero.
Always display `n` per bar.

### 4.6 Interruptions per focused hour
`(Σ internal + Σ external) / (focus minutes / 60)` over `P`.
Undefined when focus minutes = 0. Show internal and external separately as well as
combined — they have different remedies.

**Numerator and denominator are both taken over completed sessions.** §4.1 already defines
focus minutes as completed-only, so counting interruptions from abandoned sessions on top
of a completed-only denominator would divide one population by another: a user who
abandons often would see a rate inflated by sessions that contributed no hours, and
nothing they could do would move it. Interruptions recorded on abandoned sessions are
reported separately rather than hidden.

### 4.7 Mean focus rating
Mean of `focus_rating` over completed sessions in `P` **where the rating is not null**.
Display `n`. Never impute a missing rating.

### 4.8 Time allocation
Focus minutes grouped by `project_id` over `P`. Sessions with no project appear as
**"Unassigned"** and are always shown — hiding them makes the totals lie.

### 4.9 Estimate accuracy
For each task with `estimate_pomodoros` not null and `status = 'done'`:

```
actual_pomodoros = ceil(Σ actual_duration_s of completed sessions on that task
                        / pomodoro_length_s)
ratio            = actual_pomodoros / estimate_pomodoros
```

Aggregate is the **median** ratio, not the mean — one 8× outlier must not define the
user's calibration. Display `n` and the distribution. Require `n ≥ 5`.

### 4.10 Throughput balance
Count of `task_created` vs `task_completed` events with `local_date ∈ P`.
`net = created − completed`. Positive net means the backlog is growing.

### 4.11 Task age
For open tasks: `today − created_local_date`, in whole days. Ranked descending.

### 4.12 Procrastination index
Open tasks ranked by `reschedule_count` descending, ties broken by age.

`reschedule_count` increments **only** when a `task_rescheduled` event moves the due date
*later*. Pulling a task earlier is not procrastination.

### 4.13 Activity heatmap
Per logical day, a level 0–4:

- **Level 0** — zero focus minutes.
- **Levels 1–4** — bounded by the 25th, 50th, 75th and 90th percentiles of focus minutes
  across **non-zero days in the trailing 365 days**, recomputed weekly and cached.

Each percentile is the **upper** bound of its level, and the top level saturates — a day
above the 90th percentile is still level 4, because there is no level 5:

```
level 0 :         minutes == 0
level 1 :    0 <  minutes <= p25
level 2 :  p25 <  minutes <= p50
level 3 :  p50 <  minutes <= p75
level 4 :  p75 <  minutes          (nominal ceiling p90 — legend only)
```

The 90th percentile therefore never assigns a level. It is what the legend shows as the
top of the scale.

Percentiles use the **nearest-rank** method: with `n` values sorted ascending, the `p`th
percentile is the value at 1-based rank `ceil(p × n / 100)`. Compute that rank in integer
arithmetic — `(p * n + 99) ÷ 100` — not as `ceil(p / 100 × n)`. One representation error is
enough to step a whole rank, and a threshold that moves by a rank changes which days light
up.

"Trailing 365 days" includes today. The cache is keyed by the start of the current week, so
it expires by being from a different week rather than by storing a timestamp.

Thresholds are relative to the user, not absolute. Fixed thresholds make every user's
heatmap look the same; relative ones make it theirs. With fewer than 14 non-zero days,
fall back to fixed thresholds of 25 / 50 / 100 / 180 minutes and mark the legend
"provisional".

### 4.14 Perfect day
A logical day where **both** hold:

- focus goal met (or the goal is disabled), and
- every task due that day was completed on that day.

A day with no tasks due and the goal met is a perfect day. A day with the goal disabled
and no tasks due is **not** a perfect day — it is undefined and excluded from the count.

### 4.15 Weekly review
Recomputable for **any** past week, from events alone. Contains:

focus hours + Δ vs prior week · sessions completed / abandoned ·
interruptions per hour + Δ · tasks completed · tasks created · net ·
best single day · peak window that week · top 3 projects by hours ·
tasks that were due in the week and are still open.

Nothing here may be stored at week-end and read back — it must be a pure function of the
event log, or it stops matching when history is corrected.

---

## 5. Statistics that must be worded carefully

Any cross-metric observation is an **association within one person's data**, over a small
sample, with no control. Phrase them accordingly:

- ✅ "On days you completed your morning routine, focus averaged 42% higher."
- ❌ "Your morning routine improves your focus."

Require `n ≥ 14` days on both sides of any comparison before displaying it, and always
show `n`. This costs nothing and keeps the feature honest.

---

## 6. Edge cases the implementation must handle

| Case | Required behaviour |
|---|---|
| Timezone changes mid-session | `local_date` fixed at session start; do not recompute |
| Session crosses midnight | Belongs wholly to the starting logical day |
| `day_start_offset` changed | New events only; historical `local_date` untouched |
| Task deleted | Soft delete (`status = 'archived'`); events retained; past-period stats unchanged |
| Manual session entry | `occurred_at` in the past, `recorded_at` now, `is_manual = 1`, visibly marked in the UI |
| Device clock moved backwards | Elapsed clamped at 0; `clock_anomaly` flagged |
| Session with no task | Valid; counts toward all totals; shows as "Unassigned" |
| Zero-length period queried | Return undefined, not zero |
| DST transition day | Duration math from UTC deltas; day grouping from stored `local_date` |
| App killed mid-session | Recovered per §3.3 |

---

## 7. Test fixtures — required before the stats engine is considered done

The stats engine is pure Dart with no device dependency and must be tested
exhaustively. **Tests are written from this document, not from the implementation.**
A test derived from the code confirms the bug.

- **Fixture A — DST.** 90 days of synthetic events in `America/Edmonton` spanning both
  the November and March transitions, with hand-computed expected values for every
  metric in §4.
- **Fixture B — Relocation.** Events in `America/Edmonton` followed by events in
  `Asia/Kolkata` mid-week. Assert that earlier days' `local_date` values and all
  historical metrics are byte-identical before and after the move.
  **Built — `test/relocation_test.dart`.** Three evening sessions in Edmonton, a flight on
  the Thursday, three morning sessions in Kolkata. It carries a control case that
  deliberately misattributes the Kolkata sessions to Edmonton's offset and asserts the
  result is different, so the fixture cannot pass by accident.

  These two zones are the ones to test against, not a generic pair: they are where the app
  will be used. The fixture is framed as a relocation because that is the sharpest way to
  assert the invariant — history must not move — not because users are expected to emigrate.

  `Asia/Kolkata` is the more demanding of the two, because UTC+5:30 puts every local hour
  boundary at :30 past the UTC hour. Any arithmetic that assumes whole-hour offsets fails
  there on every session — and it is not only an India problem: **`America/St_Johns` is
  UTC−3:30**, so a Canadian user in Newfoundland takes exactly the same path.
- **Fixture C — Streaks.** Exact-goal days, zero days, a day one minute short, today
  not yet met, a 400-day history for longest-streak.
- **Fixture D — Recurrence.** `on_schedule` with two missed occurrences;
  `after_completion` completed late; month-end rollover (31st in a 30-day month).
- **Fixture E — Recovery.** Process killed at t=10 min of a 25 min session, relaunched
  at t=30 min. Assert exactly one `session_completed`, `actual_duration_s == 1500`,
  and `ended_at == expected_end`.

CI runs `flutter analyze` and `flutter test` on every change. A failing analyzer is a
failing build.

---

## 8. Device checklist — manual, run on real hardware

The emulator will pass all of these. Only a physical phone tells the truth.

1. Start a 25-minute session, **swipe the app away** from recents. Notification survives;
   reopening shows the correct remaining time.
2. Start a session, **reboot the phone**, reopen after the session would have ended.
   Exactly one completed session appears, with the correct end time.
3. Start a session, enable **battery saver**, lock the phone for 20 minutes.
   Timer completes and the notification fires.
4. Start a session, **change the device timezone**, complete it. The session stays on the
   day it started.
5. Start a session at **23:50** with a 04:00 day start. It lands on the previous
   logical day.
6. **Deny the notification permission**, then start a session. The app explains what is
   lost and still runs.
7. Pause a session, background the app for 10 minutes, resume.
   Paused time is excluded from `actual_duration_s`.
8. Complete a session with **no task attached**. It appears in totals under "Unassigned".

Report the number and what happened; each maps to a specific piece of §3.

---

## 9. Build order

| Phase | Contents | Done when |
|---|---|---|
| 01 | Drift schema, events table, theme wired, navigation shell, empty Today screen | App runs on device |
| 02 | Timer: state machine, persistence, recovery, foreground service, interruptions, rating | Checklist §8 passes |
| 03 | Tasks: capture, projects, tags, priorities, recurrence, subtasks, three views, session↔task link | Usable daily |
| 04 | Stats v1: §4.1–4.8 and 4.13, with fixtures A–C green | Numbers trustworthy |
| 05 | Stats v2: §4.9–4.12, 4.14, 4.15, fixtures D–E green | The differentiated half |
| 06 | Habits (§10) | Three modules connected |
| 07 | Widgets, export, backup, app lock, onboarding, release | v1.0 |

Nothing in a later phase may require changing the `events` schema. If it does, the schema
was wrong and should be fixed in phase 01.

---

## 10. Habits

Phase 06. The schema reserved in §2.1 and §2.2 is now implemented. Habits are the
third module, and the statistics read all three together.

A habit answers a different question from a task. A task is a thing you finish; a
habit is a thing you keep doing, and the only interesting number is whether you are
still doing it. That makes the **streak** the feature, and everything below exists to
stop the streak from lying.

### 10.1 Data model

`habits` — read model, derived from events.

| column | type | notes |
|---|---|---|
| `id` | TEXT PK | UUIDv7 |
| `title` | TEXT | |
| `notes` | TEXT NULL | |
| `color_index` | INTEGER | into the theme's habit palette |
| `icon_name` | TEXT | a **name**, never a code point — see below |
| `schedule_rule` | TEXT | RRULE subset, the same grammar as §2.6 |
| `anchor_date` | TEXT | `YYYY-MM-DD`; intervals count from here |
| `target_count` | INTEGER | check-offs that complete a day; 1 = yes/no |
| `unit_label` | TEXT NULL | "pages", "glasses"; null for yes/no |
| `skip_allowance_per_month` | INTEGER | rest days a month excuses; default 2 |
| `status` | TEXT | `active` \| `archived` |
| `sort_order` | REAL | fractional, for drag-and-drop |
| `created_at` / `created_local_date` | INTEGER / TEXT | |
| `archived_at` | INTEGER NULL | |
| `updated_at` / `device_id` / `deleted_at` | | as every other table |

`icon_name` is stored as a name because Flutter's icon code points are not stable
across versions. Storing the code point means a backup restored after an SDK upgrade
comes back as a grid of random glyphs.

`anchor_date` is stored rather than derived from `created_at`, because "every 3 days"
counts from it. Deriving it would let a backfill silently reschedule a whole history.

`habits` carries no reminder columns of its own — see §11, which superseded the
original single `reminder_time_min` design with a table of possibly-several
time-of-day reminders per habit.

`habit_entries` — one row per habit per logical day **that has activity**.

| column | type | notes |
|---|---|---|
| `id` | TEXT PK | UUIDv7 |
| `habit_id` | TEXT | |
| `local_date` | TEXT | per §1.2, computed once at write time |
| `check_count` | INTEGER | compared against `target_count` |
| `skipped` | INTEGER | 0/1 — the user marked a rest day |
| `note` | TEXT NULL | the day's journal entry |
| `last_checked_at` | INTEGER NULL | UTC ms of the most recent check-off |
| `tz_offset_min` | INTEGER | offset at write time |
| `created_at` / `updated_at` / `device_id` / `deleted_at` | | |

UNIQUE `(habit_id, local_date)`. Index on `(local_date)`, and on `habits (status, deleted_at)`.

**Absence of a row is not a miss.** The streak engine decides that, by asking whether
the day was scheduled. Writing a row per scheduled day would mean writing rows for days
the user never opened the app, and would make a habit's history depend on when it was
last queried.

**Events (§2.2 extended).** `habit_created`, `habit_updated`, `habit_archived`,
`habit_deleted`, `habit_checked` `{count_after}`, `habit_unchecked` `{count_after}`,
`habit_skipped` `{skipped}`, `habit_freeze_used` `{month}`, `habit_note_set` `{note}`.
All carry `subject_type='habit'` and `subject_id`. The note text goes in the payload,
not only in the read model — §0 means the log must be able to rebuild the projection.

Backfilling a past day writes the true instant in `occurred_at` and the backfilled day
in `local_date`, which is the split `EventsRepository.logEvent` already documents.

### 10.2 Schedule

Same RRULE subset as §2.6: daily, every N days, specific weekdays, every N weeks on
weekdays, monthly on day-of-month, monthly on nth weekday. The parser is shared.

What differs is the question. Tasks ask *"when is the next one?"*; habits ask
*"was **this** day one of them?"*, for arbitrary past dates. `HabitSchedule.occursOn`
answers the second directly rather than replaying the series from the start.

- Dates before `anchor_date` are never scheduled. A habit cannot be missed on a day it
  did not exist, and counting those would show every new habit already broken.
- Weeks are counted Monday-to-Monday regardless of the user's week-start display
  setting — as in §2.6. Otherwise changing that setting silently reschedules every
  habit and resets streaks that were never broken.
- Day-of-month clamps into short months, as §2.6 does. A habit on the 31st fires on
  28 February; it does not vanish for a month and take the streak with it.
- Changing a habit's schedule does **not** move its anchor. Moving it would re-derive
  every past day under the new rule, and a user switching from daily to Mon/Wed/Fri
  would watch a streak they earned change value.

### 10.3 Streaks

A streak counts **scheduled days only**. A day the habit is not scheduled for is
neither a hit nor a miss — it is invisible. A Mon/Wed/Fri habit must not break on a
Tuesday, and that single rule is what most habit trackers get wrong.

Each scheduled day resolves to one outcome:

| outcome | when | effect on streak |
|---|---|---|
| `done` | `check_count >= target_count` | extends |
| `neutral` | a rest day inside the month's allowance | extends, like `done` — excluded from rates |
| `pending` | **today**, scheduled, not yet met | neither — the day is not over |
| `missed` | scheduled, not met, day is over | breaks |

**Today never breaks a streak.** If today is scheduled and untouched, the walk steps
past it to yesterday. A partial count today — 5 of 8 glasses at noon — is `pending`,
not a failure. Getting this wrong is the classic habit-app bug: you open the app over
breakfast, it says 0, you stop trusting the number, and then you stop opening the app.

A **past** day below target is a miss. 5 of 8 glasses yesterday did not meet the target.

**Rest days are bounded, and cost nothing while they last.** A `neutral` day counts
toward the streak exactly like a `done` day — using an allowed rest day does not lower
the number, the same way a Duolingo freeze does not. `skip_allowance_per_month` rest
days per calendar month are excused, ranked by date; any beyond that resolve `missed`
and behave like any other miss. Bounding is the point — an unlimited skip lets someone
hold a streak while doing nothing, which makes the number meaningless. Only skips on
scheduled days consume allowance. The UI must show what remains *before* the last one
is spent: *"2 of 2 rest days used this month — skipping again will reset your streak."*

**Rates are stricter than streaks, deliberately.** `neutral` days are excluded from
completion rate and the weekday profile (§10.5), even though they do not cost the
streak. A streak answers "is the chain unbroken"; a rate answers "how often did you
actually do it" — a protected day you did not do should not be counted as done there,
even though it is protected in the streak. The two numbers are allowed to diverge.

**Longest streak** is the best run of scheduled days ever met, where `neutral` counts
the same as `done`; `pending` and `future` are stepped over without adding or resetting;
`missed` resets the run.

### 10.4 Reminders

A habit can have several time-of-day reminders (§11.3) — see §11 for the shared
reminder machinery it uses. Each fires on scheduled days only — reminding someone
about a Mon/Wed/Fri habit on Sunday is how notifications get turned off — and never in
the past; reconcile on startup, exactly as tasks do.

### 10.5 Statistics

The governing rule from §4 carries over unchanged: **a rate with a zero denominator
returns null and renders as an em dash.** It never returns 0%.

- **Completion rate** = done ÷ (scheduled days − excused − pending) over the window.
  Null when nothing remains to divide by: a Mon/Wed/Fri habit asked about a weekend, a
  window before the habit existed, or a window whose only scheduled day was excused.
  Scheduled days with nothing recorded are **0%, not null** — those days were asked for
  and missed, and that is a real answer.
- **Day-of-week profile** — completion rate per weekday. A weekday the habit never runs
  on is null, not 0%. "Sunday 0%" on a Mon/Wed/Fri habit invents a failure.
- **Current streak / longest streak** — §10.3.
- **Total check-offs** — sum of `check_count`; counts check-offs, not days.

**On the Stats screen (§4), all of the above are also shown pooled across every
active habit at once** — `core/stats/habit_statistics.dart` — the habit counterpart
of the focus-session engine in `core/stats/statistics.dart`:

- **Pooled completion rate / day-of-week profile** — every eligible scheduled day from
  every active habit is pooled into one numerator and one denominator, restricted to
  the Stats screen's selected range (the same range picker the focus-session cards
  use). The same exclusions apply per day, not per habit, so one demanding daily habit
  cannot drown out several easier ones in the pooled number.
- **Streak leaderboard** — active habits ranked by current streak. Unlike the rate
  numbers above, a habit's current/longest streak is **never re-sliced by the selected
  range** — it is read straight from its own whole-history computation (§10.3),
  because "is the chain unbroken right now" has nothing to do with which stats tab
  happens to be open.
- **Habit activity heatmap** — the habit counterpart of §4.13, same trailing 365-day
  window and the same percentile-threshold method (`HeatmapThresholds`, reused as-is),
  but bucketing **distinct habits completed that day** rather than focused minutes —
  each habit contributes at most 1, so a count-based habit ("8 glasses of water")
  cannot make one day look busier than a day five separate habits were each done once.
  Because the per-day values are much smaller than focus minutes, the provisional
  fallback thresholds (used until 14 non-zero days of history accumulate) are scaled
  down to match (1 / 2 / 3 / 5 rather than 25 / 50 / 100 / 180).
- The habits section is gated on whether **any active habit exists at all**, not on
  whether the selected range has data — a brand-new habit with no history yet still
  gets a section, showing em dashes rather than vanishing.
- Deleting a habit (§10.1's `habit_deleted` event) removes it from every one of the
  numbers above immediately, the same as archiving does — both simply drop out of
  `HabitsRepository.loadActiveSnapshots()`, which is what the whole habits section is
  built from.

### 10.6 Test fixtures — required before habits are considered done

| # | fixture | asserts |
|---|---|---|
| A | Mon/Wed/Fri, perfect 3 weeks | 9 scheduled days, streak 9 — Tuesdays invisible |
| B | the same records read as a DAILY habit | streak 1 — the schedule drives it, not the data |
| C | today scheduled and untouched | streak is yesterday's value, not 0 |
| D | today at 5 of 8 | `pending`, streak unbroken |
| E | 3 skips in a month, allowance 2 | first two `neutral`, third `missed` |
| F | 31st-of-month habit | February clamps to the 28th; 12 occurrences a year |
| G | daily with two gaps | longest is the best run, not the most recent |
| H | Mon/Wed/Fri asked about a weekend | completion rate null, not 0% |
| I | daily, window with nothing recorded | completion rate 0%, **not** null |

Every expected value must be computed independently of the implementation before the
test is written. §7 applies here too: a test derived from the code confirms the bug.

The pooled Stats-screen numbers above have their own fixtures, kept separate because
they exercise a different engine: `test/habit_statistics_test.dart` (pure, mirrors A–I
above but for pooling and the heatmap) and `test/habit_analytics_repository_test.dart`
(two real habits checked off through the real repository, confirming the wiring from
`HabitSnapshot` into `HabitStatsInput` doesn't drop or double-count anything).

---

## 11. Reminders & digest

Added when the original single-reminder-per-item design (one `reminder_offset_min` on
`tasks`, one `reminder_time_min` on `habits`) proved too rigid: a user wants to say
*how many* times to be reminded, and at what offsets or times, not just one. `tasks`
and `habits` no longer carry any reminder columns at all — this section is now the only
source of truth for reminder configuration, for both modules.

### 11.1 Schema

`task_reminder_offsets` — one row per configured countdown reminder on a task:

| column | type | notes |
|---|---|---|
| `id` | TEXT PK | UUIDv7 |
| `task_id` | TEXT | |
| `offset_min` | INTEGER | minutes before `tasks.due_at`; 0 = at the due time |
| `notification_id` | INTEGER NULL | device-local, see §11.5 |
| `created_at` / `updated_at` | INTEGER | UTC ms |
| `device_id` | TEXT | |

`habit_reminder_times` — one row per configured time-of-day reminder on a habit:

| column | type | notes |
|---|---|---|
| `id` | TEXT PK | UUIDv7 |
| `habit_id` | TEXT | |
| `minutes_past_midnight` | INTEGER | 0–1439, local time |
| `notification_id` | INTEGER NULL | device-local, see §11.5 |
| `created_at` / `updated_at` | INTEGER | UTC ms |
| `device_id` | TEXT | |

`UNIQUE(task_id, offset_min)` and `UNIQUE(habit_id, minutes_past_midnight)` — a value
can only be configured once per item. Neither table carries a `deleted_at` tombstone,
unlike the rest of the schema: the event that writes these rows
(`task_reminder_offsets_set` / `habit_reminder_times_set`) always carries the item's
*entire* desired set, so a rebuild from `events` replays the latest such event per item
and reproduces the live rows exactly — a removed row's history is never needed.
Rows that fall out of the set are hard-deleted.

At most 5 reminders per task and per habit (`ReminderConfigRepository.
maxRemindersPerItem`) — past that, a picker stops being something a user chose and
starts being a settings bug.

### 11.2 Task countdown reminders

Apply only to a task with a specific due time (`due_is_all_day = 0`). An all-day task
has nothing to count down to — it is covered by the digest (§11.4) instead.

A brand-new timed task is seeded with the current global default offsets
(`settings.default_reminder_offsets_min`, a JSON list, default `[10]`) at creation —
every creation path gets this, not just the edit sheet, so quick capture and a
recurring series' next instance land the same way a manually created task does. The
default only matters at creation time: changing it later never rewrites an existing
task's own offsets. A caller that wants something different — including "none" —
writes over the seed afterward with `setTaskReminderOffsets`, which always replaces the
full set.

### 11.3 Habit time-of-day reminders

No global default, unlike tasks: a reminder time that makes sense for one habit rarely
makes sense for another. A new habit starts with none; the user adds what they want.

### 11.4 Daily digest

One notification summarizing "N due today · M overdue", covering all-day tasks (which
have no per-item reminder of their own). Settings:

- `digest_enabled` — bool, default off.
- `digest_times_min` — JSON list of minutes-past-midnight, up to 6, default `[540]`
  (09:00) the first time it's turned on.

Notification ids for the digest are a **fixed reserved band, 1–6** — the Nth
configured time is always id `1 + N`. This is below where the shared counter (§11.5)
starts (1000), so nothing about the digest needs to be persisted: cancel-and-reschedule
at those fixed ids is always safe.

The body reflects due-today/overdue counts **as of the reconcile that scheduled it**,
not as of the moment it actually fires — the same limitation the per-item reminders
already have (§11.2/§11.3 also compute their body at schedule time). Reconciling runs
often enough — startup, every edit, every app resume, the day-rollover watch — that
this stays close enough in practice. Nothing is scheduled if there is nothing due or
overdue: an empty digest is worse than no digest.

### 11.5 Notification id allocation

Every id (task offset, habit time, or digest) comes from the single counter described
in §2.4's original note: `settings.next_notification_id`, starting at 1000, allocated
once per row and never reused — not a hash of anything, since hashing a UUID into a
32-bit space collides often enough that an item would silently stop reminding with
nothing in the UI to show for it. A row keeps its allocated id across reconciles; the
OS notification is cancelled and rescheduled at the *same* id rather than a fresh one
each time.

### 11.6 Test fixtures

`test/reminders_feature_test.dart`: monotonic id allocation; a timed task schedules its
default offset; several offsets on one task schedule one notification each; an all-day
task gets no offsets; past due dates never schedule; a due-date change reschedules at
the same id; complete/uncomplete/archive/delete cancel and (where appropriate)
reschedule; the master switch cancels everything and restores only future ones; two
years of seeded data produce zero notifications in the past; the digest is off by
default, fires one notification per configured time when something is due or overdue,
and fires nothing when there isn't.

`test/habits_feature_test.dart` (Reminders group): scheduled only on scheduled days,
from the shared counter; never in the past, skips a day already complete; a reminder
before the day start fires on the next calendar date; `reconcileAll` schedules and
cancels correctly.
