import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// GitHub's release list, not `/releases/latest`: `/latest` returns a single
/// release, so it can't give the "N releases behind" count that
/// `decideUpdateAction` needs. The list also includes drafts and prereleases,
/// which [UpdateChecker] filters out.
///
/// Public repo, unauthenticated, so no token ships in the APK. The 60 requests
/// an hour per IP limit is far above one check per launch.
const String releasesApiUrl =
    'https://api.github.com/repos/blueebeettle/cairn/releases';

/// The line in a release's notes that makes the update mandatory. See
/// [hasForceUpdateMarker].
const String forceUpdateMarker = 'FORCE_UPDATE';

/// A GitHub release, trimmed to what the updater needs.
class ReleaseInfo {
  const ReleaseInfo({
    required this.version,
    required this.tagName,
    required this.notes,
    required this.assets,
    required this.publishedAt,
    required this.isMandatory,
  });

  /// "2.3.0": the tag without its leading "v". Releases are compared and named
  /// by this, never by the build number (see [compareVersions]).
  final String version;

  /// "v2.3.0", as published.
  final String tagName;

  /// The release body, raw. It still contains the [forceUpdateMarker] line, so
  /// pass it through [releaseNotesForDisplay] before showing it.
  final String notes;

  /// Asset name -> download URL, for every asset on the release.
  final Map<String, String> assets;

  final DateTime publishedAt;

  /// Whether the notes carry the [forceUpdateMarker] line.
  final bool isMandatory;
}

/// Releases newer than [currentVersion] (no drafts or prereleases), newest
/// first. Empty when already current.
class ReleaseStatus {
  const ReleaseStatus({
    required this.newerReleases,
    required this.currentVersion,
  });

  final List<ReleaseInfo> newerReleases;
  final String currentVersion;

  /// The newest release, or null when already current.
  ReleaseInfo? get latest => newerReleases.isEmpty ? null : newerReleases.first;

  /// How many releases the running build is missing. Recomputed from the live
  /// list on every check rather than counted locally, so it can't drift.
  int get releasesBehind => newerReleases.length;
}

/// The release list could not be fetched or parsed.
///
/// Thrown for a non-200 response or a body that isn't a JSON array. Transport
/// failures (no connection, timeout) are not wrapped.
class UpdateCheckException implements Exception {
  const UpdateCheckException(this.message);

  final String message;

  @override
  String toString() => 'UpdateCheckException: $message';
}

/// Compares dotted versions numerically per segment, so "2.10.0" beats "2.9.0".
/// Returns a negative number, zero or a positive number as [a] is older than,
/// equal to or newer than [b].
///
/// Tolerant, because tags are typed by hand: a non-numeric or missing segment
/// counts as 0 ("2.3" == "2.3.0"), one leading "v" is ignored, and it never
/// throws, so one odd tag can't take the whole check down.
///
/// Compare by this, never by `PackageInfo.buildNumber`: tags carry only
/// MAJOR.MINOR.PATCH and diverge from the `+BUILD` suffix.
int compareVersions(String a, String b) {
  final left = _versionSegments(a);
  final right = _versionSegments(b);
  final length = left.length > right.length ? left.length : right.length;
  for (var i = 0; i < length; i++) {
    final l = i < left.length ? left[i] : 0;
    final r = i < right.length ? right[i] : 0;
    if (l != r) return l < r ? -1 : 1;
  }
  return 0;
}

List<int> _versionSegments(String version) {
  var v = version.trim();
  if (v.startsWith('v') || v.startsWith('V')) v = v.substring(1);
  return [for (final part in v.split('.')) _segmentValue(part)];
}

/// Digits only: `int.tryParse` alone accepts "+1" and "-1", and a negative
/// segment would sort below a missing one.
int _segmentValue(String segment) =>
    RegExp(r'^\d+$').hasMatch(segment) ? (int.tryParse(segment) ?? 0) : 0;

/// "v2.3.0" -> "2.3.0". Only the leading "v" is removed; [compareVersions]
/// copes with anything odd after it.
String versionFromTag(String tag) {
  final trimmed = tag.trim();
  return trimmed.startsWith('v') || trimmed.startsWith('V')
      ? trimmed.substring(1)
      : trimmed;
}

/// Whether [body], a release's notes, marks the release as mandatory: a line
/// that is exactly `FORCE_UPDATE` after trimming, ignoring case.
///
/// Whole line only, so notes can mention the mechanism without triggering it:
/// `NO_FORCE_UPDATE`, `FORCE_UPDATE:` and `**FORCE_UPDATE**` don't match. Lines
/// split on `\n`, `\r\n` and `\r`, because GitHub's web editor submits `\r\n`.
bool hasForceUpdateMarker(String body) {
  for (final line in const LineSplitter().convert(body)) {
    if (line.trim().toUpperCase() == forceUpdateMarker) return true;
  }
  return false;
}

/// [notes] with the [forceUpdateMarker] line removed. Blank lines left at either
/// end are trimmed; blank lines between paragraphs stay.
String releaseNotesForDisplay(String notes) {
  final kept = [
    for (final line in const LineSplitter().convert(notes))
      if (line.trim().toUpperCase() != forceUpdateMarker) line,
  ];
  return kept.join('\n').trim();
}

/// Asks GitHub which releases the running build is missing. The [http.Client]
/// is injected so tests never touch the network.
class UpdateChecker {
  /// [timeout] bounds the whole request: long enough for a slow connection,
  /// short enough that the Settings spinner doesn't look hung.
  UpdateChecker({
    required this._client,
    this._timeout = const Duration(seconds: 15),
  });

  final http.Client _client;
  final Duration _timeout;

  /// Fetches the release list, drops drafts and prereleases, and returns
  /// everything newer than [currentVersion], newest first. Throws on any
  /// network or parse failure; the caller decides whether to surface it.
  ///
  /// Reads only the first page (30 releases). That's enough, since an update
  /// turns mandatory five releases behind; follow the `Link` header here if
  /// releases ever become frequent.
  ///
  /// Sorted by version, not publish date, so a hotfix tagged v2.1.1 after
  /// v2.2.0 still ranks below it. An entry with no tag is skipped.
  Future<ReleaseStatus> checkForUpdates({required String currentVersion}) async {
    final http.Response response = await _client.get(
      Uri.parse(releasesApiUrl),
      headers: const {'Accept': 'application/vnd.github+json'},
    ).timeout(_timeout);

    if (response.statusCode != 200) {
      throw UpdateCheckException(
        'GitHub answered ${response.statusCode} for the release list.',
      );
    }

    final Object? decoded;
    try {
      // Always UTF-8: `http` falls back to Latin-1 when no charset is declared,
      // which garbles the dashes and quotes in release notes.
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException catch (e) {
      throw UpdateCheckException('The release list was not valid JSON: ${e.message}');
    }
    if (decoded is! List) {
      throw const UpdateCheckException('The release list was not a JSON array.');
    }

    final newer = <ReleaseInfo>[];
    for (final entry in decoded) {
      final release = _parseRelease(entry);
      if (release == null) continue;
      if (compareVersions(release.version, currentVersion) <= 0) continue;
      newer.add(release);
    }
    newer.sort((a, b) {
      final byVersion = compareVersions(b.version, a.version);
      return byVersion != 0 ? byVersion : b.publishedAt.compareTo(a.publishedAt);
    });

    return ReleaseStatus(newerReleases: newer, currentVersion: currentVersion);
  }

  /// One list entry as a [ReleaseInfo], or null for a draft, a prerelease or an
  /// entry with no usable tag.
  static ReleaseInfo? _parseRelease(Object? entry) {
    if (entry is! Map<String, dynamic>) return null;
    if (entry['draft'] == true || entry['prerelease'] == true) return null;

    final tag = entry['tag_name'];
    if (tag is! String || tag.trim().isEmpty) return null;

    // `body` is null, not "", on a release with no notes.
    final body = entry['body'] is String ? entry['body'] as String : '';

    final assets = <String, String>{};
    final rawAssets = entry['assets'];
    if (rawAssets is List) {
      for (final asset in rawAssets) {
        if (asset is! Map<String, dynamic>) continue;
        final name = asset['name'];
        final url = asset['browser_download_url'];
        if (name is String && url is String) assets[name] = url;
      }
    }

    final published = entry['published_at'] is String
        ? DateTime.tryParse(entry['published_at'] as String)
        : null;

    return ReleaseInfo(
      version: versionFromTag(tag),
      tagName: tag,
      notes: body,
      assets: assets,
      publishedAt: published ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      isMandatory: hasForceUpdateMarker(body),
    );
  }
}
