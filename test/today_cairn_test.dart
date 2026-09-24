import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/time/time_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:habit_tracker/core/habits/habit_streak.dart';
import 'package:habit_tracker/core/widgets/cairn_glyph.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/data/providers/habit_providers.dart';
import 'package:habit_tracker/data/repositories/habits_repository.dart';
import 'package:habit_tracker/features/habits/presentation/widgets/habit_check_burst.dart';
import 'package:habit_tracker/features/today/presentation/widgets/grow_your_cairn_card.dart';
import 'package:habit_tracker/features/today/presentation/widgets/momentum_week_strip.dart';
import 'package:habit_tracker/theme/app_theme.dart';

// 2026-09-23 is a Wednesday, so this week runs Mon 21 -> Sun 27.
const _today = '2026-09-23';
const _monday = '2026-09-21';

Habit _habit(String id) => Habit(
      id: id,
      title: id,
      colorIndex: 0,
      iconName: 'check',
      scheduleRule: 'FREQ=DAILY',
      anchorDate: _monday,
      targetCount: 1,
      skipAllowancePerMonth: 2,
      status: 'active',
      sortOrder: 0,
      createdAt: 0,
      createdLocalDate: _monday,
      updatedAt: 0,
      deviceId: 'test',
    );

/// A snapshot carrying nothing but the day outcomes the strip reads.
HabitSnapshot _snapshot(String id, Map<String, HabitDayOutcome> outcomes) =>
    HabitSnapshot(
      habit: _habit(id),
      scheduledDates: outcomes.keys.toList()..sort(),
      entries: const {},
      streaks: HabitStreakResult(current: 0, longest: 0, outcomes: outcomes),
      todayLocalDate: _today,
    );

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  final themes = <String, ThemeData Function()>{
    'light': () => AppTheme.light,
    'dark': () => AppTheme.dark,
  };

  // ── stoneCount from today's check-offs ────────────────────────────────────

  group('cairnStoneCount', () {
    test('one stone per habit when four or fewer are due', () {
      expect(cairnStoneCount(checked: 0, total: 4), 0);
      expect(cairnStoneCount(checked: 1, total: 4), 1);
      expect(cairnStoneCount(checked: 2, total: 4), 2);
      expect(cairnStoneCount(checked: 3, total: 4), 3);
      expect(cairnStoneCount(checked: 4, total: 4), 4);

      // Fewer habits than stones still walks 0 -> 4 and tops out full.
      expect(cairnStoneCount(checked: 0, total: 1), 0);
      expect(cairnStoneCount(checked: 1, total: 1), 4);
      expect(cairnStoneCount(checked: 1, total: 3), 2);
      expect(cairnStoneCount(checked: 2, total: 3), 3);
      expect(cairnStoneCount(checked: 3, total: 3), 4);
    });

    test('each stone is a quarter of the list when more than four are due', () {
      // min(4, ceil(checked / total * 4))
      expect(cairnStoneCount(checked: 1, total: 10), 1);
      expect(cairnStoneCount(checked: 2, total: 10), 1);
      expect(cairnStoneCount(checked: 3, total: 10), 2);
      expect(cairnStoneCount(checked: 5, total: 10), 2);
      expect(cairnStoneCount(checked: 6, total: 10), 3);
      expect(cairnStoneCount(checked: 8, total: 10), 4);
      expect(cairnStoneCount(checked: 10, total: 10), 4);
    });

    test('a first check-off always shows a stone', () {
      for (var total = 1; total <= 40; total++) {
        expect(
          cairnStoneCount(checked: 1, total: total),
          greaterThanOrEqualTo(1),
          reason: '1 of $total should already be growing',
        );
      }
    });

    test('degenerate counts never produce a cairn out of nothing', () {
      expect(cairnStoneCount(checked: 0, total: 0), 0);
      expect(cairnStoneCount(checked: 3, total: 0), 0);
      expect(cairnStoneCount(checked: -1, total: 5), 0);
      // More checked than due (a stale frame mid-write) still caps at full.
      expect(cairnStoneCount(checked: 9, total: 5), 4);
    });

    test('never exceeds what CairnGlyph can draw', () {
      for (var total = 1; total <= 30; total++) {
        for (var checked = 0; checked <= total; checked++) {
          final stones = cairnStoneCount(checked: checked, total: total);
          expect(stones, inInclusiveRange(0, CairnGlyph.stoneFills.length));
        }
      }
    });
  });

  // ── week strip day model ──────────────────────────────────────────────────

  group('MomentumWeekStrip.daysFor', () {
    List<MomentumDay> build({
      String weekOf = _today,
      List<HabitSnapshot> snapshots = const [],
      int weekStart = DateTime.monday,
    }) =>
        MomentumWeekStrip.daysFor(
          weekOf: weekOf,
          todayLocalDate: _today,
          snapshots: snapshots,
          weekStart: weekStart,
        );

    test('runs Monday to Sunday of the week containing the date', () {
      final days = build();
      expect(days.length, 7);
      expect(days.first.localDate, _monday);
      expect(days.last.localDate, '2026-09-27');
      expect(days.map((d) => d.label).toList(), ['M', 'T', 'W', 'T', 'F', 'S', 'S']);
    });

    test('a Sunday-start week begins on Sunday and labels match the dates',
        () {
      // _today is Wed 2026-09-23, so a Sunday-start week runs 09-20..09-26.
      final days = build(weekStart: DateTime.sunday);
      expect(days.first.localDate, '2026-09-20');
      expect(days.last.localDate, '2026-09-26');
      expect(days.map((d) => d.label).toList(),
          ['S', 'M', 'T', 'W', 'T', 'F', 'S']);
    });

    test('a Saturday-start week begins on Saturday and labels match the dates',
        () {
      // Sat 2026-09-19 .. Fri 2026-09-25.
      final days = build(weekStart: DateTime.saturday);
      expect(days.first.localDate, '2026-09-19');
      expect(days.last.localDate, '2026-09-25');
      expect(days.map((d) => d.label).toList(),
          ['S', 'S', 'M', 'T', 'W', 'T', 'F']);
    });

    test("every label is its own date's weekday, at every setting", () {
      const initials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
      for (final start in [
        DateTime.monday,
        DateTime.sunday,
        DateTime.saturday,
      ]) {
        for (final day in build(weekStart: start)) {
          final weekday = TimeService.parseLocalDate(day.localDate).weekday;
          expect(day.label, initials[weekday - 1],
              reason: '${day.localDate} at weekStart $start');
        }
      }
    });

    test('a week starting on today itself puts today at position 0', () {
      // _today is a Wednesday; ask for a Wednesday-start week.
      final days = build(weekStart: DateTime.wednesday);
      expect(days.first.localDate, _today);
      expect(days.first.isToday, isTrue);
      expect(days.last.localDate, '2026-09-29');
      expect(days.where((d) => d.isToday), hasLength(1));
    });

    test('a week ending on today puts today at position 6', () {
      // Thursday-start: Thu 09-17 .. Wed 09-23, so today is last.
      final days = build(weekStart: DateTime.thursday);
      expect(days.first.localDate, '2026-09-17');
      expect(days.last.localDate, _today);
      expect(days.last.isToday, isTrue);
      expect(days.where((d) => d.isFuture), isEmpty);
    });

    test('any day of the week resolves to the same Monday', () {
      for (final date in [
        '2026-09-21',
        '2026-09-23',
        '2026-09-27',
      ]) {
        expect(build(weekOf: date).first.localDate, _monday);
      }
    });

    test('exactly one day is today, and later days are future', () {
      final days = build();
      expect(days.where((d) => d.isToday).map((d) => d.localDate), [_today]);
      expect(
        days.where((d) => d.isFuture).map((d) => d.localDate),
        ['2026-09-24', '2026-09-25', '2026-09-26', '2026-09-27'],
      );
      // Today is not "future", so it never renders as an unknown day.
      expect(days.firstWhere((d) => d.isToday).isFuture, isFalse);
    });

    test('a day counts as completed when any habit was done on it', () {
      final days = build(snapshots: [
        _snapshot('a', const {
          _monday: HabitDayOutcome.done,
          '2026-09-22': HabitDayOutcome.missed,
        }),
        _snapshot('b', const {
          _monday: HabitDayOutcome.missed,
          '2026-09-22': HabitDayOutcome.missed,
          _today: HabitDayOutcome.done,
        }),
      ]);

      expect(
        days.where((d) => d.completed).map((d) => d.localDate),
        [_monday, _today],
      );
    });

    test('an excused rest day is not a completion', () {
      final days = build(snapshots: [
        _snapshot('a', const {_monday: HabitDayOutcome.neutral}),
      ]);
      expect(days.where((d) => d.completed), isEmpty);
    });

    test('no habits means no completed days', () {
      expect(build().where((d) => d.completed), isEmpty);
    });
  });

  // ── week strip glow ───────────────────────────────────────────────────────

  Widget host(ThemeData theme, Widget child) => ProviderScope(
        overrides: [
          habitSnapshotsProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          theme: theme,
          home: Scaffold(body: child),
        ),
      );

  for (final entry in themes.entries) {
    final themeName = entry.key;
    final buildTheme = entry.value;

    group('MomentumWeekStrip glow ($themeName)', () {
      testWidgets('only today wears the CairnGlyph marker halo',
          (tester) async {
        late List<BoxShadow> expectedHalo;

        await tester.pumpWidget(
          host(
            buildTheme(),
            Builder(builder: (context) {
              expectedHalo = CairnGlyph.markerHalo(context);
              return const MomentumWeekStrip(
                weekOf: _today,
                todayLocalDate: _today,
                weekStart: DateTime.monday,
              );
            }),
          ),
        );
        await tester.pumpAndSettle();

        final bars = tester
            .widgetList<Container>(
              find.descendant(
                of: find.byType(MomentumWeekStrip),
                matching: find.byType(Container),
              ),
            )
            .map((c) => c.decoration)
            .whereType<BoxDecoration>()
            .toList();

        final haloed = bars.where((d) => d.boxShadow != null).toList();
        expect(haloed, hasLength(1), reason: 'exactly one "now" marker');

        // The glow is reused, not reinvented: same colours, blur and spread.
        final halo = haloed.single.boxShadow!;
        expect(halo.map((s) => s.color), expectedHalo.map((s) => s.color));
        expect(halo.map((s) => s.blurRadius), expectedHalo.map((s) => s.blurRadius));
        expect(halo.map((s) => s.spreadRadius),
            expectedHalo.map((s) => s.spreadRadius));

        // And it is the primary-filled bar, not one of the plain days.
        final scheme = buildTheme().colorScheme;
        expect(haloed.single.color, scheme.primary);
      });

      testWidgets('a week without today carries no halo at all',
          (tester) async {
        await tester.pumpWidget(
          host(
            buildTheme(),
            const MomentumWeekStrip(
              weekOf: '2026-08-12',
              todayLocalDate: _today,
              weekStart: DateTime.monday,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final haloed = tester
            .widgetList<Container>(
              find.descendant(
                of: find.byType(MomentumWeekStrip),
                matching: find.byType(Container),
              ),
            )
            .map((c) => c.decoration)
            .whereType<BoxDecoration>()
            .where((d) => d.boxShadow != null);

        expect(haloed, isEmpty);
      });
    });
  }

  // ── cairn card ────────────────────────────────────────────────────────────

  group('GrowYourCairnCard', () {
    Widget card({required int done, required int due}) => ProviderScope(
          overrides: [
            habitsDoneTodayProvider.overrideWith((ref) => (done: done, due: due)),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: GrowYourCairnCard(currentStreakDays: 12),
            ),
          ),
        );

    for (final (done, due, stones) in [
      (0, 4, 0),
      (1, 4, 1),
      (3, 4, 3),
      (4, 4, 4),
      (3, 10, 2),
      (9, 10, 4),
    ]) {
      testWidgets('$done of $due checked grows $stones stones', (tester) async {
        await tester.pumpWidget(card(done: done, due: due));
        await tester.pumpAndSettle();

        expect(
          tester.widget<CairnGlyph>(find.byType(CairnGlyph)).stoneCount,
          stones,
        );
      });
    }

    testWidgets('renders nothing when no habit is due today', (tester) async {
      await tester.pumpWidget(card(done: 0, due: 0));
      await tester.pumpAndSettle();

      expect(find.byType(CairnGlyph), findsNothing);
      expect(find.textContaining('day streak'), findsNothing);
    });

    testWidgets('shows the streak and what is left to do', (tester) async {
      await tester.pumpWidget(card(done: 2, due: 5));
      await tester.pumpAndSettle();

      expect(find.text('12'), findsOneWidget);
      expect(find.text('day streak'), findsOneWidget);
      expect(find.textContaining('3 more habits'), findsOneWidget);
    });

    testWidgets('a finished day says so', (tester) async {
      await tester.pumpWidget(card(done: 5, due: 5));
      await tester.pumpAndSettle();

      expect(find.textContaining('All 5 done'), findsOneWidget);
    });
  });

  // ── check-off burst ───────────────────────────────────────────────────────

  group('HabitCheckBurst', () {
    // One instance, reused: MaterialApp's AnimatedTheme lerps between two
    // equal-but-distinct ThemeDatas, and Color.lerp(c, c, t) is not bit-exact.
    late final ThemeData light = AppTheme.light;
    late final ThemeData dark = AppTheme.dark;

    Widget burst(ThemeData theme, {required bool done}) => MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Center(
              child: HabitCheckBurst(
                done: done,
                diameter: 52,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );

    List<Color?> flecks(WidgetTester tester) => tester
        .widgetList<Container>(
          find.descendant(
            of: find.byType(HabitCheckBurst),
            matching: find.byType(Container),
          ),
        )
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .where((d) => d.shape == BoxShape.circle)
        .map((d) => d.color)
        .toList();

    testWidgets('throws series-coloured flecks on check, then clears them',
        (tester) async {
      await tester.pumpWidget(burst(light, done: false));
      expect(flecks(tester), isEmpty, reason: 'nothing before the check');

      await tester.pumpWidget(burst(light, done: true));
      await tester.pump(const Duration(milliseconds: 60));

      final mid = flecks(tester);
      expect(mid, hasLength(3));
      expect(mid, everyElement(isIn(AppTokens.light.series)));

      // Inside 200ms, per the spec — and gone once it lands.
      await tester.pump(const Duration(milliseconds: 200));
      expect(flecks(tester), isEmpty);
      expect(HabitCheckBurst.duration.inMilliseconds, inInclusiveRange(150, 200));
    });

    testWidgets('an undo does not fire the burst', (tester) async {
      await tester.pumpWidget(burst(light, done: true));
      await tester.pumpAndSettle();

      await tester.pumpWidget(burst(light, done: false));
      await tester.pump(const Duration(milliseconds: 60));

      expect(flecks(tester), isEmpty);
    });

    testWidgets('the child keeps the full tap target throughout',
        (tester) async {
      await tester.pumpWidget(burst(dark, done: false));
      expect(tester.getSize(find.byType(HabitCheckBurst)), const Size(52, 52));

      await tester.pumpWidget(burst(dark, done: true));
      await tester.pump(const Duration(milliseconds: 60));

      expect(tester.getSize(find.byType(HabitCheckBurst)), const Size(52, 52));
      expect(
        tester.getSize(
          find.descendant(
            of: find.byType(HabitCheckBurst),
            matching: find.byType(SizedBox).last,
          ),
        ),
        const Size(52, 52),
      );
    });
  });
}
