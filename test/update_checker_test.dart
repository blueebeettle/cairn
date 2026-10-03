// The update checker: version comparison, the FORCE_UPDATE marker, and fetching
// and filtering GitHub's release list. All against a mocked HTTP client — no
// test here reaches the network.

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/updates/update_checker.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/update_fixtures.dart';

void main() {
  group('compareVersions', () {
    test('equal versions compare equal', () {
      expect(compareVersions('2.2.0', '2.2.0'), 0);
    });

    test('each of major, minor and patch decides on its own', () {
      expect(compareVersions('3.0.0', '2.9.9'), greaterThan(0));
      expect(compareVersions('2.9.9', '3.0.0'), lessThan(0));
      expect(compareVersions('2.3.0', '2.2.9'), greaterThan(0));
      expect(compareVersions('2.2.9', '2.3.0'), lessThan(0));
      expect(compareVersions('2.2.1', '2.2.0'), greaterThan(0));
      expect(compareVersions('2.2.0', '2.2.1'), lessThan(0));
    });

    test('double-digit segments beat single-digit ones, not by string order', () {
      expect(compareVersions('2.10.0', '2.9.0'), greaterThan(0));
      expect(compareVersions('2.9.0', '2.10.0'), lessThan(0));
      expect(compareVersions('2.0.10', '2.0.9'), greaterThan(0));
      expect(compareVersions('10.0.0', '9.0.0'), greaterThan(0));
    });

    test('a missing segment counts as zero', () {
      expect(compareVersions('2.3', '2.3.0'), 0);
      expect(compareVersions('2', '2.0.0'), 0);
      expect(compareVersions('2.3.1', '2.3'), greaterThan(0));
    });

    test('a malformed segment is read as zero and never throws', () {
      // "0-beta" is not a number, so it is 0: 2.3.0-beta == 2.3.0.
      expect(compareVersions('2.3.0-beta', '2.3.0'), 0);
      expect(compareVersions('2.3.0-beta', '2.2.9'), greaterThan(0));
      // A broken minor segment drops that segment to 0, not the whole version.
      expect(compareVersions('2.x.5', '2.0.5'), 0);
      expect(compareVersions('2.x.5', '2.1.0'), lessThan(0));
      expect(compareVersions('', '0.0.0'), 0);
      expect(compareVersions('not a version', '1.0.0'), lessThan(0));
      expect(compareVersions('2..1', '2.0.1'), 0);
      expect(() => compareVersions('..', '...'), returnsNormally);
      // int.tryParse would read these as numbers; they are not plain digits.
      expect(compareVersions('2.-1.0', '2.0.0'), 0);
      expect(compareVersions('2.+5.0', '2.0.0'), 0);
      // Overflow is a malformed segment too, not an exception.
      expect(() => compareVersions('99999999999999999999.0.0', '1.0.0'),
          returnsNormally);
    });

    test('a leading v is ignored rather than read as a broken first segment', () {
      expect(compareVersions('v2.3.0', '2.3.0'), 0);
      expect(compareVersions('v2.3.0', 'v2.2.0'), greaterThan(0));
    });
  });

  group('hasForceUpdateMarker', () {
    test('a line that is exactly the marker is detected', () {
      expect(hasForceUpdateMarker('FORCE_UPDATE'), isTrue);
      expect(hasForceUpdateMarker('Fixes a crash.\n\nFORCE_UPDATE\n'), isTrue);
      expect(hasForceUpdateMarker('FORCE_UPDATE\nFixes a crash.'), isTrue);
    });

    test('surrounding whitespace and letter case do not matter', () {
      expect(hasForceUpdateMarker('   FORCE_UPDATE   '), isTrue);
      expect(hasForceUpdateMarker('\tFORCE_UPDATE\t'), isTrue);
      expect(hasForceUpdateMarker('force_update'), isTrue);
      expect(hasForceUpdateMarker('Force_Update'), isTrue);
    });

    test("GitHub's CRLF and bare CR line endings still split lines", () {
      expect(hasForceUpdateMarker('Fixes a crash.\r\nFORCE_UPDATE\r\n'), isTrue);
      expect(hasForceUpdateMarker('Fixes a crash.\rFORCE_UPDATE\r'), isTrue);
    });

    test('the token inside a sentence is not the marker', () {
      expect(hasForceUpdateMarker('We removed the FORCE_UPDATE flag.'), isFalse);
      expect(hasForceUpdateMarker('FORCE_UPDATE is not set for this one'), isFalse);
      expect(hasForceUpdateMarker('Do not use FORCE_UPDATE'), isFalse);
    });

    test('the token inside a longer word is not the marker', () {
      expect(hasForceUpdateMarker('NO_FORCE_UPDATE'), isFalse);
      expect(hasForceUpdateMarker('FORCE_UPDATES'), isFalse);
      expect(hasForceUpdateMarker('FORCE_UPDATE_NOW'), isFalse);
      expect(hasForceUpdateMarker('XFORCE_UPDATE'), isFalse);
    });

    test('a line with extra punctuation or markdown decoration is not it', () {
      expect(hasForceUpdateMarker('FORCE_UPDATE:'), isFalse);
      expect(hasForceUpdateMarker('- FORCE_UPDATE'), isFalse);
      expect(hasForceUpdateMarker('**FORCE_UPDATE**'), isFalse);
      expect(hasForceUpdateMarker('`FORCE_UPDATE`'), isFalse);
    });

    test('an empty body is not mandatory', () {
      expect(hasForceUpdateMarker(''), isFalse);
    });

    test('the marker is stripped from what a person reads', () {
      expect(
        releaseNotesForDisplay('Fixes a crash.\n\nFORCE_UPDATE\n'),
        'Fixes a crash.',
      );
      expect(releaseNotesForDisplay('  force_update \r\nBody'), 'Body');
      // Other text, paragraph breaks included, is left alone.
      expect(
        releaseNotesForDisplay('One\n\nTwo\nFORCE_UPDATE\nThree'),
        'One\n\nTwo\nThree',
      );
      expect(releaseNotesForDisplay('FORCE_UPDATE'), '');
    });
  });

  group('UpdateChecker.checkForUpdates', () {
    Future<ReleaseStatus> check(
      MockClient client, {
      String current = '2.2.0',
    }) =>
        UpdateChecker(client: client).checkForUpdates(currentVersion: current);

    test('parses a realistic multi-release list into a ReleaseStatus', () async {
      final status = await check(releasesClient([
        ghRelease(
          'v2.4.0',
          body: 'Third.\n\nFORCE_UPDATE\n',
          publishedAt: '2026-10-05T12:00:00Z',
        ),
        ghRelease('v2.3.0', body: 'Second.', publishedAt: '2026-09-20T09:30:00Z'),
        ghRelease('v2.2.0', body: 'Current.'),
        ghRelease('v2.1.0', body: 'Old.'),
      ]));

      expect(status.currentVersion, '2.2.0');
      expect(status.releasesBehind, 2);
      expect([for (final r in status.newerReleases) r.version], ['2.4.0', '2.3.0']);
      expect(status.latest!.version, '2.4.0');

      final latest = status.latest!;
      expect(latest.tagName, 'v2.4.0');
      expect(latest.notes, 'Third.\n\nFORCE_UPDATE\n');
      expect(latest.isMandatory, isTrue);
      expect(latest.publishedAt, DateTime.utc(2026, 10, 5, 12));
      expect(latest.assets.keys, containsAll(standardAssetNames('2.4.0')));
      expect(
        latest.assets['cairn-v2.4.0-arm64-v8a.apk'],
        assetUrl('v2.4.0', 'cairn-v2.4.0-arm64-v8a.apk'),
      );
      // Every asset on the release, with nothing pre-selected.
      expect(latest.assets, hasLength(5));

      expect(status.newerReleases.last.isMandatory, isFalse);
    });

    test('an up-to-date build gets an empty list and a null latest', () async {
      final status = await check(releasesClient([
        ghRelease('v2.2.0'),
        ghRelease('v2.1.0'),
      ]));
      expect(status.newerReleases, isEmpty);
      expect(status.latest, isNull);
      expect(status.releasesBehind, 0);
    });

    test('a build newer than anything published is up to date', () async {
      final status = await check(releasesClient([ghRelease('v2.2.0')]),
          current: '2.3.0');
      expect(status.newerReleases, isEmpty);
    });

    test('drafts and prereleases are dropped', () async {
      final status = await check(releasesClient([
        ghRelease('v2.6.0', draft: true),
        ghRelease('v2.5.0', prerelease: true),
        ghRelease('v2.4.0', draft: true, prerelease: true),
        ghRelease('v2.3.0'),
      ]));
      expect([for (final r in status.newerReleases) r.version], ['2.3.0']);
    });

    test('sorts newest-first by version whatever order GitHub returns', () async {
      final status = await check(releasesClient([
        ghRelease('v2.3.0'),
        ghRelease('v2.10.0'),
        ghRelease('v2.4.0'),
        ghRelease('v2.9.0'),
      ]));
      expect(
        [for (final r in status.newerReleases) r.version],
        ['2.10.0', '2.9.0', '2.4.0', '2.3.0'],
      );
    });

    test('a hotfix published later still ranks by version, not by date', () async {
      final status = await check(releasesClient([
        ghRelease('v2.3.1', publishedAt: '2026-10-01T00:00:00Z'),
        ghRelease('v2.4.0', publishedAt: '2026-09-01T00:00:00Z'),
      ]));
      expect([for (final r in status.newerReleases) r.version], ['2.4.0', '2.3.1']);
    });

    test('a hand-typed or suffixed tag neither throws nor breaks the rest', () async {
      final status = await check(releasesClient([
        ghRelease('v2.3', body: 'two-part tag'),
        ghRelease('v2.4.0-beta'),
        ghRelease('v3.0.0'),
      ]));
      // 2.3 == 2.3.0 > 2.2.0; 2.4.0-beta reads as 2.4.0; 3.0.0 leads.
      expect(
        [for (final r in status.newerReleases) r.tagName],
        ['v3.0.0', 'v2.4.0-beta', 'v2.3'],
      );
      expect(status.newerReleases.last.version, '2.3');
    });

    test('a release with no body, no assets or no date still parses', () async {
      final status = await check(releasesClient([
        {
          'tag_name': 'v2.3.0',
          'body': null,
          'draft': false,
          'prerelease': false,
          'published_at': null,
          'assets': null,
        },
      ]));
      final r = status.latest!;
      expect(r.notes, '');
      expect(r.isMandatory, isFalse);
      expect(r.assets, isEmpty);
    });

    test('an entry without a usable tag is skipped, not fatal', () async {
      final status = await check(releasesClient([
        {'draft': false, 'prerelease': false},
        {'tag_name': '', 'draft': false},
        {'tag_name': 7},
        ghRelease('v2.3.0'),
      ]));
      expect([for (final r in status.newerReleases) r.version], ['2.3.0']);
    });

    test('release notes keep their non-ASCII characters', () async {
      final status = await check(releasesClient([
        ghRelease('v2.3.0', body: 'Fixed the “freeze” — all good'),
      ]));
      expect(status.latest!.notes, 'Fixed the “freeze” — all good');
    });

    test('asks the public list endpoint, with no credentials', () async {
      final log = <http.BaseRequest>[];
      await check(releasesClient([ghRelease('v2.3.0')], log: log));

      expect(log, hasLength(1));
      final request = log.single;
      expect(request.method, 'GET');
      expect(request.url.toString(),
          'https://api.github.com/repos/blueebeettle/cairn/releases');
      // The plural list, not /releases/latest, which cannot count how far behind.
      expect(request.url.path, isNot(endsWith('/latest')));
      // No token, ever: the request carries nothing that authenticates.
      expect(request.headers.keys.map((k) => k.toLowerCase()),
          isNot(contains('authorization')));
    });

    test('throws UpdateCheckException on a non-200 response', () async {
      for (final status in [403, 404, 500, 503]) {
        await expectLater(
          check(releasesClient(const [], status: status, rawBody: '{"message":"no"}')),
          throwsA(isA<UpdateCheckException>()),
          reason: 'HTTP $status',
        );
      }
    });

    test('throws UpdateCheckException on malformed JSON', () async {
      await expectLater(
        check(releasesClient(const [], rawBody: '<html>not json')),
        throwsA(isA<UpdateCheckException>()),
      );
      await expectLater(
        check(releasesClient(const [], rawBody: '[{"tag_name": ')),
        throwsA(isA<UpdateCheckException>()),
      );
    });

    test('throws UpdateCheckException when the body is JSON but not a list', () async {
      await expectLater(
        check(releasesClient(const [], rawBody: '{"message":"API rate limit exceeded"}')),
        throwsA(isA<UpdateCheckException>()),
      );
      await expectLater(
        check(releasesClient(const [], rawBody: 'null')),
        throwsA(isA<UpdateCheckException>()),
      );
    });

    test('a transport failure propagates for the caller to handle', () async {
      final client = MockClient((_) async => throw http.ClientException('offline'));
      await expectLater(check(client), throwsA(isA<http.ClientException>()));
    });

    test('gives up on a request that never answers', () async {
      final never = Completer<http.Response>();
      final client = MockClient((_) => never.future);
      await expectLater(
        UpdateChecker(client: client, timeout: const Duration(milliseconds: 20))
            .checkForUpdates(currentVersion: '2.2.0'),
        throwsA(isA<TimeoutException>()),
      );
    });
  });
}
