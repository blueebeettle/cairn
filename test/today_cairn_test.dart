import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/time/time_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:habit_tracker/core/habits/habit_streak.dart';
import 'package:habit_tracker/core/stats/habit_statistics.dart';
import 'package:habit_tracker/core/widgets/cairn_glyph.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/data/providers/habit_providers.dart';
import 'package:habit_tracker/data/repositories/habit_analytics_repository.dart';
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

    Map<String, double?> ratesOf(List<MomentumDay> days) =>
        {for (final d in days) d.localDate: d.rate};

    test("a settled day's rate is the share of its scheduled habits done", () {
      final days = build(snapshots: [
        _snapshot('a', const {
          _monday: HabitDayOutcome.done,
          '2026-09-22': HabitDayOutcome.missed,
        }),
        _snapshot('b', const {
          _monday: HabitDayOutcome.missed,
          '2026-09-22': HabitDayOutcome.missed,
        }),
      ]);
      final rates = ratesOf(days);

      // Monday: one of two done. It used to read as a flat "completed".
      expect(rates[_monday], 0.5);
      // Tuesday: scheduled and nothing done — a real zero, not "no data".
      expect(rates['2026-09-22'], 0.0);
    });

    test('a fully done day is exactly 1.0 and a partly done one is not', () {
      final days = build(snapshots: [
        _snapshot('a', const {
          _monday: HabitDayOutcome.done,
          '2026-09-22': HabitDayOutcome.done,
        }),
        _snapshot('b', const {
          _monday: HabitDayOutcome.done,
          '2026-09-22': HabitDayOutcome.missed,
        }),
      ]);

      expect(days.first.isFullyCompleted, isTrue);
      expect(days[1].isFullyCompleted, isFalse);
      // Only 1.0 counts, so a null (nothing scheduled) day never does either.
      expect(days.where((d) => d.isFullyCompleted).map((d) => d.localDate),
          [_monday]);
    });

    test('today counts habits still to do: 1 of 4 done is 0.25, not 1.0', () {
      // The reported bug, through the strip's own model. Four habits are due
      // today; one is ticked off and three are still pending. Counting only
      // the resolved habit read this as 1/1 — an instant full pip on the first
      // check-off.
      final days = build(snapshots: [
        _snapshot('a', const {_today: HabitDayOutcome.done}),
        _snapshot('b', const {_today: HabitDayOutcome.pending}),
        _snapshot('c', const {_today: HabitDayOutcome.pending}),
        _snapshot('d', const {_today: HabitDayOutcome.pending}),
      ]);

      final today = days.singleWhere((d) => d.isToday);
      expect(today.rate, 0.25);
      expect(today.isFullyCompleted, isFalse);
    });

    test('today grows a habit at a time and only reaches 1.0 when all are done',
        () {
      double? todayRate(int done) => build(snapshots: [
            for (var i = 0; i < 4; i++)
              _snapshot('h$i', {
                _today: i < done
                    ? HabitDayOutcome.done
                    : HabitDayOutcome.pending,
              }),
          ]).singleWhere((d) => d.isToday).rate;

      expect([for (var n = 0; n <= 4; n++) todayRate(n)],
          [0.0, 0.25, 0.5, 0.75, 1.0]);
    });

    test('today with habits due and none done is a real 0.0, not null', () {
      final days = build(snapshots: [
        _snapshot('a', const {_today: HabitDayOutcome.pending}),
      ]);
      expect(days.singleWhere((d) => d.isToday).rate, 0.0);
    });

    test('a frozen habit is left out of both sides', () {
      final days = build(snapshots: [
        _snapshot('a', const {_monday: HabitDayOutcome.done}),
        _snapshot('b', const {_monday: HabitDayOutcome.neutral}),
      ]);
      // One done, one frozen: 1 of 1 scoreable.
      expect(days.first.rate, 1.0);
    });

    test('a day where everything was frozen has no rate, not 0', () {
      final days = build(snapshots: [
        _snapshot('a', const {_monday: HabitDayOutcome.neutral}),
      ]);
      expect(days.first.rate, isNull);
      expect(days.first.isFullyCompleted, isFalse);
    });

    test('no habits means no rate on any day — nothing scheduled, not zero', () {
      final days = build();
      expect(days.map((d) => d.rate), everyElement(isNull));
      expect(days.where((d) => d.isFullyCompleted), isEmpty);
    });

    test('future days have no rate', () {
      final days = build(snapshots: [
        _snapshot('a', const {_today: HabitDayOutcome.done}),
      ]);
      expect(
        days.where((d) => d.isFuture).map((d) => d.rate),
        everyElement(isNull),
      );
    });

    test('a past week is all settled — no day is treated as in progress', () {
      // Asked about last week, "today" is not in it, so every day goes through
      // the settled-day path.
      final days = MomentumWeekStrip.daysFor(
        weekOf: '2026-09-14',
        todayLocalDate: _today,
        snapshots: [
          _snapshot('a', const {'2026-09-14': HabitDayOutcome.done}),
          _snapshot('b', const {'2026-09-14': HabitDayOutcome.missed}),
        ],
        weekStart: DateTime.monday,
      );
      expect(days.first.rate, 0.5);
      expect(days.where((d) => d.isToday), isEmpty);
    });

    test('agrees with the Habits weekly recap for the same week, day by day',
        () {
      // The strip and the recap bars show the same week and must not disagree
      // about it — including today, where both must count what is still to do.
      final snapshots = [
        _snapshot('a', const {
          _monday: HabitDayOutcome.done,
          '2026-09-22': HabitDayOutcome.missed,
          _today: HabitDayOutcome.done,
        }),
        _snapshot('b', const {
          _monday: HabitDayOutcome.done,
          '2026-09-22': HabitDayOutcome.done,
          _today: HabitDayOutcome.pending,
        }),
        _snapshot('c', const {
          _monday: HabitDayOutcome.missed,
          '2026-09-22': HabitDayOutcome.done,
          _today: HabitDayOutcome.pending,
        }),
      ];

      final strip = build(snapshots: snapshots);
      final recap = buildWeeklyRecap(
        habits: [for (final s in snapshots) s.toStatsInput()],
        todayLocalDate: _today,
        weekStartLocalDate: _monday,
      );

      expect(
        [for (final d in strip) d.rate],
        [for (final d in recap.days) d.rate],
      );
      // And today is the genuine fraction on both: 1 of 3.
      expect(strip.singleWhere((d) => d.isToday).rate, closeTo(1 / 3, 1e-9));
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

    group('MomentumWeekStrip pips ($themeName)', () {
      // This week is Mon 21 .. Sun 27 and today is Wed 23, so pips[0] is
      // Monday, pips[2] is today and pips[3..6] are still to come.
      const monday = 0;
      const tuesday = 1;
      const todayPip = 2;
      const thursday = 3;

      Widget stripHost(
        ThemeData theme,
        List<HabitSnapshot> snapshots, {
        ValueChanged<String>? onDayTap,
      }) =>
          ProviderScope(
            // A fresh scope per call: several of these tests re-pump with
            // different snapshots, and an unkeyed scope would keep serving the
            // first pump's already-resolved provider.
            key: UniqueKey(),
            overrides: [
              habitSnapshotsProvider.overrideWith((ref) async => snapshots),
            ],
            child: MaterialApp(
              theme: theme,
              home: Scaffold(
                body: MomentumWeekStrip(
                  weekOf: _today,
                  todayLocalDate: _today,
                  weekStart: DateTime.monday,
                  onDayTap: onDayTap,
                ),
              ),
            ),
          );

      /// The seven pips, Mon..Sun. They are the only Containers in the strip
      /// with a rounded decoration.
      List<BoxDecoration> pips(WidgetTester tester) => tester
          .widgetList<Container>(find.descendant(
            of: find.byType(MomentumWeekStrip),
            matching: find.byType(Container),
          ))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.borderRadius != null)
          .toList();

      /// Today's unfilled cover: the only FractionallySizedBox in the strip.
      Finder cover() => find.descendant(
            of: find.byType(MomentumWeekStrip),
            matching: find.byType(FractionallySizedBox),
          );

      /// [n] of four habits done today, the rest pending.
      List<HabitSnapshot> fourHabitsToday(int n) => [
            for (var i = 0; i < 4; i++)
              _snapshot('h$i', {
                _today:
                    i < n ? HabitDayOutcome.done : HabitDayOutcome.pending,
              }),
          ];

      testWidgets('past days grade by rate on the heatmap ramp', (tester) async {
        final theme = buildTheme();
        final tokens = theme.extension<AppTokens>()!;

        // 1, 2, 3 and 4 of four habits done on Monday: the four steps above
        // empty, lightest to darkest.
        for (final (done, tier) in [(1, 1), (2, 2), (3, 3), (4, 4)]) {
          await tester.pumpWidget(stripHost(theme, [
            for (var i = 0; i < 4; i++)
              _snapshot('h$i', {
                _monday:
                    i < done ? HabitDayOutcome.done : HabitDayOutcome.missed,
              }),
          ]));
          await tester.pumpAndSettle();

          expect(pips(tester)[monday].color, tokens.heatmap[tier],
              reason: '$done of 4 done should sit on tier $tier');
        }
      });

      testWidgets('a fully completed day is the darkest tier, a low one lighter',
          (tester) async {
        final theme = buildTheme();
        final tokens = theme.extension<AppTokens>()!;

        await tester.pumpWidget(stripHost(theme, [
          _snapshot('a', const {
            _monday: HabitDayOutcome.done,
            '2026-09-22': HabitDayOutcome.done,
          }),
          _snapshot('b', const {
            _monday: HabitDayOutcome.done,
            '2026-09-22': HabitDayOutcome.missed,
          }),
        ]));
        await tester.pumpAndSettle();

        final p = pips(tester);
        expect(p[monday].color, tokens.heatmap.last);
        expect(p[tuesday].color, isNot(tokens.heatmap.last));
        expect(p[tuesday].color, tokens.heatmap[2]);
      });

      testWidgets(
          'nothing scheduled, nothing done and a future day are three different looks',
          (tester) async {
        final theme = buildTheme();
        final tokens = theme.extension<AppTokens>()!;

        // Nothing scheduled on Monday; two habits scheduled Tuesday and both
        // missed; Thursday has not happened.
        await tester.pumpWidget(stripHost(theme, [
          _snapshot('a', const {'2026-09-22': HabitDayOutcome.missed}),
          _snapshot('b', const {'2026-09-22': HabitDayOutcome.missed}),
        ]));
        await tester.pumpAndSettle();

        final p = pips(tester);
        final nothingScheduled = p[monday];
        final nothingDone = p[tuesday];
        final future = p[thursday];

        // 0.0 is the empty shade at full strength; null is the same shade
        // dimmed. Collapsing them was the old behaviour.
        expect(nothingDone.color, tokens.lineSoft);
        expect(nothingScheduled.color, isNot(nothingDone.color));
        expect(nothingScheduled.color, tokens.lineSoft.withValues(alpha: 0.4));

        // A future day is outlined; a settled one is not.
        expect(future.border, isNotNull);
        expect(nothingDone.border, isNull);
        expect(nothingScheduled.border, isNull);
      });

      testWidgets('today stays primary with its halo whatever its rate',
          (tester) async {
        final theme = buildTheme();
        final scheme = theme.colorScheme;

        // null (nothing scheduled), 0.0, a fraction, and complete.
        for (final (label, snapshots) in [
          ('no habits', const <HabitSnapshot>[]),
          ('0 of 4', fourHabitsToday(0)),
          ('1 of 4', fourHabitsToday(1)),
          ('3 of 4', fourHabitsToday(3)),
          ('4 of 4', fourHabitsToday(4)),
        ]) {
          await tester.pumpWidget(stripHost(theme, snapshots));
          await tester.pumpAndSettle();

          final p = pips(tester);
          expect(p[todayPip].color, scheme.primary,
              reason: 'today with $label must not fade');
          expect(p[todayPip].boxShadow, isNotNull,
              reason: 'today with $label keeps its halo');
          expect(p.where((d) => d.boxShadow != null), hasLength(1),
              reason: 'and it is still the only day that has one');
        }
      });

      testWidgets("today's fill shows genuine partial progress, not a jump to full",
          (tester) async {
        final theme = buildTheme();

        Future<double?> unfilledAt(int done) async {
          await tester.pumpWidget(stripHost(theme, fourHabitsToday(done)));
          await tester.pumpAndSettle();
          if (cover().evaluate().isEmpty) return null;
          return tester.widget<FractionallySizedBox>(cover()).heightFactor;
        }

        // The share of the pip still to fill, as habits are checked off. The
        // first tick must leave most of it unfilled — the bug made it 0.
        expect(await unfilledAt(0), 1.0);
        expect(await unfilledAt(1), closeTo(0.75, 1e-9));
        expect(await unfilledAt(2), closeTo(0.5, 1e-9));
        expect(await unfilledAt(3), closeTo(0.25, 1e-9));
        // Everything done: no cover at all, the solid pip it always was.
        expect(await unfilledAt(4), isNull);
      });

      testWidgets("today's null and zero are told apart by the cover's tint",
          (tester) async {
        final theme = buildTheme();

        Future<Color> coverColorFor(List<HabitSnapshot> snapshots) async {
          await tester.pumpWidget(stripHost(theme, snapshots));
          await tester.pumpAndSettle();
          final box = tester.widget<DecoratedBox>(find.descendant(
            of: cover(),
            matching: find.byType(DecoratedBox),
          ));
          return (box.decoration as BoxDecoration).color!;
        }

        final nothingScheduled = await coverColorFor(const []);
        final nothingDoneYet = await coverColorFor(fourHabitsToday(0));
        expect(nothingScheduled, isNot(nothingDoneYet));
      });

      testWidgets('the header counts fully kept days, not any-habit-done days',
          (tester) async {
        // Monday fully done, Tuesday half done, today half done: one kept day.
        // Counting any-habit-done would say 3 over a row of half-filled pips.
        await tester.pumpWidget(stripHost(buildTheme(), [
          _snapshot('a', const {
            _monday: HabitDayOutcome.done,
            '2026-09-22': HabitDayOutcome.done,
            _today: HabitDayOutcome.done,
          }),
          _snapshot('b', const {
            _monday: HabitDayOutcome.done,
            '2026-09-22': HabitDayOutcome.missed,
            _today: HabitDayOutcome.pending,
          }),
        ]));
        await tester.pumpAndSettle();

        expect(find.text('1 / 7 days'), findsOneWidget);
      });

      testWidgets('each pip says what it shows, in percent or in words',
          (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(stripHost(
          buildTheme(),
          [
            _snapshot('a', const {
              '2026-09-22': HabitDayOutcome.done,
              '2026-09-23': HabitDayOutcome.done,
            }),
            _snapshot('b', const {
              '2026-09-22': HabitDayOutcome.missed,
              '2026-09-23': HabitDayOutcome.pending,
            }),
            // Monday is fully completed by this one alone.
            _snapshot('c', const {_monday: HabitDayOutcome.done}),
          ],
          onDayTap: (_) {},
        ));
        await tester.pumpAndSettle();

        expect(find.bySemanticsLabel('$_monday, fully completed'),
            findsOneWidget);
        expect(
          find.bySemanticsLabel('2026-09-22, partially completed, 50 percent'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(
              '2026-09-23, partially completed, 50 percent, today'),
          findsOneWidget,
        );
        expect(find.bySemanticsLabel('2026-09-24, upcoming'), findsOneWidget);
        handle.dispose();
      });

      testWidgets('nothing scheduled and nothing done are spoken differently',
          (tester) async {
        final handle = tester.ensureSemantics();
        await tester.pumpWidget(stripHost(
          buildTheme(),
          [
            _snapshot('a', const {'2026-09-22': HabitDayOutcome.missed}),
          ],
          onDayTap: (_) {},
        ));
        await tester.pumpAndSettle();

        expect(find.bySemanticsLabel('$_monday, nothing scheduled'),
            findsOneWidget);
        expect(find.bySemanticsLabel('2026-09-22, nothing done'),
            findsOneWidget);
        handle.dispose();
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
