// One allowance, one name: "freeze".
//
// The per-habit monthly allowance of days a user can excuse is a single
// mechanism, and it used to be called "freeze" (the Habits header chip, the
// streak-safe line, the Stats tile) and "rest day" (the day sheet, the habit
// editor, the calendar legend, the help sheet) — sometimes in the same widget.
// These tests pin the one name, and that the help text is honest that using a
// freeze is manual.
//
// The widget-level checks for the day sheet, the habit editor and the chip live
// beside the harnesses they need (`habits_feature_test.dart`,
// `habits_milestone_test.dart`, `stats_screen_test.dart`,
// `reminders_feature_test.dart`). This file holds what needs no harness: the
// help content, the words a screen reader hears, and a guard over `lib/`.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:habit_tracker/core/habits/habit_streak.dart';
import 'package:habit_tracker/core/widgets/feature_info.dart';
import 'package:habit_tracker/core/widgets/feature_info_content.dart';
import 'package:habit_tracker/features/habits/domain/habit_presentation.dart';
import 'package:habit_tracker/theme/app_theme.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  final rest = RegExp(r'rest[ -]days?', caseSensitive: false);

  final allInfo = <String, FeatureInfo>{
    'today': FeatureInfoContent.today,
    'tasks': FeatureInfoContent.tasks,
    'habits': FeatureInfoContent.habits,
    'timer': FeatureInfoContent.timer,
    'stats': FeatureInfoContent.stats,
  };

  group('help content', () {
    FeatureInfoSection freezes() => FeatureInfoContent.habits.sections
        .firstWhere((s) => s.heading == 'Freezes');

    test('the Habits help has a Freezes section and no Rest days one', () {
      final headings =
          FeatureInfoContent.habits.sections.map((s) => s.heading).toList();
      expect(headings, contains('Freezes'));
      expect(headings, isNot(contains('Rest days')));
    });

    test('it says a freeze is manual, not automatic', () {
      final body = freezes().body;
      // The missing information, not just a word swap: nothing in the app
      // applies a freeze to a missed day on its own.
      expect(body, contains('does not happen automatically'));
      expect(body, contains('Freeze this day'));
    });

    test('it says where to do it and what it covers, as the app really works',
        () {
      final body = freezes().body;
      // The day sheet opens from the habit's calendar...
      expect(body, contains('calendar'));
      // ...for today or an earlier scheduled day. `isEditableDay` excludes days
      // still to come, so the help must not promise otherwise.
      expect(body, contains('today'));
      expect(body, contains('not for days still to come'));
    });

    test('it explains the number beside the Habits title', () {
      expect(freezes().body, contains('number beside the title'));
      expect(freezes().body, contains('left this month'));
    });

    test('it says what happens past the allowance', () {
      expect(freezes().body, contains('counts as missed'));
    });

    test('the Stats help calls a frozen day frozen', () {
      final habitStreaks = FeatureInfoContent.stats.sections
          .firstWhere((s) => s.heading == 'Habit streaks');
      expect(habitStreaks.body, contains('a day you froze'));
    });

    for (final entry in allInfo.entries) {
      test('${entry.key} help never says "rest day" anywhere', () {
        final info = entry.value;
        final text = [
          info.title,
          info.summary,
          for (final s in info.sections) ...[s.heading, s.body],
        ].join('\n');
        expect(rest.hasMatch(text), isFalse,
            reason: 'found "rest day" in ${entry.key}');
      });
    }

    testWidgets('the sheet a user actually opens shows Freezes', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  showFeatureInfoSheet(context, FeatureInfoContent.habits),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('FREEZES'), findsOneWidget);
      expect(find.text('REST DAYS'), findsNothing);
      expect(find.textContaining('does not happen automatically'),
          findsOneWidget);
    });
  });

  group('what a screen reader hears', () {
    test('a frozen day is "frozen"', () {
      expect(HabitOutcomeText.of(HabitDayOutcome.neutral), 'frozen');
    });

    test('the other outcomes are unchanged', () {
      expect(HabitOutcomeText.of(HabitDayOutcome.done), 'done');
      expect(HabitOutcomeText.of(HabitDayOutcome.missed), 'missed');
      expect(HabitOutcomeText.of(HabitDayOutcome.pending), 'not done yet');
      expect(HabitOutcomeText.of(HabitDayOutcome.future), 'upcoming');
      expect(HabitOutcomeText.of(null), 'not scheduled');
    });

    test('the streak-safe line was already freeze and still is', () {
      expect(HabitDates.freezeUsedLabel('2026-09-22', '2026-09-23'),
          'Freeze used yesterday — streak safe');
    });
  });

  // The guard: a user-facing string is anything that is not a comment. The
  // words a `Text`, `Tooltip`, `SnackBar` or `Semantics` label surfaces are all
  // string literals in code, so a line of code that says "rest day" is a
  // string the user can read. Identifiers named after the old term
  // (`restDayAllowanceText`, `_restDays`) are deliberately not renamed and do
  // not match: they have no space or hyphen in them.
  group('lib/ guard', () {
    test('no user-facing string still says "rest day" or "rest days"', () {
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File) continue;
        final path = entity.path.replaceAll('\\', '/');
        if (!path.endsWith('.dart') || path.endsWith('.g.dart')) continue;

        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          // `//` and `///` comments are documentation, not user-facing.
          if (lines[i].trimLeft().startsWith('//')) continue;
          if (rest.hasMatch(lines[i])) {
            offenders.add('$path:${i + 1}: ${lines[i].trim()}');
          }
        }
      }

      expect(offenders, isEmpty,
          reason: 'These strings still call a freeze a "rest day":\n'
              '${offenders.join('\n')}');
    });

    test('the guard would notice one (sanity check of the pattern itself)', () {
      expect(rest.hasMatch("Text('Mark as rest day')"), isTrue);
      expect(rest.hasMatch("'2 of 2 rest days used this month'"), isTrue);
      expect(rest.hasMatch('Rest-day marked'), isTrue);
      // ...and leaves the retained identifiers alone.
      expect(rest.hasMatch('restDayAllowanceText(snapshot, date)'), isFalse);
      expect(rest.hasMatch('_restDays == 1'), isFalse);
    });
  });
}
