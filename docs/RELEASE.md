# Cairn — everything left before release

Rewritten 14 September 2026, after the Settings round and the request for task
reminders, home screen widgets and a notification permission prompt.

`SPEC.md` is what the app must do. `POLISH.md` is everything around the
behaviour. **This file is the plan: what is left, in what order, and why.**

---

## Where it stands

Working and tested on a real device: the focus timer with a foreground service
that survives force-kill and reboot; tasks with projects, tags, priorities,
subtasks, recurrence, archive and delete; a Stats screen carrying seven of SPEC
§4's metrics, correct across DST and across a half-hour timezone offset; an
append-only event log with sync-ready ids; a Settings screen; 253 tests and a
clean analyzer.

Four rounds of work remain before the first APK, and one feature after it.

---

## Open bug, found while checking the Settings round

**The four new timer settings do nothing.**

`session_length_s`, `break_length_s`, `long_break_length_s` and
`sessions_before_long_break` all persist correctly, and the Settings screen
reads and writes them. But `TimerController` never reads any of the four
providers — it starts from `const TimerState()`, which still carries
`plannedDurationS = 1500` and `breakDurationS = 300` as constructor defaults,
and line 238 has a literal `const breakDurationS = 300;`.

So a user can set a 50-minute session, start the timer, and get 25 minutes.
Four dead controls, which is worse than four absent ones. Fixed first in round 2.

---

## Round 2 — timer settings, task reminders, notification permission

### 2a. Make the timer settings real

Wire the four providers into `TimerController`. The rule from last round still
stands: the value is read **when a session starts** and never mid-session, so
changing the setting while the timer runs must not alter the countdown.

### 2b. Task reminders

The requested feature. `flutter_local_notifications: ^22.3.1`.

Decisions taken, each one reversible if you disagree:

| Decision | Why |
|---|---|
| **Inexact alarms** (`AndroidScheduleMode.inexactAllowWhileIdle`) | Exact alarms need `SCHEDULE_EXACT_ALARM`, which Play scrutinises, or `USE_EXACT_ALARM`, which policy reserves for alarm-clock and calendar apps. A task reminder that lands within a few minutes is fine; an app rejected at review is not. |
| **On by default for dated tasks**, off for undated, with one master switch in Settings | A reminder you have to remember to enable is a reminder you will not enable. The master switch makes it one tap to stop all of it. |
| **All-day tasks remind at 09:00 local** on the due day | "Near the time" is meaningless without a time. Configurable. |
| **Default offset: 10 minutes before**, per-task override | Enough warning to act, not so much you forget again. |
| **Never fire for a past or completed task** | Without this, installing, importing a backup, or rebooting with a backlog produces a wall of notifications for things already overdue. This is the rule that decides whether reminders feel useful or hostile. |
| **A stable integer notification id stored on the task**, not a hash of the UUID | The plugin's ids are 32-bit ints; task ids are UUID strings. Hashing gives roughly a 1-in-4000 chance of a silent collision across a thousand tasks, and a collision means one task quietly loses its reminder forever. A column costs one migration. |

Reminders must be cancelled or rescheduled on: completion, un-completion, due
date change, archive, delete, and the creation of the next instance of a
recurring task. Plus a reconcile pass on app start that cancels orphans and
schedules anything missing — that is the safety net that makes the other six
forgivable.

Reboot survival needs `RECEIVE_BOOT_COMPLETED` and the plugin's
`ScheduledNotificationBootReceiver` in the manifest. Without it, every pending
reminder dies at the next restart and nobody finds out until they miss one.

### 2c. The notification permission

You asked for this on install. One adjustment, and you can overrule it.

You cannot ask on install — only on first launch. And Android 13+ gives a
limited number of attempts: after two dismissals the dialog never appears again
and the user has to find it in system settings. A permission prompt shown before
the app has explained anything gets reflexively denied, and then the timer
notification *and* every task reminder are dead permanently.

So: ask at the first moment it is actually needed — the first session start or
the first reminder being set, whichever happens first — with one sentence saying
why. Once onboarding exists (round 4), its final screen starts a session, so in
practice this still lands within the first minute of installing. Same intent,
without the version that can permanently lose the permission.

---

## Round 3 — export and import

POLISH §9.1. No backup exists today. If a tester uses Cairn for a month and
their phone dies, everything is gone and there is nothing you can do for them.

- One JSON file: events, tasks, sessions, projects, tags, settings, with a
  schema version and an export timestamp.
- Out through the share sheet, so they choose Drive, email, wherever.
- Import offers **Merge** or **Replace** and says plainly what each does. Merge
  is where the UUIDs earn their keep — without them it cannot tell a duplicate
  from a distinct row.
- Refuse an import from a newer schema version rather than corrupting the
  database.

No server. This is the whole backup guarantee and it works offline.

---

## Round 4 — onboarding, accessibility, error states

- **Onboarding**, POLISH §3: three screens, skippable. What it is in one
  sentence; ask for the daily focus goal, the one setting that personalises the
  ring, the streak and the heatmap; then actually start a session rather than
  saying "you're all set".
- **The four explanations**, POLISH §2 — three already landed in Settings; the
  focus-rating line goes inline where the rating is asked.
- **Accessibility**, POLISH §6: font scale to 200% on every screen; screen
  reader labels on every icon-only control; 48dp touch targets; semantics on the
  focus ring so it announces "15 of 25 minutes". Font scale has already clipped
  three labels during this build — this is a known failure mode, not a
  hypothetical.
- **Error states**, POLISH §7: notification permission denied; battery
  optimisation killing the foreground service on Xiaomi and Samsung; database
  open failure showing something other than a grey screen.
- **The Today screen backlog problem** you spotted: 135 overdue tasks push
  everything actually due today out of the five visible slots. Group overdue
  separately from due-today, or offer a triage action.

---

## Round 5 — sign, build, ship

1. **Create the release keystore.** Store the file and its passwords somewhere
   you will still have them in five years, and not only on this laptop.
2. `android/key.properties`, and add it to `.gitignore`. Never commit it.
3. Replace the debug signing config in `build.gradle.kts`.
4. `flutter build apk --release --target-platform android-arm64`.
5. Test the release build on a device — R8 and ProGuard break reflection-based
   code, and Drift is the usual casualty. A debug build passing proves nothing
   here.

### Before the APK leaves your machine — SPEC §8, items 4–8

Items 1–3 are done. **These five have never been reported.** The emulator passes
all of them; only a real phone tells the truth.

4. Start a session, **change the device timezone**, complete it. It must stay on
   the day it started. *(This is the case the whole `tz_offset_min` change
   exists for.)*
5. Start a session at **23:50** with a 04:00 day start. It must land on the
   previous logical day.
6. **Deny the notification permission**, then start a session. The app must
   explain what is lost and still run.
7. Pause, background the app for 10 minutes, resume. Paused time must be
   excluded from `actual_duration_s`.
8. Complete a session with **no task attached**. It must appear under
   "Unassigned".

---

## v1.1 — home screen widgets

Deliberately after the first release. Android widgets are native code —
RemoteViews and XML layouts, not Flutter — so each one is a separate
`AppWidgetProvider` with its own layout and update plumbing, bridged through
`home_widget`. Three of them is roughly three rounds, and the live-updating
timer widget is the hard one because widget updates are rate-limited and have to
be pushed from the foreground service.

Planned set:

1. **Today** — the next few tasks, tap to open.
2. **Focus** — remaining time with start/pause, pushed from the foreground
   service that already exists.
3. **Streak** — current streak and today's focus ring. The cheapest of the
   three and the one people keep on a home screen longest.

Adding these later breaks nothing, which is why they wait. Shipping them later
is also only painless if the signing key is right the first time.

---

## Decisions taken without asking

Recorded so you can overrule any of them:

- Widgets ship in 1.1, not v1 — **your call, made this round**.
- Direct APK to a handful of testers first. No Play Console, no listing, no
  privacy policy, no Data Safety form until data leaves the device.
- Inexact alarms for reminders.
- Reminders default on for dated tasks; master switch in Settings.
- Notification permission asked at first need, not at cold launch.
- Habits stay out of v1. The schema accommodates them; no UI ships. The Dart
  package is still called `habit_tracker` — internal only, nobody outside sees
  it.
- SPEC §4.9, §4.11, §4.12, §4.14 and §4.15 stay out of v1. The event log already
  holds everything they need, so they can be added later over old history with
  no migration — which was the whole point of §0.
- No sync, no accounts. Export covers the real need without a privacy policy, a
  Data Safety attestation and a web-accessible deletion route.

---

## What to tell testers

- It is early, and their data lives only on their phone. Once export exists,
  show them how and suggest they use it.
- **The day starts at 4am, not midnight.** Say this before they use it, not
  after they report it as a bug.
- Ask one specific question rather than "any feedback": *did you still open it
  after the first week, and if not, when did you stop?* Retention is the only
  thing worth knowing this early, and it is what people volunteer least.

---

## The one thing not to lose

Back up the keystore and its passwords somewhere you will still have them in
five years, and not only on this laptop. Everything else here can be redone.
That cannot — lose it and you cannot ship an update to Cairn ever again.
