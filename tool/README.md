# tool/

Manually-run maintenance scripts. Nothing here is wired into CI or the build.

## `generate_brand_assets.py`

Regenerates every derived brand asset from `assets/icon/cairn_icon.png`, the
single approved source of truth for the Cairn mark.

**Run it whenever `assets/icon/cairn_icon.png` changes**, then commit the
regenerated files alongside the new icon:

```bash
python tool/generate_brand_assets.py
```

To check for drift without writing anything (exits non-zero if any derived
asset is out of date):

```bash
python tool/generate_brand_assets.py --check
```

Requires Pillow (`pip install Pillow`).

### What it regenerates

| Output | Notes |
|---|---|
| `brand/play-store/play-icon-512.png` | straight resize of the master icon |
| `brand/play-store/feature-graphic-1024x500.png` | artwork centred on brand purple |
| `brand/play-store/banner-1280x640.png` | artwork centred on brand purple |
| `brand/themes/cairn-{dark,amoled,deep}-1024.png` | per-theme backgrounds |
| `brand/light/cairn-light-1024.png` | cream background |
| `brand/transparent/cairn-mark-1024.png` | transparent glyph layer |
| `brand/desktop/cairn.icns` | multi-resolution, 128–1024 |
| `brand/desktop/cairn.ico` | multi-resolution, 16–256 |
| `brand/web/favicon.ico` | multi-size 16/32/48 |
| `brand/web/maskable-512.png` | PWA maskable source |
| `web/favicon.ico` | production favicon, copied from the brand source |

Edit none of these by hand. They were hand-built once and silently drifted a
full design generation behind the app icon, which no filename or config check
catches.

### What it does *not* touch

The platform launcher icons under `android/`, `ios/`, `macos/`, `windows/` and
`web/icons/` come from a different generator — `flutter_launcher_icons`,
configured in `pubspec.yaml`:

```bash
dart run flutter_launcher_icons
```

Note that that tool rewrites `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS`
from `YES` to `AppIcon` in `ios/Runner.xcodeproj/project.pbxproj` on every run;
revert that before committing. The notification icon `ic_stat_cairn.png` is a
separate hand-built asset and is not derived from the app icon.

### Known limitation

On `brand/light/cairn-light-1024.png` the artwork's glowing cream orb measures
1.00:1 against the cream background — effectively invisible, with its rim only
reaching 1.18:1. This is inherent to using the approved artwork unmodified on a
light ground. The script deliberately does not special-case it; if it needs
fixing, fix it in the source artwork so every variant stays consistent.
