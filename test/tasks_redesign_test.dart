import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/data/providers/database_provider.dart';
import 'package:habit_tracker/data/repositories/tasks_repository.dart';
import 'package:habit_tracker/features/habits/presentation/widgets/habit_check_burst.dart';
import 'package:habit_tracker/features/tasks/presentation/tasks_screen.dart';
import 'package:habit_tracker/features/tasks/presentation/widgets/task_priority_dot.dart';
import 'package:habit_tracker/features/tasks/presentation/widgets/task_summary_cards.dart';
import 'package:habit_tracker/theme/app_theme.dart';

const _today = '2026-09-23';

TaskWithDetails _task({
  required String id,
  required String title,
  int? priority,
  String status = 'open',
}) => TaskWithDetails(
  task: Task(
    id: id,
    title: title,
    priority: priority ?? 4,
    status: status,
    createdAt: 1000,
    createdLocalDate: _today,
    rescheduleCount: 0,
    sortOrder: 0.0,
    dueIsAllDay: false,
    updatedAt: 1000,
    deviceId: 'device-test',
    completedAt: status == 'done' ? 2000 : null,
    completedLocalDate: status == 'done' ? _today : null,
  ),
);

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  final themes = <String, ThemeData Function()>{
    'light': () => AppTheme.light,
    'dark': () => AppTheme.dark,
  };

  Widget host(ThemeData theme, Widget child) => MaterialApp(
    theme: theme,
    home: Scaffold(body: child),
  );

  Widget tasksScreen(ThemeData theme, List<TaskWithDetails> tasks) =>
      ProviderScope(
        overrides: [
          todayTasksStreamProvider.overrideWith(
            (ref, date) => Stream.value(tasks),
          ),
        ],
        child: MaterialApp(
          theme: theme,
          home: const Scaffold(body: TasksScreen()),
        ),
      );

  // ── Today's progress ──────────────────────────────────────────────────────

  group("TodayProgressCard", () {
    test('fraction and label track what has been cleared', () {
      for (final (open, done, fraction, label) in [
        (7, 0, 0.0, '0 / 7 cleared'),
        (3, 4, 4 / 7, '4 / 7 cleared'),
        (1, 3, 0.75, '3 / 4 cleared'),
        (0, 5, 1.0, '5 / 5 cleared'),
      ]) {
        final card = TodayProgressCard(open: open, done: done);
        expect(card.fraction, closeTo(fraction, 1e-9), reason: label);
        expect(card.label, label);
        expect(card.total, open + done);
      }
    });

    test('no tasks is 0, not a division by zero', () {
      // The screen early-returns to its empty state before reaching this, but
      // the card must not blow up on its own.
      const card = TodayProgressCard(open: 0, done: 0);
      expect(card.fraction, 0);
      expect(card.fraction.isNaN, isFalse);
      expect(card.label, '0 / 0 cleared');
    });

    for (final entry in themes.entries) {
      testWidgets('renders the bar at the right value (${entry.key})', (
        tester,
      ) async {
        await tester.pumpWidget(
          host(entry.value(), const TodayProgressCard(open: 3, done: 4)),
        );
        await tester.pumpAndSettle();

        expect(find.text("TODAY'S PROGRESS"), findsOneWidget);
        expect(find.text('4 / 7 cleared'), findsOneWidget);

        final bar = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        expect(bar.value, closeTo(4 / 7, 1e-9));
        expect(bar.minHeight, 10);
        expect(bar.backgroundColor, entry.value().extension<AppTokens>()!.lineSoft);
      });
    }

    testWidgets('appears above the task list on the Tasks screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        tasksScreen(AppTheme.light, [
          _task(id: 't1', title: 'Open one'),
          _task(id: 't2', title: 'Cleared one', status: 'done'),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 / 2 cleared'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(TodayProgressCard)).dy,
        lessThan(tester.getTopLeft(find.text('Open one')).dy),
      );
    });
  });

  // ── Done today ────────────────────────────────────────────────────────────

  group('DoneTodayCard', () {
    test('counts read naturally at the edges', () {
      expect(
        const DoneTodayCard(done: 4, remaining: 3).clearedLabel,
        '4 tasks cleared',
      );
      expect(
        const DoneTodayCard(done: 1, remaining: 3).clearedLabel,
        '1 task cleared',
      );
      // Nothing done yet reads as a start, not as a zero score.
      expect(
        const DoneTodayCard(done: 0, remaining: 3).clearedLabel,
        'Nothing cleared yet',
      );

      expect(const DoneTodayCard(done: 4, remaining: 3).remainingLabel, '3 to go');
      expect(const DoneTodayCard(done: 4, remaining: 1).remainingLabel, '1 to go');
      // An empty list is finished, not "0 to go".
      expect(const DoneTodayCard(done: 4, remaining: 0).remainingLabel, 'All clear');
    });

    for (final entry in themes.entries) {
      testWidgets('renders both halves (${entry.key})', (tester) async {
        await tester.pumpWidget(
          host(entry.value(), const DoneTodayCard(done: 4, remaining: 3)),
        );
        await tester.pumpAndSettle();

        expect(find.text('4 tasks cleared'), findsOneWidget);
        expect(find.text('3 to go'), findsOneWidget);
      });
    }

    testWidgets('sits below the list and leaves the expand row alone', (
      tester,
    ) async {
      await tester.pumpWidget(
        tasksScreen(AppTheme.light, [
          _task(id: 't1', title: 'Open one'),
          _task(id: 't2', title: 'Cleared one', status: 'done'),
        ]),
      );
      await tester.pumpAndSettle();

      // The pre-existing expand/collapse control is still there.
      expect(find.text('1 done'), findsOneWidget);
      expect(find.text('1 task cleared'), findsOneWidget);
      expect(find.text('1 to go'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(DoneTodayCard)).dy,
        greaterThan(tester.getTopLeft(find.text('Open one')).dy),
      );
    });
  });

  // ── Priority dot ──────────────────────────────────────────────────────────

  group('TaskPriorityDot', () {
    // Same mapping as _buildTaskCard's switch, which stays the one source.
    // One test per priority: a single pumpWidget-in-a-loop reuses the element
    // tree and the screen keeps the first task list it saw.
    for (final priority in [1, 2, 3, 4]) {
      testWidgets('p$priority takes the matching colour', (tester) async {
        final theme = AppTheme.light;
        final tokens = theme.extension<AppTokens>()!;
        final expected = switch (priority) {
          1 => tokens.danger,
          2 => tokens.warning,
          3 => tokens.series[1],
          _ => Colors.transparent,
        };

        await tester.pumpWidget(
          tasksScreen(theme, [
            _task(id: 't1', title: 'Task P$priority', priority: priority),
          ]),
        );
        await tester.pumpAndSettle();

        final dot = tester.widget<TaskPriorityDot>(
          find.byType(TaskPriorityDot),
        );
        expect(dot.color, expected);

        // p4 resolves transparent and draws nothing at all.
        expect(dot.isVisible, priority <= 3);
        expect(
          find.descendant(
            of: find.byType(TaskPriorityDot),
            matching: find.byType(DecoratedBox),
          ),
          priority <= 3 ? findsOneWidget : findsNothing,
        );
      });
    }

    testWidgets('an unprioritised task gets no dot', (tester) async {
      await tester.pumpWidget(
        tasksScreen(AppTheme.light, [_task(id: 't1', title: 'Plain task')]),
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget<TaskPriorityDot>(find.byType(TaskPriorityDot)).isVisible,
        isFalse,
      );
    });

    testWidgets('a completed task drops its dot', (tester) async {
      await tester.pumpWidget(
        tasksScreen(AppTheme.light, [
          _task(id: 't1', title: 'Still open'),
          _task(id: 't2', title: 'Urgent done', priority: 1, status: 'done'),
        ]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 done'));
      await tester.pumpAndSettle();

      final dots = tester
          .widgetList<TaskPriorityDot>(find.byType(TaskPriorityDot))
          .toList();
      expect(dots, hasLength(2));
      expect(dots.every((d) => !d.isVisible), isTrue);
    });

    testWidgets('renders nothing when transparent, a dot otherwise', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(AppTheme.light, const TaskPriorityDot(color: Colors.transparent)),
      );
      expect(find.byType(DecoratedBox), findsNothing);

      await tester.pumpWidget(
        host(AppTheme.light, const TaskPriorityDot(color: Color(0xFFB3261E))),
      );
      final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox));
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, const Color(0xFFB3261E));
      expect(decoration.shape, BoxShape.circle);
    });
  });

  // ── Checkbox burst ────────────────────────────────────────────────────────

  group('task checkbox burst', () {
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

    // One instance reused: MaterialApp's AnimatedTheme lerps between two
    // equal-but-distinct ThemeDatas, and Color.lerp(c, c, t) is not bit-exact.
    // `late` because AppTheme reaches into google_fonts, which needs the test
    // binding up — a group body runs at collection time.
    late final ThemeData theme = AppTheme.light;

    Widget wrapped({required bool done}) => host(
      theme,
      HabitCheckBurst(
        done: done,
        diameter: 48,
        child: Center(child: Checkbox(value: done, onChanged: (_) {})),
      ),
    );

    testWidgets('the task checkbox is wrapped in the shared burst', (
      tester,
    ) async {
      await tester.pumpWidget(
        tasksScreen(AppTheme.light, [_task(id: 't1', title: 'Open one')]),
      );
      await tester.pumpAndSettle();

      expect(
        find.ancestor(
          of: find.byType(Checkbox),
          matching: find.byType(HabitCheckBurst),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<HabitCheckBurst>(find.byType(HabitCheckBurst).first)
            .diameter,
        48,
      );
    });

    testWidgets('fires on false -> true', (tester) async {
      await tester.pumpWidget(wrapped(done: false));
      expect(flecks(tester), isEmpty);

      await tester.pumpWidget(wrapped(done: true));
      await tester.pump(const Duration(milliseconds: 60));

      final mid = flecks(tester);
      expect(mid, hasLength(3));
      expect(mid, everyElement(isIn(AppTokens.light.series)));

      await tester.pump(const Duration(milliseconds: 200));
      expect(flecks(tester), isEmpty);
    });

    testWidgets('does not fire on an undo', (tester) async {
      await tester.pumpWidget(wrapped(done: true));
      await tester.pumpAndSettle();

      await tester.pumpWidget(wrapped(done: false));
      await tester.pump(const Duration(milliseconds: 60));

      expect(flecks(tester), isEmpty);
    });

    testWidgets('does not fire for a task that was already done', (
      tester,
    ) async {
      await tester.pumpWidget(
        tasksScreen(AppTheme.light, [
          _task(id: 't1', title: 'Open one'),
          _task(id: 't2', title: 'Already done', status: 'done'),
        ]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('1 done'));
      await tester.pump(const Duration(milliseconds: 60));

      expect(flecks(tester), isEmpty);
    });
  });
}
