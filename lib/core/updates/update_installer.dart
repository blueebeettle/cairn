import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'apk_asset_matcher.dart';

/// The release asset that carries the published SHA-256 of each APK, in the
/// shape the hand-generated `checksums.json` has always had:
/// `[{"Name", "Bytes", "SizeMB", "SHA256", "Path"}, ...]`.
const String checksumsAssetName = 'checksums.json';

/// The MIME type Android's package installer registers for.
const String _apkMimeType = 'application/vnd.android.package-archive';

/// Why an update could not be installed. The dialog turns each into a plain
/// sentence; none of the exception text behind them is ever shown.
enum UpdateFailure {
  /// The APK did not arrive: no connection, a non-200 answer, a stalled or cut
  /// off transfer, or a disk error writing it.
  download,

  /// `checksums.json` is on the release but could not be used — it could not be
  /// fetched, is not the expected shape, or has no entry for this APK. See
  /// [UpdateInstaller.downloadAndVerify] for why that stops the install.
  checksumUnavailable,

  /// The downloaded file's SHA-256 is not the published one.
  checksumMismatch,

  /// Android would not take the verified file (see [UpdateInstaller.install]).
  installerNotLaunched,
}

class UpdateInstallException implements Exception {
  const UpdateInstallException(this.failure, this.message);

  final UpdateFailure failure;

  /// For logs and tests, not for people.
  final String message;

  @override
  String toString() => 'UpdateInstallException(${failure.name}): $message';
}

/// The tester backed out of the download. Not a failure, so not an
/// [UpdateInstallException].
class UpdateCancelledException implements Exception {
  const UpdateCancelledException();
}

/// Lets the UI stop a download it started. Checked between chunks, so a
/// cancel lands within one chunk of the tester's tap.
class UpdateCancelToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;
}

/// Byte progress. [total] is null when the server did not say how long the
/// file is.
typedef DownloadProgress = void Function(int received, int? total);

/// Hands a file to the platform to open. Injected so the order of operations
/// (verify, *then* open) can be tested without a device.
typedef ApkOpener = Future<OpenResult> Function(String path);

Future<OpenResult> _openWithPlatform(String path) =>
    OpenFilex.open(path, type: _apkMimeType);

/// Downloads a release's APK, checks it against the published checksum, and
/// hands it to Android's package installer.
///
/// The three outside dependencies — the HTTP client, the directory to
/// download into, and the thing that opens the file — are constructor
/// arguments so tests can supply fakes and never touch the network, the real
/// filesystem layout or a device.
class UpdateInstaller {
  UpdateInstaller({
    required this._client,
    Future<Directory> Function()? tempDirectory,
    ApkOpener? opener,
  })  : _tempDirectory = tempDirectory ?? getTemporaryDirectory,
        _opener = opener ?? _openWithPlatform;

  final http.Client _client;
  final Future<Directory> Function() _tempDirectory;
  final ApkOpener _opener;

  /// How long to wait for a server to start answering.
  static const Duration _connectTimeout = Duration(seconds: 30);

  /// How long a download may go without a single byte arriving before it is
  /// treated as dead. A stalled transfer would otherwise leave the progress bar
  /// frozen forever.
  static const Duration _stallTimeout = Duration(seconds: 30);

  /// Downloads [apk] into the temp directory and returns it once it is known to
  /// be the file the release published.
  ///
  /// [checksumsUrl] is the release's `checksums.json` asset, or null when the
  /// release has none. Null skips verification: releases that predate this
  /// feature never had one, and refusing them would strand testers on exactly
  /// the old builds that need to move. It is the *only* way verification is
  /// skipped. A `checksums.json` that exists but cannot be fetched or parsed,
  /// or that has no entry for this APK, fails with
  /// [UpdateFailure.checksumUnavailable] instead of installing an unverified
  /// file — the publisher put the file there to be checked against. The
  /// checksums are read *before* the download, so that failure costs a few
  /// kilobytes rather than a 70MB transfer.
  ///
  /// What this protects against: a corrupt or truncated download. It does not
  /// defend against a tampered release, since the checksums come from the same
  /// place as the APK — that is Android's job, which refuses to install an
  /// update signed with a different key.
  ///
  /// On *any* failure — a download error, a cancel, a mismatch — the file is
  /// deleted before the exception leaves, so temp storage never keeps a partial
  /// or rejected APK. A file that fails its checksum is never returned, so
  /// nothing downstream can offer to install it. Any APK left from an earlier
  /// attempt is cleared first.
  ///
  /// [onVerifying] fires once, after the last byte lands and before hashing
  /// starts, so the UI can swap its progress bar for a "verifying" state.
  /// Throws [UpdateInstallException] or [UpdateCancelledException].
  Future<File> downloadAndVerify({
    required ApkAsset apk,
    String? checksumsUrl,
    DownloadProgress? onProgress,
    void Function()? onVerifying,
    UpdateCancelToken? cancel,
  }) async {
    final expectedSha256 =
        checksumsUrl == null ? null : await _expectedSha256(checksumsUrl, apk.name);

    final dir = await _tempDirectory();
    await _clearStaleApks(dir);
    // The asset name is the file name, so a stray separator in it must not be
    // able to walk out of the temp directory.
    final file = File('${dir.path}/${apk.name.replaceAll(RegExp(r'[\\/]'), '_')}');

    try {
      await _download(apk.url, file, onProgress, cancel);
      if (expectedSha256 != null) {
        onVerifying?.call();
        // Off the main isolate: hashing 25-70MB is long enough to drop frames
        // out from under the progress UI.
        final actual = await Isolate.run(() => _sha256OfFile(file.path));
        if (actual.toLowerCase() != expectedSha256.toLowerCase()) {
          throw const UpdateInstallException(
            UpdateFailure.checksumMismatch,
            'The downloaded APK does not match its published SHA-256.',
          );
        }
      }
      return file;
    } on UpdateInstallException {
      await _deleteQuietly(file);
      rethrow;
    } on UpdateCancelledException {
      await _deleteQuietly(file);
      rethrow;
    } catch (e) {
      await _deleteQuietly(file);
      throw UpdateInstallException(UpdateFailure.download, '$e');
    }
  }

  /// Hands a verified [apk] to Android's package installer.
  ///
  /// Returns normally when the install intent launched. That is *all* it
  /// means: the system installer now owns the screen and may still be waiting
  /// on the tester, who can back out of it, or has to first allow installs from
  /// this app — Android shows that prompt itself because the manifest declares
  /// `REQUEST_INSTALL_PACKAGES`. There is no callback for how it ends. A
  /// successful install replaces this process, so the only outcome the app
  /// ever observes is the tester coming back to it.
  ///
  /// Anything other than a launch deletes the file and throws
  /// [UpdateFailure.installerNotLaunched]; the plugin's own message is kept on
  /// the exception for logs.
  Future<void> install(File apk) async {
    final OpenResult result;
    try {
      result = await _opener(apk.path);
    } catch (e) {
      await _deleteQuietly(apk);
      throw UpdateInstallException(UpdateFailure.installerNotLaunched, '$e');
    }
    if (result.type != ResultType.done) {
      await _deleteQuietly(apk);
      throw UpdateInstallException(
        UpdateFailure.installerNotLaunched,
        '${result.type.name}: ${result.message}',
      );
    }
  }

  /// Deletes a file [downloadAndVerify] returned that is not going to be
  /// installed after all — the tester cancelled in the instant between the last
  /// byte arriving and the install starting.
  Future<void> discard(File apk) => _deleteQuietly(apk);

  Future<void> _download(
    String url,
    File file,
    DownloadProgress? onProgress,
    UpdateCancelToken? cancel,
  ) async {
    // Redirects are followed by default, which this needs: a release asset's
    // browser_download_url answers 302 and the bytes live on GitHub's CDN.
    final response =
        await _client.send(http.Request('GET', Uri.parse(url))).timeout(_connectTimeout);
    if (response.statusCode != 200) {
      await response.stream.drain<void>();
      throw UpdateInstallException(
        UpdateFailure.download,
        'The server answered ${response.statusCode} for the APK.',
      );
    }

    final total = response.contentLength;
    var received = 0;
    final sink = file.openWrite();
    try {
      await for (final chunk in response.stream.timeout(_stallTimeout)) {
        if (cancel?.isCancelled ?? false) throw const UpdateCancelledException();
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
    } finally {
      await sink.close();
    }

    // A connection that closes early can end the stream without an error. When
    // the length was announced, holding the file to it catches a short file
    // even if the release has no checksum to catch it for us.
    if (total != null && received != total) {
      throw UpdateInstallException(
        UpdateFailure.download,
        'Received $received of $total bytes.',
      );
    }
  }

  /// The SHA-256 `checksums.json` publishes for [assetName].
  Future<String> _expectedSha256(String url, String assetName) async {
    final Object? decoded;
    try {
      final response = await _client.get(Uri.parse(url)).timeout(_connectTimeout);
      if (response.statusCode != 200) {
        throw UpdateInstallException(
          UpdateFailure.checksumUnavailable,
          'The checksums answered ${response.statusCode}.',
        );
      }
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } on UpdateInstallException {
      rethrow;
    } catch (e) {
      throw UpdateInstallException(UpdateFailure.checksumUnavailable, '$e');
    }

    // PowerShell's ConvertTo-Json turns a one-element list into a bare object,
    // so a release with a single APK can have been generated that way.
    final entries = decoded is List ? decoded : [decoded];
    for (final entry in entries) {
      if (entry is! Map) continue;
      // Keys are matched ignoring case: the hand-generated file is PowerShell's
      // (`Name`, `SHA256`) and nothing should hinge on that capitalisation.
      final fields = {
        for (final e in entry.entries) e.key.toString().toLowerCase(): e.value,
      };
      final hash = fields['sha256'];
      if (fields['name'] == assetName && hash is String && hash.trim().isNotEmpty) {
        return hash.trim();
      }
    }
    throw UpdateInstallException(
      UpdateFailure.checksumUnavailable,
      'checksums.json has no SHA-256 for $assetName.',
    );
  }

  /// Removes APKs an earlier attempt left in [dir] — including the one that
  /// installed the version now running — so the cache holds at most one.
  ///
  /// Only files matching the release-asset naming are touched; this is the
  /// app's cache directory and other things live in it.
  static Future<void> _clearStaleApks(Directory dir) async {
    try {
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = entity.uri.pathSegments.last;
        if (RegExp(r'^cairn-v.*\.apk$').hasMatch(name)) {
          await _deleteQuietly(entity);
        }
      }
    } catch (_) {}
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}

/// SHA-256 of the file at [path], streamed so it is never held in memory whole.
/// Top level so [Isolate.run] can send it to another isolate.
Future<String> _sha256OfFile(String path) async =>
    (await sha256.bind(File(path).openRead()).first).toString();
