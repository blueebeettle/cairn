# Contributing to Cairn

Thank you for your interest in contributing to **Cairn**! We welcome contributions that help improve performance, design, test coverage, and documentation.

## Code of Conduct

All contributors and maintainers are expected to adhere to our [Code of Conduct](CODE_OF_CONDUCT.md).

## Development Setup

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (`>= 3.24.0`)
- [Dart SDK](https://dart.dev/get-dart) (`>= 3.5.0`)
- Android Studio / VS Code with Dart & Flutter extensions

### Getting Started
1. **Fork & clone** the repository:
   ```bash
   git clone https://github.com/blueebeettle/cairn.git
   cd cairn
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Generate Drift database code**:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Verify analysis and tests**:
   ```bash
   flutter analyze
   flutter test
   ```

## Development Workflow

### 1. Code Generation
Whenever you touch Drift table definitions under `lib/data/database/tables/` or `app_database.dart`, regenerate the database code before committing:
```bash
dart run build_runner build --delete-conflicting-outputs
```

### 2. Time Semantics & Event Sourcing
Cairn is built around strict architectural rules:
- **Immutable Events:** User actions append to `events`. Never delete or update an existing event row.
- **Logical Day Rollover:** Day boundaries roll over at `04:00 AM` by default. Never use local wall-clock strings as the source of truth for instants — all timestamps are UTC milliseconds.
- **Honest Statistics:** Never return `0%` when a metric's denominator is zero; always return `null` (renders as em dash `—`).

### 3. Testing Standards
- All new features and bug fixes must include unit or widget tests.
- UI components must pass the 200% font scale accessibility audit:
  ```bash
  flutter test test/font_scale_200_audit_test.dart
  ```

### 4. Commits & Pull Requests
- Keep commits focused and descriptive.
- Ensure `flutter analyze` has zero issues before opening a PR.
- Ensure all automated tests pass (`flutter test`).
