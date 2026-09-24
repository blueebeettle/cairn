import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:habit_tracker/core/habits/habit_streak.dart';
import 'package:habit_tracker/core/habits/milestone_thresholds.dart';
import 'package:habit_tracker/core/widgets/cairn_glyph.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/data/providers/habit_providers.dart';
import 'package:habit_tracker/data/repositories/habits_repository.dart';
import 'package:habit_tracker/features/habits/domain/habit_presentation.dart';
import 'package:habit_tracker/features/habits/presentation/habits_screen.dart';
import 'package:habit_tracker/features/habits/presentation/widgets/habit_marks.dart';
import 'package:habit_tracker/features/habits/presentation/widgets/habit_milestone.dart';
import 'package:habit_tracker/theme/app_theme.dart';

const _today = '2026-09-23';

Habit _habit(String id, {String title = 'Evening walk', int allowance = 2}) =>
    Habit(
      id: id,
      title: title,
      colorIndex: 0,
      iconName: 'check',
      scheduleRule: 'FREQ=DAILY',
      anchorDate: '2026-01-01',
      targetCount: 1,
      skipAllowancePerMonth: allowance,
      status: 'active',
      sortOrder: 0,
      createdAt: 0,
      createdLocalDate: '2026-01-01',
      updatedAt: 0,
      deviceId: 'test',
    );

/// A snapshot whose scheduled days run up to [_today] with the given outcomes.
HabitSnapshot _snapshot({
  String id = 'h1',
  String title = 'Evening walk',
  int streak = 6,
  int allowance = 2,
  Map<String, HabitDayOutcome> outcomes = const {},
  List<String>? scheduledDates,
}) {
  final dates = scheduledDates ?? (outcomes.keys.toList()..sort());
  return HabitSnapshot(
    habit: _habit(id, title: title, allowance: allowance),
    scheduledDates: dates,
    entries: const {},
    streaks: HabitStreakResult(
      current: streak,
      longest: streak,
      outcomes: outcomes,
    ),
    todayLocalDate: _today,
  );
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  // ── the shared threshold helper ───────────────────────────────────────────

  group('MilestoneThresholds', () {
    test('lands exactly on the early thresholds', () {
      for (final threshold in MilestoneThresholds.early) {
        expect(MilestoneThresholds.reached(threshold), isTrue,
            reason: '$threshold is a milestone');
      }
    });

    test('every hundred after the early run', () {
      for (final streak in [200, 300, 1000, 12300]) {
        expect(MilestoneThresholds.reached(streak), isTrue, reason: '$streak');
      }
    });

    test('a day past a milestone is not a milestone', () {
      // This is what stops the celebration re-firing for a whole month.
      for (final threshold in [...MilestoneThresholds.early, 200, 300]) {
        expect(MilestoneThresholds.reached(threshold + 1), isFalse,
            reason: '${threshold + 1}');
        expect(MilestoneThresholds.reached(threshold - 1), isFalse,
            reason: '${threshold - 1}');
      }
    });

    test('no milestone at or below zero', () {
      expect(MilestoneThresholds.reached(0), isFalse);
      expect(MilestoneThresholds.reached(-5), isFalse);
    });

    test('nothing between 100 and 200 counts', () {
      for (var streak = 101; streak < 200; streak++) {
        expect(MilestoneThresholds.reached(streak), isFalse, reason: '$streak');
      }
    });

    test('highestReached tracks what has been passed', () {
      expect(MilestoneThresholds.highestReached(0), isNull);
      expect(MilestoneThresholds.highestReached(6), isNull);
      expect(MilestoneThresholds.highestReached(7), 7);
      expect(MilestoneThresholds.highestReached(29), 14);
      expect(MilestoneThresholds.highestReached(30), 30);
      expect(MilestoneThresholds.highestReached(99), 60);
      expect(MilestoneThresholds.highestReached(150), 100);
      expect(MilestoneThresholds.highestReached(250), 200);
    });

    test('next always moves forward and is itself a milestone', () {
      for (var streak = 0; streak <= 320; streak++) {
        final next = MilestoneThresholds.next(streak);
        expect(next, greaterThan(streak), reason: 'from $streak');
        expect(MilestoneThresholds.reached(next), isTrue, reason: 'from $streak');
        expect(MilestoneThresholds.daysToNext(streak), next - streak);
      }
    });
  });

  // ── snapshot views ────────────────────────────────────────────────────────

  group('HabitSnapshot milestone and freeze views', () {
    test('milestoneToday is the streak only on the exact day', () {
      expect(_snapshot(streak: 7).milestoneToday, 7);
      expect(_snapshot(streak: 100).milestoneToday, 100);
      expect(_snapshot(streak: 8).milestoneToday, isNull);
      expect(_snapshot(streak: 0).milestoneToday, isNull);
    });

    test('freezeUsedOn reports only the latest resolved scheduled day', () {
      final frozen = _snapshot(
        outcomes: const {
          '2026-09-20': HabitDayOutcome.done,
          '2026-09-21': HabitDayOutcome.done,
          '2026-09-22': HabitDayOutcome.neutral,
        },
      );
      expect(frozen.freezeUsedOn, '2026-09-22');
    });

    test('an older freeze behind a completed day is history', () {
      final recovered = _snapshot(
        outcomes: const {
          '2026-09-20': HabitDayOutcome.neutral,
          '2026-09-21': HabitDayOutcome.done,
          '2026-09-22': HabitDayOutcome.done,
        },
      );
      expect(recovered.freezeUsedOn, isNull);
    });

    test('a missed latest day is not a freeze', () {
      final missed = _snapshot(
        outcomes: const {
          '2026-09-21': HabitDayOutcome.neutral,
          '2026-09-22': HabitDayOutcome.missed,
        },
      );
      expect(missed.freezeUsedOn, isNull);
    });

    test('today is skipped — it is still open', () {
      // An unchecked habit resolves to `missed` all day. Reading today would
      // bury yesterday's freeze behind a miss that has not happened yet.
      final pending = _snapshot(
        scheduledDates: const ['2026-09-21', '2026-09-22', _today],
        outcomes: const {
          '2026-09-21': HabitDayOutcome.done,
          '2026-09-22': HabitDayOutcome.neutral,
          _today: HabitDayOutcome.missed,
        },
      );
      expect(pending.freezeUsedOn, '2026-09-22');
    });

    test('a rest day marked for today needs no forgiveness line', () {
      // It is already filed under "done today" by the list's grouping.
      final restingToday = _snapshot(
        scheduledDates: const ['2026-09-22', _today],
        outcomes: const {
          '2026-09-22': HabitDayOutcome.done,
          _today: HabitDayOutcome.neutral,
        },
      );
      expect(restingToday.freezeUsedOn, isNull);
    });

    test('no history means nothing to forgive', () {
      expect(_snapshot().freezeUsedOn, isNull);
    });
  });

  group('HabitDates.freezeUsedLabel', () {
    test('says when, and never says missed', () {
      expect(
        HabitDates.freezeUsedLabel('2026-09-22', _today),
        'Freeze used yesterday — streak safe',
      );
      expect(
        HabitDates.freezeUsedLabel(_today, _today),
        'Freeze used today — streak safe',
      );
      expect(
        HabitDates.freezeUsedLabel('2026-09-20', _today),
        'Freeze used on Sunday — streak safe',
      );
      expect(
        HabitDates.freezeUsedLabel('2026-09-01', _today),
        'Freeze used on 1 Sep — streak safe',
      );
    });
  });

  // ── the screen ────────────────────────────────────────────────────────────

  Widget screen(ThemeData theme, List<HabitSnapshot> snapshots) => ProviderScope(
    overrides: [
      habitSnapshotsProvider.overrideWith((ref) async => snapshots),
    ],
    child: MaterialApp(theme: theme, home: const HabitsScreen()),
  );

  final themes = <String, ThemeData Function()>{
    'light': () => AppTheme.light,
    'dark': () => AppTheme.dark,
  };

  for (final entry in themes.entries) {
    final themeName = entry.key;
    final buildTheme = entry.value;

    group('HabitsScreen ($themeName)', () {
      testWidgets('a milestone habit gets the cairn, the pill and the ring',
          (tester) async {
        await tester.pumpWidget(
          screen(buildTheme(), [
            _snapshot(
              streak: 100,
              scheduledDates: const [_today],
              outcomes: const {_today: HabitDayOutcome.missed},
            ),
          ]),
        );
        await tester.pumpAndSettle();

        // Three stones, at the mockup's 46x50.
        final glyph = tester.widget<CairnGlyph>(find.byType(CairnGlyph));
        expect(glyph.stoneCount, 3);
        expect(glyph.scale, 0.6);

        expect(find.byType(MilestoneStreakPill), findsOneWidget);
        expect(find.byType(HabitStreakBadge), findsNothing);
        expect(find.text('100-day milestone today'), findsOneWidget);

        // The card wears the 2px accent ring instead of the hairline.
        final card = tester.widget<Card>(find.byType(Card).first);
        final side = (card.shape! as RoundedRectangleBorder).side;
        expect(side.width, 2);
        expect(side.color, MilestoneChrome.accent(tester.element(find.byType(HabitsScreen))));
      });

      testWidgets('an ordinary habit keeps the flame badge and no glow',
          (tester) async {
        await tester.pumpWidget(
          screen(buildTheme(), [
            _snapshot(
              streak: 6,
              scheduledDates: const [_today],
              outcomes: const {_today: HabitDayOutcome.missed},
            ),
          ]),
        );
        await tester.pumpAndSettle();

        expect(find.byType(CairnGlyph), findsNothing);
        expect(find.byType(MilestoneStreakPill), findsNothing);
        expect(find.byType(HabitStreakBadge), findsOneWidget);
        expect(find.text('Every day'), findsOneWidget);
        expect(tester.widget<Card>(find.byType(Card).first).shape, isNull);
      });

      testWidgets('a frozen habit reads as safe, not missed', (tester) async {
        await tester.pumpWidget(
          screen(buildTheme(), [
            _snapshot(
              streak: 24,
              scheduledDates: const ['2026-09-22', _today],
              outcomes: const {
                '2026-09-22': HabitDayOutcome.neutral,
                _today: HabitDayOutcome.missed,
              },
            ),
          ]),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Freeze used yesterday — streak safe'),
          findsOneWidget,
        );
        expect(find.text('Every day'), findsNothing);
        // Forgiveness, not celebration: no milestone chrome on this row.
        expect(find.byType(MilestoneStreakPill), findsNothing);
      });

      testWidgets('a milestone outranks a freeze in the subtitle',
          (tester) async {
        await tester.pumpWidget(
          screen(buildTheme(), [
            _snapshot(
              streak: 30,
              scheduledDates: const ['2026-09-22', _today],
              outcomes: const {
                '2026-09-22': HabitDayOutcome.neutral,
                _today: HabitDayOutcome.missed,
              },
            ),
          ]),
        );
        await tester.pumpAndSettle();

        expect(find.text('30-day milestone today'), findsOneWidget);
        expect(find.textContaining('Freeze used'), findsNothing);
      });

      testWidgets('the freezes chip totals the remaining allowance',
          (tester) async {
        await tester.pumpWidget(
          screen(buildTheme(), [
            // 2 allowed, 1 used this month -> 1 left.
            _snapshot(
              id: 'a',
              title: 'Walk',
              allowance: 2,
              scheduledDates: const ['2026-09-10', _today],
              outcomes: const {
                '2026-09-10': HabitDayOutcome.neutral,
                _today: HabitDayOutcome.missed,
              },
            ),
            // 2 allowed, none used -> 2 left.
            _snapshot(
              id: 'b',
              title: 'Read',
              allowance: 2,
              scheduledDates: const [_today],
              outcomes: const {_today: HabitDayOutcome.missed},
            ),
          ]),
        );
        await tester.pumpAndSettle();

        expect(find.byType(FreezesChip), findsOneWidget);
        expect(find.text('3 freezes'), findsOneWidget);
      });

      testWidgets('a single remaining freeze is singular', (tester) async {
        await tester.pumpWidget(
          screen(buildTheme(), [
            _snapshot(
              allowance: 1,
              scheduledDates: const [_today],
              outcomes: const {_today: HabitDayOutcome.missed},
            ),
          ]),
        );
        await tester.pumpAndSettle();

        expect(find.text('1 freeze'), findsOneWidget);
      });

      testWidgets('no habits, no chip', (tester) async {
        await tester.pumpWidget(screen(buildTheme(), const []));
        await tester.pumpAndSettle();

        expect(find.byType(FreezesChip), findsNothing);
      });
    });
  }
}
