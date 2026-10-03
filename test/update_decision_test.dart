// decideUpdateAction is the heart of the updater: every "what should happen"
// rule lives in that one pure function, so it is tested against a table. A
// tester on 2.2.0 is always the starting point; statusBehind(n) is n newer
// releases, 2.3.0 .. 2.(2+n).0.

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/updates/update_checker.dart';
import 'package:habit_tracker/core/updates/update_decision.dart';

import 'support/update_fixtures.dart';

/// What a row of the table expects.
sealed class _Expect {
  const _Expect();
}

class _Nothing extends _Expect {
  const _Nothing();
}

class _Optional extends _Expect {
  const _Optional();
}

class _Mandatory extends _Expect {
  const _Mandatory(this.reason);
  final MandatoryReason reason;
}

typedef _Row = ({
  String name,
  int behind,
  bool latestMarked,
  String? skipped,
  _Expect expected,
});

void main() {
  // The version statusBehind(n) puts at the top.
  String latestOf(int n) => '2.${2 + n}.0';

  /// Rows whose `skipped` should be "the latest release's own version" use this
  /// sentinel; it is resolved against the row's `behind`.
  const latest = '<latest>';

  final rows = <_Row>[
    // ── Nothing newer ────────────────────────────────────────────────────────
    (name: 'zero newer releases', behind: 0, latestMarked: false, skipped: null, expected: const _Nothing()),
    (name: 'zero newer releases, with a stale skip on file', behind: 0, latestMarked: false, skipped: '2.1.0', expected: const _Nothing()),

    // ── 1-4 behind, not marked, not declined: an optional offer ──────────────
    (name: '1 behind', behind: 1, latestMarked: false, skipped: null, expected: const _Optional()),
    (name: '2 behind', behind: 2, latestMarked: false, skipped: null, expected: const _Optional()),
    (name: '3 behind', behind: 3, latestMarked: false, skipped: null, expected: const _Optional()),
    (name: '4 behind (the most a tester can decline in a row)', behind: 4, latestMarked: false, skipped: null, expected: const _Optional()),

    // ── 1-4 behind, the latest is the one already declined: quiet ────────────
    (name: '1 behind, latest already declined', behind: 1, latestMarked: false, skipped: latest, expected: const _Nothing()),
    (name: '2 behind, latest already declined', behind: 2, latestMarked: false, skipped: latest, expected: const _Nothing()),
    (name: '3 behind, latest already declined', behind: 3, latestMarked: false, skipped: latest, expected: const _Nothing()),
    (name: '4 behind, latest already declined', behind: 4, latestMarked: false, skipped: latest, expected: const _Nothing()),

    // ── A decline of something older does not silence what is newer ──────────
    (name: 'declined an older release, a newer one is out', behind: 3, latestMarked: false, skipped: '2.3.0', expected: const _Optional()),
    (name: 'declined a version no longer on the list', behind: 2, latestMarked: false, skipped: '9.9.9', expected: const _Optional()),

    // ── Exactly 5 behind: no longer optional ─────────────────────────────────
    (name: '5 behind', behind: 5, latestMarked: false, skipped: null, expected: const _Mandatory(MandatoryReason.tooFarBehind)),
    (name: '5 behind, even if the latest was declined', behind: 5, latestMarked: false, skipped: latest, expected: const _Mandatory(MandatoryReason.tooFarBehind)),
    (name: '6 behind', behind: 6, latestMarked: false, skipped: null, expected: const _Mandatory(MandatoryReason.tooFarBehind)),
    (name: '12 behind, even if the latest was declined', behind: 12, latestMarked: false, skipped: latest, expected: const _Mandatory(MandatoryReason.tooFarBehind)),

    // ── The marker, at any distance ──────────────────────────────────────────
    (name: 'marked, 1 behind, never declined anything', behind: 1, latestMarked: true, skipped: null, expected: const _Mandatory(MandatoryReason.markedByRelease)),
    (name: 'marked, 1 behind, and that release was declined', behind: 1, latestMarked: true, skipped: latest, expected: const _Mandatory(MandatoryReason.markedByRelease)),
    (name: 'marked, 2 behind', behind: 2, latestMarked: true, skipped: null, expected: const _Mandatory(MandatoryReason.markedByRelease)),
    (name: 'marked, 4 behind', behind: 4, latestMarked: true, skipped: null, expected: const _Mandatory(MandatoryReason.markedByRelease)),
    (name: 'marked, after an earlier release was declined', behind: 2, latestMarked: true, skipped: '2.3.0', expected: const _Mandatory(MandatoryReason.markedByRelease)),

    // ── Both triggers at once: the marker is the reported reason ─────────────
    (name: 'marked and 5 behind', behind: 5, latestMarked: true, skipped: null, expected: const _Mandatory(MandatoryReason.markedByRelease)),
    (name: 'marked and 8 behind, latest declined', behind: 8, latestMarked: true, skipped: latest, expected: const _Mandatory(MandatoryReason.markedByRelease)),
  ];

  group('decideUpdateAction', () {
    for (final row in rows) {
      test(row.name, () {
        final skipped = row.skipped == latest ? latestOf(row.behind) : row.skipped;
        final status = statusBehind(row.behind, latestMandatory: row.latestMarked);

        final action = decideUpdateAction(status: status, lastSkippedVersion: skipped);

        switch (row.expected) {
          case _Nothing():
            expect(action, isA<NoAction>());
          case _Optional():
            expect(action, isA<OptionalUpdate>());
            expect((action as OptionalUpdate).release.version, latestOf(row.behind),
                reason: 'the offer is for the latest release');
          case _Mandatory(:final reason):
            expect(action, isA<MandatoryUpdate>());
            final mandatory = action as MandatoryUpdate;
            expect(mandatory.reason, reason);
            expect(mandatory.release.version, latestOf(row.behind),
                reason: 'the update on offer is the latest release');
        }
      });
    }

    test('the threshold is five: 4 is optional, 5 is not', () {
      expect(mandatoryReleasesBehind, 5);
      expect(
        decideUpdateAction(status: statusBehind(4), lastSkippedVersion: null),
        isA<OptionalUpdate>(),
      );
      expect(
        decideUpdateAction(status: statusBehind(5), lastSkippedVersion: null),
        isA<MandatoryUpdate>(),
      );
    });

    test('only the latest release\'s marker counts', () {
      // 2.4.0 is marked but 2.5.0 (the latest, and what would be installed) is
      // not, so the offer is optional.
      final status = ReleaseStatus(
        newerReleases: [
          fakeRelease('2.5.0'),
          fakeRelease('2.4.0', mandatory: true),
          fakeRelease('2.3.0'),
        ],
        currentVersion: '2.2.0',
      );
      expect(
        decideUpdateAction(status: status, lastSkippedVersion: null),
        isA<OptionalUpdate>(),
      );
    });

    test('a decline suppresses only an optional update, never a mandatory one', () {
      // Declined 2.3.0 earlier; 2.4.0 now ships marked. The old decline is
      // irrelevant: mandatory wins outright.
      final status = ReleaseStatus(
        newerReleases: [fakeRelease('2.4.0', mandatory: true), fakeRelease('2.3.0')],
        currentVersion: '2.2.0',
      );
      final action = decideUpdateAction(status: status, lastSkippedVersion: '2.3.0');
      expect(action, isA<MandatoryUpdate>());
      expect((action as MandatoryUpdate).reason, MandatoryReason.markedByRelease);
    });

    test('a declined release is matched exactly, not "at or below"', () {
      // Declined 2.3.0; 2.4.0 is out. Stays quiet only until something *newer
      // than the declined one* appears — which 2.4.0 is.
      final status = ReleaseStatus(
        newerReleases: [fakeRelease('2.4.0'), fakeRelease('2.3.0')],
        currentVersion: '2.2.0',
      );
      expect(
        decideUpdateAction(status: status, lastSkippedVersion: '2.3.0'),
        isA<OptionalUpdate>(),
      );
    });
  });
}
