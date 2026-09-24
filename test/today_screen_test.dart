import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/data/providers/database_provider.dart';
import 'package:habit_tracker/data/repositories/stats_repository.dart';
import 'package:habit_tracker/core/widgets/focus_ring.dart';
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
    ThemeData Function()? buildTheme,
    List<Override> extraOverrides = const [],
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
        ...extraOverrides,
      ],
      child: MaterialApp(
        theme: buildTheme == null ? AppTheme.light : buildTheme(),
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
      // The sessions list is the last section on the screen; scroll to it.
      await tester.scrollUntilVisible(
        find.text('No sessions yet today.'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text('No sessions yet today.', skipOffstage: false),
        findsOneWidget,
      );

      // Tap previous day arrow — the date row scrolled out of view above.
      await tester.scrollUntilVisible(
        find.byTooltip('Previous day'),
        -150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byTooltip('Previous day'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Empty state explicitly mentions which date is empty (never showing ISO format)
      await tester.scrollUntilVisible(
        find.textContaining('No sessions on '),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining('No sessions on ', skipOffstage: false),
        findsOneWidget,
      );

      // Tapping "Today" button returns to today
      await tester.tap(find.widgetWithText(TextButton, 'Today'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // The sessions list is the last section on the screen; scroll to it.
      await tester.scrollUntilVisible(
        find.text('No sessions yet today.'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text('No sessions yet today.', skipOffstage: false),
        findsOneWidget,
      );
    });
  });

  // The goal ring used to float bare on the page background between two
  // cards. These pin it inside the card system: the eyebrow, the shadowed
  // 22-radius surface, and one tap target over the whole thing.
  group('TodayScreen — Focus card', () {
    const stats = FocusStats(
      focusMinutesToday: 28,
      currentStreakDays: 2,
      longestStreakDays: 9,
      dailyGoalMinutes: 45,
    );

    /// The focus card: the only 22-radius filled Container on the screen that
    /// holds the ring. Matched on radius and fill rather than a shadow — the
    /// card system is flat.
    Finder focusCard() => find.ancestor(
          of: find.byType(FocusRing),
          matching: find.byWidgetPredicate((w) {
            if (w is! Container) return false;
            final decoration = w.decoration;
            if (decoration is! BoxDecoration) return false;
            return decoration.color != null &&
                decoration.borderRadius == BorderRadius.circular(22);
          }),
        );

    final themes = <String, ThemeData Function()>{
      'light': () => AppTheme.light,
      'dark': () => AppTheme.dark,
    };

    for (final entry in themes.entries) {
      final themeName = entry.key;
      final buildTheme = entry.value;

      testWidgets('($themeName) the ring sits in a filled 22-radius card',
          (tester) async {
        await tester.pumpWidget(
          createTestWidget(stats: stats, buildTheme: buildTheme),
        );
        await tester.pump();
        await tester.pump();

        expect(focusCard(), findsOneWidget);

        // Eyebrow, ring figure and caption all live inside it.
        expect(
          find.descendant(of: focusCard(), matching: find.text('FOCUS')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: focusCard(), matching: find.text('28m')),
          findsOneWidget,
        );
        expect(
          find.descendant(
              of: focusCard(), matching: find.text('Goal: 45 min')),
          findsOneWidget,
        );
        expect(
          find.descendant(
              of: focusCard(), matching: find.text('Ready to focus')),
          findsOneWidget,
        );
      });

      testWidgets('($themeName) the card fill follows the theme',
          (tester) async {
        await tester.pumpWidget(
          createTestWidget(stats: stats, buildTheme: buildTheme),
        );
        await tester.pump();
        await tester.pump();

        final decoration =
            tester.widget<Container>(focusCard()).decoration! as BoxDecoration;
        final colors =
            Theme.of(tester.element(find.byType(FocusRing))).colorScheme;
        expect(
          decoration.color,
          equals(colors.brightness == Brightness.dark
              ? colors.surfaceContainer
              : colors.surfaceContainerLowest),
        );
      });
    }

    testWidgets('tapping the card padding — not the ring — opens the Timer tab',
        (tester) async {
      late ProviderContainer container;
      await tester.pumpWidget(
        createTestWidget(
          stats: stats,
          extraOverrides: [navigationIndexProvider.overrideWith((ref) => 0)],
        ),
      );
      await tester.pump();
      await tester.pump();

      container = ProviderScope.containerOf(
        tester.element(find.byType(TodayScreen)),
      );
      expect(container.read(navigationIndexProvider), equals(0));

      // The eyebrow is inside the card but outside the ring's own hit area,
      // so this only passes because of the whole-card InkWell.
      await tester.tap(find.text('FOCUS'));
      await tester.pumpAndSettle();

      expect(container.read(navigationIndexProvider), equals(1));
    });

    testWidgets('tapping the ring still opens the Timer tab', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          stats: stats,
          extraOverrides: [navigationIndexProvider.overrideWith((ref) => 0)],
        ),
      );
      await tester.pump();
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(TodayScreen)),
      );
      await tester.tap(find.text('28m'));
      await tester.pumpAndSettle();

      expect(container.read(navigationIndexProvider), equals(1));
    });

    testWidgets('renders at zero minutes with an empty ring', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          stats: const FocusStats(
            focusMinutesToday: 0,
            currentStreakDays: 0,
            longestStreakDays: 0,
            dailyGoalMinutes: 45,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(focusCard(), findsOneWidget);
      expect(
        find.descendant(of: focusCard(), matching: find.text('0m')),
        findsOneWidget,
      );
      expect(tester.widget<FocusRing>(find.byType(FocusRing)).progress,
          equals(0.0));
    });

    testWidgets('renders over goal with a full ring, not past it',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          stats: const FocusStats(
            focusMinutesToday: 90,
            currentStreakDays: 1,
            longestStreakDays: 1,
            dailyGoalMinutes: 45,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(focusCard(), findsOneWidget);
      expect(tester.widget<FocusRing>(find.byType(FocusRing)).progress,
          equals(1.0));
    });
  });
}
