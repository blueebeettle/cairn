// The Habits screen's "This week" card.
//
// Driven entirely through a `weeklyRecapBundleProvider` override rather than a
// real database — the arithmetic behind `WeeklyRecap` is covered without
// widgets in `habit_statistics_test.dart`, so what is under test here is the
// rendering: the date range, the comparison line's three shapes, the bar
// colours (today, a scored day, an empty day, a day still to come) and the
// three tiles. Both themes are pumped for each case, following
// `milestone_celebration_test.dart`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:habit_tracker/core/stats/habit_statistics.dart';
import 'package:habit_tracker/core/time/time_service.dart';
import 'package:habit_tracker/data/providers/habit_analytics_providers.dart';
import 'package:habit_tracker/features/habits/presentation/widgets/weekly_recap_card.dart';
import 'package:habit_tracker/theme/app_theme.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  const weekStart = '2026-09-14'; // Monday
  const weekEnd = '2026-09-20';
  const today = '2026-09-16'; // Wednesday

  WeeklyRecapDay day(int index, {double? rate}) {
    final date = TimeService.addDays(weekStart, index);
    return WeeklyRecapDay(
      date: date,
      rate: rate,
      isToday: date == today,
      isFuture: date.compareTo(today) > 0,
    );
  }

  WeeklyRecap recap({
    double? completionRate = 0.87,
    double? priorCompletionRate,
    List<WeeklyRecapDay>? days,
    int bestStreak = 24,
    int habitsKept = 6,
    int freezesUsed = 1,
    int activeHabitCount = 3,
    String start = weekStart,
    String end = weekEnd,
  }) =>
      WeeklyRecap(
        weekStart: start,
        weekEnd: end,
        completionRate: completionRate,
        priorCompletionRate: priorCompletionRate,
        days: days ??
            [
              day(0, rate: 0.8),
              day(1, rate: 1.0),
              day(2, rate: 0.4), // today
              day(3),
              day(4),
              day(5),
              day(6),
            ],
        bestStreak: bestStreak,
        habitsKept: habitsKept,
        freezesUsed: freezesUsed,
        activeHabitCount: activeHabitCount,
      );

  Widget harness(ThemeData Function() buildTheme, WeeklyRecap value) {
    return ProviderScope(
      key: UniqueKey(),
      overrides: [
        weeklyRecapBundleProvider
            .overrideWith((ref) => Stream<WeeklyRecap>.value(value)),
      ],
      child: MaterialApp(
        theme: buildTheme(),
        home: const Scaffold(
          body: SingleChildScrollView(child: WeeklyRecapCard()),
        ),
      ),
    );
  }

  /// Every bar in the strip, in Monday-first order.
  List<Container> bars(WidgetTester tester) => tester
      .widgetList<Container>(find.byType(Container))
      .where((c) => c.constraints?.maxWidth == 20)
      .toList();

  Color barColor(Container bar) => (bar.decoration! as BoxDecoration).color!;

  // Lazy thunks: `AppTheme` reaches for Google Fonts' asset manifest, which
  // needs the binding `testWidgets` installs.
  final themes = <String, ThemeData Function()>{
    'light': () => AppTheme.light,
    'dark': () => AppTheme.dark,
  };

  for (final entry in themes.entries) {
    final themeName = entry.key;
    final buildTheme = entry.value;

    group('WeeklyRecapCard ($themeName)', () {
      testWidgets('renders the heading, range and three tiles', (tester) async {
        await tester.pumpWidget(harness(buildTheme, recap()));
        await tester.pumpAndSettle();

        // Rendered as the app-wide uppercase card eyebrow.
        expect(find.text('THIS WEEK'), findsOneWidget);
        expect(find.text('Sep 14 – 20'), findsOneWidget);

        expect(find.text('24'), findsOneWidget);
        expect(find.text('best streak'), findsOneWidget);
        expect(find.text('6'), findsOneWidget);
        expect(find.text('habits kept'), findsOneWidget);
        expect(find.text('1'), findsOneWidget);
        expect(find.text('freeze used'), findsOneWidget);
      });

      testWidgets('pluralises the freeze tile', (tester) async {
        await tester.pumpWidget(harness(buildTheme, recap(freezesUsed: 2)));
        await tester.pumpAndSettle();

        expect(find.text('freezes used'), findsOneWidget);
        expect(find.text('freeze used'), findsNothing);
      });

      testWidgets('a week spanning two months names both', (tester) async {
        await tester.pumpWidget(harness(
          buildTheme,
          recap(start: '2026-09-28', end: '2026-10-04', days: [
            for (var i = 0; i < 7; i++)
              WeeklyRecapDay(
                date: TimeService.addDays('2026-09-28', i),
                rate: 0.5,
                isToday: i == 0,
                isFuture: false,
              ),
          ]),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Sep 28 – Oct 4'), findsOneWidget);
      });

      testWidgets('renders nothing at all when there are no habits',
          (tester) async {
        await tester.pumpWidget(
          harness(buildTheme, recap(activeHabitCount: 0)),
        );
        await tester.pumpAndSettle();

        expect(find.byType(WeeklyRecapCard), findsOneWidget);
        expect(find.text('THIS WEEK'), findsNothing);
        expect(find.text('best streak'), findsNothing);
        expect(bars(tester), isEmpty);
      });

      testWidgets("today's bar is distinguished from the other six",
          (tester) async {
        await tester.pumpWidget(harness(buildTheme, recap()));
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(WeeklyRecapCard));
        final colors = context.colors;
        final tokens = context.tokens;
        final all = bars(tester);
        expect(all, hasLength(7));

        // Wednesday is today, and only Wednesday wears the brand primary.
        expect(barColor(all[2]), equals(colors.primary));
        expect(barColor(all[0]), equals(tokens.heatmap[3]));
        expect(barColor(all[1]), equals(tokens.heatmap[3]));
        expect(
          all.where((b) => barColor(b) == colors.primary),
          hasLength(1),
          reason: 'exactly one bar is today',
        );
      });

      testWidgets('a day still to come is drawn differently from an empty day',
          (tester) async {
        // Tuesday happened with nothing scored; Thursday has not happened.
        // Reading the same would accuse the user of missing Thursday.
        await tester.pumpWidget(harness(
          buildTheme,
          recap(days: [
            day(0, rate: 0.8),
            day(1), // happened, nothing to score
            day(2, rate: 0.4), // today
            day(3), // future
            day(4),
            day(5),
            day(6),
          ]),
        ));
        await tester.pumpAndSettle();

        final tokens = tester.element(find.byType(WeeklyRecapCard)).tokens;
        final all = bars(tester);

        expect(barColor(all[1]), equals(tokens.lineSoft));
        expect(barColor(all[3]), isNot(equals(tokens.lineSoft)));
        expect(barColor(all[3]).a, lessThan(barColor(all[1]).a),
            reason: 'a future day is the fainter of the two');
      });

      testWidgets('bar height tracks the rate, with a stub for an empty day',
          (tester) async {
        await tester.pumpWidget(harness(
          buildTheme,
          recap(days: [
            day(0, rate: 1.0),
            day(1, rate: 0.5),
            day(2, rate: 0.0), // today, scored, but nothing done
            day(3),
            day(4),
            day(5),
            day(6),
          ]),
        ));
        await tester.pumpAndSettle();

        final all = bars(tester);
        double height(Container c) => c.constraints!.maxHeight;

        expect(height(all[0]), equals(64));
        expect(height(all[0]), greaterThan(height(all[1])));
        expect(height(all[1]), greaterThan(height(all[2])));
        expect(height(all[2]), equals(16),
            reason: 'a zero day still reads as a day, not a gap');
      });

      testWidgets('a first-ever week shows the rate with no comparison',
          (tester) async {
        await tester.pumpWidget(
          harness(buildTheme, recap(priorCompletionRate: null)),
        );
        await tester.pumpAndSettle();

        expect(find.text('87% completion so far.'), findsOneWidget);
        expect(find.textContaining('from last week'), findsNothing);
        // Explicitly not the boards' unverifiable superlative.
        expect(find.textContaining('best week'), findsNothing);
      });

      testWidgets('with a prior week it reports a real signed move',
          (tester) async {
        await tester.pumpWidget(harness(
          buildTheme,
          recap(completionRate: 0.87, priorCompletionRate: 0.75),
        ));
        await tester.pumpAndSettle();

        expect(
          find.text('87% completion — 12 points up from last week.'),
          findsOneWidget,
        );
      });

      testWidgets('a drop is reported as a drop, not hidden', (tester) async {
        await tester.pumpWidget(harness(
          buildTheme,
          recap(completionRate: 0.50, priorCompletionRate: 0.75),
        ));
        await tester.pumpAndSettle();

        expect(
          find.text('50% completion — 25 points down from last week.'),
          findsOneWidget,
        );
      });

      testWidgets('an unchanged week says so rather than "0 points up"',
          (tester) async {
        await tester.pumpWidget(harness(
          buildTheme,
          recap(completionRate: 0.75, priorCompletionRate: 0.75),
        ));
        await tester.pumpAndSettle();

        expect(
          find.text('75% completion — level with last week.'),
          findsOneWidget,
        );
      });

      testWidgets('no scorable day this week is an em dash, never 0%',
          (tester) async {
        await tester.pumpWidget(harness(
          buildTheme,
          recap(completionRate: null, priorCompletionRate: 0.5),
        ));
        await tester.pumpAndSettle();

        expect(
          find.text('— completion. Check something off and this fills in.'),
          findsOneWidget,
        );
        expect(find.textContaining('0%'), findsNothing);
      });
    });
  }

  group('WeeklyRecapCard — week-start setting', () {
    /// A recap anchored on [start], with every day scored so all seven bars
    /// carry a label.
    WeeklyRecap weekFrom(String start) => WeeklyRecap(
          weekStart: start,
          weekEnd: TimeService.addDays(start, 6),
          completionRate: 0.8,
          priorCompletionRate: null,
          days: [
            for (var i = 0; i < 7; i++)
              WeeklyRecapDay(
                date: TimeService.addDays(start, i),
                rate: 0.5,
                isToday: i == 2,
                isFuture: false,
              ),
          ],
          bestStreak: 4,
          habitsKept: 9,
          freezesUsed: 0,
          activeHabitCount: 2,
        );

    /// The bar labels, left to right.
    List<String> labelsOf(WidgetTester tester) => tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .where((d) => d.length == 1 && 'MTWFS'.contains(d))
        .toList();

    testWidgets('a Monday-start week reads M T W T F S S', (tester) async {
      // 2026-09-14 is a Monday.
      await tester.pumpWidget(
        harness(() => AppTheme.light, weekFrom('2026-09-14')),
      );
      await tester.pumpAndSettle();

      expect(labelsOf(tester), equals(['M', 'T', 'W', 'T', 'F', 'S', 'S']));
    });

    testWidgets('a Sunday-start week reads S M T W T F S', (tester) async {
      // 2026-09-13 is a Sunday. Before the fix this still read "M T W T F S S"
      // over Sunday-first dates — every letter wrong by one.
      await tester.pumpWidget(
        harness(() => AppTheme.light, weekFrom('2026-09-13')),
      );
      await tester.pumpAndSettle();

      expect(labelsOf(tester), equals(['S', 'M', 'T', 'W', 'T', 'F', 'S']));
    });

    testWidgets('a Saturday-start week reads S S M T W T F', (tester) async {
      // 2026-09-12 is a Saturday.
      await tester.pumpWidget(
        harness(() => AppTheme.light, weekFrom('2026-09-12')),
      );
      await tester.pumpAndSettle();

      expect(labelsOf(tester), equals(['S', 'S', 'M', 'T', 'W', 'T', 'F']));
    });

    testWidgets('every label matches the weekday of its own date',
        (tester) async {
      const initials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
      for (final start in ['2026-09-12', '2026-09-13', '2026-09-14']) {
        final recap = weekFrom(start);
        await tester.pumpWidget(harness(() => AppTheme.light, recap));
        await tester.pumpAndSettle();

        final labels = labelsOf(tester);
        for (var i = 0; i < 7; i++) {
          final weekday =
              TimeService.parseLocalDate(recap.days[i].date).weekday;
          expect(labels[i], equals(initials[weekday - 1]),
              reason: '${recap.days[i].date} in the week from $start');
        }
      }
    });
  });

  group('formatWeekRange', () {
    test('a week inside one month names the month once', () {
      expect(formatWeekRange('2026-09-14', '2026-09-20'), equals('Sep 14 – 20'));
    });

    test('a week across a month boundary names both', () {
      expect(
        formatWeekRange('2026-09-28', '2026-10-04'),
        equals('Sep 28 – Oct 4'),
      );
    });

    test('a week across a year boundary names both', () {
      expect(
        formatWeekRange('2026-12-28', '2027-01-03'),
        equals('Dec 28 – Jan 3'),
      );
    });
  });
}
