<p align="center">
  <img src="assets/icon/cairn_icon.png" alt="Cairn Icon" width="140" />
</p>

<h1 align="center">Cairn</h1>

<p align="center">
  <strong>A calm, local-first focus timer, task manager, and habit tracker built on event-sourcing and rock-solid time semantics.</strong>
</p>

<p align="center">
  <a href="https://github.com/blueebeettle/cairn/actions/workflows/ci.yml"><img src="https://github.com/blueebeettle/cairn/actions/workflows/ci.yml/badge.svg" alt="CI" /></a>
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20Desktop-4CAF50" alt="Platform" />
  <img src="https://img.shields.io/badge/Database-Drift%20(SQLite)-003B57" alt="Database" />
  <img src="https://img.shields.io/badge/Tests-408%20passed-success" alt="Tests" />
  <img src="https://img.shields.io/badge/Architecture-Event--Sourced-8B3FAE" alt="Architecture" />
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-blue.svg" alt="License" /></a>
</p>

---

## 🏔️ Overview

A **cairn** is a man-made pile of stones raised as a trail marker or memorial — steady, deliberate, and built one stone at a time.

Most productivity tools suffer from brittle data models, midnight streak resets that punish night owls, confusing reminders, and dishonest statistics that show 0% when nothing was even scheduled.

**Cairn** solves these problems with:
- **Event-Sourced Architecture:** Every user action is an append-only immutable event. History is preserved forever, analytics are mathematically honest, and state can be perfectly reconstructed.
- **Logical Day Rollover (04:00 AM default):** Streaks never reset at midnight. Work done at 1:30 AM counts towards the day you actually experienced.
- **Local-First & Private:** Everything runs locally on device with zero cloud dependency required. Optional backups are end-to-end encrypted with **AES-256-GCM**.

---

## ✨ Features

### ⏱️ 1. Focus Timer & Sessions
- **Interval Flexibility:** Quick presets (15, 25, 45, 60 min) or custom focus/break picker (1–120 minutes).
- **Foreground Service:** Persistent notification with real-time countdown, pause/resume, and complete controls right from the lock screen.
- **Interruption Tracking:** Log internal and external interruptions with honest impact analytics.
- **Session Ratings:** Rate focus depth and associate sessions with specific projects or tasks.
- **Crash Recovery:** Deterministic timer state machine recovery persists focus sessions across app restarts.

### ✅ 2. Tasks & Natural Quick Capture
- **Rapid Keyboard Entry:** Powerful syntax parser without requiring awkward quotes:
  - `!p1` to `!p4` — Priority levels
  - `#project` — Project tag assignment
  - `~2p` or `2p` — Estimated Pomodoros (focus sessions)
  - `fri 5pm`, `tomorrow 10am`, `oct 4`, `noon`, `midnight` — Natural language due dates and times
- **Single-Level Subtasks:** Structured decomposition without infinite nesting sprawl.
- **Recurring Series (RRULE):**
  - **On schedule:** Automatically aligns to fixed schedule dates.
  - **After completion:** Spawns next instance relative to when you actually finish.
- **Tombstoned Deletion:** Soft-deletion with an immediate undo window, archive view, and permanent deletion option.

### 🌿 3. Resilient Habit Tracking
- **Rich Scheduling Rules:**
  - Every day
  - Certain weekdays (e.g. Mon, Wed, Fri)
  - Interval (Every N days)
  - Monthly (On the Nth day)
- **Target Counter Habits:** Track habits requiring multiple daily check-offs (e.g., "8 glasses of water").
- **Streak Shield & Rest Days:** Configure monthly rest day allowances (1–5 days) without breaking your active streak.
- **Interactive Calendar Heatmap:** Year-long grid of daily completions, rest days, and missed dates with reflective notes.
- **Flexible View Modes:** Switch between grouped, regular, and compact grid views.

### 📊 4. Honest Statistics & Analytics
- **Card 1 — Summary Metrics:** Total focus minutes, completed sessions, and active days.
- **Card 2 — Peak Productivity Window:** Identifies your most productive hours of the day (gated until 10 sessions are logged).
- **Card 3 & 9 — Activity Heatmaps:** GitHub-style 365-day contribution grids with quantile-based color intensity ramps:
  - *Focus Session Heatmap:* Total focused minutes per day.
  - *Habit Activity Heatmap:* Distinct habits checked off per day.
- **Card 8 — Pooled Habits Leaderboard:** Overall completion rate, total check-offs, and top current streaks across all active habits.
- **Strict "Honest Statistics" Rule:** Rates with zero denominator render as an em dash (`—`), never misleading `0%`.

### 🔔 5. Multi-Reminder Engine & Daily Digest
- **Multiple Reminders Per Item:**
  - Up to 5 countdown offsets per timed task (e.g. at due time, 10 min before, 1 hour before).
  - Up to 5 time-of-day reminders per habit, firing only on scheduled days.
- **Daily Digest:** Configurable morning/evening digest notifications summarizing tasks due today and overdue items.
- **Persistent Notification IDs:** Device-local counter allocation prevents duplicate notification storms or OS ID collisions.

### 📱 6. Android Home Screen Widgets
- **Habits Widget:** Glanceable checklist with interactive check-off and circular progress ring.
- **Today at a Glance Widget:** Combined dashboard showing focus time, overdue/due tasks, and pending habits.
- **Tasks Widget:** Scrollable list of today's tasks with quick completion.
- **Timer Widget:** Quick-launch focus sessions directly from your home screen.
- **Appearance Customization:** Toggle between solid dark ground and translucent glassmorphism styles.

### 🔐 7. Local-First, Encrypted Backups & Data Portability
- **Encrypted Cloud Backups:** Optional end-to-end encrypted backup to Supabase Storage.
- **Client-Side Cryptography:** Encrypted with **AES-256-GCM** using PBKDF2 key derivation (100,000 iterations), unique salt, and initialization vectors.
- **Zero-Knowledge:** Passphrase is never transmitted or stored remotely.
- **CSV Data Export:** One-tap export of tasks, habits, and focus history for complete data ownership.

### 💡 8. Tactile Feedback & In-App Guides
- **Haptic Feedback:** Tactile confirmation for habit check-offs, task completions, and timer events.
- **Interactive Concept Guides:** Built-in explanation sheets detailing Cairn's core philosophies (Event Sourcing, Logical Day, Honest Stats, and Streaks).

---

## 🎨 Design & Palette

Cairn follows a warm, earthy, pebble-and-mineral palette with high contrast ratios designed to reduce eye strain:

<p align="center">
  <img src="brand/themes/cairn-dark-1024.png" width="30%" alt="Cairn Dark Theme" />
  &nbsp;&nbsp;
  <img src="brand/themes/cairn-amoled-1024.png" width="30%" alt="Cairn AMOLED Theme" />
  &nbsp;&nbsp;
  <img src="brand/themes/cairn-deep-1024.png" width="30%" alt="Cairn Deep Theme" />
</p>

| Token | Hex | Role | Contrast Ratio |
|---|---|---|---|
| **Brand Purple** | `#590D86` | Primary brand accent & ground | `10.5:1` |
| **Dark Ground** | `#17111C` | Dark theme surface background | `16.9:1` |
| **AMOLED Black** | `#000000` | True black for OLED power efficiency | `19.1:1` |
| **Cream** | `#FAF3F0` | Primary text and stone surfaces | `10.5:1` |
| **Lavender** | `#BA7DD6` | Top stone cap accent & highlights | `3.8:1` |

---

## ⌨️ Quick Capture Syntax

From the quick-capture modal (`+`), you can type naturally without needing quotation marks:

```text
Review Q3 roadmap !p1 #work ~3p tomorrow 3pm
Read 25 pages of Dune !p3 ~1p fri 9pm
File tax return !p2 oct 15
Buy groceries #errands
```

| Token | Meaning | Example |
|---|---|---|
| `!p1` – `!p4` | Priority level (p1 urgent to p4 low) | `!p1`, `!P2` |
| `#tag` | Project / category tag | `#work`, `#personal` |
| `~Np` or `Np` | Estimated pomodoros (focus sessions) | `~2p`, `3p` |
| `Date / Time` | Natural language due date and time | `today`, `tomorrow 3pm`, `fri 9pm`, `oct 15`, `noon` |

---

## 🏗️ Architecture

```
lib/
├── app.dart             # Root MaterialApp with theme wiring & routes
├── main.dart            # Initialization, service locators & error handling
├── core/
│   ├── constants/       # Event types, recurrence enums, notification bands
│   ├── habits/          # Pure streak calculation engine & scheduling
│   ├── notifications/   # Notification channels, permission helpers & IDs
│   ├── recurrence/      # Pure RRULE parsing & next instance calculators
│   ├── stats/           # Database-free stats computation (focus & habits)
│   ├── time/            # TimeService, logical day offset & timezone logic
│   └── widgets/         # Feature guide cards & sheets, shared UI primitives
├── data/
│   ├── database/        # Drift SQLite database, schema tables & migrations
│   ├── providers/       # Riverpod dependency injection & streams
│   └── repositories/    # Event-sourced repositories (Tasks, Habits, Reminders, Settings)
├── features/
│   ├── backup/          # Supabase encrypted backup & CSV export services
│   ├── developer/       # Dev seeds, database inspect & diagnostic tooling
│   ├── habits/          # Habit tracking, streak badges, calendar heatmaps
│   ├── navigation/      # Navigation shell & bottom navigation bar
│   ├── reminders/       # Notification service & daily digest reconciliation
│   ├── settings/        # Theme switcher, logical day rollover, reminder prefs, haptics
│   ├── stats/           # 9-card analytics dashboard & heatmaps
│   ├── tasks/           # Task list, NLP quick capture & detail sheet
│   ├── timer/           # Foreground focus timer service, recovery & controls
│   ├── today/           # Today screen dashboard (tasks, habits, focus summary)
│   └── widgets/         # Android home screen widget sync & update dispatch
└── theme/               # Cairn color tokens, typography & dark/AMOLED/deep palettes
```

### Event-Sourcing Guarantee
```
User Action ──▶ Write to `events` (Append-Only) ──▶ Project to Read Tables (`tasks`, `habits`)
```
No row in `events` is ever updated or deleted. Replays reconstruct state deterministically.

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (`>= 3.24.0`)
- Android Studio / VS Code with Flutter extension
- An Android device or emulator (API 26+)

### 1. Clone the repository
```bash
git clone https://github.com/blueebeettle/cairn.git
cd cairn
```

### 2. Install dependencies
```bash
flutter pub get
```

### 3. Generate Database Models (Drift)
```bash
dart run build_runner build --delete-conflicting-outputs
```

### 4. Run Static Analysis & Tests
```bash
flutter analyze
flutter test
```

### 5. Launch the Application
```bash
# Run on connected Android device or desktop
flutter run
```

---

## 🧪 Testing

Cairn maintains a comprehensive test suite of **408 tests** covering:
- **Unit tests:** Timezone shifts, DST transitions, logical day boundaries, and recurrence algorithms.
- **Repository integration tests:** Drift in-memory transactions, event replay, and monotonic notification ID counters.
- **Widget & Accessibility tests:** 200% font scale layout validation without overflow across all screens.
- **Home Screen Widgets & Timer Recovery:** AppWidget data synchronization, ring rendering, background mode toggles, and state machine crash recovery.

Run specific test modules:
```bash
# Reminders and notification tests
flutter test test/reminders_feature_test.dart

# Habit engine & pooled stats tests
flutter test test/habit_statistics_test.dart
flutter test test/habits_feature_test.dart

# 200% accessibility font scale audit
flutter test test/font_scale_200_audit_test.dart

# Home screen widgets and timer recovery
flutter test test/home_screen_widget_service_test.dart
flutter test test/timer_recovery_test.dart
```

---

## 🏛️ Architecture & Standards

Cairn is engineered with strict domain boundaries and architectural guarantees:

- **Event-Sourced Ledger**: User actions append immutable entries to the `events` table; projections are rebuilt deterministically.
- **Strict Time Semantics**: Logical day rollover occurs at `04:00 AM` by default. Timestamps use UTC epoch milliseconds with explicit timezone offsets.
- **Honest Statistics**: Metrics never report `0%` when the denominator is zero, distinguishing true absence of data from positive zero.
- **Accessibility**: All screens and dialogs are verified to scale cleanly at 200% text scale with zero layout overflow.

---

## 🤝 Contributing & Community

Contributions are welcome! Please check our community guidelines before getting started:
- [**Contributing Guide**](CONTRIBUTING.md) — Development setup, code generation, and pull request guidelines.
- [**Code of Conduct**](CODE_OF_CONDUCT.md) — Community standards and pledge.
- [**Security Policy**](SECURITY.md) — Vulnerability reporting and encryption disclosure process.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).

