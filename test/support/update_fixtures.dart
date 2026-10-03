// Shared fixtures for the in-app updater's tests: GitHub-shaped release JSON, a
// mock HTTP client that serves it, and ReleaseInfo builders. Nothing here
// touches the network.

import 'dart:convert';

import 'package:habit_tracker/core/updates/update_checker.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// The four APK names a release carries, plus the checksums file, as a real
/// release published under the existing build convention would.
List<String> standardAssetNames(String version) => [
      'cairn-v$version-arm64-v8a.apk',
      'cairn-v$version-armeabi-v7a.apk',
      'cairn-v$version-x86_64.apk',
      'cairn-v$version-universal.apk',
      'checksums.json',
    ];

String assetUrl(String tag, String name) =>
    'https://github.com/blueebeettle/cairn/releases/download/$tag/$name';

/// One entry of GitHub's `GET /repos/.../releases` array, trimmed to the fields
/// the updater reads (the shape in the spec's REQUIREMENT 10).
Map<String, dynamic> ghRelease(
  String tag, {
  Object? body = '',
  bool draft = false,
  bool prerelease = false,
  String? publishedAt = '2026-10-05T12:00:00Z',
  List<String>? assetNames,
}) {
  final version = versionFromTag(tag);
  return {
    'tag_name': tag,
    'name': 'Cairn $version',
    'body': body,
    'draft': draft,
    'prerelease': prerelease,
    'published_at': publishedAt,
    'assets': [
      for (final name in assetNames ?? standardAssetNames(version))
        {
          'name': name,
          'browser_download_url': assetUrl(tag, name),
          'size': 25900000,
        },
    ],
  };
}

/// A client that answers the releases request with [releases] as JSON, or with
/// [status] and [rawBody] when given. Every request it sees lands in [log].
MockClient releasesClient(
  List<Map<String, dynamic>> releases, {
  int status = 200,
  String? rawBody,
  List<http.BaseRequest>? log,
}) {
  return MockClient((request) async {
    log?.add(request);
    return http.Response.bytes(
      utf8.encode(rawBody ?? jsonEncode(releases)),
      status,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

/// A [ReleaseInfo] without going through JSON.
ReleaseInfo fakeRelease(
  String version, {
  bool mandatory = false,
  String notes = '',
  Map<String, String>? assets,
}) {
  final tag = 'v$version';
  return ReleaseInfo(
    version: version,
    tagName: tag,
    notes: notes,
    assets: assets ??
        {for (final n in standardAssetNames(version)) n: assetUrl(tag, n)},
    publishedAt: DateTime.utc(2026, 10, 5),
    isMandatory: mandatory,
  );
}

/// [count] releases, newest first, 2.(2+count).0 down to 2.3.0 — i.e. what a
/// tester on 2.2.0 is behind by. [latestMandatory] marks only the newest.
ReleaseStatus statusBehind(int count, {bool latestMandatory = false}) {
  final releases = [
    for (var i = count; i >= 1; i--)
      fakeRelease('2.${2 + i}.0', mandatory: latestMandatory && i == count),
  ];
  return ReleaseStatus(newerReleases: releases, currentVersion: '2.2.0');
}
