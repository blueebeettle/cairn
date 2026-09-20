import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/stats/statistics.dart';
import 'package:habit_tracker/core/time/time_service.dart';

/// SPEC.md §7, Fixture B — relocation.
///
/// *"Events in `America/Edmonton` followed by events in `Asia/Kolkata`
/// mid-week. Assert that earlier days' `local_date` values and all historical
/// metrics are byte-identical before and after the move."*
///
/// This is not a hypothetical for Cairn. The two zones it will actually be used
/// in are 11½ hours apart, and the same person may well use it in both. If
/// history moves when the phone does, the app is lying about the user's past
/// every time they fly.
///
/// The fixture: three evening sessions in Edmonton, then a flight, then three
/// morning sessions in Kolkata.
///
///   Mon 14 Sep  20:00 Edmonton (UTC−6)   50 min
///   Tue 15 Sep  20:00 Edmonton (UTC−6)   50 min
///   Wed 16 Sep  20:00 Edmonton (UTC−6)   50 min
///   ── flight ──
///   Fri 18 Sep  09:00 Kolkata (UTC+5:30) 50 min
///   Sat 19 Sep  09:00 Kolkata (UTC+5:30) 50 min
///   Sun 20 Sep  09:00 Kolkata (UTC+5:30) 50 min
void main() {
  const edmonton = -360; // MDT
  const kolkata = 330; // IST — no DST, ever

  int at(int y, int mo, int d, int h, int mi, int offsetMin) =>
      DateTime.utc(y, mo, d, h, mi).millisecondsSinceEpoch - offsetMin * 60000;

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

  SessionRecord evening(int day) {
    final start = at(2026, 9, day, 20, 0, edmonton);
    return SessionRecord(
      id: 'edmonton-$day',
      localDate: logicalDate(start, edmonton),
      startedAtUtcMs: start,
      endedAtUtcMs: start + 50 * 60000,
      actualDurationS: 3000,
      outcome: 'completed',
      tzOffsetMin: edmonton,
      focusRating: 4,
    );
  }

  SessionRecord morning(int day) {
    final start = at(2026, 9, day, 9, 0, kolkata);
    return SessionRecord(
      id: 'kolkata-$day',
      localDate: logicalDate(start, kolkata),
      startedAtUtcMs: start,
      endedAtUtcMs: start + 50 * 60000,
      actualDurationS: 3000,
      outcome: 'completed',
      tzOffsetMin: kolkata,
      focusRating: 4,
    );
  }

  final beforeTheMove = [evening(14), evening(15), evening(16)];
  final afterTheMove = [morning(18), morning(19), morning(20)];
  final everything = [...beforeTheMove, ...afterTheMove];

  /// The three Edmonton days, which is the window §7 asks us to hold still.
  const historyWindow = StatsPeriod(start: '2026-09-14', end: '2026-09-16');

  List<SessionRecord> inPeriod(
          List<SessionRecord> sessions, StatsPeriod period) =>
      sessions.where((s) => period.contains(s.localDate)).toList();

  group('the fixture is what it claims to be', () {
    test('logical dates land on the local calendar, not the UTC one', () {
      // 20:00 in Edmonton is 02:00 the NEXT day in UTC. If local_date were
      // derived from UTC, every evening session would be filed a day late.
      expect(beforeTheMove.map((s) => s.localDate).toList(),
          equals(['2026-09-14', '2026-09-15', '2026-09-16']));
      expect(afterTheMove.map((s) => s.localDate).toList(),
          equals(['2026-09-18', '2026-09-19', '2026-09-20']));
    });

    test('the two zones really are 11.5 hours apart', () {
      expect(kolkata - edmonton, equals(690));
    });
  });

  group('§7 Fixture B — history does not move when the user does', () {
    test('local_date values are untouched by the relocation', () {
      // SPEC §1.2: local_date is resolved once at write time and never
      // recomputed. Adding later events in another zone cannot disturb it.
      final before = beforeTheMove.map((s) => s.localDate).toList();
      final after = inPeriod(everything, historyWindow)
          .map((s) => s.localDate)
          .toList();
      expect(after, equals(before));
    });

    test('focus minutes per day are identical', () {
      expect(
        focusMinutesByDate(inPeriod(everything, historyWindow)),
        equals(focusMinutesByDate(beforeTheMove)),
      );
      expect(focusMinutesByDate(beforeTheMove),
          equals({'2026-09-14': 50, '2026-09-15': 50, '2026-09-16': 50}));
    });

    test('the peak window is identical', () {
      final before =
          PeakWindow.of(beforeTheMove, totalCompletedSessions: 3).minutesByHour;
      final after = PeakWindow.of(inPeriod(everything, historyWindow),
              totalCompletedSessions: 6)
          .minutesByHour;
      expect(after, equals(before));
      // And it is still the evening, which is when they actually happened.
      expect(before[20], closeTo(150.0, 1e-9));
    });

    test('completion rate, ratings and allocation are identical', () {
      final windowed = inPeriod(everything, historyWindow);

      expect(CompletionRate.of(windowed).rate,
          equals(CompletionRate.of(beforeTheMove).rate));
      expect(FocusRatingStats.of(windowed).mean,
          equals(FocusRatingStats.of(beforeTheMove).mean));
      expect(
        TimeAllocation.of(windowed, projectNames: const {}).totalMinutes,
        equals(TimeAllocation.of(beforeTheMove, projectNames: const {})
            .totalMinutes),
      );
    });

    test('heatmap levels for the Edmonton days are identical', () {
      final thresholds = HeatmapThresholds.fromDailyMinutes(
          focusMinutesByDate(everything).values);
      final before = buildHeatmap(
        period: historyWindow,
        minutesByDate: focusMinutesByDate(beforeTheMove),
        thresholds: thresholds,
      ).map((c) => c.level).toList();
      final after = buildHeatmap(
        period: historyWindow,
        minutesByDate: focusMinutesByDate(everything),
        thresholds: thresholds,
      ).map((c) => c.level).toList();
      expect(after, equals(before));
    });
  });

  group('both zones keep their own hours in one chart', () {
    test('evenings in Edmonton and mornings in Kolkata do not merge', () {
      final w = PeakWindow.of(everything, totalCompletedSessions: 6);
      expect(w.minutesByHour[20], closeTo(150.0, 1e-9),
          reason: 'three Edmonton evenings');
      expect(w.minutesByHour[9], closeTo(150.0, 1e-9),
          reason: 'three Kolkata mornings');
      expect(w.totalMinutes, closeTo(300.0, 1e-9));

      // Exactly two hours are occupied. Six sessions, two habits, no smearing.
      final occupied = [
        for (var h = 0; h < 24; h++)
          if (w.minutesByHour[h] > 0) h,
      ];
      expect(occupied, equals([9, 20]));
    });

    test('the stored offset is what decides, and it has teeth', () {
      // The control. If these sessions carried Edmonton's offset instead of
      // their own — which is what reading through the device's current zone
      // amounts to — the Kolkata mornings would land at 21:30 the evening
      // before. This asserts the difference is real, so the tests above are
      // not passing by accident.
      final misattributed = [
        for (final s in afterTheMove)
          SessionRecord(
            id: s.id,
            localDate: s.localDate,
            startedAtUtcMs: s.startedAtUtcMs,
            endedAtUtcMs: s.endedAtUtcMs,
            actualDurationS: s.actualDurationS,
            outcome: s.outcome,
            tzOffsetMin: edmonton, // the reader's zone, not the session's
          ),
      ];
      final right = PeakWindow.of(afterTheMove, totalCompletedSessions: 3);
      final wrong = PeakWindow.of(misattributed, totalCompletedSessions: 3);

      expect(right.peakHour, isNull, reason: 'three sessions is below the gate');
      expect(right.minutesByHour[9], closeTo(150.0, 1e-9));
      expect(wrong.minutesByHour[9], equals(0.0));
      expect(wrong.minutesByHour[21], closeTo(90.0, 1e-9));
      expect(wrong.minutesByHour[22], closeTo(60.0, 1e-9));
    });
  });

  group('day-of-week survives the move', () {
    test('each day keeps the weekday it had locally', () {
      final activeDates = everything.map((s) => s.localDate).toSet();
      final profile = WeekdayProfile.of(
        activeDates: activeDates,
        minutesByDate: focusMinutesByDate(everything),
      );
      // Mon/Tue/Wed in Edmonton, Fri/Sat/Sun in Kolkata, Thursday spent flying.
      for (final wd in [
        DateTime.monday,
        DateTime.tuesday,
        DateTime.wednesday,
        DateTime.friday,
        DateTime.saturday,
        DateTime.sunday,
      ]) {
        expect(profile.forWeekday(wd).activeDays, equals(1), reason: 'wd $wd');
        expect(profile.forWeekday(wd).meanMinutes, closeTo(50.0, 1e-9),
            reason: 'wd $wd');
      }
      expect(profile.forWeekday(DateTime.thursday).activeDays, equals(0));
      expect(profile.forWeekday(DateTime.thursday).meanMinutes, isNull,
          reason: 'a day in the air is undefined, not zero');
    });
  });
}
