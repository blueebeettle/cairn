import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Where the updater looks for releases: the plural list endpoint, not
/// `/releases/latest`. `/latest` returns a single release, so it cannot say
/// how many releases the running build is behind — and that count is what the
/// "too far behind" rule in `decideUpdateAction` is built on. The cost of the
/// list endpoint is that it does not hide drafts and prereleases for us the
/// way `/latest` does, so [UpdateChecker] filters them itself.
///
/// Public repository, unauthenticated request, on purpose: this URL ships
/// inside the APK, so there is no token to leak because there is no token. The
/// unauthenticated limit is 60 requests an hour per IP, far above one check
/// per launch for a handful of testers.
const String releasesApiUrl =
    'https://api.github.com/repos/blueebeettle/cairn/releases';

/// The line a release's notes carry to mark it unskippable. See
/// [hasForceUpdateMarker].
const String forceUpdateMarker = 'FORCE_UPDATE';

/// What GitHub's release API gave us, trimmed to what the updater needs.
class ReleaseInfo {
  const ReleaseInfo({
    required this.version,
    required this.tagName,
    required this.notes,
    required this.assets,
    required this.publishedAt,
    required this.isMandatory,
  });

  /// "2.3.0" — the tag with its leading "v" stripped. This, never the build
  /// number, is what releases are compared and named by (see
  /// [compareVersions]).
  final String version;

  /// "v2.3.0", exactly as published.
  final String tagName;

  /// The release's body, for display. Raw, so it still contains the
  /// [forceUpdateMarker] line when there is one; run it through
  /// [releaseNotesForDisplay] before showing it to a person.
  final String notes;

  /// Asset name -> download URL, for every asset on the release. Nothing is
  /// pre-selected here: choosing the APK for a device is `selectApkAsset`'s
  /// job, and finding `checksums.json` is the installer's.
  final Map<String, String> assets;

  final DateTime publishedAt;

  /// Whether the release's notes carry the [forceUpdateMarker] line.
  final bool isMandatory;
}

/// Every non-draft, non-prerelease release newer than [currentVersion],
/// newest first. Empty when already current. [latest] is simply the first
/// element — kept as a named getter so callers don't reach for `.first`
/// on a list that might be empty.
class ReleaseStatus {
  const ReleaseStatus({
    required this.newerReleases,
    required this.currentVersion,
  });

  final List<ReleaseInfo> newerReleases;
  final String currentVersion;

  ReleaseInfo? get latest => newerReleases.isEmpty ? null : newerReleases.first;

  /// How many published releases the running build is missing. Recomputed from
  /// the live release list on every check rather than counted locally, so it
  /// cannot drift: a tester who skips opening the app across three releases is
  /// still told the true number the next time they do.
  int get releasesBehind => newerReleases.length;
}

/// The release list could not be fetched or understood.
///
/// Thrown for a non-200 response and for a body that is not the JSON array
/// GitHub documents. Transport failures (no connection, a timeout) are not
/// wrapped — they already have clean types of their own — so callers that only
/// care *whether* it worked catch everything.
class UpdateCheckException implements Exception {
  const UpdateCheckException(this.message);

  final String message;

  @override
  String toString() => 'UpdateCheckException: $message';
}

/// Compares dotted version strings ("2.2.0" vs "2.3.0") numerically,
/// segment by segment, not lexicographically ("2.10.0" must beat "2.9.0").
///
/// Returns a negative number, zero or a positive number as [a] is older than,
/// equal to or newer than [b].
///
/// Tolerant by design, because tags are typed by hand on GitHub's website. A
/// segment that is not a plain run of digits (`0-beta`, `x`, an empty string
/// from `2..1`) counts as 0, and a missing segment counts as 0, so "2.3" ==
/// "2.3.0" and a malformed tag compares as if the broken part were absent — it
/// never throws, which is what keeps one odd tag from taking the whole update
/// check down with it. One leading "v" is ignored for the same reason: a
/// caller that hands in the raw tag should not have it read as 0.3.0.
///
/// Compare by this, never by `PackageInfo.buildNumber`: the tag only carries
/// MAJOR.MINOR.PATCH, and the tag and the `+BUILD` suffix are free to diverge.
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

/// Digits only: `int.tryParse` alone would also accept "+1" and "-1", and a
/// negative segment would sort a release *below* a missing one.
int _segmentValue(String segment) =>
    RegExp(r'^\d+$').hasMatch(segment) ? (int.tryParse(segment) ?? 0) : 0;

/// "v2.3.0" -> "2.3.0". Only the leading "v" goes; whatever follows is left
/// alone for [compareVersions] to be forgiving about.
String versionFromTag(String tag) {
  final trimmed = tag.trim();
  return trimmed.startsWith('v') || trimmed.startsWith('V')
      ? trimmed.substring(1)
      : trimmed;
}

/// Whether [body] — a release's notes — marks that release as mandatory.
///
/// The convention is a plain-text one, typed once into the notes on GitHub's
/// website with nothing structured to maintain: a line that is, after
/// trimming whitespace and ignoring case, exactly `FORCE_UPDATE`.
///
/// "On its own line" is the whole line, not a substring of it. A sentence that
/// merely mentions the token ("We removed the FORCE_UPDATE flag"), a longer
/// word that contains it (`NO_FORCE_UPDATE`, `FORCE_UPDATES`) and a line with
/// extra punctuation (`FORCE_UPDATE:`) all fail to match, so release notes can
/// talk about the mechanism without triggering it. Markdown decoration also
/// counts as extra text — `**FORCE_UPDATE**` or a code-formatted token is not
/// the marker; type it bare. Line endings of every kind (`\n`, `\r\n`, `\r`)
/// split lines, because GitHub's web editor submits `\r\n`.
bool hasForceUpdateMarker(String body) {
  for (final line in const LineSplitter().convert(body)) {
    if (line.trim().toUpperCase() == forceUpdateMarker) return true;
  }
  return false;
}

/// [notes] with the [forceUpdateMarker] line removed, ready to show.
///
/// The marker is an instruction to the app, not something for a tester to
/// read. Blank lines the removal leaves at either end are trimmed too; blank
/// lines between paragraphs stay.
String releaseNotesForDisplay(String notes) {
  final kept = [
    for (final line in const LineSplitter().convert(notes))
      if (line.trim().toUpperCase() != forceUpdateMarker) line,
  ];
  return kept.join('\n').trim();
}

/// Asks GitHub which releases the running build is missing.
///
/// Takes its [http.Client] by constructor injection so tests can hand in a
/// fake and never touch the network.
class UpdateChecker {
  /// [timeout] bounds the whole request. The default is long enough for a slow
  /// mobile connection and short enough that the Settings row's spinner does not
  /// turn into a hang; tests pass something tiny.
  UpdateChecker({
    required this._client,
    this._timeout = const Duration(seconds: 15),
  });

  final http.Client _client;
  final Duration _timeout;

  /// Hits GitHub's public, unauthenticated releases API for this repo,
  /// fetches every release (first page — see below), drops drafts and
  /// prereleases, and returns everything newer than [currentVersion] sorted
  /// newest-first. Throws on any network/parse failure — the caller decides
  /// how to treat that (silently, on launch; visibly, from the Settings
  /// button).
  ///
  /// Known limit: the endpoint is paginated at 30 releases a page and only the
  /// first page is read. That is deliberate, not an oversight. This repo ships
  /// tags infrequently, and a tester is forced to update (see
  /// `decideUpdateAction`) five releases behind — long before the list could
  /// outgrow one page. If releases ever become frequent enough for that to
  /// stop being true, this is where to follow the `Link` header.
  ///
  /// Releases are ordered by version, not by publish date: a hotfix tagged
  /// v2.1.1 *after* v2.2.0 still ranks below it. A release that cannot be
  /// understood (no tag) is skipped rather than failing the whole check.
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
      // Decoded as UTF-8 regardless of the declared charset: JSON is UTF-8,
      // and the `http` package falls back to Latin-1 when a response omits
      // one, which would garble the dashes and quotes in release notes.
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

  /// One list entry as a [ReleaseInfo], or null when it is a draft, a
  /// prerelease, or has no usable tag.
  ///
  /// The list endpoint returns drafts (to anyone who can see them) and
  /// prereleases alongside real releases; neither is something to push onto a
  /// tester.
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
