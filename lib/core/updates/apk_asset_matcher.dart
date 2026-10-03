/// One downloadable APK on a release. The name is kept with the URL because the
/// checksum step looks the file up in `checksums.json` by name.
class ApkAsset {
  const ApkAsset({required this.name, required this.url});

  final String name;
  final String url;
}

/// The asset-name slot for the all-ABIs build: `cairn-v2.3.0-universal.apk`.
const String universalApkAbi = 'universal';

/// Asset name for [abi]'s build, `cairn-vX.Y.Z-<abi>.apk`, matching how releases
/// are built (`flutter build apk --split-per-abi` plus a universal build).
String apkAssetName(String version, String abi) => 'cairn-v$version-$abi.apk';

/// Picks the APK in [assets] that best fits a device, or null if there is none.
///
/// [supportedAbis] is `Build.SUPPORTED_ABIS`, most preferred first. Walking it in
/// order gets the device its native build: an x86_64 emulator that can also
/// translate ARM gets the x86_64 APK. If no listed ABI has a build, falls back
/// to the universal APK, then to null. It never guesses, because an APK for
/// another architecture only fails at the installer, after the whole download.
///
/// [version] is `ReleaseInfo.version` (no "v"); [assets] is `ReleaseInfo.assets`.
ApkAsset? selectApkAsset({
  required List<String> supportedAbis,
  required String version,
  required Map<String, String> assets,
}) {
  for (final abi in [...supportedAbis, universalApkAbi]) {
    final name = apkAssetName(version, abi);
    final url = assets[name];
    if (url != null) return ApkAsset(name: name, url: url);
  }
  return null;
}
