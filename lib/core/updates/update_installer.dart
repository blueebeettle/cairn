import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'apk_asset_matcher.dart';

/// The release asset holding each APK's published SHA-256:
/// `[{"Name", "Bytes", "SizeMB", "SHA256", "Path"}, ...]`.
const String checksumsAssetName = 'checksums.json';

/// The MIME type Android's package installer registers for.
const String _apkMimeType = 'application/vnd.android.package-archive';

/// Why an update could not be installed. The dialog shows a plain sentence for
/// each; the exception text behind them is never shown.
enum UpdateFailure {
  /// The APK did not arrive: no connection, a non-200 answer, a stalled or cut
  /// off transfer, or a disk error.
  download,

  /// `checksums.json` is on the release but unusable: it couldn't be fetched,
  /// has the wrong shape, or has no entry for this APK. See
  /// [UpdateInstaller.downloadAndVerify].
  checksumUnavailable,

  /// The downloaded file's SHA-256 doesn't match the published one.
  checksumMismatch,

  /// Android wouldn't take the verified file (see [UpdateInstaller.install]).
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

/// The tester cancelled the download. Not a failure, so not an
/// [UpdateInstallException].
class UpdateCancelledException implements Exception {
  const UpdateCancelledException();
}

/// Lets the UI stop a download. Checked between chunks.
class UpdateCancelToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;
}

/// Byte progress. [total] is null when the server didn't send a length.
typedef DownloadProgress = void Function(int received, int? total);

/// Opens a file with the platform. Injected so tests can check the order
/// (verify, then open) without a device.
typedef ApkOpener = Future<OpenResult> Function(String path);

Future<OpenResult> _openWithPlatform(String path) =>
    OpenFilex.open(path, type: _apkMimeType);

/// Downloads a release's APK, checks it against the published checksum, and
/// hands it to Android's package installer.
///
/// The HTTP client, temp directory and file opener are constructor arguments so
/// tests can fake them.
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

  /// How long a download may go without a byte arriving before it counts as
  /// dead, so a stalled transfer doesn't freeze the progress bar forever.
  static const Duration _stallTimeout = Duration(seconds: 30);

  /// Downloads [apk] into the temp directory and returns it once it's known to
  /// be the file the release published.
  ///
  /// [checksumsUrl] is the release's `checksums.json` asset, or null if it has
  /// none. Null is the only way verification is skipped: releases that predate
  /// checksums never had one, and refusing them would strand testers on the old
  /// builds that most need to move. A `checksums.json` that exists but can't be
  /// fetched or parsed, or has no entry for this APK, fails with
  /// [UpdateFailure.checksumUnavailable] rather than installing unverified. It
  /// is read *before* the download, so that failure costs kilobytes, not 70MB.
  ///
  /// This guards against a corrupt or truncated download, not a tampered
  /// release: the checksums come from the same place as the APK. Android covers
  /// that by refusing an update signed with a different key.
  ///
  /// On any failure (download error, cancel, mismatch) the file is deleted
  /// before the exception leaves, so a partial or rejected APK is never kept or
  /// returned. APKs from earlier attempts are cleared first.
  ///
  /// [onVerifying] fires once, after the last byte lands and before hashing, so
  /// the UI can swap its progress bar for a "verifying" state. Throws
  /// [UpdateInstallException] or [UpdateCancelledException].
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
    // A separator in the asset name must not walk out of the temp directory.
    final file = File('${dir.path}/${apk.name.replaceAll(RegExp(r'[\\/]'), '_')}');

    try {
      await _download(apk.url, file, onProgress, cancel);
      if (expectedSha256 != null) {
        onVerifying?.call();
        // Off the main isolate: hashing 25-70MB would drop frames.
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
  /// Returning normally means only that the install intent launched. The system
  /// installer now owns the screen and may still be waiting on the tester, who
  /// can back out or must first allow installs from this app (a prompt Android
  /// shows itself, because the manifest declares `REQUEST_INSTALL_PACKAGES`).
  /// There is no callback, and a successful install replaces this process, so
  /// the only outcome the app ever sees is the tester coming back.
  ///
  /// Anything other than a launch deletes the file and throws
  /// [UpdateFailure.installerNotLaunched], keeping the plugin's message for logs.
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

  /// Deletes a file [downloadAndVerify] returned that won't be installed after
  /// all: the tester cancelled between the last byte and the install.
  Future<void> discard(File apk) => _deleteQuietly(apk);

  Future<void> _download(
    String url,
    File file,
    DownloadProgress? onProgress,
    UpdateCancelToken? cancel,
  ) async {
    // Redirects (followed by default) are needed: a release asset's
    // browser_download_url answers 302 to GitHub's CDN.
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

    // A connection closing early can end the stream without an error. Checking
    // the announced length catches a short file even when there's no checksum.
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

    // PowerShell's ConvertTo-Json turns a one-element list into a bare object.
    final entries = decoded is List ? decoded : [decoded];
    for (final entry in entries) {
      if (entry is! Map) continue;
      // Keys match case-insensitively; the hand-generated file uses PowerShell's
      // `Name` and `SHA256`.
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

  /// Removes APKs earlier attempts left in [dir], including the one that
  /// installed the running version, so the cache holds at most one. Only files
  /// matching the release-asset naming are touched; other things live here.
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

/// SHA-256 of the file at [path], streamed. Top level so [Isolate.run] can use it.
Future<String> _sha256OfFile(String path) async =>
    (await sha256.bind(File(path).openRead()).first).toString();
