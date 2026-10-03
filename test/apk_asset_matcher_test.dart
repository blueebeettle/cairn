// Picking the right APK for a device out of a release's assets. Pure: the
// device's ABI list is a plain argument, so none of this needs a device.

import 'package:flutter_test/flutter_test.dart';
import 'package:habit_tracker/core/updates/apk_asset_matcher.dart';

import 'support/update_fixtures.dart';

void main() {
  const version = '2.3.0';
  final all = {
    for (final n in standardAssetNames(version)) n: assetUrl('v$version', n),
  };

  ApkAsset? pick(List<String> abis, [Map<String, String>? assets]) =>
      selectApkAsset(
        supportedAbis: abis,
        version: version,
        assets: assets ?? all,
      );

  test('the assets are named the way the existing builds are', () {
    expect(apkAssetName('2.3.0', 'arm64-v8a'), 'cairn-v2.3.0-arm64-v8a.apk');
    expect(apkAssetName('2.3.0', universalApkAbi), 'cairn-v2.3.0-universal.apk');
  });

  test('an exact match is found, with its name and URL', () {
    final apk = pick(['arm64-v8a'])!;
    expect(apk.name, 'cairn-v2.3.0-arm64-v8a.apk');
    expect(apk.url, assetUrl('v2.3.0', 'cairn-v2.3.0-arm64-v8a.apk'));
  });

  test("the device's own preference order decides, not the asset order", () {
    // A device that prefers armeabi-v7a gets it even though arm64-v8a is on
    // the release too.
    expect(pick(['armeabi-v7a', 'arm64-v8a'])!.name,
        'cairn-v2.3.0-armeabi-v7a.apk');
    expect(pick(['arm64-v8a', 'armeabi-v7a'])!.name,
        'cairn-v2.3.0-arm64-v8a.apk');
  });

  test('a typical 64-bit ARM phone gets arm64, its first-listed ABI', () {
    expect(pick(['arm64-v8a', 'armeabi-v7a', 'armeabi'])!.name,
        'cairn-v2.3.0-arm64-v8a.apk');
  });

  test('falls through unmatched ABIs to a later-preferred one that has a build', () {
    // x86 and armeabi have no build; armeabi-v7a, third in line, does.
    expect(pick(['x86', 'armeabi', 'armeabi-v7a'])!.name,
        'cairn-v2.3.0-armeabi-v7a.apk');
    // An x86_64 emulator that translates ARM still gets its native build.
    expect(pick(['x86_64', 'x86', 'arm64-v8a', 'armeabi-v7a'])!.name,
        'cairn-v2.3.0-x86_64.apk');
  });

  test('falls back to the universal APK when no listed ABI has a build', () {
    final apk = pick(['riscv64', 'mips'])!;
    expect(apk.name, 'cairn-v2.3.0-universal.apk');
    expect(apk.url, assetUrl('v2.3.0', 'cairn-v2.3.0-universal.apk'));
  });

  test('an ABI none of the four builds cover reaches the universal APK', () {
    expect(pick(['x86'])!.name, 'cairn-v2.3.0-universal.apk');
  });

  test('an empty ABI list (device info unreadable) still reaches universal', () {
    expect(pick(const [])!.name, 'cairn-v2.3.0-universal.apk');
  });

  test('a native build still beats universal', () {
    expect(pick(['arm64-v8a'])!.name, isNot(contains('universal')));
  });

  test('returns null when neither a matching ABI nor universal exists', () {
    final withoutUniversal = {...all}..remove('cairn-v2.3.0-universal.apk');
    expect(pick(['x86'], withoutUniversal), isNull);
    expect(pick(['riscv64'], withoutUniversal), isNull);
    expect(pick(const [], withoutUniversal), isNull);
  });

  test('returns null for a release with no APK assets at all', () {
    // A tag pushed without the GitHub Release, or one still uploading.
    expect(pick(['arm64-v8a'], const {}), isNull);
    expect(pick(['arm64-v8a'], {'checksums.json': 'https://example.test/c'}),
        isNull);
  });

  test('only an asset literally named for this version matches', () {
    final otherVersion = {
      'cairn-v2.2.0-arm64-v8a.apk': 'https://example.test/old.apk',
      'cairn-v2.2.0-universal.apk': 'https://example.test/old-u.apk',
    };
    expect(pick(['arm64-v8a'], otherVersion), isNull);
    // Near misses are not matches either.
    expect(
      pick(['arm64-v8a'], {'Cairn-v2.3.0-arm64-v8a.apk': 'https://example.test/x'}),
      isNull,
    );
    expect(
      pick(['arm64-v8a'], {'cairn-v2.3.0-arm64-v8a.apk.sha256': 'https://example.test/x'}),
      isNull,
    );
  });
}
