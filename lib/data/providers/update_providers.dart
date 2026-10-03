import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/updates/update_checker.dart';
import '../../core/updates/update_decision.dart';
import '../../core/updates/update_installer.dart';
import '../repositories/settings_repository.dart';
import 'database_provider.dart';

/// Riverpod wiring for the in-app updater. The logic is plain Dart under
/// `lib/core/updates`; this file hands it the real client, device and settings
/// table, and is the seam tests override to keep the network out.

/// Whether this build can update itself: Android only. Elsewhere the launch
/// check never runs and Settings hides the row. Overridable so tests on a
/// desktop host can exercise the Android path.
final updatesSupportedProvider =
    Provider<bool>((ref) => !kIsWeb && Platform.isAndroid);

/// The one HTTP client the updater uses for the release list, the checksums and
/// the APK.
final updateHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final updateCheckerProvider = Provider<UpdateChecker>(
  (ref) => UpdateChecker(client: ref.watch(updateHttpClientProvider)),
);

final updateInstallerProvider = Provider<UpdateInstaller>(
  (ref) => UpdateInstaller(client: ref.watch(updateHttpClientProvider)),
);

/// The running build's `MAJOR.MINOR.PATCH`, from `PackageInfo.version` rather
/// than the build number: releases are tagged by version alone.
final installedVersionProvider = FutureProvider<String>(
  (ref) async => (await PackageInfo.fromPlatform()).version,
);

/// The device's ABIs in Android's preference order, for picking an APK.
final supportedAbisProvider = FutureProvider<List<String>>(
  (ref) async => (await DeviceInfoPlugin().androidInfo).supportedAbis,
);

/// The `settings` key holding the version the tester last tapped "Later" on.
/// Absent means never declined, or since updated.
///
/// The only thing persisted. There is no skip counter: how far behind the tester
/// is comes from the live release list (`ReleaseStatus.releasesBehind`), so it
/// can't drift.
const updateLastSkippedVersionSettingsKey = 'update_last_skipped_version';

/// The version last declined, or null. An unreadable settings table answers
/// null, which only repeats an optional offer; mandatory updates never consult
/// this.
Future<String?> readLastSkippedUpdateVersion(SettingsRepository settings) async {
  try {
    final value = await settings.getString(updateLastSkippedVersionSettingsKey);
    return (value == null || value.isEmpty) ? null : value;
  } catch (_) {
    return null;
  }
}

/// Records that the tester declined [version]. Written only on "Later" for an
/// optional update.
Future<void> rememberSkippedUpdateVersion(
  SettingsRepository settings,
  String version,
) async {
  try {
    await settings.setString(updateLastSkippedVersionSettingsKey, version);
  } catch (_) {}
}

/// Forgets the declined version. Called when the tester taps "Update" in either
/// dialog.
Future<void> clearSkippedUpdateVersion(SettingsRepository settings) async {
  try {
    await settings.delete(updateLastSkippedVersionSettingsKey);
  } catch (_) {}
}

/// The launch-time check, resolved to what the UI should do about it.
/// `NavigationShell` listens for it and shows the dialog after the first frame.
///
/// First read when the shell builds, so the check starts after the first-run
/// tutorial and the network call stays off the startup path. Not autoDispose:
/// it runs once per launch, so rebuilding the shell doesn't re-check or
/// re-prompt.
///
/// Never an error: any failure resolves to [NoAction], so the automatic check
/// can't put an error in front of anyone. The Settings button is where a failed
/// check is reported. Everything is `ref.read`, since this is a one-shot and a
/// dependency change shouldn't trigger a second request.
final launchUpdateActionProvider = FutureProvider<UpdateAction>((ref) async {
  if (!ref.read(updatesSupportedProvider)) return const NoAction();
  try {
    final currentVersion = await ref.read(installedVersionProvider.future);
    final status = await ref
        .read(updateCheckerProvider)
        .checkForUpdates(currentVersion: currentVersion);
    final skipped =
        await readLastSkippedUpdateVersion(ref.read(settingsRepositoryProvider));
    return decideUpdateAction(status: status, lastSkippedVersion: skipped);
  } catch (e) {
    debugPrint('Update check skipped: $e');
    return const NoAction();
  }
});
