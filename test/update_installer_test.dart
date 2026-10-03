// Download, checksum verification and the hand-off to Android's installer, run
// against a mock HTTP client and a real temp directory. The one thing faked on
// the platform side is "open this file" — which is how the order of events
// (verify first, open second) can be pinned down without a device.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/updates/apk_asset_matcher.dart';
import 'package:habit_tracker/core/updates/update_installer.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:open_filex/open_filex.dart';

const _apkUrl = 'https://example.test/cairn-v2.3.0-arm64-v8a.apk';
const _checksumsUrl = 'https://example.test/checksums.json';
const _apk = ApkAsset(name: 'cairn-v2.3.0-arm64-v8a.apk', url: _apkUrl);

/// 10 KB of non-repeating-looking bytes, so a corrupted copy cannot match.
final _apkBytes = List<int>.generate(10000, (i) => (i * 7 + 3) % 251);
final _apkSha256 = sha256.convert(_apkBytes).toString();

String _checksumsJson({
  String name = 'cairn-v2.3.0-arm64-v8a.apk',
  String? hash,
  bool asList = true,
}) {
  final entry = {
    'Name': name,
    'Bytes': _apkBytes.length,
    'SizeMB': 0.01,
    // PowerShell's Get-FileHash writes upper case, which is what the existing
    // hand-generated checksums.json holds.
    'SHA256': hash ?? _apkSha256.toUpperCase(),
    'Path': r'D:\build\release\cairn-v2.3.0-arm64-v8a.apk',
  };
  return jsonEncode(asList
      ? [
          {...entry, 'Name': 'cairn-v2.3.0-universal.apk', 'SHA256': 'AB' * 32},
          entry,
        ]
      : entry);
}

http.StreamedResponse _streamOf(
  List<int> data, {
  int status = 200,
  int? contentLength,
  int chunkSize = 1000,
}) {
  final chunks = [
    for (var i = 0; i < data.length; i += chunkSize)
      data.sublist(i, i + chunkSize > data.length ? data.length : i + chunkSize),
  ];
  return http.StreamedResponse(
    Stream.fromIterable(chunks),
    status,
    contentLength: contentLength ?? data.length,
  );
}

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('cairn_update_test_');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  /// A server for the APK and checksums URLs. [requested] logs every URL hit.
  MockClient server({
    List<int>? apk,
    int apkStatus = 200,
    int? apkContentLength,
    String? checksums,
    int checksumsStatus = 200,
    List<String>? requested,
  }) {
    return MockClient.streaming((request, _) async {
      requested?.add(request.url.toString());
      if (request.url.toString() == _apkUrl) {
        return _streamOf(apk ?? _apkBytes,
            status: apkStatus, contentLength: apkContentLength);
      }
      if (request.url.toString() == _checksumsUrl) {
        return _streamOf(utf8.encode(checksums ?? _checksumsJson()),
            status: checksumsStatus);
      }
      return _streamOf(const [], status: 404);
    });
  }

  UpdateInstaller installerFor(MockClient client, {ApkOpener? opener}) =>
      UpdateInstaller(
        client: client,
        tempDirectory: () async => dir,
        opener: opener ?? (_) async => OpenResult(),
      );

  Future<List<String>> filesInDir() async =>
      [for (final f in await dir.list().toList()) f.uri.pathSegments.last];

  group('downloadAndVerify', () {
    test('a matching checksum passes and returns the file', () async {
      final events = <String>[];
      final progress = <(int, int?)>[];

      final file = await installerFor(server()).downloadAndVerify(
        apk: _apk,
        checksumsUrl: _checksumsUrl,
        onProgress: (r, t) => progress.add((r, t)),
        onVerifying: () => events.add('verifying'),
      );

      expect(file.path, startsWith(dir.path));
      expect(file.uri.pathSegments.last, 'cairn-v2.3.0-arm64-v8a.apk');
      expect(await file.readAsBytes(), _apkBytes);
      expect(events, ['verifying']);

      // Byte progress against Content-Length, ending at the whole file.
      expect(progress, hasLength(10));
      expect(progress.last, (10000, 10000));
      expect([for (final p in progress) p.$1], orderedEquals([
        for (var i = 1; i <= 10; i++) i * 1000,
      ]));
    });

    test('the published hash compares case-insensitively', () async {
      final lower = _checksumsJson(hash: _apkSha256.toLowerCase());
      final upper = _checksumsJson(hash: _apkSha256.toUpperCase());
      for (final body in [lower, upper]) {
        final file = await installerFor(server(checksums: body))
            .downloadAndVerify(apk: _apk, checksumsUrl: _checksumsUrl);
        expect(await file.exists(), isTrue);
      }
    });

    test('a checksums.json holding a single object, not a list, is understood', () async {
      final body = _checksumsJson(asList: false);
      final file = await installerFor(server(checksums: body))
          .downloadAndVerify(apk: _apk, checksumsUrl: _checksumsUrl);
      expect(await file.exists(), isTrue);
    });

    test('a mismatched hash is rejected and the file is deleted', () async {
      final wrong = sha256.convert(utf8.encode('something else')).toString();

      await expectLater(
        installerFor(server(checksums: _checksumsJson(hash: wrong))).downloadAndVerify(
          apk: _apk,
          checksumsUrl: _checksumsUrl,
        ),
        throwsA(isA<UpdateInstallException>()
            .having((e) => e.failure, 'failure', UpdateFailure.checksumMismatch)),
      );

      expect(await filesInDir(), isEmpty, reason: 'the rejected APK must not be kept');
    });

    test('a download corrupted in flight is caught by the checksum', () async {
      final corrupted = [..._apkBytes]..[5000] ^= 0xFF;

      await expectLater(
        installerFor(server(apk: corrupted))
            .downloadAndVerify(apk: _apk, checksumsUrl: _checksumsUrl),
        throwsA(isA<UpdateInstallException>()
            .having((e) => e.failure, 'failure', UpdateFailure.checksumMismatch)),
      );
      expect(await filesInDir(), isEmpty);
    });

    test('a release with no checksums.json proceeds without verifying', () async {
      final requested = <String>[];
      var verifying = false;

      final file = await installerFor(server(requested: requested)).downloadAndVerify(
        apk: _apk,
        checksumsUrl: null,
        onVerifying: () => verifying = true,
      );

      expect(await file.readAsBytes(), _apkBytes);
      expect(verifying, isFalse);
      expect(requested, [_apkUrl], reason: 'no checksums asset, so none is fetched');
    });

    test('a checksums.json with no entry for this APK stops the install', () async {
      final requested = <String>[];
      final body = _checksumsJson(name: 'cairn-v2.3.0-x86_64.apk');
      // The list form holds a universal entry and the (renamed) x86_64 one;
      // neither is the arm64 build being installed.
      await expectLater(
        installerFor(server(checksums: body, requested: requested))
            .downloadAndVerify(apk: _apk, checksumsUrl: _checksumsUrl),
        throwsA(isA<UpdateInstallException>()
            .having((e) => e.failure, 'failure', UpdateFailure.checksumUnavailable)),
      );
      // Found out from a few KB of JSON, before spending a 70MB download.
      expect(requested, [_checksumsUrl]);
      expect(await filesInDir(), isEmpty);
    });

    test('a checksums.json that cannot be fetched or read stops the install', () async {
      for (final client in [
        server(checksumsStatus: 404),
        server(checksums: '<html>not json'),
        server(checksums: '"just a string"'),
        server(checksums: '[{"Name":"cairn-v2.3.0-arm64-v8a.apk"}]'),
        server(checksums: '[{"Name":"cairn-v2.3.0-arm64-v8a.apk","SHA256":""}]'),
      ]) {
        await expectLater(
          installerFor(client)
              .downloadAndVerify(apk: _apk, checksumsUrl: _checksumsUrl),
          throwsA(isA<UpdateInstallException>().having(
              (e) => e.failure, 'failure', UpdateFailure.checksumUnavailable)),
        );
      }
      expect(await filesInDir(), isEmpty);
    });

    test('a failed APK request is a download failure and leaves nothing behind', () async {
      await expectLater(
        installerFor(server(apkStatus: 404))
            .downloadAndVerify(apk: _apk, checksumsUrl: _checksumsUrl),
        throwsA(isA<UpdateInstallException>()
            .having((e) => e.failure, 'failure', UpdateFailure.download)),
      );
      expect(await filesInDir(), isEmpty);
    });

    test('a transfer that ends short of Content-Length is a download failure', () async {
      // Announces 10000 bytes, delivers 4000, ends without an error — with no
      // checksum on the release this is the only thing that can catch it.
      await expectLater(
        installerFor(server(apk: _apkBytes.sublist(0, 4000), apkContentLength: 10000))
            .downloadAndVerify(apk: _apk, checksumsUrl: null),
        throwsA(isA<UpdateInstallException>()
            .having((e) => e.failure, 'failure', UpdateFailure.download)),
      );
      expect(await filesInDir(), isEmpty);
    });

    test('a network error mid-flight is a download failure, file deleted', () async {
      final client = MockClient.streaming((request, _) async {
        Stream<List<int>> failing() async* {
          yield _apkBytes.sublist(0, 2000);
          throw const SocketException('connection reset');
        }

        return http.StreamedResponse(failing(), 200, contentLength: 10000);
      });
      await expectLater(
        installerFor(client).downloadAndVerify(apk: _apk, checksumsUrl: null),
        throwsA(isA<UpdateInstallException>()
            .having((e) => e.failure, 'failure', UpdateFailure.download)),
      );
      expect(await filesInDir(), isEmpty);
    });

    test('no connection at all is a download failure', () async {
      final client = MockClient.streaming(
          (request, _) async => throw http.ClientException('offline'));
      await expectLater(
        installerFor(client).downloadAndVerify(apk: _apk, checksumsUrl: null),
        throwsA(isA<UpdateInstallException>()
            .having((e) => e.failure, 'failure', UpdateFailure.download)),
      );
    });

    test('cancelling stops the download and deletes the partial file', () async {
      final token = UpdateCancelToken();
      var last = 0;

      await expectLater(
        installerFor(server()).downloadAndVerify(
          apk: _apk,
          checksumsUrl: _checksumsUrl,
          cancel: token,
          onProgress: (received, _) {
            last = received;
            if (received >= 3000) token.cancel();
          },
        ),
        throwsA(isA<UpdateCancelledException>()),
      );

      expect(last, lessThan(10000), reason: 'it stopped early');
      expect(await filesInDir(), isEmpty);
    });

    test('earlier APKs are cleared; unrelated files in the directory are not', () async {
      await File('${dir.path}/cairn-v2.0.0-universal.apk').writeAsBytes([1, 2, 3]);
      await File('${dir.path}/cairn-v2.2.0-arm64-v8a.apk').writeAsBytes([4, 5, 6]);
      await File('${dir.path}/keep.txt').writeAsString('mine');
      await File('${dir.path}/notes-cairn-v1.apk.txt').writeAsString('mine too');

      await installerFor(server())
          .downloadAndVerify(apk: _apk, checksumsUrl: _checksumsUrl);

      expect(await filesInDir(), unorderedEquals([
        'cairn-v2.3.0-arm64-v8a.apk',
        'keep.txt',
        'notes-cairn-v1.apk.txt',
      ]));
    });

    test('an asset name with a path separator cannot leave the directory', () async {
      const sneaky = ApkAsset(name: '../../evil.apk', url: _apkUrl);
      final file = await installerFor(server())
          .downloadAndVerify(apk: sneaky, checksumsUrl: null);
      expect(file.parent.path, dir.path);
    });
  });

  group('install', () {
    test('the file is opened only after it has been verified', () async {
      final events = <String>[];
      final installer = installerFor(
        server(),
        opener: (path) async {
          events.add('open ${File(path).uri.pathSegments.last}');
          return OpenResult();
        },
      );

      final file = await installer.downloadAndVerify(
        apk: _apk,
        checksumsUrl: _checksumsUrl,
        onVerifying: () => events.add('verifying'),
      );
      events.add('verified');
      await installer.install(file);

      expect(events, ['verifying', 'verified', 'open cairn-v2.3.0-arm64-v8a.apk']);
    });

    test('a rejected download can never reach the opener', () async {
      final opened = <String>[];
      final installer = installerFor(
        server(checksums: _checksumsJson(hash: 'ab' * 32)),
        opener: (path) async {
          opened.add(path);
          return OpenResult();
        },
      );

      Object? error;
      try {
        final file = await installer.downloadAndVerify(
            apk: _apk, checksumsUrl: _checksumsUrl);
        await installer.install(file);
      } catch (e) {
        error = e;
      }

      expect(error, isA<UpdateInstallException>());
      expect(opened, isEmpty);
    });

    test('the opener is given the real path of the verified file', () async {
      String? openedPath;
      final installer = installerFor(server(), opener: (path) async {
        openedPath = path;
        return OpenResult();
      });
      final file = await installer.downloadAndVerify(apk: _apk, checksumsUrl: null);
      await installer.install(file);
      expect(openedPath, file.path);
    });

    test('any result other than "launched" deletes the file and throws', () async {
      for (final type in [
        ResultType.noAppToOpen,
        ResultType.fileNotFound,
        ResultType.permissionDenied,
        ResultType.error,
      ]) {
        final installer = installerFor(
          server(),
          opener: (_) async => OpenResult(type: type, message: type.name),
        );
        final file = await installer.downloadAndVerify(apk: _apk, checksumsUrl: null);

        await expectLater(
          installer.install(file),
          throwsA(isA<UpdateInstallException>().having(
              (e) => e.failure, 'failure', UpdateFailure.installerNotLaunched)),
          reason: type.name,
        );
        expect(await file.exists(), isFalse, reason: type.name);
      }
    });

    test('an opener that throws is the same failure, file deleted', () async {
      final installer = installerFor(
        server(),
        opener: (_) async => throw StateError('channel exploded'),
      );
      final file = await installer.downloadAndVerify(apk: _apk, checksumsUrl: null);

      await expectLater(
        installer.install(file),
        throwsA(isA<UpdateInstallException>().having(
            (e) => e.failure, 'failure', UpdateFailure.installerNotLaunched)),
      );
      expect(await file.exists(), isFalse);
    });

    test('discard removes a verified file that will not be installed', () async {
      final installer = installerFor(server());
      final file = await installer.downloadAndVerify(apk: _apk, checksumsUrl: null);
      await installer.discard(file);
      expect(await file.exists(), isFalse);
      // And is harmless when it is already gone.
      await installer.discard(file);
    });
  });
}
