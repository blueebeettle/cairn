import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/widgets/cairn_card.dart';
import 'package:habit_tracker/core/widgets/feature_info.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/data/providers/database_provider.dart';
import 'package:habit_tracker/features/settings/presentation/settings_screen.dart';
import 'package:habit_tracker/theme/app_theme.dart';

void main() {
  const testInfo = FeatureInfo(
    id: 'test_feature',
    title: 'Test Feature Guide',
    summary: 'A short summary explaining the feature at a glance on the inline card.',
    sections: [
      FeatureInfoSection(
        heading: 'How it works',
        body: 'Detailed explanation of the mechanics and philosophy.',
      ),
      FeatureInfoSection(
        heading: 'Best practices',
        body: 'Tips on using the feature daily without burning out.',
      ),
    ],
  );

  group('Settings and Info pages shared card system (390x844 light & dark)', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    for (final themeMode in ['light', 'dark']) {
      final isDark = themeMode == 'dark';

      testWidgets('SettingsScreen renders all 7 sections at 390x844 ($themeMode) with no overflow',
          (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
            ],
            child: MaterialApp(
              theme: isDark ? AppTheme.dark : AppTheme.light,
              home: const SettingsScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Focus
        expect(find.text('FOCUS'), findsOneWidget);

        final scrollable = find.byType(Scrollable).first;

        // 2. Reminders
        await tester.scrollUntilVisible(find.text('REMINDERS'), 200, scrollable: scrollable);
        expect(find.text('REMINDERS'), findsOneWidget);

        // 3. Day & week
        await tester.scrollUntilVisible(find.text('DAY & WEEK'), 200, scrollable: scrollable);
        expect(find.text('DAY & WEEK'), findsOneWidget);

        // 4. Appearance
        await tester.scrollUntilVisible(find.text('APPEARANCE'), 200, scrollable: scrollable);
        expect(find.text('APPEARANCE'), findsOneWidget);

        // 5. Notifications
        await tester.scrollUntilVisible(find.text('NOTIFICATIONS'), 200, scrollable: scrollable);
        expect(find.text('NOTIFICATIONS'), findsOneWidget);

        // 6. Data
        await tester.scrollUntilVisible(find.text('DATA'), 200, scrollable: scrollable);
        expect(find.text('DATA'), findsOneWidget);

        // 7. About
        await tester.scrollUntilVisible(find.text('ABOUT'), 200, scrollable: scrollable);
        expect(find.text('ABOUT'), findsOneWidget);
        expect(find.textContaining('from beetlebyte'), findsOneWidget);

        // Confirm CairnCards are used
        expect(find.byType(CairnCard), findsWidgets);

        // Verify no overflow exception
        expect(tester.takeException(), isNull);
      });

      testWidgets('FeatureInfo surfaces render cleanly at 390x844 ($themeMode) with CairnCard & section labels',
          (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
            ],
            child: MaterialApp(
              theme: isDark ? AppTheme.dark : AppTheme.light,
              home: const Scaffold(
                body: FeatureInfoCard(info: testInfo),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // FeatureInfoCard is wrapped in CairnCard
        expect(find.byType(CairnCard), findsOneWidget);
        expect(find.text(testInfo.summary), findsOneWidget);

        // Tap card to open showFeatureInfoSheet
        await tester.tap(find.byType(CairnCard));
        await tester.pumpAndSettle();

        // Sheet is open
        expect(find.text('Test Feature Guide'), findsOneWidget);
        // Verify section headings are rendered using CardChrome.sectionLabel (uppercase)
        expect(find.text('HOW IT WORKS'), findsOneWidget);
        expect(find.text('BEST PRACTICES'), findsOneWidget);
        expect(find.text('Got it'), findsOneWidget);

        // Dismiss sheet via 'Got it' button
        await tester.tap(find.text('Got it'));
        await tester.pumpAndSettle();

        // Sheet dismissed, FeatureInfoCard still visible
        expect(find.byType(CairnCard), findsOneWidget);

        // Dismiss card via close icon button
        await tester.tap(find.byTooltip('Dismiss'));
        await tester.pumpAndSettle();

        // Card is now dismissed and gone
        expect(find.byType(CairnCard), findsNothing);

        // No overflow exception
        expect(tester.takeException(), isNull);
      });
    }
  });
}
