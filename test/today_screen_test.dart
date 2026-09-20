import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/data/providers/database_provider.dart';
import 'package:habit_tracker/data/repositories/stats_repository.dart';
import 'package:habit_tracker/features/today/presentation/today_screen.dart';
import 'package:habit_tracker/theme/app_theme.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Widget createTestWidget({
    FocusStats? stats,
    List<Event>? events,
    int? dailyGoal,
    String? selectedDate,
  }) {
    return ProviderScope(
      overrides: [
        todayEventsStreamProvider.overrideWith(
          (ref) => Stream<List<Event>>.value(events ?? const []),
        ),
        eventsForDateStreamProvider.overrideWith(
          (ref, date) => Stream<List<Event>>.value(events ?? const []),
        ),
        sessionsForDateStreamProvider.overrideWith(
          (ref, date) => Stream<List<FocusSession>>.value(const []),
        ),
        if (stats != null)
          focusStatsStreamProvider.overrideWith(
            (ref) => Stream<FocusStats>.value(stats),
          ),
        if (dailyGoal != null)
          dailyGoalMinutesProvider.overrideWith(
            (ref) => DailyGoalMinutesNotifier(
              ref.watch(settingsRepositoryProvider),
              dailyGoal,
            ),
          ),
        if (selectedDate != null)
          selectedDateProvider.overrideWith((ref) => selectedDate),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const TodayScreen(),
      ),
    );
  }

  group('TodayScreen — Focus Stats Wiring', () {
    testWidgets('zero counts render as 0m and 0 days, never as em dashes',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          stats: const FocusStats(
            focusMinutesToday: 0,
            currentStreakDays: 0,
            longestStreakDays: 0,
            dailyGoalMinutes: 25,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // FOCUS TIME figure: '0m', not '—'
      expect(find.text('0m'), findsOneWidget);
      // STREAK figure: '0 days', not '—'
      expect(find.text('0 days'), findsOneWidget);
      // Daily goal
      expect(find.text('Goal: 25 min'), findsOneWidget);

      // Verify no em dash used for counts
      expect(find.text('—'), findsNothing);
    });

    testWidgets('renders non-zero focus time (1h 20m) and streak (3 days)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          stats: const FocusStats(
            focusMinutesToday: 80,
            currentStreakDays: 3,
            longestStreakDays: 5,
            dailyGoalMinutes: 25,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('1h 20m'), findsOneWidget);
      expect(find.text('3 days'), findsOneWidget);
      expect(find.text('Goal: 25 min'), findsOneWidget);
    });

    testWidgets('displays daily goal from settings rather than hardcoded 25',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          stats: const FocusStats(
            focusMinutesToday: 45,
            currentStreakDays: 1,
            longestStreakDays: 1,
            dailyGoalMinutes: 50,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('45m'), findsOneWidget);
      expect(find.text('1 day'), findsOneWidget);
      expect(find.text('Goal: 50 min'), findsOneWidget);
    });
  });

  group('TodayScreen — Day Boundary & Navigation', () {
    testWidgets('shows previous/next day arrows, date, and Today button',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump();

      expect(find.byTooltip('Previous day'), findsOneWidget);
      expect(find.byTooltip('Next day'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Today'), findsOneWidget);
    });

    testWidgets(
        'navigating to previous day shows previous date and date-specific empty state',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump();

      // Initial state is today
      expect(
        find.text('No sessions yet today.', skipOffstage: false),
        findsOneWidget,
      );

      // Tap previous day arrow
      await tester.tap(find.byTooltip('Previous day'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Empty state explicitly mentions which date is empty (never showing ISO format)
      expect(
        find.textContaining('No sessions on ', skipOffstage: false),
        findsOneWidget,
      );

      // Tapping "Today" button returns to today
      await tester.tap(find.widgetWithText(TextButton, 'Today'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.text('No sessions yet today.', skipOffstage: false),
        findsOneWidget,
      );
    });
  });
}
