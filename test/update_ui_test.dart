// The updater's UI: the Settings "Check for updates" row, the two dialog
// shapes, and the launch-time prompt wired through the real app shell.
//
// The network is mocked at the HTTP client (the real UpdateChecker and the real
// decideUpdateAction run), and the installer is replaced by a fake that records
// what it was asked to do — so these tests are about what the person sees and
// what is persisted, never about the network or a device.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:habit_tracker/app.dart';
import 'package:habit_tracker/core/updates/apk_asset_matcher.dart';
import 'package:habit_tracker/core/updates/update_checker.dart';
import 'package:habit_tracker/core/updates/update_decision.dart';
import 'package:habit_tracker/core/updates/update_installer.dart';
import 'package:habit_tracker/data/database/app_database.dart';
import 'package:habit_tracker/data/providers/database_provider.dart';
import 'package:habit_tracker/data/providers/onboarding_providers.dart';
import 'package:habit_tracker/data/providers/update_providers.dart';
import 'package:habit_tracker/data/repositories/settings_repository.dart';
import 'package:habit_tracker/features/navigation/presentation/navigation_shell.dart';
import 'package:habit_tracker/features/settings/presentation/settings_screen.dart';
import 'package:habit_tracker/features/updates/presentation/update_dialog.dart';
import 'package:habit_tracker/theme/app_theme.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/update_fixtures.dart';

/// Stands in for [UpdateInstaller]: records what it is asked to do and lets a
/// test decide when a "download" finishes, so every phase of the dialog can be
/// looked at.
class _FakeInstaller extends UpdateInstaller {
  _FakeInstaller()
      : super(client: MockClient((_) async => http.Response('', 500)));

  final events = <String>[];
  Completer<File> download = Completer<File>();
  ApkAsset? lastApk;
  String? lastChecksumsUrl;
  UpdateCancelToken? lastToken;
  Object? installError;

  @override
  Future<File> downloadAndVerify({
    required ApkAsset apk,
    String? checksumsUrl,
    DownloadProgress? onProgress,
    void Function()? onVerifying,
    UpdateCancelToken? cancel,
  }) {
    events.add('download ${apk.name}');
    lastApk = apk;
    lastChecksumsUrl = checksumsUrl;
    lastToken = cancel;
    onProgress?.call(2 * 1024 * 1024, 5 * 1024 * 1024);
    return download.future;
  }

  @override
  Future<void> install(File apk) async {
    events.add('install');
    final error = installError;
    if (error != null) throw error;
  }

  @override
  Future<void> discard(File apk) async => events.add('discard');
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  late AppDatabase db;
  late SettingsRepository settings;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    settings = SettingsRepository(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  // ── Harness ────────────────────────────────────────────────────────────────

  List<Override> overrides({
    required UpdateChecker checker,
    bool supported = true,
    String version = '2.2.0',
    List<String> abis = const ['arm64-v8a', 'armeabi-v7a'],
    UpdateInstaller? installer,
  }) =>
      [
        databaseProvider.overrideWithValue(db),
        updatesSupportedProvider.overrideWithValue(supported),
        installedVersionProvider.overrideWith((ref) async => version),
        supportedAbisProvider.overrideWith((ref) async => abis),
        updateCheckerProvider.overrideWithValue(checker),
        if (installer != null) updateInstallerProvider.overrideWithValue(installer),
      ];

  /// Gives the futures behind a tap a few frames to land. Not pumpAndSettle: a
  /// spinner or progress bar would make that wait forever.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  UpdateChecker checkerFor(List<Map<String, dynamic>> releases,
          {List<http.BaseRequest>? log}) =>
      UpdateChecker(client: releasesClient(releases, log: log));

  // ── Settings: the "Check for updates" row ──────────────────────────────────

  group('Settings → About → Check for updates', () {
    Future<void> openSettings(
      WidgetTester tester, {
      required UpdateChecker checker,
      bool supported = true,
      UpdateInstaller? installer,
    }) async {
      await tester.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: overrides(
            checker: checker, supported: supported, installer: installer),
        child: MaterialApp(theme: AppTheme.light, home: const SettingsScreen()),
      ));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('ABOUT'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('is not shown at all where the updater does not exist', (tester) async {
      final log = <http.BaseRequest>[];
      await openSettings(tester,
          checker: checkerFor([ghRelease('v2.3.0')], log: log), supported: false);

      expect(find.text('Version'), findsOneWidget, reason: 'About is on screen');
      expect(find.text('Check for updates'), findsNothing);
      expect(log, isEmpty);
    });

    testWidgets('idle on Android, with nothing checked yet', (tester) async {
      final log = <http.BaseRequest>[];
      await openSettings(tester,
          checker: checkerFor([ghRelease('v2.3.0')], log: log));

      expect(find.text('Check for updates'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text("You're on the latest version"), findsNothing);
      expect(log, isEmpty, reason: 'opening Settings must not check by itself');
    });

    testWidgets('checking shows an inline spinner, then "up to date"', (tester) async {
      final gate = Completer<http.Response>();
      final checker = UpdateChecker(client: MockClient((_) => gate.future));
      await openSettings(tester, checker: checker);

      await tester.tap(find.text('Check for updates'));
      await settle(tester);

      expect(find.text('Checking…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // The spinner is small and inline, in the row's trailing slot.
      final tile = find.widgetWithText(ListTile, 'Check for updates');
      expect(
        find.descendant(of: tile, matching: find.byType(CircularProgressIndicator)),
        findsOneWidget,
      );

      gate.complete(http.Response.bytes(
        utf8.encode('[{"tag_name":"v2.2.0","draft":false,"prerelease":false}]'),
        200,
      ));
      await settle(tester);

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text("You're on the latest version"), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('an optional update opens the dismissible dialog', (tester) async {
      await openSettings(tester,
          checker: checkerFor([ghRelease('v2.3.0', body: 'Fixes sync.')]));

      await tester.tap(find.text('Check for updates'));
      await tester.pumpAndSettle();

      expect(find.text('Update available'), findsOneWidget);
      expect(find.text('Cairn 2.3.0 is available.'), findsOneWidget);
      expect(find.text('Fixes sync.'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
      expect(find.text('Update'), findsOneWidget);

      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Version 2.3.0 is available'), findsOneWidget);
    });

    testWidgets('a release marked FORCE_UPDATE gets the same undismissable dialog',
        (tester) async {
      await openSettings(tester,
          checker: checkerFor([ghRelease('v2.3.0', body: 'Security fix.\n\nFORCE_UPDATE\n')]));

      await tester.tap(find.text('Check for updates'));
      await tester.pumpAndSettle();

      expect(find.text('Update required'), findsOneWidget);
      expect(find.text('This update is required.'), findsOneWidget);
      expect(find.text('Later'), findsNothing);
      // The marker is for the app, not the tester.
      expect(find.textContaining('FORCE_UPDATE'), findsNothing);
      expect(find.text('Security fix.'), findsOneWidget);

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('Update required'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Update required'), findsOneWidget);
    });

    testWidgets('five releases behind forces the update, and says why', (tester) async {
      await openSettings(tester, checker: checkerFor([
        for (final v in ['2.7.0', '2.6.0', '2.5.0', '2.4.0', '2.3.0']) ghRelease('v$v'),
      ]));

      await tester.tap(find.text('Check for updates'));
      await tester.pumpAndSettle();

      expect(find.text('Update required'), findsOneWidget);
      expect(find.text("You've skipped several updates — this one's required."),
          findsOneWidget);
      expect(find.text('Later'), findsNothing);
      expect(find.text('Cairn 2.7.0 is available.'), findsOneWidget);
    });

    testWidgets('four releases behind is still optional', (tester) async {
      await openSettings(tester, checker: checkerFor([
        for (final v in ['2.6.0', '2.5.0', '2.4.0', '2.3.0']) ghRelease('v$v'),
      ]));

      await tester.tap(find.text('Check for updates'));
      await tester.pumpAndSettle();

      expect(find.text('Update available'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
    });

    testWidgets('a release dismissed earlier is offered again when asked for',
        (tester) async {
      await settings.setString(updateLastSkippedVersionSettingsKey, '2.3.0');
      await openSettings(tester, checker: checkerFor([ghRelease('v2.3.0')]));

      await tester.tap(find.text('Check for updates'));
      await tester.pumpAndSettle();

      // The row must not claim "latest version" when it is not.
      expect(find.text('Update available'), findsOneWidget);
      expect(find.text("You're on the latest version"), findsNothing);
    });

    testWidgets('a network failure is reported in plain language, then retryable',
        (tester) async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        if (calls == 1) {
          throw const SocketException("Failed host lookup: 'api.github.com'");
        }
        return http.Response.bytes(utf8.encode('[]'), 200);
      });
      await openSettings(tester, checker: UpdateChecker(client: client));

      await tester.tap(find.text('Check for updates'));
      await settle(tester);

      expect(find.text("Couldn't check for updates — try again later"),
          findsOneWidget);
      expect(find.textContaining('SocketException'), findsNothing);
      expect(find.textContaining('api.github.com'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);

      // Tapping again tries again.
      await tester.tap(find.text('Check for updates'));
      await settle(tester);
      expect(find.text("You're on the latest version"), findsOneWidget);
      expect(calls, 2);
    });

    testWidgets('GitHub answering with an error says the same thing', (tester) async {
      await openSettings(tester,
          checker: UpdateChecker(client: releasesClient(const [], status: 403)));

      await tester.tap(find.text('Check for updates'));
      await settle(tester);

      expect(find.text("Couldn't check for updates — try again later"),
          findsOneWidget);
      expect(find.textContaining('403'), findsNothing);
      expect(find.textContaining('UpdateCheckException'), findsNothing);
    });

    testWidgets('a garbled response says the same thing', (tester) async {
      await openSettings(tester,
          checker: UpdateChecker(
              client: releasesClient(const [], rawBody: '<<not json>>')));

      await tester.tap(find.text('Check for updates'));
      await settle(tester);

      expect(find.text("Couldn't check for updates — try again later"),
          findsOneWidget);
    });
  });

  // ── The dialog itself ──────────────────────────────────────────────────────

  group('UpdateDialog', () {
    /// A bare host with one button that opens the dialog for [action].
    Future<void> openDialog(
      WidgetTester tester,
      UpdateAction action, {
      required _FakeInstaller installer,
      List<String> abis = const ['arm64-v8a', 'armeabi-v7a'],
    }) async {
      await tester.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: overrides(
          checker: checkerFor(const []),
          installer: installer,
          abis: abis,
        ),
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showUpdateDialog(context, action),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    OptionalUpdate optional([ReleaseInfo? release]) =>
        OptionalUpdate(release ?? fakeRelease('2.3.0', notes: 'Fixes sync.'));

    MandatoryUpdate mandatory({
      MandatoryReason reason = MandatoryReason.markedByRelease,
      ReleaseInfo? release,
    }) =>
        MandatoryUpdate(release ?? fakeRelease('2.3.0', mandatory: true), reason);

    testWidgets('NoAction shows nothing', (tester) async {
      await openDialog(tester, const NoAction(), installer: _FakeInstaller());
      expect(find.byType(AlertDialog), findsNothing);
    });

    group('optional', () {
      testWidgets('offers the version and notes with Later and Update', (tester) async {
        await openDialog(
          tester,
          optional(fakeRelease('2.3.0',
              notes: 'Streak fix.\n\nSecond paragraph.\nFORCE_UPDATE\n')),
          installer: _FakeInstaller(),
        );

        expect(find.text('Update available'), findsOneWidget);
        expect(find.text('Cairn 2.3.0 is available.'), findsOneWidget);
        expect(find.text("What's new"), findsOneWidget);
        expect(find.text('Streak fix.\n\nSecond paragraph.'), findsOneWidget);
        expect(find.text('Later'), findsOneWidget);
        expect(find.text('Update'), findsOneWidget);
        expect(find.text('This update is required.'), findsNothing);
      });

      testWidgets('empty notes leave out the "What\'s new" section', (tester) async {
        await openDialog(tester, optional(fakeRelease('2.3.0')),
            installer: _FakeInstaller());
        expect(find.text("What's new"), findsNothing);
      });

      testWidgets('Later remembers the version and closes', (tester) async {
        await openDialog(tester, optional(), installer: _FakeInstaller());

        await tester.tap(find.text('Later'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        expect(await settings.getString(updateLastSkippedVersionSettingsKey), '2.3.0');
      });

      testWidgets('tapping outside counts as Later', (tester) async {
        await openDialog(tester, optional(), installer: _FakeInstaller());

        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        expect(await settings.getString(updateLastSkippedVersionSettingsKey), '2.3.0',
            reason: 'closing it this way must not bring it back next launch');
      });

      testWidgets('the back button counts as Later', (tester) async {
        await openDialog(tester, optional(), installer: _FakeInstaller());

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        expect(await settings.getString(updateLastSkippedVersionSettingsKey), '2.3.0');
      });
    });

    group('mandatory', () {
      testWidgets('has only Update, and says why — marked by the release', (tester) async {
        await openDialog(tester, mandatory(), installer: _FakeInstaller());

        expect(find.text('Update required'), findsOneWidget);
        expect(find.text('This update is required.'), findsOneWidget);
        expect(find.text('Update'), findsOneWidget);
        expect(find.text('Later'), findsNothing);
        expect(find.text('Close'), findsNothing);
      });

      testWidgets('says why — too far behind', (tester) async {
        await openDialog(
          tester,
          mandatory(reason: MandatoryReason.tooFarBehind),
          installer: _FakeInstaller(),
        );
        expect(find.text("You've skipped several updates — this one's required."),
            findsOneWidget);
        expect(find.text('This update is required.'), findsNothing);
      });

      testWidgets('cannot be dismissed by tapping the barrier', (tester) async {
        await openDialog(tester, mandatory(), installer: _FakeInstaller());

        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(790, 590));
        await tester.pumpAndSettle();

        expect(find.text('Update required'), findsOneWidget);
        expect(await settings.getString(updateLastSkippedVersionSettingsKey), isNull);
      });

      testWidgets('cannot be dismissed with the back button', (tester) async {
        await openDialog(tester, mandatory(), installer: _FakeInstaller());

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(find.text('Update required'), findsOneWidget);
        expect(await settings.getString(updateLastSkippedVersionSettingsKey), isNull);
      });

      testWidgets('stays undismissable after a failure, and still has no Close',
          (tester) async {
        final installer = _FakeInstaller();
        await openDialog(tester, mandatory(), installer: installer);

        await tester.tap(find.text('Update'));
        await settle(tester);
        installer.download.completeError(
          const UpdateInstallException(UpdateFailure.download, 'x'),
        );
        await settle(tester);

        expect(find.textContaining("didn't finish"), findsOneWidget);
        expect(find.text('Close'), findsNothing);
        expect(find.text('Try again'), findsOneWidget);
        expect(find.text('This update is required.'), findsOneWidget);

        await tester.tapAt(const Offset(5, 5));
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Update required'), findsOneWidget);
      });

      testWidgets('stays undismissable once the installer has opened', (tester) async {
        final installer = _FakeInstaller();
        await openDialog(tester, mandatory(), installer: installer);

        await tester.tap(find.text('Update'));
        await settle(tester);
        installer.download.complete(File('cairn.apk'));
        await settle(tester);

        expect(find.text('Install again'), findsOneWidget);
        expect(find.text('Close'), findsNothing);
        await tester.binding.handlePopRoute();
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
        expect(find.text('Update required'), findsOneWidget);
      });
    });

    group('the update flow, in place', () {
      testWidgets('Update clears the remembered decline, from either dialog', (tester) async {
        await settings.setString(updateLastSkippedVersionSettingsKey, '2.3.0');
        final installer = _FakeInstaller();
        await openDialog(tester, optional(), installer: installer);

        await tester.tap(find.text('Update'));
        await settle(tester);

        expect(await settings.getString(updateLastSkippedVersionSettingsKey), isNull);

        // And from a mandatory dialog.
        await settings.setString(updateLastSkippedVersionSettingsKey, '2.3.0');
        final installer2 = _FakeInstaller();
        await openDialog(tester, mandatory(), installer: installer2);
        await tester.tap(find.text('Update'));
        await settle(tester);
        expect(await settings.getString(updateLastSkippedVersionSettingsKey), isNull);
      });

      testWidgets('shows byte progress in the same dialog, then hands off to Android',
          (tester) async {
        final installer = _FakeInstaller();
        await openDialog(tester, optional(), installer: installer);

        await tester.tap(find.text('Update'));
        await settle(tester);

        // Same dialog, new content — not a second dialog.
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.text('Downloading… 2.0 of 5.0 MB'), findsOneWidget);
        final bar = tester.widget<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator));
        expect(bar.value, closeTo(0.4, 0.001));
        expect(find.text("What's new"), findsNothing);
        expect(installer.events, ['download cairn-v2.3.0-arm64-v8a.apk']);

        installer.download.complete(File('cairn-v2.3.0-arm64-v8a.apk'));
        await settle(tester);

        expect(installer.events.last, 'install');
        expect(find.textContaining('Finish installing Cairn 2.3.0'), findsOneWidget);
        expect(find.byType(AlertDialog), findsOneWidget);
      });

      testWidgets('picks the APK for the device and passes the release\'s checksums',
          (tester) async {
        final installer = _FakeInstaller();
        final release = fakeRelease('2.3.0');
        await openDialog(tester, optional(release),
            installer: installer, abis: const ['armeabi-v7a', 'armeabi']);

        await tester.tap(find.text('Update'));
        await settle(tester);

        expect(installer.lastApk!.name, 'cairn-v2.3.0-armeabi-v7a.apk');
        expect(installer.lastApk!.url, release.assets['cairn-v2.3.0-armeabi-v7a.apk']);
        expect(installer.lastChecksumsUrl, release.assets['checksums.json']);
      });

      testWidgets('a device with an uncovered architecture gets the universal APK',
          (tester) async {
        final installer = _FakeInstaller();
        await openDialog(tester, optional(), installer: installer, abis: const ['riscv64']);

        await tester.tap(find.text('Update'));
        await settle(tester);

        expect(installer.lastApk!.name, 'cairn-v2.3.0-universal.apk');
      });

      testWidgets('a release without checksums.json is installed unverified',
          (tester) async {
        final installer = _FakeInstaller();
        final release = fakeRelease('2.3.0', assets: {
          'cairn-v2.3.0-arm64-v8a.apk': assetUrl('v2.3.0', 'cairn-v2.3.0-arm64-v8a.apk'),
        });
        await openDialog(tester, optional(release), installer: installer);

        await tester.tap(find.text('Update'));
        await settle(tester);

        expect(installer.lastChecksumsUrl, isNull);
      });

      testWidgets('"Install again" reopens the installer without downloading again',
          (tester) async {
        final installer = _FakeInstaller();
        await openDialog(tester, optional(), installer: installer);
        await tester.tap(find.text('Update'));
        await settle(tester);
        installer.download.complete(File('cairn.apk'));
        await settle(tester);

        await tester.tap(find.text('Install again'));
        await settle(tester);

        expect(installer.events.where((e) => e.startsWith('download')), hasLength(1));
        expect(installer.events.where((e) => e == 'install'), hasLength(2));
      });

      testWidgets('an optional dialog can be closed once the installer is open',
          (tester) async {
        final installer = _FakeInstaller();
        await openDialog(tester, optional(), installer: installer);
        await tester.tap(find.text('Update'));
        await settle(tester);
        installer.download.complete(File('cairn.apk'));
        await settle(tester);

        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        // Closing here is not "Later": the decline stays cleared.
        expect(await settings.getString(updateLastSkippedVersionSettingsKey), isNull);
      });

      testWidgets('an optional dialog cannot be dismissed mid-download', (tester) async {
        final installer = _FakeInstaller();
        await openDialog(tester, optional(), installer: installer);
        await tester.tap(find.text('Update'));
        await settle(tester);

        await tester.tapAt(const Offset(5, 5));
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle(const Duration(milliseconds: 100));

        expect(find.text('Downloading… 2.0 of 5.0 MB'), findsOneWidget);
        expect(installer.lastToken!.isCancelled, isFalse);
      });

      testWidgets('Cancel stops the download and returns to the offer', (tester) async {
        final installer = _FakeInstaller();
        await openDialog(tester, optional(), installer: installer);
        await tester.tap(find.text('Update'));
        await settle(tester);

        await tester.tap(find.text('Cancel'));
        await settle(tester);

        expect(installer.lastToken!.isCancelled, isTrue);
        expect(find.text('Cancelling…'), findsOneWidget);
        // No way to start a second download into the file the first is closing.
        expect(find.text('Update'), findsNothing);

        installer.download.completeError(const UpdateCancelledException());
        await settle(tester);

        expect(find.text('Cairn 2.3.0 is available.'), findsOneWidget);
        expect(find.text('Update'), findsOneWidget);
        expect(find.text('Later'), findsOneWidget);
        expect(installer.events.where((e) => e == 'install'), isEmpty);
      });

      testWidgets('cancelling a mandatory download returns to Update, not out of it',
          (tester) async {
        final installer = _FakeInstaller();
        await openDialog(tester, mandatory(), installer: installer);
        await tester.tap(find.text('Update'));
        await settle(tester);

        await tester.tap(find.text('Cancel'));
        await settle(tester);
        installer.download.completeError(const UpdateCancelledException());
        await settle(tester);

        expect(find.text('Update required'), findsOneWidget);
        expect(find.text('Update'), findsOneWidget);
        expect(find.text('Later'), findsNothing);
      });

      testWidgets('a cancel that lands as the download finishes installs nothing',
          (tester) async {
        final installer = _FakeInstaller();
        await openDialog(tester, optional(), installer: installer);
        await tester.tap(find.text('Update'));
        await settle(tester);

        await tester.tap(find.text('Cancel'));
        installer.download.complete(File('cairn.apk'));
        await settle(tester);

        expect(installer.events, contains('discard'));
        expect(installer.events, isNot(contains('install')));
        expect(find.text('Update'), findsOneWidget);
      });
    });

    group('failures', () {
      testWidgets('a checksum mismatch is explained, retryable, and never installed',
          (tester) async {
        final installer = _FakeInstaller();
        await openDialog(tester, optional(), installer: installer);
        await tester.tap(find.text('Update'));
        await settle(tester);

        installer.download.completeError(const UpdateInstallException(
            UpdateFailure.checksumMismatch, 'sha mismatch: abc != def'));
        await settle(tester);

        expect(find.textContaining("didn't match its published checksum"),
            findsOneWidget);
        expect(find.textContaining('sha mismatch'), findsNothing,
            reason: 'raw exception text is never shown');
        expect(installer.events, isNot(contains('install')),
            reason: 'a rejected file is never offered to the installer');
        expect(find.text('Install again'), findsNothing);
        expect(find.text('Try again'), findsOneWidget);
        expect(find.text('Close'), findsOneWidget);
      });

      testWidgets('Try again starts a fresh download', (tester) async {
        final installer = _FakeInstaller();
        await openDialog(tester, optional(), installer: installer);
        await tester.tap(find.text('Update'));
        await settle(tester);
        installer.download.completeError(
            const UpdateInstallException(UpdateFailure.download, 'x'));
        await settle(tester);

        installer.download = Completer<File>();
        await tester.tap(find.text('Try again'));
        await settle(tester);

        expect(find.text('Downloading… 2.0 of 5.0 MB'), findsOneWidget);
        expect(installer.events.where((e) => e.startsWith('download')), hasLength(2));
      });

      testWidgets('an unexpected error is reported as a failed download', (tester) async {
        final installer = _FakeInstaller();
        await openDialog(tester, optional(), installer: installer);
        await tester.tap(find.text('Update'));
        await settle(tester);

        installer.download.completeError(StateError('disk on fire'));
        await settle(tester);

        expect(find.textContaining("didn't finish"), findsOneWidget);
        expect(find.textContaining('disk on fire'), findsNothing);
      });

      testWidgets('an installer that would not open is reported', (tester) async {
        final installer = _FakeInstaller()
          ..installError = const UpdateInstallException(
              UpdateFailure.installerNotLaunched, 'noAppToOpen');
        await openDialog(tester, optional(), installer: installer);
        await tester.tap(find.text('Update'));
        await settle(tester);
        installer.download.complete(File('cairn.apk'));
        await settle(tester);

        expect(find.textContaining("Couldn't open Android's installer"), findsOneWidget);
        expect(find.text('Try again'), findsOneWidget);
        expect(find.text('Install again'), findsNothing);
      });

      testWidgets('a release with no APK says so, and starts no download', (tester) async {
        final installer = _FakeInstaller();
        final noApks = fakeRelease('2.3.0', assets: const {});
        await openDialog(tester, mandatory(release: noApks), installer: installer);

        await tester.tap(find.text('Update'));
        await settle(tester);

        expect(find.textContaining('No compatible build found for your device'),
            findsOneWidget);
        expect(installer.events, isEmpty);
        // Retrying cannot help: the asset list in hand is the stale one.
        expect(find.text('Try again'), findsNothing);
        // Still blocking: the tester waits for the release to be finished.
        await tester.binding.handlePopRoute();
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
        expect(find.text('Update required'), findsOneWidget);
      });

      testWidgets('a release with only a checksums file has no compatible build either',
          (tester) async {
        final installer = _FakeInstaller();
        final release = fakeRelease('2.3.0',
            assets: {'checksums.json': assetUrl('v2.3.0', 'checksums.json')});
        await openDialog(tester, optional(release), installer: installer);

        await tester.tap(find.text('Update'));
        await settle(tester);

        expect(find.textContaining('No compatible build found'), findsOneWidget);
        expect(find.text('Close'), findsOneWidget);
        expect(installer.events, isEmpty);
      });
    });
  });

  // ── The launch-time check, through the real app ────────────────────────────

  group('on launch', () {
    Widget launch(
      UpdateChecker checker, {
      bool supported = true,
      _FakeInstaller? installer,
      String version = '2.2.0',
    }) =>
        ProviderScope(
          // A fresh key per launch, so a second launch is a genuinely new scope.
          key: UniqueKey(),
          overrides: [
            ...overrides(
                checker: checker,
                supported: supported,
                installer: installer ?? _FakeInstaller(),
                version: version),
            initialOnboardingCompletedProvider.overrideWithValue(true),
            todayEventsStreamProvider.overrideWith(
              (ref) => Stream<List<Event>>.value(const []),
            ),
          ],
          child: const FocusStackApp(),
        );

    /// pump(), not pumpAndSettle(): the shell's screens hold streams that never
    /// go idle (see widget_test.dart).
    Future<void> boot(WidgetTester tester, Widget app) async {
      await tester.pumpWidget(app);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('a newer release opens the dialog over a usable app, once', (tester) async {
      final log = <http.BaseRequest>[];
      await boot(tester, launch(checkerFor([ghRelease('v2.3.0', body: 'Hello.')], log: log)));

      // The app is on screen underneath: the check never gated it.
      expect(find.byType(NavigationShell), findsOneWidget);
      expect(find.text('Update available'), findsOneWidget);
      expect(find.text('Cairn 2.3.0 is available.'), findsOneWidget);
      expect(log, hasLength(1));

      // Dismissing it does not bring it straight back.
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Update available'), findsNothing);
    });

    testWidgets('a mandatory update cannot be dismissed by barrier or back',
        (tester) async {
      await boot(tester, launch(checkerFor([
        ghRelease('v2.3.0', body: 'Critical fix.\n\nFORCE_UPDATE'),
      ])));

      expect(find.text('Update required'), findsOneWidget);
      expect(find.text('This update is required.'), findsOneWidget);
      expect(find.text('Later'), findsNothing);

      await tester.tapAt(const Offset(5, 5));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Update required'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Update required'), findsOneWidget);
      expect(find.byType(NavigationShell), findsOneWidget);
    });

    testWidgets('five behind is mandatory on launch too', (tester) async {
      await boot(tester, launch(checkerFor([
        for (final v in ['2.7.0', '2.6.0', '2.5.0', '2.4.0', '2.3.0']) ghRelease('v$v'),
      ])));

      expect(find.text('Update required'), findsOneWidget);
      expect(find.text("You've skipped several updates — this one's required."),
          findsOneWidget);
    });

    testWidgets('declining stays quiet until something newer is published',
        (tester) async {
      final v230 = checkerFor([ghRelease('v2.3.0')]);

      // Launch 1: offered, declined.
      await boot(tester, launch(v230));
      expect(find.text('Update available'), findsOneWidget);
      await tester.tap(find.text('Later'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(await settings.getString(updateLastSkippedVersionSettingsKey), '2.3.0');

      // Launch 2, same release still the latest: quiet.
      await boot(tester, launch(v230));
      expect(find.byType(NavigationShell), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);

      // Launch 3, 2.4.0 now out: offered again, for 2.4.0.
      await boot(tester, launch(checkerFor([ghRelease('v2.4.0'), ghRelease('v2.3.0')])));
      expect(find.text('Cairn 2.4.0 is available.'), findsOneWidget);
    });

    testWidgets('a decline does not hold back a release that became mandatory',
        (tester) async {
      await settings.setString(updateLastSkippedVersionSettingsKey, '2.3.0');
      await boot(tester, launch(checkerFor([
        ghRelease('v2.4.0', body: 'FORCE_UPDATE'),
        ghRelease('v2.3.0'),
      ])));

      expect(find.text('Update required'), findsOneWidget);
    });

    testWidgets('being current shows nothing', (tester) async {
      await boot(tester, launch(checkerFor([ghRelease('v2.2.0'), ghRelease('v2.1.0')])));
      expect(find.byType(NavigationShell), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('no connection shows nothing and raises nothing', (tester) async {
      final client = MockClient((_) async => throw const SocketException('offline'));
      await boot(tester, launch(UpdateChecker(client: client)));

      expect(find.byType(NavigationShell), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('GitHub errors and garbage resolve to no action', (tester) async {
      for (final client in [
        releasesClient(const [], status: 500),
        releasesClient(const [], status: 403, rawBody: '{"message":"rate limited"}'),
        releasesClient(const [], rawBody: 'not json at all'),
      ]) {
        await boot(tester, launch(UpdateChecker(client: client)));
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('off Android the network is never touched', (tester) async {
      final log = <http.BaseRequest>[];
      await boot(
        tester,
        launch(checkerFor([ghRelease('v2.3.0', body: 'FORCE_UPDATE')], log: log),
            supported: false),
      );

      expect(find.byType(NavigationShell), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(log, isEmpty);
    });

    test('the launch provider resolves to a plain UpdateAction', () async {
      final container = ProviderContainer(overrides: [
        ...overrides(checker: checkerFor([ghRelease('v2.3.0')])),
      ]);
      addTearDown(container.dispose);

      final action = await container.read(launchUpdateActionProvider.future);
      expect(action, isA<OptionalUpdate>());
      expect((action as OptionalUpdate).release.version, '2.3.0');
    });
  });
}
