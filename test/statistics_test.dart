import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/stats/statistics.dart';
import 'package:habit_tracker/core/time/time_service.dart';

/// Tests for SPEC.md §4.2, §4.4-4.8 and §4.13.
///
/// Written from SPEC.md, not from the implementation - §7 is explicit that a
/// test derived from the code confirms the bug. Every expected value below was
/// computed independently before the engine was written.
///
/// Two zones, because those are the two Cairn will actually live in:
///
///   America/Edmonton  UTC-7, UTC-6 in summer, so DST is exercised rather than
///                     assumed away. In 2026 it springs forward on Sunday
///                     8 March (02:00 -> 03:00) and falls back on Sunday
///                     1 November (02:00 -> 01:00).
///   Asia/Kolkata      UTC+5:30, no DST, ever. The half hour is the point: a
///                     local hour boundary there falls at :30 past the UTC
///                     hour, so any arithmetic that quietly assumes whole-hour
///                     offsets breaks in India and nowhere else.
///
/// They are 11.5 hours apart, which is what makes SPEC §7 Fixture B (see
/// `relocation_test.dart`) worth having.
void main() {
  // ── Zone constants, in minutes east of UTC ───────────────────────────────
  const edmontonSummer = -360; // MDT
  const edmontonWinter = -420; // MST
  const kolkata = 330; // IST

  /// The UTC instant at which a clock running at [offsetMin] reads these
  /// fields. Exact and unambiguous, because the offset is given rather than
  /// looked up - which also means a wrong epoch constant cannot creep into a
  /// test premise the way a hand-typed one can.
  int at(int y, int mo, int d, int h, int mi, int offsetMin) =>
      DateTime.utc(y, mo, d, h, mi).millisecondsSinceEpoch - offsetMin * 60000;

  /// SPEC.md §1.2 - the logical date an instant falls on, with the default
  /// 04:00 day start. The app computes this once at write time; the stats
  /// engine only ever reads the stored string. Reproduced here so the fixtures
  /// carry realistic dates.
  String logicalDate(int utcMs, int offsetMin) {
    final local = DateTime.fromMillisecondsSinceEpoch(
      utcMs + offsetMin * 60000,
      isUtc: true,
    );
    final minutesIntoDay = local.hour * 60 + local.minute;
    final shifted = DateTime.utc(
      local.year,
      local.month,
      local.day + (minutesIntoDay < 240 ? -1 : 0),
    );
    return TimeService.formatIsoDate(shifted.year, shifted.month, shifted.day);
  }

  SessionRecord session({
    String id = 's',
    required int startedAtUtcMs,
    required int endedAtUtcMs,
    required int actualDurationS,
    int tzOffsetMin = edmontonSummer,
    String outcome = 'completed',
    int internal = 0,
    int external = 0,
    int? rating,
    String? projectId,
  }) {
    return SessionRecord(
      id: id,
      localDate: logicalDate(startedAtUtcMs, tzOffsetMin),
      startedAtUtcMs: startedAtUtcMs,
      endedAtUtcMs: endedAtUtcMs,
      actualDurationS: actualDurationS,
      outcome: outcome,
      tzOffsetMin: tzOffsetMin,
      interruptionsInternal: internal,
      interruptionsExternal: external,
      focusRating: rating,
      projectId: projectId,
    );
  }

  /// A 25-minute completed session starting at the given local hour on
  /// Tuesday 15 September 2026, in Edmonton unless told otherwise.
  SessionRecord pomodoroAt(int hour,
          {String id = 'p', int tzOffsetMin = edmontonSummer}) =>
      session(
        id: id,
        startedAtUtcMs: at(2026, 9, 15, hour, 0, tzOffsetMin),
        endedAtUtcMs: at(2026, 9, 15, hour, 25, tzOffsetMin),
        actualDurationS: 1500,
        tzOffsetMin: tzOffsetMin,
      );

  group('§1.2 logical day, in both zones', () {
    test('before the 04:00 day start the session belongs to yesterday', () {
      expect(logicalDate(at(2026, 3, 8, 1, 30, edmontonWinter), edmontonWinter),
          equals('2026-03-07'));
      expect(logicalDate(at(2026, 9, 15, 3, 30, kolkata), kolkata),
          equals('2026-09-14'));
      expect(logicalDate(at(2026, 9, 15, 0, 15, kolkata), kolkata),
          equals('2026-09-14'));
    });

    test('from 04:00 onwards it belongs to today', () {
      expect(logicalDate(at(2026, 9, 15, 4, 1, kolkata), kolkata),
          equals('2026-09-15'));
      expect(logicalDate(at(2026, 9, 15, 23, 50, kolkata), kolkata),
          equals('2026-09-15'));
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  group('§4.1 focus minutes (the shared denominator)', () {
    test('seconds are summed per day before being converted', () {
      // Three 59-second sessions on one day are 2 minutes, not 0.
      final sessions = [
        for (var i = 0; i < 3; i++)
          session(
            id: 'x$i',
            startedAtUtcMs: at(2026, 9, 15, 9 + i, 0, edmontonSummer),
            endedAtUtcMs: at(2026, 9, 15, 9 + i, 1, edmontonSummer),
            actualDurationS: 59,
          ),
      ];
      expect(focusMinutesByDate(sessions)['2026-09-15'], equals(2));
      expect(focusMinutesTotal(sessions), equals(2));
    });

    test('abandoned sessions contribute zero', () {
      final sessions = [
        pomodoroAt(9, id: 'done'),
        session(
          id: 'gone',
          startedAtUtcMs: at(2026, 9, 15, 11, 0, edmontonSummer),
          endedAtUtcMs: at(2026, 9, 15, 12, 0, edmontonSummer),
          actualDurationS: 3600,
          outcome: 'abandoned',
        ),
      ];
      expect(focusMinutesTotal(sessions), equals(25));
    });

    test('a session that crossed midnight lands on its starting day only', () {
      final sessions = [
        session(
          startedAtUtcMs: at(2026, 9, 15, 23, 30, edmontonSummer),
          endedAtUtcMs: at(2026, 9, 16, 0, 30, edmontonSummer),
          actualDurationS: 3600,
        ),
      ];
      final byDate = focusMinutesByDate(sessions);
      expect(byDate['2026-09-15'], equals(60));
      expect(byDate.containsKey('2026-09-16'), isFalse);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  group('§4.2 session completion rate', () {
    test('seven completed and three abandoned is 70%', () {
      final sessions = [
        for (var i = 0; i < 7; i++) pomodoroAt(9, id: 'c$i'),
        for (var i = 0; i < 3; i++)
          session(
            id: 'a$i',
            startedAtUtcMs: at(2026, 9, 15, 10, 0, edmontonSummer),
            endedAtUtcMs: at(2026, 9, 15, 10, 8, edmontonSummer),
            actualDurationS: 480,
            outcome: 'abandoned',
          ),
      ];
      final r = CompletionRate.of(sessions);
      expect(r.completed, equals(7));
      expect(r.abandoned, equals(3));
      expect(r.total, equals(10));
      expect(r.rate, closeTo(0.7, 1e-12));
    });

    test('no sessions at all is UNDEFINED, not zero', () {
      // SPEC.md §4: a zero that means "no data" is a lie the user will act on.
      expect(CompletionRate.of(const []).rate, isNull);
    });

    test('all abandoned is a DEFINED zero, not undefined', () {
      // The mirror of the case above, and the one that gets conflated with it.
      // The user really did fail to complete anything; 0% is the true answer
      // and an em dash here would hide it.
      final r = CompletionRate.of([
        session(
          startedAtUtcMs: at(2026, 9, 15, 10, 0, edmontonSummer),
          endedAtUtcMs: at(2026, 9, 15, 10, 8, edmontonSummer),
          actualDurationS: 480,
          outcome: 'abandoned',
        ),
      ]);
      expect(r.rate, isNotNull);
      expect(r.rate, equals(0.0));
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  group('§4.4 peak window', () {
    test('a session spanning three hours is split by actual overlap', () {
      // 09:40 → 11:10, no pausing: 20 minutes in the 9 bin, 60 in the 10 bin,
      // 10 in the 11 bin. NOT 90 minutes dumped into the 9 bin.
      final s = session(
        startedAtUtcMs: at(2026, 9, 15, 9, 40, edmontonSummer),
        endedAtUtcMs: at(2026, 9, 15, 11, 10, edmontonSummer),
        actualDurationS: 5400,
      );
      final bins = PeakWindow.apportionToHourBins(s);
      expect(bins[9], closeTo(20.0, 1e-9));
      expect(bins[10], closeTo(60.0, 1e-9));
      expect(bins[11], closeTo(10.0, 1e-9));
      expect(bins.reduce((a, b) => a + b), closeTo(90.0, 1e-9));
    });

    test('paused time is excluded, so the bins total focus minutes', () {
      // Same 90-minute wall-clock span, but only 60 minutes focused. The bins
      // must total 60 so the chart agrees with the §4.1 figure beside it.
      final s = session(
        startedAtUtcMs: at(2026, 9, 15, 9, 40, edmontonSummer),
        endedAtUtcMs: at(2026, 9, 15, 11, 10, edmontonSummer),
        actualDurationS: 3600,
      );
      final bins = PeakWindow.apportionToHourBins(s);
      expect(bins[9], closeTo(40.0 / 3, 1e-9));
      expect(bins[10], closeTo(40.0, 1e-9));
      expect(bins[11], closeTo(20.0 / 3, 1e-9));
      expect(bins.reduce((a, b) => a + b), closeTo(60.0, 1e-9));
    });

    test('IST: a half-hour offset splits a whole UTC hour across two bins', () {
      // The case that only India produces. 04:00-05:00 UTC is one clean UTC
      // hour, but in Kolkata it reads 09:30-10:30, so it belongs half to the
      // 9 bin and half to the 10. Anything that divides the span by whole
      // hours, or builds hour boundaries off UTC, gets this wrong and gets it
      // wrong for every Indian user on every session.
      final s = session(
        startedAtUtcMs: at(2026, 9, 15, 9, 30, kolkata),
        endedAtUtcMs: at(2026, 9, 15, 10, 30, kolkata),
        actualDurationS: 3600,
        tzOffsetMin: kolkata,
      );
      final bins = PeakWindow.apportionToHourBins(s);
      expect(bins[9], closeTo(30.0, 1e-9));
      expect(bins[10], closeTo(30.0, 1e-9));
      expect(bins.reduce((a, b) => a + b), closeTo(60.0, 1e-9));
    });

    test('IST: a three-hour session splits the same way as anywhere else', () {
      final s = session(
        startedAtUtcMs: at(2026, 9, 15, 9, 40, kolkata),
        endedAtUtcMs: at(2026, 9, 15, 11, 10, kolkata),
        actualDurationS: 5400,
        tzOffsetMin: kolkata,
      );
      final bins = PeakWindow.apportionToHourBins(s);
      expect(bins[9], closeTo(20.0, 1e-9));
      expect(bins[10], closeTo(60.0, 1e-9));
      expect(bins[11], closeTo(10.0, 1e-9));
    });

    test('the bins do not move when the reader is somewhere else', () {
      // The whole reason SessionRecord carries tzOffsetMin. A 09:00 session in
      // Ahmedabad must still read as 09:00 after the phone lands in Edmonton.
      // Nothing in this test changes except who is looking.
      final inIndia = pomodoroAt(9, tzOffsetMin: kolkata);
      final bins = PeakWindow.apportionToHourBins(inIndia);
      expect(bins[9], closeTo(25.0, 1e-9));
      expect(bins[21], equals(0.0),
          reason: '21:00 is where Edmonton would have put it');
    });

    test('a session spanning a DST change is binned by its starting offset', () {
      // Deliberate, documented, and the cheaper half of a real trade-off.
      //
      // Spring forward, 8 March: the session starts at 01:30 MST and runs 90
      // real minutes, so the wall clock actually reads 04:00 when it ends —
      // 02:00 never happened. Binned by the stored −420 offset, the second hour
      // lands in the 2 bin rather than the 3 bin.
      //
      // That is one bin out, on at most two sessions a year, in a histogram
      // that will not display below ten sessions. Getting it exactly right
      // would mean consulting a live timezone database at read time, which is
      // precisely what makes the peak window follow the reader around the
      // world. See the note on apportionToHourBins.
      final springStart = at(2026, 3, 8, 1, 30, edmontonWinter);
      final spring = session(
        startedAtUtcMs: springStart,
        endedAtUtcMs: springStart + 90 * 60000,
        actualDurationS: 5400,
        tzOffsetMin: edmontonWinter,
      );
      final springBins = PeakWindow.apportionToHourBins(spring);
      expect(springBins[1], closeTo(30.0, 1e-9));
      expect(springBins[2], closeTo(60.0, 1e-9));
      expect(springBins.reduce((a, b) => a + b), closeTo(90.0, 1e-9),
          reason: 'no minutes are lost, whichever bin they land in');

      // Fall back, 1 November: starts at 01:30 MDT, ends at 02:00 MST by the
      // wall clock because 01:00 runs twice. Binned by the stored −360 offset
      // it reads as a plain 01:30 → 03:00.
      final fallStart = at(2026, 11, 1, 1, 30, edmontonSummer);
      final fall = session(
        startedAtUtcMs: fallStart,
        endedAtUtcMs: fallStart + 90 * 60000,
        actualDurationS: 5400,
        tzOffsetMin: edmontonSummer,
      );
      final fallBins = PeakWindow.apportionToHourBins(fall);
      expect(fallBins[1], closeTo(30.0, 1e-9));
      expect(fallBins[2], closeTo(60.0, 1e-9));
      expect(fallBins.reduce((a, b) => a + b), closeTo(90.0, 1e-9));
    });

    test('a session crossing midnight bins into both hours', () {
      final s = session(
        startedAtUtcMs: at(2026, 9, 15, 23, 30, edmontonSummer),
        endedAtUtcMs: at(2026, 9, 16, 0, 30, edmontonSummer),
        actualDurationS: 3600,
      );
      final bins = PeakWindow.apportionToHourBins(s);
      expect(bins[23], closeTo(30.0, 1e-9));
      expect(bins[0], closeTo(30.0, 1e-9));
      // §1.4: the session still belongs wholly to the day it started.
      expect(s.localDate, equals('2026-09-15'));
    });

    test('fewer than ten completed sessions in total shows no peak', () {
      // SPEC.md §4.4 — a peak from four sessions is noise presented as insight.
      final nine = [for (var i = 0; i < 9; i++) pomodoroAt(9, id: 'n$i')];
      final w = PeakWindow.of(nine, totalCompletedSessions: 9);
      expect(w.hasEnoughData, isFalse);
      expect(w.peakHour, isNull);
      // The bins are still computed — only the display is gated.
      expect(w.minutesByHour[9], closeTo(225.0, 1e-9));
    });

    test('the tenth completed session unlocks the peak', () {
      final ten = [
        for (var i = 0; i < 9; i++) pomodoroAt(9, id: 'n$i'),
        pomodoroAt(14, id: 'n9'),
      ];
      final w = PeakWindow.of(ten, totalCompletedSessions: 10);
      expect(w.hasEnoughData, isTrue);
      expect(w.peakHour, equals(9));
      expect(w.minutesByHour[14], closeTo(25.0, 1e-9));
    });

    test('abandoned sessions contribute nothing to any bin', () {
      final sessions = [
        for (var i = 0; i < 9; i++) pomodoroAt(9, id: 'n$i'),
        pomodoroAt(14, id: 'n9'),
        session(
          id: 'ab',
          startedAtUtcMs: at(2026, 9, 15, 20, 0, edmontonSummer),
          endedAtUtcMs: at(2026, 9, 15, 22, 0, edmontonSummer),
          actualDurationS: 7200,
          outcome: 'abandoned',
        ),
      ];
      final w = PeakWindow.of(sessions, totalCompletedSessions: 10);
      expect(w.minutesByHour[20], equals(0.0));
      expect(w.peakHour, equals(9));
    });

    test('the bins total exactly the focused seconds, in minutes', () {
      // The invariant that keeps §4.4 and §4.1 from disagreeing on screen:
      // bins sum to seconds/60 exactly; §4.1 is the floor of that.
      final sessions = [
        session(
          id: 'g1',
          startedAtUtcMs: at(2026, 9, 15, 9, 0, edmontonSummer),
          endedAtUtcMs: at(2026, 9, 15, 9, 10, edmontonSummer),
          actualDurationS: 605,
        ),
        session(
          id: 'g2',
          startedAtUtcMs: at(2026, 9, 15, 10, 0, edmontonSummer),
          endedAtUtcMs: at(2026, 9, 15, 10, 10, edmontonSummer),
          actualDurationS: 600,
        ),
      ];
      final w = PeakWindow.of(sessions, totalCompletedSessions: 2);
      expect(w.totalMinutes, closeTo(1205 / 60.0, 1e-9));
      expect(w.totalMinutes.floor(), equals(20));
    });

    test('a zero-length span is attributed to the starting hour, not lost', () {
      // Manual entries and clock anomalies (§1.5) can produce these.
      final s = session(
        startedAtUtcMs: at(2026, 9, 15, 16, 0, edmontonSummer),
        endedAtUtcMs: at(2026, 9, 15, 16, 0, edmontonSummer),
        actualDurationS: 1500,
      );
      final bins = PeakWindow.apportionToHourBins(s);
      expect(bins[16], closeTo(25.0, 1e-9));
      expect(bins.reduce((a, b) => a + b), closeTo(25.0, 1e-9));
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  group('§4.5 day-of-week profile', () {
    // Two weeks: Mon 7 Sep 2026 through Sun 20 Sep 2026.
    // The app was opened on four days. One of those — Monday the 14th — has an
    // event but no focus time, so it is a real zero and must be averaged in.
    // Every other day is untouched and must be excluded, not counted as zero.
    const activeDates = [
      '2026-09-07', // Mon, 30 min
      '2026-09-09', // Wed, 50 min
      '2026-09-14', // Mon, opened the app, focused for none of it
      '2026-09-16', // Wed, 70 min
    ];
    const minutesByDate = {
      '2026-09-07': 30,
      '2026-09-09': 50,
      '2026-09-16': 70,
    };

    test('active days with no focus time count as zero', () {
      final p = WeekdayProfile.of(
        activeDates: activeDates,
        minutesByDate: minutesByDate,
      );
      final monday = p.forWeekday(DateTime.monday);
      expect(monday.activeDays, equals(2));
      expect(monday.meanMinutes, closeTo(15.0, 1e-12)); // (30 + 0) / 2
    });

    test('untouched days are excluded from the denominator', () {
      final p = WeekdayProfile.of(
        activeDates: activeDates,
        minutesByDate: minutesByDate,
      );
      final wednesday = p.forWeekday(DateTime.wednesday);
      expect(wednesday.activeDays, equals(2));
      // (50 + 70) / 2 — NOT (50 + 70) / 14 days, and not diluted by the
      // eleven days the phone was never picked up.
      expect(wednesday.meanMinutes, closeTo(60.0, 1e-12));
    });

    test('a weekday that was never active is undefined, not zero', () {
      final p = WeekdayProfile.of(
        activeDates: activeDates,
        minutesByDate: minutesByDate,
      );
      for (final wd in [
        DateTime.tuesday,
        DateTime.thursday,
        DateTime.friday,
        DateTime.saturday,
        DateTime.sunday,
      ]) {
        expect(p.forWeekday(wd).activeDays, equals(0));
        expect(p.forWeekday(wd).meanMinutes, isNull, reason: 'weekday $wd');
      }
    });

    test('the bins are indexed Monday-first', () {
      final p = WeekdayProfile.of(
        activeDates: activeDates,
        minutesByDate: minutesByDate,
      );
      expect(p.bins.length, equals(7));
      expect(p.bins.first.weekday, equals(DateTime.monday));
      expect(p.bins.last.weekday, equals(DateTime.sunday));
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  group('§4.6 interruptions per focused hour', () {
    final abandonedWithInterruptions = session(
      id: 'i3',
      startedAtUtcMs: at(2026, 9, 15, 14, 0, edmontonSummer),
      endedAtUtcMs: at(2026, 9, 15, 14, 30, edmontonSummer),
      actualDurationS: 1800,
      outcome: 'abandoned',
      internal: 5,
      external: 2,
    );

    final sessions = [
      session(
        id: 'i1',
        startedAtUtcMs: at(2026, 9, 15, 9, 0, edmontonSummer),
        endedAtUtcMs: at(2026, 9, 15, 10, 0, edmontonSummer),
        actualDurationS: 3600,
        internal: 3,
        external: 1,
      ),
      session(
        id: 'i2',
        startedAtUtcMs: at(2026, 9, 15, 11, 0, edmontonSummer),
        endedAtUtcMs: at(2026, 9, 15, 12, 0, edmontonSummer),
        actualDurationS: 3600,
        internal: 1,
        external: 1,
      ),
      abandonedWithInterruptions,
    ];

    test('six interruptions across two focused hours is three per hour', () {
      final r = InterruptionRate.of(sessions);
      expect(r.focusMinutes, equals(120));
      expect(r.internal, equals(4));
      expect(r.external, equals(2));
      expect(r.total, equals(6));
      expect(r.perHourTotal, closeTo(3.0, 1e-12));
    });

    test('internal and external are reported separately', () {
      // §4.6: they have different remedies, so a single combined figure hides
      // which one to act on.
      final r = InterruptionRate.of(sessions);
      expect(r.perHourInternal, closeTo(2.0, 1e-12));
      expect(r.perHourExternal, closeTo(1.0, 1e-12));
    });

    test('interruptions on abandoned sessions stay out of the rate', () {
      final r = InterruptionRate.of(sessions);
      // The denominator is completed-only (§4.1), so the numerator must be too,
      // or the ratio spans two different populations.
      expect(r.internal, equals(4), reason: 'not 9');
      expect(r.abandonedInternal, equals(5));
      expect(r.abandonedExternal, equals(2));
    });

    test('no focus minutes makes every rate undefined', () {
      final r = InterruptionRate.of([abandonedWithInterruptions]);
      expect(r.focusMinutes, equals(0));
      expect(r.perHourTotal, isNull);
      expect(r.perHourInternal, isNull);
      expect(r.perHourExternal, isNull);
    });

    test('focused seconds are summed before being converted to minutes', () {
      // Two 59-second sessions are 1 minute together, not 0 + 0.
      final r = InterruptionRate.of([
        session(
          id: 'a',
          startedAtUtcMs: at(2026, 9, 15, 9, 0, edmontonSummer),
          endedAtUtcMs: at(2026, 9, 15, 9, 1, edmontonSummer),
          actualDurationS: 59,
        ),
        session(
          id: 'b',
          startedAtUtcMs: at(2026, 9, 15, 10, 0, edmontonSummer),
          endedAtUtcMs: at(2026, 9, 15, 10, 1, edmontonSummer),
          actualDurationS: 59,
        ),
      ]);
      expect(r.focusMinutes, equals(1));
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  group('§4.7 mean focus rating', () {
    final rated = [
      session(id: 'r1', startedAtUtcMs: at(2026, 9, 15, 9, 0, edmontonSummer), endedAtUtcMs: at(2026, 9, 15, 9, 25, edmontonSummer), actualDurationS: 1500, rating: 5),
      session(id: 'r2', startedAtUtcMs: at(2026, 9, 15, 10, 0, edmontonSummer), endedAtUtcMs: at(2026, 9, 15, 10, 25, edmontonSummer), actualDurationS: 1500, rating: 4),
      session(id: 'r3', startedAtUtcMs: at(2026, 9, 15, 11, 0, edmontonSummer), endedAtUtcMs: at(2026, 9, 15, 11, 25, edmontonSummer), actualDurationS: 1500, rating: 4),
      session(id: 'r4', startedAtUtcMs: at(2026, 9, 15, 12, 0, edmontonSummer), endedAtUtcMs: at(2026, 9, 15, 12, 25, edmontonSummer), actualDurationS: 1500),
      session(id: 'r5', startedAtUtcMs: at(2026, 9, 15, 13, 0, edmontonSummer), endedAtUtcMs: at(2026, 9, 15, 13, 25, edmontonSummer), actualDurationS: 1500, rating: 2),
      session(id: 'r6', startedAtUtcMs: at(2026, 9, 15, 15, 0, edmontonSummer), endedAtUtcMs: at(2026, 9, 15, 15, 25, edmontonSummer), actualDurationS: 1500, outcome: 'abandoned', rating: 1),
    ];

    test('an unrated session is not imputed — it is absent from both sides', () {
      final r = FocusRatingStats.of(rated);
      expect(r.n, equals(4), reason: 'six sessions, four of them usable');
      expect(r.mean, closeTo(3.75, 1e-12)); // (5 + 4 + 4 + 2) / 4
    });

    test('an abandoned session is excluded even when it carries a rating', () {
      final r = FocusRatingStats.of(rated);
      // Folding the abandoned 1 in would give (5+4+4+2+1)/5 = 3.2.
      expect(r.mean, isNot(closeTo(3.2, 1e-9)));
      expect(r.distribution[0], equals(0), reason: 'no rating of 1 counted');
    });

    test('the distribution is reported for all five ratings', () {
      final r = FocusRatingStats.of(rated);
      expect(r.distribution, equals([0, 1, 0, 2, 1]));
    });

    test('nothing rated is undefined, not zero', () {
      final r = FocusRatingStats.of([rated[3]]);
      expect(r.n, equals(0));
      expect(r.mean, isNull);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  group('§4.8 time allocation', () {
    final sessions = [
      session(id: 't1', startedAtUtcMs: at(2026, 9, 15, 9, 0, edmontonSummer), endedAtUtcMs: at(2026, 9, 15, 9, 25, edmontonSummer), actualDurationS: 1500, projectId: 'p1'),
      session(id: 't2', startedAtUtcMs: at(2026, 9, 15, 10, 0, edmontonSummer), endedAtUtcMs: at(2026, 9, 15, 10, 35, edmontonSummer), actualDurationS: 2100, projectId: 'p1'),
      session(id: 't3', startedAtUtcMs: at(2026, 9, 15, 11, 0, edmontonSummer), endedAtUtcMs: at(2026, 9, 15, 11, 45, edmontonSummer), actualDurationS: 2700, projectId: 'p2'),
      session(id: 't4', startedAtUtcMs: at(2026, 9, 15, 13, 0, edmontonSummer), endedAtUtcMs: at(2026, 9, 15, 13, 20, edmontonSummer), actualDurationS: 1200),
      session(id: 't5', startedAtUtcMs: at(2026, 9, 15, 16, 0, edmontonSummer), endedAtUtcMs: at(2026, 9, 15, 16, 30, edmontonSummer), actualDurationS: 1800, outcome: 'abandoned', projectId: 'p1'),
    ];
    const names = {'p1': 'Cairn', 'p2': 'Reading'};

    test('sessions with no project are shown, never dropped', () {
      // The bug §4.8 exists to prevent: GROUP BY project_id quietly losing
      // every null row, so the chart reads 100% across projects while half the
      // user's week was unassigned.
      final a = TimeAllocation.of(sessions, projectNames: names);
      final unassigned =
          a.slices.firstWhere((s) => s.isUnassigned);
      expect(unassigned.label, equals('Unassigned'));
      expect(unassigned.minutes, equals(20));
      expect(a.totalMinutes, equals(125));
    });

    test('minutes and shares are correct and ordered largest first', () {
      final a = TimeAllocation.of(sessions, projectNames: names);
      expect(a.slices.map((s) => s.label).toList(),
          equals(['Cairn', 'Reading', 'Unassigned']));
      expect(a.slices[0].minutes, equals(60)); // 1500 + 2100 seconds
      expect(a.slices[1].minutes, equals(45));
      expect(a.slices[2].minutes, equals(20));
      expect(a.slices[0].share, closeTo(0.48, 1e-12));
      expect(a.slices[1].share, closeTo(0.36, 1e-12));
      expect(a.slices[2].share, closeTo(0.16, 1e-12));
    });

    test('abandoned time is excluded per §4.1', () {
      final a = TimeAllocation.of(sessions, projectNames: names);
      // The abandoned 30 minutes were on p1. If they leaked in, Cairn would
      // read 90 and the total 155.
      expect(a.slices[0].minutes, equals(60));
      expect(a.totalMinutes, equals(125));
    });

    test('a project with no name still appears', () {
      final a = TimeAllocation.of(sessions, projectNames: const {});
      expect(a.slices.map((s) => s.label), contains('Unknown project'));
      expect(a.totalMinutes, equals(125));
    });

    test('nothing completed is undefined, not an empty chart', () {
      final a = TimeAllocation.of([sessions[4]], projectNames: names);
      expect(a.isDefined, isFalse);
      expect(a.totalMinutes, equals(0));
      expect(a.slices, isEmpty);
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  group('§4.13 activity heatmap', () {
    test('nearest rank picks the ceil(p × n / 100)th value', () {
      final twenty = [for (var i = 1; i <= 20; i++) i * 10]; // 10..200
      expect(HeatmapThresholds.nearestRankPercentile(twenty, 25), equals(50));
      expect(HeatmapThresholds.nearestRankPercentile(twenty, 50), equals(100));
      expect(HeatmapThresholds.nearestRankPercentile(twenty, 75), equals(150));
      expect(HeatmapThresholds.nearestRankPercentile(twenty, 90), equals(180));
    });

    test('fewer than fourteen non-zero days falls back to fixed thresholds', () {
      final thirteen = [for (var i = 1; i <= 13; i++) i * 10];
      final t = HeatmapThresholds.fromDailyMinutes(thirteen);
      expect(t.provisional, isTrue);
      expect(t.nonZeroDayCount, equals(13));
      expect(
        [t.level1Max, t.level2Max, t.level3Max, t.level4Nominal],
        equals([25, 50, 100, 180]),
      );
      expect(
        [0, 25, 26, 50, 51, 100, 101, 180, 181].map(t.levelFor).toList(),
        equals([0, 1, 2, 2, 3, 3, 4, 4, 4]),
      );
    });

    test('fourteen non-zero days is exactly enough to go personal', () {
      final fourteen = [for (var i = 1; i <= 14; i++) i];
      final t = HeatmapThresholds.fromDailyMinutes(fourteen);
      expect(t.provisional, isFalse);
      expect(
        [t.level1Max, t.level2Max, t.level3Max, t.level4Nominal],
        equals([4, 7, 11, 13]),
      );
      expect(
        [1, 4, 5, 7, 8, 11, 12, 14].map(t.levelFor).toList(),
        equals([1, 1, 2, 2, 3, 3, 4, 4]),
      );
    });

    test('thresholds are the user\'s own percentiles', () {
      final twenty = [for (var i = 1; i <= 20; i++) i * 10];
      final t = HeatmapThresholds.fromDailyMinutes(twenty);
      expect(t.provisional, isFalse);
      expect(t.nonZeroDayCount, equals(20));
      expect(
        [t.level1Max, t.level2Max, t.level3Max, t.level4Nominal],
        equals([50, 100, 150, 180]),
      );
    });

    test('level boundaries are inclusive at the top and the top saturates', () {
      final t = HeatmapThresholds.fromDailyMinutes(
          [for (var i = 1; i <= 20; i++) i * 10]);
      expect(t.levelFor(0), equals(0));
      expect(t.levelFor(1), equals(1));
      expect(t.levelFor(50), equals(1));
      expect(t.levelFor(51), equals(2));
      expect(t.levelFor(100), equals(2));
      expect(t.levelFor(101), equals(3));
      expect(t.levelFor(150), equals(3));
      expect(t.levelFor(151), equals(4));
      // Above the nominal 90th percentile there is no level 5.
      expect(t.levelFor(999), equals(4));
    });

    test('zero days are excluded from the percentile population', () {
      // Fourteen non-zero days plus a hundred blank ones must give the same
      // thresholds as the fourteen alone — otherwise a holiday would redraw
      // the whole heatmap.
      final withZeros = [
        for (var i = 1; i <= 14; i++) i,
        for (var i = 0; i < 100; i++) 0,
      ];
      final t = HeatmapThresholds.fromDailyMinutes(withZeros);
      expect(t.nonZeroDayCount, equals(14));
      expect(
        [t.level1Max, t.level2Max, t.level3Max],
        equals([4, 7, 11]),
      );
    });

    test('no history at all is provisional', () {
      final t = HeatmapThresholds.fromDailyMinutes(const []);
      expect(t.provisional, isTrue);
      expect(t.nonZeroDayCount, equals(0));
      expect(t.levelFor(0), equals(0));
    });

    test('every date in the period gets a cell, gaps included', () {
      // A missing square would shift every later square into the wrong column.
      final t = HeatmapThresholds.fromDailyMinutes(const []);
      final cells = buildHeatmap(
        period: const StatsPeriod(start: '2026-09-14', end: '2026-09-20'),
        minutesByDate: const {'2026-09-14': 30, '2026-09-17': 200},
        thresholds: t,
      );
      expect(cells.length, equals(7));
      expect(cells.first.date, equals('2026-09-14'));
      expect(cells.last.date, equals('2026-09-20'));
      expect(cells[0].level, equals(2)); // 30 min, provisional scale
      expect(cells[1].level, equals(0)); // no data
      expect(cells[3].level, equals(4)); // 200 min
      expect(cells.where((c) => c.minutes == 0).length, equals(5));
    });
  });

  // ═════════════════════════════════════════════════════════════════════════
  group('StatsPeriod', () {
    test('lastNDays is inclusive of both ends', () {
      final p = StatsPeriod.lastNDays('2026-09-15', 7);
      expect(p.start, equals('2026-09-09'));
      expect(p.end, equals('2026-09-15'));
      expect(p.dates().length, equals(7));
    });

    test('month clamps to the real length of the month', () {
      expect(StatsPeriod.month('2026-02-10').end, equals('2026-02-28'));
      expect(StatsPeriod.month('2028-02-10').end, equals('2028-02-29'));
      expect(StatsPeriod.month('2026-09-10').end, equals('2026-09-30'));
    });

    test('week follows the user\'s week-start setting', () {
      const monday = TimeService(weekStart: DateTime.monday);
      const sunday = TimeService(weekStart: DateTime.sunday);
      // 2026-09-15 is a Tuesday.
      expect(StatsPeriod.week(monday, '2026-09-15').start,
          equals('2026-09-14'));
      expect(StatsPeriod.week(sunday, '2026-09-15').start,
          equals('2026-09-13'));
    });

    test('contains is inclusive and string-ordered', () {
      const p = StatsPeriod(start: '2026-09-09', end: '2026-09-15');
      expect(p.contains('2026-09-09'), isTrue);
      expect(p.contains('2026-09-15'), isTrue);
      expect(p.contains('2026-09-08'), isFalse);
      expect(p.contains('2026-09-16'), isFalse);
    });

    test('allTime contains any date the app can store', () {
      expect(StatsPeriod.allTime.contains('1970-01-01'), isTrue);
      expect(StatsPeriod.allTime.contains('2026-09-15'), isTrue);
      expect(StatsPeriod.allTime.contains('2999-12-31'), isTrue);
    });

    test('dates() spans a DST transition without losing or repeating a day', () {
      const p = StatsPeriod(start: '2026-03-06', end: '2026-03-10');
      expect(p.dates(),
          equals(['2026-03-06', '2026-03-07', '2026-03-08', '2026-03-09', '2026-03-10']));
    });
  });
}
