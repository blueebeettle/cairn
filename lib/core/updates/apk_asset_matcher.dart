/// One downloadable APK on a release: the asset's file name and where to get it.
///
/// The name travels with the URL because the checksum step looks the file up
/// in `checksums.json` by name, and recovering a name from the tail of a URL
/// would be guessing at how GitHub formats them.
class ApkAsset {
  const ApkAsset({required this.name, required this.url});

  final String name;
  final String url;
}

/// The asset-name slot the all-ABIs build fills: `cairn-v2.3.0-universal.apk`.
const String universalApkAbi = 'universal';

/// The asset name a release uses for [abi]'s build — the convention the
/// release builds already follow (`flutter build apk --split-per-abi`, plus a
/// universal build, renamed `cairn-vX.Y.Z-<abi>.apk`).
String apkAssetName(String version, String abi) => 'cairn-v$version-$abi.apk';

/// Picks the APK in [assets] that best fits a device, or null if there is none.
///
/// [supportedAbis] is the device's own list from Android's
/// `Build.SUPPORTED_ABIS`: every instruction set it can run, most preferred
/// first (a 64-bit ARM phone says `arm64-v8a, armeabi-v7a, armeabi`). Walking
/// it in order is what gets a device its *native* build rather than an
/// emulated one — an x86_64 emulator that can also translate ARM lists x86_64
/// first, and gets the x86_64 APK.
///
/// 1. For each ABI, in order, the asset literally named
///    `cairn-v{version}-{abi}.apk`. The first one present wins.
/// 2. If no ABI the device lists has a build, `cairn-v{version}-universal.apk`.
///    This is also what an architecture none of the split builds cover falls
///    through to.
/// 3. Otherwise null — never a guess. Installing an APK built for another
///    architecture fails at the installer, after the whole download; the
///    caller reports "no compatible build" instead. A release with no APK
///    assets at all (a tag pushed before the GitHub Release was made, or one
///    still uploading) lands here too.
///
/// Takes plain arguments rather than reading the device itself so it can be
/// tested without one. [version] is the release's version without the "v",
/// i.e. `ReleaseInfo.version`; [assets] is `ReleaseInfo.assets`.
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
