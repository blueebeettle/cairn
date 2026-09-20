import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/data/providers/database_provider.dart';
import 'package:habit_tracker/data/repositories/settings_repository.dart';
import 'package:habit_tracker/features/backup/presentation/backup_restore_screen.dart';
import 'package:habit_tracker/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('BackupRestoreScreen Widget Tests', () {
    late AppDatabase db;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    Widget buildTestApp(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      return ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          home: const BackupRestoreScreen(),
        ),
      );
    }

    testWidgets('Renders recommended card and alternative options without overflow', (tester) async {
      await tester.pumpWidget(buildTestApp(tester));
      await tester.pumpAndSettle();

      expect(find.text('Backup'), findsOneWidget);
      expect(find.text('Only you can open your backups'), findsOneWidget);

      // Verify Recommended Card: Google Drive
      expect(find.text('Back up to Google Drive'), findsOneWidget);
      expect(find.text('Connect Google Drive'), findsOneWidget);

      // Verify Alternatives Card
      expect(find.text('Other ways to back up'), findsOneWidget);
      expect(find.text('Save a file to this phone'), findsOneWidget);
      expect(find.text('Save a backup file'), findsOneWidget);
      expect(find.text('Restore from backup file'), findsOneWidget);
      expect(find.text('Use a Cairn account'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Tapping Save a backup file opens dialog with no-recovery warning and enforces 8-char min', (tester) async {
      await tester.pumpWidget(buildTestApp(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save a backup file'));
      await tester.pumpAndSettle();

      // Verify A.1 No-recovery warning
      expect(find.text('There is no way to recover this password.'), findsOneWidget);
      expect(
        find.textContaining('Nobody — not even us — can read it or reset the password'),
        findsOneWidget,
      );

      // Verify A.2 8-char min password labels
      expect(find.text('Set Backup Password'), findsOneWidget);
      expect(find.text('Backup password'), findsOneWidget);
      expect(find.text('Confirm backup password'), findsOneWidget);
      expect(find.text('Encrypt & Export'), findsOneWidget);

      // Attempt with 4 characters - should show error
      await tester.enterText(find.widgetWithText(TextField, 'Backup password'), '1234');
      await tester.enterText(find.widgetWithText(TextField, 'Confirm backup password'), '1234');
      await tester.tap(find.text('Encrypt & Export'));
      await tester.pumpAndSettle();

      expect(find.text('Password must be at least 8 characters.'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Set Backup Password'), findsNothing);
    });

    testWidgets('Tapping Connect Google Drive opens connect dialog', (tester) async {
      await tester.pumpWidget(buildTestApp(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Connect Google Drive'));
      await tester.pumpAndSettle();

      expect(find.text('Connect Google Drive'), findsNWidgets(2)); // Card title + Dialog title
      expect(find.text('Sign In with Google Account'), findsOneWidget);
      expect(find.text('Google Account Email'), findsOneWidget);
      expect(find.text('Connect'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('Displays Cairn account sign in dialog with toggle and Google Sign-In', (tester) async {
      final settingsRepo = SettingsRepository(db: db);
      await settingsRepo.setString('supabase_url', 'https://xyzproject.supabase.co');
      await settingsRepo.setString('supabase_anon_key', 'public-anon-key-123');

      await tester.pumpWidget(buildTestApp(tester));
      await tester.pumpAndSettle();

      expect(find.text('Sign In or Register'), findsOneWidget);

      await tester.tap(find.text('Sign In or Register'));
      await tester.pumpAndSettle();

      expect(find.text('Sign In to Cairn Account'), findsOneWidget);
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);

      // Toggle to Sign Up
      await tester.tap(find.text("Don't have an account? Sign Up"));
      await tester.pumpAndSettle();

      expect(find.text('Create Cairn Account'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
  });
}
