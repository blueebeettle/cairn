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

/// Riverpod wiring for the in-app updater.
///
/// The logic itself is plain Dart under `lib/core/updates` — the checker, the
/// decision, the ABI match and the installer — and knows nothing of Riverpod.
/// This file hands each of them the real client, device and settings table,
/// which is also the seam tests override to keep the network out.

/// Whether this build can update itself at all.
///
/// Android only. iOS and macOS have no way for an app to replace itself (Apple
/// does not allow it) and desktop installs work differently again, so there the
/// launch check never runs, and Settings does not show the row — there is no
/// dead control to explain. Overridable so tests, which run on a desktop host,
/// can exercise the Android path.
final updatesSupportedProvider =
    Provider<bool>((ref) => !kIsWeb && Platform.isAndroid);

/// The one HTTP client the updater uses for the release list, the checksums
/// and the APK.
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

/// The running build's `MAJOR.MINOR.PATCH` — `PackageInfo.version`, never the
/// build number: releases are tagged by version alone, and the two numbering
/// schemes are free to diverge.
final installedVersionProvider = FutureProvider<String>(
  (ref) async => (await PackageInfo.fromPlatform()).version,
);

/// The device's ABIs in Android's own preference order, for picking an APK.
final supportedAbisProvider = FutureProvider<List<String>>(
  (ref) async => (await DeviceInfoPlugin().androidInfo).supportedAbis,
);

/// The `settings` key holding the version the tester last tapped "Later" on.
///
/// A plain string, written through `setString` and read through `getString`
/// like the other string settings. Absent means "never declined, or has since
/// updated".
///
/// Deliberately the only thing persisted. There is no skip *count*: how far
/// behind the tester is comes from the live release list on every check
/// (`ReleaseStatus.releasesBehind`), so it cannot drift out of step with
/// reality the way a counter incremented on each "Later" could — if they let
/// several releases pass without opening the app, the next check still counts
/// them all.
const updateLastSkippedVersionSettingsKey = 'update_last_skipped_version';

/// The version last declined, or null.
///
/// An unreadable settings table answers null, which only costs a repeat offer
/// of an optional update. Mandatory updates never consult this value.
Future<String?> readLastSkippedUpdateVersion(SettingsRepository settings) async {
  try {
    final value = await settings.getString(updateLastSkippedVersionSettingsKey);
    return (value == null || value.isEmpty) ? null : value;
  } catch (_) {
    return null;
  }
}

/// Records that the tester declined [version]. Written only when they tap
/// "Later" on an optional update.
Future<void> rememberSkippedUpdateVersion(
  SettingsRepository settings,
  String version,
) async {
  try {
    await settings.setString(updateLastSkippedVersionSettingsKey, version);
  } catch (_) {}
}

/// Forgets the declined version. Called the moment the tester taps "Update",
/// from either dialog: whatever happens next, they are no longer in a "just
/// declined" state.
Future<void> clearSkippedUpdateVersion(SettingsRepository settings) async {
  try {
    await settings.delete(updateLastSkippedVersionSettingsKey);
  } catch (_) {}
}

/// The launch-time check, resolved to what the UI should do about it.
///
/// Read by `NavigationShell`, which listens for the result and shows the
/// matching dialog after the first frame. It is first read when the shell
/// builds, so the check starts after the app is on screen and past the
/// first-run tutorial, and the network call never sits on the startup path.
/// A plain (non-autoDispose) provider, so it runs once per launch: the shell
/// being rebuilt does not re-check or re-prompt.
///
/// Never an error. Any failure — no connection, GitHub down, rate limited, a
/// body that does not parse, an unreadable version — resolves to [NoAction],
/// so the automatic check cannot put an error in front of anyone; the Settings
/// button is where a failed check is reported, because there the tester asked.
///
/// Everything is `ref.read`, not `watch`: this is a one-shot, and no change to
/// a dependency should trigger a second request.
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
