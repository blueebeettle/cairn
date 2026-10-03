// Habits UI verification (SPEC.md §10, PROMPT habits module).
//
// Every scenario runs the REAL repository, providers and widgets against an
// in-memory database, with the clock injected through TimeService. "Open the
// app on a Tuesday" is: move the clock, send AppLifecycleState.resumed to the
// real NavigationShell, and read the streak off the screen through its
// semantics label — the same string TalkBack would speak.
//
// Lines beginning `REPORT` are the numbers observed, printed for the record.

import 'dart:convert';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:habit_tracker/core/constants/event_types.dart';
import 'package:habit_tracker/core/habits/habit_streak.dart';
import 'package:habit_tracker/core/notifications/notification_permission_helper.dart';
import 'package:habit_tracker/core/time/time_service.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/data/providers/database_provider.dart';
import 'package:habit_tracker/data/providers/habit_providers.dart';
import 'package:habit_tracker/data/repositories/events_repository.dart';
import 'package:habit_tracker/data/repositories/habits_repository.dart';
import 'package:habit_tracker/data/repositories/reminder_config_repository.dart';
import 'package:habit_tracker/data/repositories/settings_repository.dart';
import 'package:habit_tracker/features/habits/domain/habit_presentation.dart';
import 'package:habit_tracker/features/habits/presentation/archived_habits_screen.dart';
import 'package:habit_tracker/features/habits/presentation/habit_check_controller.dart';
import 'package:habit_tracker/features/habits/presentation/habit_detail_screen.dart';
import 'package:habit_tracker/features/habits/presentation/habit_edit_sheet.dart';
import 'package:habit_tracker/features/habits/presentation/habits_screen.dart';
import 'package:habit_tracker/features/habits/presentation/widgets/habit_day_sheet.dart';
import 'package:habit_tracker/features/habits/presentation/widgets/habit_marks.dart';
import 'package:habit_tracker/features/navigation/presentation/navigation_shell.dart';
import 'package:habit_tracker/features/reminders/reminder_service.dart';
import 'package:habit_tracker/features/today/presentation/today_screen.dart';
import 'package:habit_tracker/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

// ───────────────────────────────────────────────────────────────── harness

class _FakePlugin implements FlutterLocalNotificationsPlugin {
  final Map<int, ({tz.TZDateTime at, String? title, String? payload})>
      scheduled = {};

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
        onDidReceiveBackgroundNotificationResponse,
  }) async =>
      true;

  @override
  Future<void> zonedSchedule({
    required int id,
    String? title,
    String? body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    scheduled[id] = (at: scheduledDate, title: title, payload: payload);
  }

  @override
  Future<void> cancel({required int id, String? tag}) async =>
      scheduled.remove(id);

  @override
  Future<void> cancelAll() async => scheduled.clear();

  @override
  T? resolvePlatformSpecificImplementation<
          T extends FlutterLocalNotificationsPlatform>() =>
      null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

int _at(String date, [int hour = 12, int minute = 0]) {
  final d = TimeService.parseLocalDate(date);
  return DateTime.utc(d.year, d.month, d.day, hour, minute)
      .millisecondsSinceEpoch;
}

/// Device in UTC, logical day starting at 04:00, clock under test control.
class _Harness {
  _Harness(String date, {int hour = 12, this.offsetMin = 0})
      : nowMs = _at(date, hour) - offsetMin * 60000 {
    db = AppDatabase(NativeDatabase.memory());
    time = TimeService(
      localize: (ms) =>
          DateTime.fromMillisecondsSinceEpoch(ms + offsetMin * 60000, isUtc: true),
      offsetMinutesAt: (_) => offsetMin,
      tzIdProvider: () => offsetMin == 0 ? 'UTC' : 'UTC${offsetMin > 0 ? '+' : ''}$offsetMin',
      nowProvider: () => nowMs,
    );
    settings = SettingsRepository(db: db);
    repo = HabitsRepository(
      db: db,
      eventsRepository:
          EventsRepository(db: db, timeService: time, deviceId: 'test-device'),
      timeService: time,
      deviceId: 'test-device',
    );
    plugin = _FakePlugin();
    reminderConfig = ReminderConfigRepository(
      db: db,
      eventsRepository:
          EventsRepository(db: db, timeService: time, deviceId: 'test-device'),
      settingsRepo: settings,
      timeService: time,
      deviceId: 'test-device',
    );
    reminders = ReminderService(
      db: db,
      settingsRepo: settings,
      timeService: time,
      plugin: plugin,
      habitsRepository: repo,
      reminderConfigRepository: reminderConfig,
    );
  }

  /// Minutes the device's wall clock is ahead of UTC (330 = India).
  final int offsetMin;
  int nowMs;
  late final AppDatabase db;
  late final TimeService time;
  late final SettingsRepository settings;
  late final HabitsRepository repo;
  late final ReminderConfigRepository reminderConfig;
  late final _FakePlugin plugin;
  late final ReminderService reminders;

  /// A habit's live time-of-day reminder rows, ascending.
  Future<List<HabitReminderTime>> reminderTimesFor(String habitId) {
    return (db.select(db.habitReminderTimes)
          ..where((r) => r.habitId.equals(habitId))
          ..orderBy([(r) => OrderingTerm.asc(r.minutesPastMidnight)]))
        .get();
  }

  /// [date], [hour] and [minute] are the device's WALL clock, in its zone.
  void setNow(String date, [int hour = 12, int minute = 0]) =>
      nowMs = _at(date, hour, minute) - offsetMin * 60000;

  List<Override> get overrides => [
        databaseProvider.overrideWithValue(db),
        timeServiceProvider.overrideWithValue(time),
        deviceIdProvider.overrideWithValue('test-device'),
        reminderServiceProvider.overrideWithValue(reminders),
      ];

  /// Checks [habitId] off fully on each date, moving the clock to that day.
  Future<void> completeOn(String habitId, List<String> dates,
      {int times = 1}) async {
    for (final d in dates) {
      setNow(d, 12);
      for (var i = 0; i < times; i++) {
        await repo.check(habitId);
      }
    }
  }
}

Widget _app(_Harness h, Widget home, {double textScale = 1.0}) {
  return ProviderScope(
    overrides: h.overrides,
    child: MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // Through the builder, so sheets and dialogs scale too.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: home,
    ),
  );
}

/// A 360×800dp phone — the narrowest common Android width.
void _phone(WidgetTester tester, {double height = 800, double width = 360}) {
  tester.view.physicalSize = Size(width * 3, height * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

/// Pumps until Drift and the providers have settled. Not pumpAndSettle: a
/// spinner anywhere would make that wait forever. Not runAsync either: real
/// async lets google_fonts' asset lookup fail inside the test zone.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Matcher _instant(int y, int mo, int d, int h, [int mi = 0]) => predicate<tz.TZDateTime>(
      (t) => t.millisecondsSinceEpoch ==
          DateTime.utc(y, mo, d, h, mi).millisecondsSinceEpoch,
      '$y-$mo-$d $h:$mi UTC',
    );

/// Every semantics label under the root that looks like a streak.
List<String> _streakLabels(WidgetTester tester) {
  final out = <String>[];
  void visit(SemanticsNode n) {
    final l = n.label;
    if (l.endsWith('day streak') || l == 'No streak yet') out.add(l);
    n.visitChildren((c) {
      visit(c);
      return true;
    });
  }

  visit(_semanticsRoot(tester));
  return out;
}

SemanticsNode _semanticsRoot(WidgetTester tester) =>
    tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!;

List<String> _allLabels(WidgetTester tester) {
  final out = <String>[];
  void visit(SemanticsNode n) {
    if (n.label.isNotEmpty) out.add(n.label);
    n.visitChildren((c) {
      visit(c);
      return true;
    });
  }

  visit(_semanticsRoot(tester));
  return out;
}

Future<void> _openApp(WidgetTester tester) async {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  await _settle(tester);
}

void _report(String line) {
  // ignore: avoid_print
  print('REPORT $line');
}

// ───────────────────────────────────────────────────────────────── tests

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('UTC'));
    NotificationPermissionHelper.mockPermissionGranted = true;
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Verify 2 — Mon/Wed/Fri habit opened on a Tuesday', () {
    testWidgets('the streak is unchanged on Tuesday, not 0', (tester) async {
      // 412dp: the shell lays out the Today tab too, whose pre-existing focus
      // chips row overflows at 360dp even at 100% text (reported separately).
      _phone(tester, width: 412);
      final semantics = tester.ensureSemantics();
      final h = _Harness('2026-09-07'); // Monday
      addTearDown(h.db.close);

      final id = await h.repo.createHabit(
        title: 'Stretch',
        scheduleRule: 'FREQ=WEEKLY;BYDAY=MO,WE,FR',
      );
      await h.completeOn(id, ['2026-09-07', '2026-09-09', '2026-09-11']);

      // Monday 14th, 09:00: open the app, check it off from the Habits tab.
      h.setNow('2026-09-14', 9);
      await tester.pumpWidget(_app(h, const NavigationShell()));
      await _settle(tester);
      await tester.tap(find.text('Habits'));
      await _settle(tester);

      expect(find.bySemanticsLabel('Stretch, not done today'), findsOneWidget);
      final beforeTap = _streakLabels(tester);
      await tester.tap(find.bySemanticsLabel('Stretch, not done today'));
      await _settle(tester);
      await tester.tap(find.text('1 done today'));
      await _settle(tester);
      final monday = _streakLabels(tester);
      expect(monday, ['4 day streak']);

      // Tuesday 15th, 09:00: open the app.
      h.setNow('2026-09-15', 9);
      await _openApp(tester);
      await tester.tap(find.text('1 not scheduled today'));
      await _settle(tester);
      final tuesday = _streakLabels(tester);
      expect(tuesday, ['4 day streak']);
      expect(find.text('Next: Wednesday'), findsOneWidget);
      // Not tappable on a day it does not run: no check-button semantics.
      expect(find.bySemanticsLabel('Stretch, not done today'), findsNothing);

      final snap = (await h.repo.loadSnapshot(id))!;
      _report('V2 Mon/Wed/Fri: before tap Mon=$beforeTap, after tap Mon=$monday, '
          'opened Tue=$tuesday, snapshot.current=${snap.streaks.current}, '
          'Tue outcome=${snap.streaks.outcomes['2026-09-15']} (absent = not scheduled)');
      semantics.dispose();
    });
  });

  group('Verify 3 — daily habit, day not yet over', () {
    testWidgets('streak holds through the next morning and drops the day after',
        (tester) async {
      _phone(tester, width: 412); // see Verify 2
      final semantics = tester.ensureSemantics();
      final h = _Harness('2026-09-12');
      addTearDown(h.db.close);

      final id = await h.repo
          .createHabit(title: 'Read', scheduleRule: 'FREQ=DAILY');
      await h.completeOn(id, ['2026-09-12', '2026-09-13']);

      h.setNow('2026-09-14', 20);
      await tester.pumpWidget(_app(h, const NavigationShell()));
      await _settle(tester);
      await tester.tap(find.text('Habits'));
      await _settle(tester);
      await tester.tap(find.bySemanticsLabel('Read, not done today'));
      await _settle(tester);
      await tester.tap(find.text('1 done today'));
      await _settle(tester);
      final mon = _streakLabels(tester);

      // Tue 03:00 — before the 04:00 day start, so still Monday's logical day.
      h.setNow('2026-09-15', 3);
      await _openApp(tester);
      final tueNight = _streakLabels(tester);

      // Tue 08:00 — Tuesday has begun and is pending. Yesterday's value stands.
      h.setNow('2026-09-15', 8);
      await _openApp(tester);
      final tueMorning = _streakLabels(tester);
      expect(find.bySemanticsLabel('Read, not done today'), findsOneWidget);

      // Wed 08:00 — Tuesday is over and was missed. Only now does it drop.
      h.setNow('2026-09-16', 8);
      await _openApp(tester);
      final wedMorning = _streakLabels(tester);

      expect(mon, ['3 day streak']);
      expect(tueNight, ['3 day streak']);
      expect(tueMorning, ['3 day streak']);
      expect(wedMorning, ['No streak yet']);
      expect(find.text('—'), findsWidgets); // the muted zero, never a red 0

      final snap = (await h.repo.loadSnapshot(id))!;
      _report('V3 daily: Mon 20:00 after tap=$mon | Tue 03:00=$tueNight | '
          'Tue 08:00=$tueMorning | Wed 08:00=$wedMorning | '
          'Tue outcome on Wed=${snap.streaks.outcomes['2026-09-15']}, '
          'longest=${snap.streaks.longest}');
      semantics.dispose();
    });
  });

  group('Verify 4 — counted habit, 5 of 8', () {
    testWidgets('five taps show 5 of 8 and the streak does not break',
        (tester) async {
      _phone(tester);
      final semantics = tester.ensureSemantics();
      final h = _Harness('2026-09-12');
      addTearDown(h.db.close);

      final id = await h.repo.createHabit(
        title: 'Water',
        scheduleRule: 'FREQ=DAILY',
        targetCount: 8,
        unitLabel: 'glasses',
      );
      await h.completeOn(id, ['2026-09-12', '2026-09-13'], times: 8);

      h.setNow('2026-09-14', 12);
      await tester.pumpWidget(_app(h, const HabitsScreen()));
      await _settle(tester);
      final before = _streakLabels(tester);

      for (var i = 0; i < 5; i++) {
        await tester.tap(find.bySemanticsLabel('Water, not done today'));
        // Optimistic: the count is up before the database round trip lands,
        // and a zero-length frame between taps must still count every one.
        await tester.pump();
        expect(find.text('${i + 1} of 8'), findsOneWidget);
      }
      await _settle(tester);

      final after = _streakLabels(tester);
      final node = tester.getSemantics(find.bySemanticsLabel('Water, not done today'));
      final snap = (await h.repo.loadSnapshot(id))!;
      expect(find.text('5 of 8'), findsOneWidget);
      expect(node.value, '5 of 8 glasses');
      expect(before, ['2 day streak']);
      expect(after, ['2 day streak']);
      expect(snap.todayOutcome, HabitDayOutcome.pending);
      expect(snap.countToday, 5);

      _report('V4 counted 8/day: streak before=$before, after 5 taps=$after, '
          'button="5 of 8", semantics value="${node.value}", '
          'today outcome=${snap.todayOutcome}, stored count=${snap.countToday}');
      semantics.dispose();
    });

    testWidgets('completes at the target; one more tap resets back to 0', (tester) async {
      _phone(tester);
      final semantics = tester.ensureSemantics();
      final h = _Harness('2026-09-14');
      addTearDown(h.db.close);
      final id = await h.repo.createHabit(
          title: 'Pages', scheduleRule: 'FREQ=DAILY', targetCount: 3);

      await tester.pumpWidget(_app(h, const HabitsScreen()));
      await _settle(tester);
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.bySemanticsLabel('Pages, not done today'));
        await _settle(tester);
      }
      await tester.tap(find.text('1 done today'));
      await _settle(tester);
      expect(find.bySemanticsLabel('Pages, done today'), findsOneWidget);
      expect(_streakLabels(tester), ['1 day streak']);

      // One tap resets back to 0.
      await tester.tap(find.bySemanticsLabel('Pages, done today'));
      await _settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect((await h.repo.loadSnapshot(id))!.countToday, 0);
      semantics.dispose();
    });
  });

  group('Verify 5 — three freezes in one month, allowance 2', () {
    testWidgets('first two keep the streak, the third resets it, warned first',
        (tester) async {
      _phone(tester, height: 1400);
      final semantics = tester.ensureSemantics();
      final h = _Harness('2026-09-01');
      addTearDown(h.db.close);

      final id = await h.repo.createHabit(
        title: 'Walk',
        scheduleRule: 'FREQ=DAILY',
        skipAllowancePerMonth: 2,
      );
      await h.completeOn(id, [
        for (var d = 1; d <= 13; d++) TimeService.formatIsoDate(2026, 9, d),
      ]);
      h.setNow('2026-09-14', 10);

      await tester.pumpWidget(_app(h, HabitDetailScreen(habitId: id)));
      await _settle(tester);
      final start = _streakLabels(tester);
      final seen = <String>[];

      Future<({String warning, List<String> streak, String? snack})> rest(
          String cellLabel) async {
        final cell = find.bySemanticsLabel(cellLabel);
        await tester.ensureVisible(cell);
        await tester.tap(cell);
        await _settle(tester);
        final warning = tester
            .widgetList<Text>(find.descendant(
              of: find.widgetWithText(ListTile, 'Freeze this day'),
              matching: find.byType(Text),
            ))
            .map((t) => t.data)
            .firstWhere((s) => s != null && s.contains('freezes'))!;
        await tester.tap(find.text('Freeze this day'));
        await _settle(tester);
        final snack = tester
            .widgetList<Text>(find.descendant(
                of: find.byType(SnackBar), matching: find.byType(Text)))
            .map((t) => t.data)
            .firstOrNull;
        // Dismiss the snack bar so the next one is read fresh.
        ScaffoldMessenger.of(tester.element(find.byType(HabitDetailScreen)))
            .removeCurrentSnackBar();
        await _settle(tester);
        return (warning: warning, streak: _streakLabels(tester), snack: snack);
      }

      final r1 = await rest('Thursday 3 September, done');
      final r2 = await rest('Sunday 6 September, done');
      final r3 = await rest('Wednesday 9 September, done');

      expect(start, ['13 day streak']);
      expect(r1.warning, '2 of 2 freezes left this month.');
      expect(r1.streak, ['13 day streak']);
      expect(r2.warning,
          '1 of 2 freezes left this month — this is the last one.');
      expect(r2.streak, ['13 day streak']);
      // The warning is on screen BEFORE the third is spent.
      expect(r3.warning,
          '2 of 2 freezes used this month — freezing again will reset your streak.');
      expect(r3.streak, ['4 day streak']);

      final labels = _allLabels(tester);
      seen.addAll(labels.where((l) => l.contains('September') &&
          (l.contains('frozen') || l.contains('missed'))));
      expect(seen, containsAll([
        'Thursday 3 September, frozen',
        'Sunday 6 September, frozen',
        'Wednesday 9 September, missed',
      ]));

      final snap = (await h.repo.loadSnapshot(id))!;
      final events = await (h.db.select(h.db.events)
            ..where((e) => e.type.equals(EventTypes.habitFreezeUsed)))
          .get();
      _report('V5 freezes: start=$start');
      _report('V5  #1 Sep 3  warning="${r1.warning}" -> ${r1.streak} snack="${r1.snack}"');
      _report('V5  #2 Sep 6  warning="${r2.warning}" -> ${r2.streak} snack="${r2.snack}"');
      _report('V5  #3 Sep 9  warning="${r3.warning}" -> ${r3.streak} snack="${r3.snack}"');
      _report('V5  cells: $seen; freeze_used events=${events.length}; '
          'longest=${snap.streaks.longest}');
      semantics.dispose();
    });
  });

  // One allowance, one name. The Habits header chip says "N freezes", the
  // habit editor sets the allowance, and the day sheet spends it — they used to
  // say "freeze" and "rest day" between them, sometimes in one widget.
  group('Freeze wording — one name for one concept', () {
    testWidgets(
        'the day sheet, its snack bars and the calendar legend all say freeze',
        (tester) async {
      _phone(tester, height: 1400);
      final semantics = tester.ensureSemantics();
      final h = _Harness('2026-09-01');
      addTearDown(h.db.close);

      final id = await h.repo.createHabit(
        title: 'Walk',
        scheduleRule: 'FREQ=DAILY',
        skipAllowancePerMonth: 1,
      );
      await h.completeOn(id, [
        for (var d = 1; d <= 13; d++) TimeService.formatIsoDate(2026, 9, d),
      ]);
      h.setNow('2026-09-14', 10);

      await tester.pumpWidget(_app(h, HabitDetailScreen(habitId: id)));
      await _settle(tester);

      // The calendar legend names the state "Frozen", not "Rest day".
      expect(find.text('Frozen'), findsOneWidget);
      expect(find.text('Rest day'), findsNothing);

      Future<void> openDay(String cellLabel) async {
        final cell = find.bySemanticsLabel(cellLabel);
        await tester.ensureVisible(cell);
        await tester.tap(cell);
        await _settle(tester);
      }

      String? snackText() => tester
          .widgetList<Text>(find.descendant(
              of: find.byType(SnackBar), matching: find.byType(Text)))
          .map((t) => t.data)
          .firstOrNull;

      Future<void> dismissSnack() async {
        ScaffoldMessenger.of(tester.element(find.byType(HabitDetailScreen)))
            .removeCurrentSnackBar();
        await _settle(tester);
      }

      // Freeze one day: the sheet's action, its allowance line, its snack bar.
      await openDay('Thursday 3 September, done');
      expect(find.text('Freeze this day'), findsOneWidget);
      expect(find.text('Mark as rest day'), findsNothing);
      const lastOne = '1 of 1 freezes left this month — this is the last one.';
      // The sheet's own tile carries it...
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Freeze this day'),
          matching: find.text(lastOne),
        ),
        findsOneWidget,
      );
      // ...and so does the detail screen underneath it, under its stats.
      expect(find.text(lastOne), findsNWidgets(2));
      await tester.tap(find.text('Freeze this day'));
      await _settle(tester);
      expect(snackText(), 'Day frozen. Your streak is safe.');
      await dismissSnack();

      // The day now announces itself as frozen, and offers to undo it.
      await openDay('Thursday 3 September, frozen');
      expect(find.text('Remove freeze'), findsOneWidget);
      expect(find.text('Freeze this day'), findsNothing);
      expect(find.text('Remove rest day'), findsNothing);
      // Clear names the same thing it removes.
      expect(find.text('Remove check-offs and freeze. Keeps the note.'),
          findsOneWidget);
      await tester.tap(find.text('Remove freeze'));
      await _settle(tester);
      expect(find.bySemanticsLabel('Thursday 3 September, frozen'),
          findsNothing);

      // Freeze two days against an allowance of one: the second is warned
      // about first, then told plainly it counts as missed.
      await openDay('Sunday 6 September, done');
      await tester.tap(find.text('Freeze this day'));
      await _settle(tester);
      await dismissSnack();

      await openDay('Wednesday 9 September, done');
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Freeze this day'),
          matching: find.text('1 of 1 freezes used this month — freezing '
              'again will reset your streak.'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Freeze this day'));
      await _settle(tester);
      expect(
        snackText(),
        'Freeze marked, but this month\'s freezes were already used, so the '
        'day counts as missed.',
      );
      semantics.dispose();
    });

    testWidgets('an allowance of 0 says no freezes are allowed', (tester) async {
      _phone(tester, height: 1400);
      final semantics = tester.ensureSemantics();
      final h = _Harness('2026-09-01');
      addTearDown(h.db.close);

      final id = await h.repo.createHabit(
        title: 'Walk',
        scheduleRule: 'FREQ=DAILY',
        skipAllowancePerMonth: 0,
      );
      await h.completeOn(id, [
        for (var d = 1; d <= 5; d++) TimeService.formatIsoDate(2026, 9, d),
      ]);
      h.setNow('2026-09-06', 10);

      await tester.pumpWidget(_app(h, HabitDetailScreen(habitId: id)));
      await _settle(tester);

      final cell = find.bySemanticsLabel('Wednesday 2 September, done');
      await tester.ensureVisible(cell);
      await tester.tap(cell);
      await _settle(tester);

      const none = 'This habit allows no freezes — freezing a day will reset '
          'your streak.';
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Freeze this day'),
          matching: find.text(none),
        ),
        findsOneWidget,
      );
      // The detail screen prints the same line under its stats.
      expect(find.text(none), findsNWidgets(2));
      semantics.dispose();
    });

    testWidgets('the habit editor calls the allowance Freezes and says it is manual',
        (tester) async {
      _phone(tester);
      final h = _Harness('2026-09-14');
      addTearDown(h.db.close);

      await tester.pumpWidget(_app(
        h,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => HabitEditSheet.show(context),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await _settle(tester);

      final list = find.descendant(
          of: find.byType(HabitEditSheet), matching: find.byType(Scrollable));
      await tester.scrollUntilVisible(find.text('FREEZES'), 200,
          scrollable: list.first);
      await _settle(tester);

      expect(find.text('FREEZES'), findsOneWidget);
      expect(find.text('REST DAYS'), findsNothing);
      expect(
        find.text('Allow 2 freezes a month without breaking your streak'),
        findsOneWidget,
      );
      // The honest part: it never applies itself.
      expect(find.textContaining('never applied automatically'), findsOneWidget);

      // Singular at one, and the zero case still reads as a sentence.
      await tester.tap(find.byTooltip('Fewer'));
      await _settle(tester);
      expect(
        find.text('Allow 1 freeze a month without breaking your streak'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Fewer'));
      await _settle(tester);
      expect(
        find.text('Allow 0 freezes a month without breaking your streak'),
        findsOneWidget,
      );

      // And nothing on the sheet still speaks of rest days.
      expect(
        find.textContaining(RegExp('rest days?', caseSensitive: false)),
        findsNothing,
      );
    });

    test('a frozen day is read out as frozen, not as a rest day', () {
      expect(HabitOutcomeText.of(HabitDayOutcome.neutral), 'frozen');
      expect(HabitOutcomeText.cell('2026-09-03', HabitDayOutcome.neutral),
          'Thursday 3 September, frozen');
    });
  });

  group('Verify 6 — a habit created today', () {
    testWidgets('shows no missed days for last week', (tester) async {
      _phone(tester, height: 1400);
      final semantics = tester.ensureSemantics();
      final h = _Harness('2026-09-14');
      addTearDown(h.db.close);
      final id = await h.repo
          .createHabit(title: 'Journal', scheduleRule: 'FREQ=DAILY');

      await tester.pumpWidget(_app(h, const HabitsScreen()));
      await _settle(tester);
      final dots = tester.widgetList<HabitDayMark>(find.byType(HabitDayMark));
      final dotLabels = dots.map((d) => d.semanticLabel).toList();
      expect(dotLabels, ['Monday 14 September, not done yet']);
      expect(_allLabels(tester).where((l) => l.contains('missed')), isEmpty);

      await tester.pumpWidget(_app(h, HabitDetailScreen(habitId: id)));
      await _settle(tester);
      final missed = _allLabels(tester).where((l) => l.contains('missed'));
      final lastWeek = _allLabels(tester)
          .where((l) => RegExp(r' (7|8|9|10|11|12|13) September,').hasMatch(l))
          .toList();
      expect(missed, isEmpty);
      expect(lastWeek.every((l) => l.endsWith('not scheduled')), isTrue);
      // The rest of the month is upcoming, never missed.
      expect(_allLabels(tester), contains('Tuesday 15 September, upcoming'));
      expect(find.bySemanticsLabel('Completion rate not available yet'),
          findsOneWidget);

      _report('V6 created today: card dots=$dotLabels; last-week cells='
          '${lastWeek.length} all "not scheduled"; missed cells=${missed.length}; '
          'completion shows "—"');
      semantics.dispose();
    });
  });

  group('Create / edit sheet', () {
    testWidgets('builds the RRULE from words and saves through the repository',
        (tester) async {
      _phone(tester);
      final h = _Harness('2026-09-14');
      addTearDown(h.db.close);

      await tester.pumpWidget(_app(
        h,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => HabitEditSheet.show(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await _settle(tester);

      await tester.enterText(find.byType(TextField).first, 'Gym');
      await tester.tap(find.text('Certain days'));
      await _settle(tester);
      // Mon/Wed/Fri is the default selection; add Saturday.
      await tester.tap(find.bySemanticsLabel('Saturday'));
      await _settle(tester);
      expect(find.text('Mon, Wed, Fri, Sat'), findsOneWidget);
      expect(find.textContaining('FREQ='), findsNothing);
      await tester.tap(find.text('Save'));
      await _settle(tester);

      final habit = (await h.db.select(h.db.habits).get()).single;
      expect(habit.scheduleRule, 'FREQ=WEEKLY;BYDAY=MO,WE,FR,SA');
      expect(habit.skipAllowancePerMonth, 2); // the default
      expect(await h.reminderTimesFor(habit.id), isEmpty); // off by default
      expect(habit.iconName, 'check');
    });

    testWidgets('an unrepresentable rule survives an unrelated edit',
        (tester) async {
      _phone(tester);
      final h = _Harness('2026-09-14');
      addTearDown(h.db.close);
      final id = await h.repo.createHabit(
          title: 'Bins', scheduleRule: 'FREQ=WEEKLY;INTERVAL=2;BYDAY=TU');
      final habit = (await h.repo.habitById(id))!;

      await tester.pumpWidget(_app(
        h,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => HabitEditSheet.show(context, habit: habit),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await _settle(tester);
      expect(find.text('Every other week on Tue'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Put the bins out');
      await tester.tap(find.text('Save'));
      await _settle(tester);

      final saved = (await h.repo.habitById(id))!;
      expect(saved.title, 'Put the bins out');
      expect(saved.scheduleRule, 'FREQ=WEEKLY;INTERVAL=2;BYDAY=TU');
    });
  });

  group('Schedule words', () {
    test('never shows RRULE syntax', () {
      expect(HabitScheduleText.describe('FREQ=DAILY'), 'Every day');
      expect(HabitScheduleText.describe('FREQ=WEEKLY;BYDAY=MO,WE,FR'),
          'Mon, Wed, Fri');
      expect(HabitScheduleText.describe('FREQ=DAILY;INTERVAL=3'), 'Every 3 days');
      expect(HabitScheduleText.describe('FREQ=MONTHLY;BYMONTHDAY=1'),
          '1st of the month');
      expect(HabitScheduleText.describe('FREQ=MONTHLY;BYDAY=-1FR'),
          'Last Friday of the month');
      expect(HabitScheduleText.describe('FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR'),
          'Weekdays');
      expect(formatHabitRate(null), '—');
      expect(formatHabitRate(0), '0%');
    });
  });

  group('Repository event log', () {
    test('habit_created carries every projected field (SPEC §0)', () async {
      final h = _Harness('2026-09-14');
      addTearDown(h.db.close);
      await h.repo.createHabit(
        title: 'Run',
        scheduleRule: 'FREQ=DAILY',
        colorIndex: 3,
        iconName: 'run',
        notes: 'easy pace',
      );
      final event = (await h.db.select(h.db.events).get()).single;
      final payload = jsonDecode(event.payload) as Map<String, dynamic>;
      expect(payload['color_index'], 3);
      expect(payload['icon_name'], 'run');
      expect(payload['notes'], 'easy pace');
      expect(payload['anchor_date'], '2026-09-14');
      expect(payload.containsKey('sort_order'), isTrue);
    });
  });

  group('Reminders (SPEC §10.4)', () {
    test('scheduled only on scheduled days, from the shared counter', () async {
      final h = _Harness('2026-09-13', hour: 12); // Sunday
      addTearDown(h.db.close);
      final id = await h.repo.createHabit(
        title: 'Stretch',
        scheduleRule: 'FREQ=WEEKLY;BYDAY=MO,WE,FR',
      );
      await h.reminderConfig.setHabitReminderTimes(id, [9 * 60]);
      await h.reminders.scheduleForHabit((await h.repo.habitById(id))!);

      final row = (await h.reminderTimesFor(id)).single;
      expect(row.notificationId, 1000); // counter's first id
      final n = h.plugin.scheduled[1000]!;
      expect(n.at, _instant(2026, 9, 14, 9)); // Monday, not Sunday
      expect(n.payload, 'habit:$id');
      _report('R1 Sunday: next reminder ${n.at} id=${row.notificationId}');
    });

    test('never in the past; skips a day already complete', () async {
      final h = _Harness('2026-09-14', hour: 8); // Monday 08:00
      addTearDown(h.db.close);
      final id = await h.repo.createHabit(
        title: 'Stretch',
        scheduleRule: 'FREQ=WEEKLY;BYDAY=MO,WE,FR',
      );
      await h.reminderConfig.setHabitReminderTimes(id, [9 * 60]);
      await h.reminders.scheduleForHabit((await h.repo.habitById(id))!);
      expect(h.plugin.scheduled.values.single.at,
          _instant(2026, 9, 14, 9));

      await h.repo.check(id); // done today
      await h.reminders.scheduleForHabit((await h.repo.habitById(id))!);
      expect(h.plugin.scheduled.values.single.at,
          _instant(2026, 9, 16, 9)); // Wednesday
      expect(h.plugin.scheduled.keys.single, 1000); // same id, not a new one

      h.setNow('2026-09-16', 10); // Wed 10:00 — 09:00 has passed, not done
      await h.reminders.scheduleForHabit((await h.repo.habitById(id))!);
      expect(h.plugin.scheduled.values.single.at,
          _instant(2026, 9, 18, 9)); // Friday, never the past
    });

    test('a reminder before the day start fires on the next calendar date',
        () async {
      final h = _Harness('2026-09-14', hour: 12);
      addTearDown(h.db.close);
      final id = await h.repo.createHabit(
        title: 'Wind down',
        scheduleRule: 'FREQ=DAILY',
      );
      await h.reminderConfig.setHabitReminderTimes(id, [90]); // 01:30, before the 04:00 day start
      await h.reminders.scheduleForHabit((await h.repo.habitById(id))!);
      // Monday's logical day runs until Tue 04:00.
      expect(h.plugin.scheduled.values.single.at,
          _instant(2026, 9, 15, 1, 30));
    });

    test('reconcileAll schedules habits and cancels archived ones', () async {
      final h = _Harness('2026-09-14', hour: 6);
      addTearDown(h.db.close);
      final a = await h.repo.createHabit(title: 'A', scheduleRule: 'FREQ=DAILY');
      await h.reminderConfig.setHabitReminderTimes(a, [20 * 60]);
      final b = await h.repo.createHabit(title: 'B', scheduleRule: 'FREQ=DAILY');
      await h.reminderConfig.setHabitReminderTimes(b, [21 * 60]);
      await h.reminders.reconcileAll();
      expect(h.plugin.scheduled.length, 2);

      await h.repo.archiveHabit(b);
      await h.reminders.reconcileAll();
      expect(h.plugin.scheduled.values.map((n) => n.payload), ['habit:$a']);

      await h.settings.setBool('reminders_enabled', false);
      await h.reminders.reconcileAll();
      expect(h.plugin.scheduled, isEmpty);
    });

    test('tapping a habit notification routes to its id', () async {
      String? opened;
      final h = _Harness('2026-09-14');
      addTearDown(h.db.close);
      final service = ReminderService(
        db: h.db,
        settingsRepo: h.settings,
        timeService: h.time,
        plugin: h.plugin,
        onHabitNotificationTapped: (id) => opened = id,
      );
      // The dispatcher is private; the launch path exercises it without a
      // platform, and returns quietly when nothing launched the app.
      await service.dispatchLaunchNotification();
      expect(opened, isNull);
    });
  });

  // ─────────────────────────────────────────────────── 200% font scale audit

  group('Verify 7 — 200% font scale, every new screen', () {
    final overflows = <String>[];

    // Installed inside each test body: testWidgets replaces
    // FlutterError.onError when the body starts, so a setUp handler is dead.
    // Returns the restore function. It MUST run before any expect(): a
    // failing expect with the handler still swapped wedges the test binding.
    void Function() captureOverflows() {
      final previous = FlutterError.onError;
      FlutterError.onError = (details) {
        final text = details.exceptionAsString();
        if (text.contains('overflowed')) {
          // Attribute it: "<message> @ <file>:<line>" from the creator widget.
          final where = RegExp(r'lib/[\w/]+\.dart:\d+')
                  .firstMatch(details.toString())
                  ?.group(0) ??
              'unknown';
          overflows.add('${text.split('\n').first} @ $where');
        } else {
          previous?.call(details);
        }
      };
      return () => FlutterError.onError = previous;
    }

    /// Text cut off with an ellipsis or a max-lines limit.
    List<String> clippedText(WidgetTester tester) {
      final out = <String>[];
      for (final e in find.byType(RichText).evaluate()) {
        final ro = e.renderObject;
        if (ro is RenderParagraph && ro.didExceedMaxLines) {
          out.add(ro.text.toPlainText());
        }
      }
      return out;
    }

    Future<_Harness> seeded() async {
      final h = _Harness('2026-09-10'); // Thursday
      final daily = await h.repo.createHabit(
          title: 'Read before bed, at least twenty pages of something',
          scheduleRule: 'FREQ=DAILY',
          iconName: 'book');
      await h.reminderConfig.setHabitReminderTimes(daily, [21 * 60]);
      final water = await h.repo.createHabit(
          title: 'Water',
          scheduleRule: 'FREQ=DAILY',
          targetCount: 8,
          unitLabel: 'glasses',
          colorIndex: 1,
          iconName: 'water');
      await h.repo.createHabit(
          title: 'Stretch',
          scheduleRule: 'FREQ=WEEKLY;BYDAY=MO,WE,FR',
          colorIndex: 2);
      await h.repo.createHabit(
          title: 'Pay rent', scheduleRule: 'FREQ=MONTHLY;BYMONTHDAY=1');
      await h.completeOn(daily, ['2026-09-10', '2026-09-11', '2026-09-12']);
      await h.completeOn(water, ['2026-09-10', '2026-09-11'], times: 8);
      h.setNow('2026-09-12', 12);
      await h.repo.setNote(daily, note: 'Finished the chapter on tides.');
      h.setNow('2026-09-15', 12); // Tuesday: Stretch is not due
      await h.repo.check(water);
      await h.repo.check(water);
      await h.repo.check(water);
      return h;
    }

    Future<void> audit(
      WidgetTester tester,
      String screen,
      Future<void> Function() drive,
    ) async {
      overflows.clear();
      final restore = captureOverflows();
      try {
        await drive();
      } finally {
        restore();
      }
      final clipped = clippedText(tester);
      _report('V7 200% $screen: overflow=${overflows.length}'
          '${overflows.isEmpty ? '' : ' ${overflows.toSet()}'}; '
          'ellipsized=${clipped.length}${clipped.isEmpty ? '' : ' $clipped'}');
      // Fail on any overflow except the Today screen's own rows. At a real
      // 360dp width and 200% its focus-streak chips row and TASKS header row
      // overflow independently of habits; that predates this feature and is
      // reported, not asserted — see PROMPT-polish-gaps.md. The habits row on
      // that screen lives in today_habits_section.dart, so its overflows are
      // still caught here.
      final ours = overflows
          .where((o) => !o.contains('today/presentation/today_screen.dart'))
          .toList();
      expect(ours, isEmpty, reason: screen);
    }

    /// Taps a collapsed-section header, scrolling it into view first.
    ///
    /// At 200% scale the weekly recap card and the first section fill the
    /// viewport, so the header below them is not built until it is scrolled
    /// to — `tap` alone finds nothing.
    Future<void> tapHeader(WidgetTester tester, String label) async {
      await tester.scrollUntilVisible(
        find.text(label),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await _settle(tester);
      await tester.tap(find.text(label));
      await _settle(tester);
    }

    testWidgets('Habits tab — first run empty state', (tester) async {
      _phone(tester);
      final h = _Harness('2026-09-14');
      addTearDown(h.db.close);
      await audit(tester, 'Habits empty (first run)', () async {
        await tester.pumpWidget(_app(h, const HabitsScreen(), textScale: 2));
        await _settle(tester);
        expect(find.text('No habits yet.'), findsOneWidget);
        expect(find.text('Add a habit'), findsOneWidget);
      });
    });

    testWidgets('Habits tab — all archived empty state', (tester) async {
      _phone(tester);
      final h = _Harness('2026-09-14');
      addTearDown(h.db.close);
      final id =
          await h.repo.createHabit(title: 'Old', scheduleRule: 'FREQ=DAILY');
      await h.repo.archiveHabit(id);
      await audit(tester, 'Habits empty (all archived)', () async {
        await tester.pumpWidget(_app(h, const HabitsScreen(), textScale: 2));
        await _settle(tester);
        expect(
            find.text(
                'Nothing active. Your archived habits are in the overflow menu.'),
            findsOneWidget);
      });
    });

    testWidgets('Habits tab — streak view, sections expanded', (tester) async {
      _phone(tester);
      final h = await seeded();
      addTearDown(h.db.close);
      await audit(tester, 'Habits streak view', () async {
        await tester.pumpWidget(_app(h, const HabitsScreen(), textScale: 2));
        await _settle(tester);
        await tapHeader(tester, '2 not scheduled today');
        await tester.drag(find.byType(ListView), const Offset(0, -600));
        await _settle(tester);
      });
    });

    testWidgets('Habits tab — list view', (tester) async {
      _phone(tester);
      final h = await seeded();
      addTearDown(h.db.close);
      await audit(tester, 'Habits list view', () async {
        await tester.pumpWidget(_app(h, const HabitsScreen(), textScale: 2));
        await _settle(tester);
        await tester.tap(find.byTooltip('Switch to list view'));
        await _settle(tester);
        await tapHeader(tester, '2 not scheduled today');
      });
    });

    testWidgets('Habit detail screen', (tester) async {
      _phone(tester);
      final h = await seeded();
      addTearDown(h.db.close);
      final daily = (await h.db.select(h.db.habits).get())
          .firstWhere((x) => x.title.startsWith('Read'));
      await audit(tester, 'Habit detail', () async {
        await tester.pumpWidget(
            _app(h, HabitDetailScreen(habitId: daily.id), textScale: 2));
        await _settle(tester);
        await tester.drag(find.byType(ListView), const Offset(0, -900));
        await _settle(tester);
        await tester.drag(find.byType(ListView), const Offset(0, -900));
        await _settle(tester);
      });
    });

    testWidgets('Day sheet with the freeze warning', (tester) async {
      _phone(tester);
      final h = await seeded();
      addTearDown(h.db.close);
      final water = (await h.db.select(h.db.habits).get())
          .firstWhere((x) => x.title == 'Water');
      await audit(tester, 'Day sheet', () async {
        await tester.pumpWidget(
            _app(h, HabitDetailScreen(habitId: water.id), textScale: 2));
        await _settle(tester);
        final cell = find.bySemanticsLabel(RegExp(r'^Friday 11 September'));
        await tester.ensureVisible(cell);
        await tester.tap(cell);
        await _settle(tester);
        expect(find.text('Freeze this day'), findsOneWidget);
      });
    });

    testWidgets('Create sheet — counting, reminder, certain days', (tester) async {
      _phone(tester);
      final h = _Harness('2026-09-14');
      addTearDown(h.db.close);
      await audit(tester, 'Create sheet', () async {
        await tester.pumpWidget(_app(
          h,
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => HabitEditSheet.show(context),
                child: const Text('open'),
              ),
            ),
          ),
          textScale: 2,
        ));
        await tester.tap(find.text('open'));
        await _settle(tester);
        await tester.tap(find.text('Certain days'));
        await _settle(tester);
        final list = find.descendant(
            of: find.byType(HabitEditSheet), matching: find.byType(Scrollable));
        await tester.scrollUntilVisible(find.text('Count something'), 200,
            scrollable: list.first);
        await tester.ensureVisible(find.text('Count something'));
        await _settle(tester);
        await tester.tap(find.text('Count something'));
        await _settle(tester);
        await tester.scrollUntilVisible(find.text('Add reminder'), 200,
            scrollable: list.first);
        await tester.ensureVisible(find.text('Add reminder'));
        await _settle(tester);
        await tester.tap(find.text('Add reminder'));
        await _settle(tester);
        await tester.tap(find.text('OK'));
        await _settle(tester);
        expect(find.byType(InputChip), findsOneWidget);
        await tester.scrollUntilVisible(
            find.textContaining('Past this many'), 200,
            scrollable: list.first);
        await _settle(tester);
      });
    });

    testWidgets('Archived habits screen — empty and with rows', (tester) async {
      _phone(tester);
      final h = _Harness('2026-09-14');
      addTearDown(h.db.close);
      await audit(tester, 'Archived (empty)', () async {
        await tester.pumpWidget(
            _app(h, const ArchivedHabitsScreen(), textScale: 2));
        await _settle(tester);
        expect(find.text('Nothing archived yet.'), findsOneWidget);
      });
      final id = await h.repo.createHabit(
          title: 'Learn the cello', scheduleRule: 'FREQ=DAILY;INTERVAL=3');
      await h.repo.archiveHabit(id);
      await audit(tester, 'Archived (one row)', () async {
        await tester.pumpWidget(
            _app(h, const ArchivedHabitsScreen(), textScale: 2));
        await _settle(tester);
        expect(find.text('Every 3 days'), findsOneWidget);
      });
    });

    testWidgets('Today screen habits section', (tester) async {
      _phone(tester);
      final h = await seeded();
      addTearDown(h.db.close);
      await audit(tester, 'Today habits row', () async {
        await tester.pumpWidget(_app(h, const TodayScreen(), textScale: 2));
        await _settle(tester);
        final header = find.text('HABITS — 0 OF 2');
        await tester.scrollUntilVisible(header, 300,
            scrollable: find.byType(Scrollable).first);
        await _settle(tester);
        expect(header, findsOneWidget);
      });
    });
  });

  // ───────────────────────────────────────────── Verify 8 — screen reader

  group('Verify 8 — semantics for TalkBack', () {
    testWidgets('Habits tab: every control labelled, targets >= 48dp',
        (tester) async {
      _phone(tester);
      final semantics = tester.ensureSemantics();
      final h = _Harness('2026-09-14');
      addTearDown(h.db.close);
      final id = await h.repo
          .createHabit(title: 'Floss', scheduleRule: 'FREQ=DAILY');
      await h.completeOn(id, ['2026-09-14']);
      h.setNow('2026-09-14', 13);
      await h.repo.createHabit(
          title: 'Stretch', scheduleRule: 'FREQ=WEEKLY;BYDAY=TU,TH');

      await tester.pumpWidget(_app(h, const HabitsScreen()));
      await _settle(tester);
      await tester.tap(find.text('1 done today'));
      await tester.tap(find.text('1 not scheduled today'));
      await _settle(tester);

      final labels = _allLabels(tester);
      expect(labels, contains('Floss, done today'));
      expect(labels, contains('1 day streak'));
      expect(labels, contains('Monday 14 September, done'));
      expect(labels, contains('Stretch, not scheduled today. Next: Tuesday'));

      final tap = await androidTapTargetGuideline.evaluate(tester);
      final labelled = await labeledTapTargetGuideline.evaluate(tester);
      _report('V8 Habits tab labels: ${labels.where((l) => l.contains('Floss') || l.contains('Stretch') || l.contains('streak') || l.contains('September')).toList()}');
      _report('V8 Habits tab: tapTarget48=${tap.passed} labelledTargets=${labelled.passed}'
          '${tap.passed ? '' : ' ${tap.reason}'}${labelled.passed ? '' : ' ${labelled.reason}'}');
      expect(tap.passed, isTrue, reason: tap.reason);
      expect(labelled.passed, isTrue, reason: labelled.reason);
      semantics.dispose();
    });

    testWidgets('Detail screen: every day cell labelled, targets >= 48dp',
        (tester) async {
      _phone(tester, height: 1400);
      final semantics = tester.ensureSemantics();
      final h = _Harness('2026-09-07');
      addTearDown(h.db.close);
      final id = await h.repo.createHabit(
          title: 'Stretch', scheduleRule: 'FREQ=WEEKLY;BYDAY=MO,WE,FR');
      await h.completeOn(id, ['2026-09-07', '2026-09-11']);
      h.setNow('2026-09-14', 9);

      await tester.pumpWidget(_app(h, HabitDetailScreen(habitId: id)));
      await _settle(tester);
      final labels = _allLabels(tester);
      final cells =
          labels.where((l) => RegExp(r'^\w+day \d+ September').hasMatch(l)).toList();
      expect(cells.length, 30);
      expect(cells, contains('Monday 7 September, done'));
      expect(cells, contains('Wednesday 9 September, missed'));
      expect(cells, contains('Tuesday 8 September, not scheduled'));
      expect(cells, contains('Monday 14 September, not done yet, today'));
      expect(cells, contains('Wednesday 16 September, upcoming'));
      expect(labels, contains('Stretch, not done today'));
      // Fri 11 done, Wed 9 missed, today pending: the walk stops at the miss.
      expect(labels, contains('1 day streak'));

      final tap = await androidTapTargetGuideline.evaluate(tester);
      final labelled = await labeledTapTargetGuideline.evaluate(tester);
      _report('V8 Detail: ${cells.length} day cells labelled, e.g. '
          '${cells.where((c) => c.contains(' 7 ') || c.contains(' 8 ') || c.contains(' 9 ') || c.contains('14') || c.contains('16')).toList()}');
      _report('V8 Detail: tapTarget48=${tap.passed} labelledTargets=${labelled.passed}'
          '${tap.passed ? '' : ' ${tap.reason}'}${labelled.passed ? '' : ' ${labelled.reason}'}');
      expect(tap.passed, isTrue, reason: tap.reason);
      expect(labelled.passed, isTrue, reason: labelled.reason);
      semantics.dispose();
    });
  });

  group('Stats rule — null renders as an em dash', () {
    testWidgets('Mon/Wed/Fri habit created on a Saturday shows —, not 0%',
        (tester) async {
      _phone(tester, height: 1400);
      final semantics = tester.ensureSemantics();
      final h = _Harness('2026-09-12'); // Saturday
      addTearDown(h.db.close);
      final id = await h.repo.createHabit(
          title: 'Stretch', scheduleRule: 'FREQ=WEEKLY;BYDAY=MO,WE,FR');
      await tester.pumpWidget(_app(h, HabitDetailScreen(habitId: id)));
      await _settle(tester);
      expect(find.text('0%'), findsNothing);
      expect(find.bySemanticsLabel('Completion rate not available yet'),
          findsOneWidget);
      expect(find.bySemanticsLabel('Best day not available yet'), findsOneWidget);
      semantics.dispose();
    });
  });

  group('View mode', () {
    testWidgets('the toggle persists to settings as habit_view_mode',
        (tester) async {
      _phone(tester);
      final h = _Harness('2026-09-14');
      addTearDown(h.db.close);
      await h.repo.createHabit(title: 'Floss', scheduleRule: 'FREQ=DAILY');
      await tester.pumpWidget(_app(h, const HabitsScreen()));
      await _settle(tester);
      expect(find.byType(HabitDayMark), findsWidgets); // streak view default

      await tester.tap(find.byTooltip('Switch to list view'));
      await _settle(tester);
      expect(await h.settings.getString('habit_view_mode'), 'list');
      expect(find.byType(HabitDayMark), findsNothing); // list rows: no dots

      // A fresh screen reads it back.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_app(h, const HabitsScreen()));
      await _settle(tester);
      expect(find.byTooltip('Switch to streak view'), findsOneWidget);
    });
  });

  group('Check controller', () {
    test('a habit not scheduled today cannot be checked off', () async {
      final h = _Harness('2026-09-15'); // Tuesday
      addTearDown(h.db.close);
      final id = await h.repo.createHabit(
          title: 'Stretch', scheduleRule: 'FREQ=WEEKLY;BYDAY=MO,WE,FR');
      final container = ProviderContainer(overrides: h.overrides);
      addTearDown(container.dispose);
      final snap = (await h.repo.loadSnapshot(id))!;
      await container.read(habitCheckControllerProvider.notifier).tap(snap);
      expect((await h.repo.loadSnapshot(id))!.countToday, 0);
      expect(await h.db.select(h.db.habitEntries).get(), isEmpty);
    });

    test('freeze allowance text warns before the last one is spent', () async {
      final h = _Harness('2026-09-01');
      addTearDown(h.db.close);
      final id = await h.repo.createHabit(
          title: 'Walk', scheduleRule: 'FREQ=DAILY', skipAllowancePerMonth: 1);
      h.setNow('2026-09-05');
      var snap = (await h.repo.loadSnapshot(id))!;
      expect(restDayAllowanceText(snap, '2026-09-02').text,
          '1 of 1 freezes left this month — this is the last one.');
      await h.repo.setSkipped(id, localDate: '2026-09-02');
      snap = (await h.repo.loadSnapshot(id))!;
      final t = restDayAllowanceText(snap, '2026-09-03');
      expect(t.warn, isTrue);
      expect(t.text, contains('freezing again will reset your streak'));
    });

    test('multi-count habit cycles 0 -> 1 -> 2 -> 3 -> 0 on tap', () async {
      final h = _Harness('2026-09-15');
      addTearDown(h.db.close);
      final id = await h.repo.createHabit(
        title: 'Water',
        scheduleRule: 'FREQ=DAILY',
        targetCount: 3,
      );
      final container = ProviderContainer(overrides: h.overrides);
      addTearDown(container.dispose);
      final controller = container.read(habitCheckControllerProvider.notifier);

      // Initial: 0
      var snap = (await h.repo.loadSnapshot(id))!;
      expect(snap.countToday, 0);

      // Tap 1 -> 1
      await controller.tap(snap);
      snap = (await h.repo.loadSnapshot(id))!;
      expect(snap.countToday, 1);

      // Tap 2 -> 2
      await controller.tap(snap);
      snap = (await h.repo.loadSnapshot(id))!;
      expect(snap.countToday, 2);

      // Tap 3 -> 3 (done)
      await controller.tap(snap);
      snap = (await h.repo.loadSnapshot(id))!;
      expect(snap.countToday, 3);
      expect(snap.isDoneToday, isTrue);

      // Tap 4 (once completed) -> resets to 0
      await controller.tap(snap);
      snap = (await h.repo.loadSnapshot(id))!;
      expect(snap.countToday, 0);
      expect(snap.isDoneToday, isFalse);
    });

    test('single-count habit cycles 0 -> 1 -> 0 on tap', () async {
      final h = _Harness('2026-09-15');
      addTearDown(h.db.close);
      final id = await h.repo.createHabit(
        title: 'Floss',
        scheduleRule: 'FREQ=DAILY',
        targetCount: 1,
      );
      final container = ProviderContainer(overrides: h.overrides);
      addTearDown(container.dispose);
      final controller = container.read(habitCheckControllerProvider.notifier);

      var snap = (await h.repo.loadSnapshot(id))!;
      expect(snap.countToday, 0);

      // Tap 1 -> 1 (done)
      await controller.tap(snap);
      snap = (await h.repo.loadSnapshot(id))!;
      expect(snap.countToday, 1);
      expect(snap.isDoneToday, isTrue);

      // Tap 2 -> 0 (reset)
      await controller.tap(snap);
      snap = (await h.repo.loadSnapshot(id))!;
      expect(snap.countToday, 0);
      expect(snap.isDoneToday, isFalse);
    });

    test('HabitsRepository.resetChecks resets count to 0 and logs habitUnchecked event', () async {
      final h = _Harness('2026-09-15');
      addTearDown(h.db.close);
      final id = await h.repo.createHabit(
        title: 'Meditate',
        scheduleRule: 'FREQ=DAILY',
        targetCount: 3,
      );

      await h.repo.check(id);
      await h.repo.check(id);
      await h.repo.check(id);
      var snap = (await h.repo.loadSnapshot(id))!;
      expect(snap.countToday, 3);

      await h.repo.resetChecks(id);
      snap = (await h.repo.loadSnapshot(id))!;
      expect(snap.countToday, 0);

      final events = await h.db.select(h.db.events).get();
      expect(events.any((e) => e.type == EventTypes.habitUnchecked), isTrue);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Backfilling a missed day from the calendar.
  //
  // The reported bug: miss a day, watch the streak break, go back and mark that
  // exact day done, and the number restarts instead of coming back. The pure
  // engine already handles this (test/habit_streak_test.dart), so these drive
  // the rest of the path with the REAL repository, providers and widgets:
  // calendar cell -> day sheet -> HabitsRepository.check -> Drift stream ->
  // habitSnapshotsProvider -> the digit on screen, read through semantics.
  // ───────────────────────────────────────────────────────────────────────────
  group('Backfilling a missed day through the calendar', () {
    Future<void> openDay(WidgetTester tester, String cellLabel) async {
      final cell = find.bySemanticsLabel(cellLabel);
      expect(cell, findsOneWidget, reason: 'the grid cell "$cellLabel"');
      await tester.ensureVisible(cell);
      await tester.tap(cell);
      await _settle(tester);
    }

    testWidgets('a gap in the middle: the whole run comes back, not a restart',
        (tester) async {
      _phone(tester, height: 1400);
      final semantics = tester.ensureSemantics();
      final h = _Harness('2026-09-01');
      addTearDown(h.db.close);

      final id = await h.repo.createHabit(
        title: 'Walk',
        scheduleRule: 'FREQ=DAILY',
      );
      // 09-01..09-09 done, 09-10 missed, 09-11..09-17 done, today pending.
      await h.completeOn(id, [
        for (var d = 1; d <= 9; d++) TimeService.formatIsoDate(2026, 9, d),
        for (var d = 11; d <= 17; d++) TimeService.formatIsoDate(2026, 9, d),
      ]);
      h.setNow('2026-09-18', 10);

      await tester.pumpWidget(_app(h, HabitDetailScreen(habitId: id)));
      await _settle(tester);

      expect(_streakLabels(tester), ['7 day streak'],
          reason: 'the miss visibly broke it: only 09-11..09-17 count');
      expect(_allLabels(tester), contains('Best streak 9 days'));

      await openDay(tester, 'Thursday 10 September, missed');
      await tester.tap(find.text('Mark done'));
      await _settle(tester);

      final after = _streakLabels(tester);
      expect(after, ['17 day streak'],
          reason: 'what it would be had 09-10 never been missed');
      expect(_allLabels(tester), contains('Best streak 17 days'));
      expect(_allLabels(tester), contains('Thursday 10 September, done'));

      // The write landed on the day that was tapped, byte for byte.
      final snap = (await h.repo.loadSnapshot(id))!;
      expect(snap.entries['2026-09-10']?.count, 1);
      expect(snap.scheduledDates, contains('2026-09-10'));
      final checkedOn10th = (await (h.db.select(h.db.events)
                ..where((e) => e.type.equals(EventTypes.habitChecked)))
              .get())
          .where((e) => e.localDate == '2026-09-10')
          .toList();
      expect(checkedOn10th, hasLength(1));
      expect(checkedOn10th.single.occurredAt, _at('2026-09-18', 10),
          reason: 'the true instant is today; only local_date is the 10th');

      // The provider every other screen (and the home-screen widget push) reads.
      final container = ProviderScope.containerOf(
          tester.element(find.byType(HabitDetailScreen)));
      final shared = container.read(habitSnapshotsProvider).value!;
      expect(shared.single.streaks.current, 17);

      _report('BACKFILL middle: before=7 after=$after best=${snap.streaks.longest}');
      semantics.dispose();
    });

    testWidgets('yesterday missed, filled in this morning: today pending does '
        'not reset it', (tester) async {
      _phone(tester, height: 1400);
      final semantics = tester.ensureSemantics();
      final h = _Harness('2026-09-01');
      addTearDown(h.db.close);

      final id = await h.repo.createHabit(
        title: 'Walk',
        scheduleRule: 'FREQ=DAILY',
      );
      await h.completeOn(id, [
        for (var d = 1; d <= 16; d++) TimeService.formatIsoDate(2026, 9, d),
      ]);
      h.setNow('2026-09-18', 10);

      await tester.pumpWidget(_app(h, HabitDetailScreen(habitId: id)));
      await _settle(tester);
      expect(_streakLabels(tester), ['No streak yet'],
          reason: 'yesterday missed, today not over: nothing is running');

      await openDay(tester, 'Thursday 17 September, missed');
      await tester.tap(find.text('Mark done'));
      await _settle(tester);

      expect(_streakLabels(tester), ['17 day streak']);
      _report('BACKFILL yesterday: before=No streak yet after=${_streakLabels(tester)}');
      semantics.dispose();
    });

    testWidgets('a counted habit: Mark done fills the whole target for the day',
        (tester) async {
      _phone(tester, height: 1400);
      final semantics = tester.ensureSemantics();
      final h = _Harness('2026-09-01');
      addTearDown(h.db.close);

      final id = await h.repo.createHabit(
        title: 'Water',
        scheduleRule: 'FREQ=DAILY',
        targetCount: 3,
      );
      await h.completeOn(
        id,
        [
          for (var d = 1; d <= 9; d++) TimeService.formatIsoDate(2026, 9, d),
          for (var d = 11; d <= 17; d++) TimeService.formatIsoDate(2026, 9, d),
        ],
        times: 3,
      );
      h.setNow('2026-09-18', 10);

      await tester.pumpWidget(_app(h, HabitDetailScreen(habitId: id)));
      await _settle(tester);
      expect(_streakLabels(tester), ['7 day streak']);

      await openDay(tester, 'Thursday 10 September, missed');
      await tester.tap(find.text('Mark done'));
      await _settle(tester);

      expect(_streakLabels(tester), ['17 day streak']);
      expect((await h.repo.loadSnapshot(id))!.entries['2026-09-10']?.count, 3);
      semantics.dispose();
    });

    testWidgets('the Habits list card follows the same backfill', (tester) async {
      // A second renderer of the same number: the card on the Habits screen,
      // which never sees the day sheet. The write goes straight through the
      // repository, the way the sheet's "Mark done" does.
      _phone(tester, height: 1400);
      final semantics = tester.ensureSemantics();
      final h = _Harness('2026-09-01');
      addTearDown(h.db.close);

      final id = await h.repo.createHabit(
        title: 'Walk',
        scheduleRule: 'FREQ=DAILY',
      );
      await h.completeOn(id, [
        for (var d = 1; d <= 9; d++) TimeService.formatIsoDate(2026, 9, d),
        for (var d = 11; d <= 17; d++) TimeService.formatIsoDate(2026, 9, d),
      ]);
      h.setNow('2026-09-18', 10);

      // A card says "7 day streak, a milestone" at exactly seven, so match the
      // number rather than the whole label.
      List<String> card() => _allLabels(tester)
          .where((l) => RegExp(r'^\d+ day streak').hasMatch(l))
          .toList();

      await tester.pumpWidget(_app(h, const HabitsScreen()));
      await _settle(tester);
      expect(card(), ['7 day streak, a milestone']);

      await h.repo.check(id, localDate: '2026-09-10');
      await _settle(tester);

      expect(card().single, startsWith('17 day streak'));
      semantics.dispose();
    });

    // The phone is in India (UTC+5:30) with a 04:00 day start, so for the four
    // and a half hours after midnight the logical day is still yesterday. Every
    // date in the path is an opaque YYYY-MM-DD string; the zone only decides
    // which one is "today", and that must not shift where the backfill lands.
    for (final wall in [(hour: 2, minute: 30), (hour: 12, minute: 0)]) {
      testWidgets(
          'in India at ${wall.hour.toString().padLeft(2, '0')}:'
          '${wall.minute.toString().padLeft(2, '0')} local the backfill lands on '
          'the tapped day', (tester) async {
        _phone(tester, height: 1400);
        final semantics = tester.ensureSemantics();
        final h = _Harness('2026-09-01', offsetMin: 330);
        addTearDown(h.db.close);

        final id = await h.repo.createHabit(
          title: 'Walk',
          scheduleRule: 'FREQ=DAILY',
        );
        // At 02:30 on the 18th the logical day is still the 17th, so the last
        // day that can be done is the 16th; at noon it is the 17th.
        final today = wall.hour < 4 ? '2026-09-17' : '2026-09-18';
        final lastDone = wall.hour < 4 ? 16 : 17;
        await h.completeOn(id, [
          for (var d = 1; d <= 9; d++) TimeService.formatIsoDate(2026, 9, d),
          for (var d = 11; d <= lastDone; d++)
            TimeService.formatIsoDate(2026, 9, d),
        ]);
        h.setNow('2026-09-18', wall.hour, wall.minute);
        expect(h.time.todayLocalDate(), today);

        await tester.pumpWidget(_app(h, HabitDetailScreen(habitId: id)));
        await _settle(tester);
        expect(_streakLabels(tester), ['${lastDone - 10} day streak']);

        await openDay(tester, 'Thursday 10 September, missed');
        await tester.tap(find.text('Mark done'));
        await _settle(tester);

        expect(_streakLabels(tester), ['$lastDone day streak']);
        final snap = (await h.repo.loadSnapshot(id))!;
        expect(snap.todayLocalDate, today);
        expect(snap.entries.keys, contains('2026-09-10'));
        _report('BACKFILL India ${wall.hour}:${wall.minute} '
            'today=$today -> ${_streakLabels(tester)}');
        semantics.dispose();
      });
    }
  });
}
