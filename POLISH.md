# Cairn — Polish & Release Checklist

Work through this in order. Sections 0 and 1 change decisions the rest depends on,
so don't start at section 5 because it looks easier.

Companion to `SPEC.md`, which stays the source of truth for behaviour. This
document is about everything *around* the behaviour.

---

## 0. Two things that get more expensive every day

These are not polish. They are decisions that are cheap now and painful later.

### 0.1 Ids must become globally unique — decide before adding more data

Every table uses `integer().autoIncrement()`. That is correct for a single
device and fatal for sync: a phone and a desktop both generate id 5 for
different rows, and any merge silently mixes them.

Since the plan is backup now and sync later, fix it now — while the only data
in the world is your own test data.

**Change:** `events`, `tasks`, `focus_sessions`, `projects` and `tags` take a
`TEXT` primary key holding a UUIDv7. Not v4: v7 is time-ordered, so it still
sorts chronologically and keeps index locality, which is why it exists.

Add to every mutable row:

```
updated_at   INTEGER   UTC ms, set on every write
device_id    TEXT      a UUID generated once per install, stored in settings
deleted_at   INTEGER?  soft-delete tombstone, null when live
```

`deleted_at` matters more than it looks. Sync cannot distinguish "this row was
deleted on the other device" from "this row hasn't reached me yet" unless the
deletion is itself a record. Without tombstones, deleted rows resurrect.

This is a Drift schema migration: bump `schemaVersion`, write the `onUpgrade`
step, and generate ids for existing rows. Test the migration against a database
that has real data in it, not an empty one.

**If you decide sync is never happening, skip this entirely.** Do not do it
halfway.

### 0.2 Create the release keystore and back it up

`android/app/build.gradle.kts` still has:

```
// TODO: Add your own signing config for the release build.
signingConfig = signingConfigs.getByName("debug")
```

Play rejects debug-signed builds. More importantly, **the key you first publish
with can never be changed.** Lose it and you cannot ship another update to
Cairn, ever — you would have to publish a new listing and abandon every install
and review.

- Generate a release keystore.
- Store the keystore file and its passwords somewhere you will still have them
  in five years. Not only on this laptop.
- Put credentials in `android/key.properties`, and add that file to
  `.gitignore`. Never commit it.
- Consider opting into Play App Signing, which lets Google hold the signing key
  and gives you a recovery path if you lose the upload key.

---

## 1. Language pass — do this before writing any help text

A control that needs a tooltip usually needs a better label. Rename first, then
see what explanation is actually left.

| Current | Problem | Better |
|---|---|---|
| Internal / External | Jargon from the Pomodoro book | **My own thought** / **Someone else** |
| `on_schedule` | Means nothing to a reader | **Every Monday regardless** |
| `after_completion` | Same | **3 days after I finish it** |
| Abandoned | Sounds like failure | **Stopped** |
| Flow | Ambiguous — flow state? a flowchart? | **No timer** or **Open-ended** |
| Estimate (pomodoros) | Unit only you know | **How many sessions?** |

Recurrence modes should show a live example under each option using the user's
actual chosen day, not an abstract description.

Then audit every remaining string in the app. For each one ask: would someone
who has never read SPEC.md know what this means? Rewrite the ones that fail.

---

## 2. The four things that genuinely need explaining

Everything else should be self-evident after section 1. These four are real
ideas that cannot be renamed away.

1. **The day starts at 4am.** Someone finishing at 1am will see it counted
   toward yesterday and assume the app is broken. One line in Settings beside
   the setting itself, plus a one-time note the first time a session lands on
   the previous day.

2. **Stopped sessions don't count toward totals.** Otherwise a user who stops
   at 24 minutes sees their focus time unchanged and thinks nothing recorded.

3. **Today can't break your streak.** Without this, a user checking the app at
   9am sees yesterday's streak intact and wonders why it hasn't reset.

4. **What the focus rating is for.** One line at the point of asking: "Helps
   you see which kinds of work actually hold your attention."

Put 1–3 in Settings next to the relevant control. Put 4 inline. Do not build a
help centre.

---

## 3. Onboarding

The goal is not to explain Cairn. It is to get someone into one focused session
in under a minute, because that is the moment the app makes sense.

- Three screens maximum, skippable at every step.
- Screen 1: what it is, in one sentence. Not a feature list.
- Screen 2: ask for the **daily focus goal**. This is the only setting that
  personalises everything downstream — the ring, the streak, the heatmap.
- Screen 3: start a session. Not "you're all set" — actually start one.
- Ask for the notification permission **when the first session starts**, with a
  sentence saying why, never on launch. A permission dialog before the app has
  earned anything is the fastest way to a denial you can never re-ask for.
- Never gate anything behind an account (see section 9).

---

## 4. Settings screen

Does not properly exist yet. Group in this order — most-changed first.

**Focus**
- Daily goal (minutes)
- Default session length, break length, long break length, sessions before long break
- Auto-start breaks / auto-start next session
- Strict mode

**Day & week**
- Day starts at — with the explanation from §2.1
- Week starts on

**Appearance**
- Theme: system / light / dark
- (later) AMOLED black

**Notifications**
- Session complete, break complete
- Link out to system settings when permission is denied

**Data**
- Export everything (§8)
- Import
- (later) Back up to account (§9)
- Archived tasks — a second entry point alongside the Tasks menu

**About**
- Version and build number
- "from beetlebyte"
- Open-source licences — `showLicensePage()` is built into Flutter and is a
  legal requirement for the packages you ship

---

## 5. Empty states

Every list, chart and screen needs one, and first-run is different from
"you cleared everything."

- Today, nothing at all: "Nothing due today." Not an illustration, not a
  motivational quote.
- Today, first run ever: point at the one action that matters — start a session.
- Tasks, each of the three tabs, separately.
- Archived: "Nothing archived yet."
- Every statistic with no data: an em dash and one line saying what will make it
  appear. Never a zero, never an empty chart frame.
- Stats screen on first run: say how many days of data it needs before the
  patterns mean anything. Honest and it sets expectations.

---

## 6. Accessibility

Not optional, and the font-scale one will find real bugs — three labels have
already clipped during this build.

- **Font scale to 200%.** Every screen. This is the one that breaks things.
- **Screen reader labels** on every icon-only control: the play button on task
  rows, the theme toggle, the day arrows, the developer-log icon. Currently
  these announce as "button" and nothing else.
- **Touch targets** minimum 48×48dp. Check the day-nav arrows and the row
  checkboxes.
- **Contrast** on anything added since the theme was written. The palette was
  verified; individual widgets that override colours were not.
- **`prefers-reduced-motion`** — honour it on the ring animation and any
  transitions.
- **Semantics on the ring**: it should announce "15 of 25 minutes", not be
  invisible to a screen reader.

---

## 7. Errors and edge cases

Every one of these is a real state a user will hit.

- Notification permission denied — explain what's lost, offer a route to system
  settings, keep the timer working.
- Battery optimisation killing the foreground service — detect it, show a
  one-time prompt pointing at the OEM setting. Xiaomi and Samsung are the worst.
- Database open failure — do not crash to a grey screen. Show something that
  says what happened and offers export if possible.
- Clock moved backwards mid-session (§1.5 already handles the maths; make sure
  the UI doesn't show a negative).
- Session running when the app is force-killed — already tested, keep it tested.
- Very long task titles, project names, tag names.
- 1000+ tasks, 10,000+ events (see section 8).

---

## 8. Performance

The event log grows forever by design. That is correct, and it means query cost
has to be measured rather than assumed.

- **Seed a test database** with 10,000 events and 1,000 tasks. Everything below
  is measured against that, not against your 50 rows.
- Confirm the three `events` indexes from §2.1 are actually being used —
  `EXPLAIN QUERY PLAN` on the stats queries.
- **N+1 check**: the task list loads tags per task. With 200 tasks that is 201
  queries. Batch it.
- The heatmap reads a trailing 365 days on every rebuild. Cache the percentile
  thresholds — §4.13 already says recompute weekly, so make sure it does.
- Startup time to first frame. Lazy-load anything not needed for the Today
  screen.
- `flutter build apk --analyze-size` — see what is actually in the binary.

---

## 9. Export, import, and the account

Decisions already made: **backup now, sync later**, and **the account is always
optional**.

### 9.1 Export / import — build this first

This is the whole backup guarantee, and it works with no server at all.

- Export everything to one JSON file: events, tasks, sessions, projects, tags,
  settings. Include a schema version and an export timestamp.
- Share-sheet it out, so the user chooses Drive, email, wherever.
- Import offers **Merge** or **Replace**, and says plainly what each does.
  Merge is where the UUIDs from §0.1 earn their keep — without them, merge
  cannot tell a duplicate from a distinct row.
- Refuse an import from a newer schema version rather than corrupting the
  database. Say so clearly.

### 9.2 The account, when you get there

- The app works completely without one. No wall, no nag screen on launch.
- Offer it exactly where it is relevant: Settings → Data → "Back up your data",
  and once, non-modally, after the user has a streak worth protecting.
- Sign-in options: email link or Google. Skip passwords entirely — you do not
  want to be storing password hashes.
- On sign-in, upload the existing local database. Do not make the user choose
  between their local data and their account.
- Signing out keeps everything local. Deleting the account deletes the server
  copy only.

### 9.3 What accounts oblige you to do

The moment data leaves the device:

- A privacy policy, publicly hosted, linked from the Play listing and from
  Settings → About.
- The Play Data Safety form, filled in accurately. It is an attestation.
- A working account- and data-deletion route, and Play now requires a
  **web-accessible** deletion request URL, not only an in-app one.
- If any user might be in the EU or UK: a lawful basis, and export on request —
  which §9.1 already gives you.

---

## 10. Release

- Release keystore created and backed up (§0.2).
- `flutter build appbundle --release` — Play wants an AAB, not an APK.
- R8 / ProGuard enabled; test the release build on a device, not just debug.
  Drift and reflection-based code are the usual casualties.
- Play Console listing: title, short description, full description.
- Screenshots at the required sizes. Use real data, not empty states.
- Feature graphic, 1024×500 — the one place the beetlebyte mark actually shows.
- Content rating questionnaire.
- Target API level check — Play enforces a minimum that rises annually.
- Internal testing track first. Install from Play on a device that has never had
  a debug build, which catches signing and ProGuard problems nothing else will.

---

## Suggested order

1. §0 — ids and keystore. Everything else assumes these.
2. §1 — language. Cheap, and it shrinks §2.
3. §8 — performance, with the seeded database. Finding a problem here changes
   what you build in §3–5.
4. §4, §5, §3 — settings, empty states, onboarding, in that order. Onboarding
   last, because it should point at a finished app.
5. §6, §7 — accessibility and error states.
6. §9.1 — export and import.
7. §10 — release.
8. §9.2 — the account, after the app is genuinely good on its own.

**Statistics (SPEC §4.2, §4.4–4.8, §4.13) are still unbuilt.** They are the
reason to choose Cairn over any other timer. Polishing first is a legitimate
call — a finished small app beats a rough large one — but don't lose track of
the fact that the differentiator is still missing.
