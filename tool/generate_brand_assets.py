#!/usr/bin/env python3
"""Regenerate every derived brand asset from the approved Cairn glyph.

`assets/icon/cairn_foreground.png` -- the stones on a transparent canvas -- is
the single source of truth. Everything else is composed from it, including the
full-bleed master `assets/icon/cairn_icon.png`, everything under `brand/`, the
production favicon at `web/favicon.ico`, and the Android-only adaptive layers.
None of them may be edited by hand -- they were hand-built once and silently
drifted a whole design generation behind the glyph, which no filename or config
check catches.

Run this whenever `assets/icon/cairn_foreground.png` changes:

    python tool/generate_brand_assets.py           # rewrite the derived assets
    python tool/generate_brand_assets.py --check   # report drift, write nothing

`--check` exits non-zero if any derived asset differs from what this script
would produce, which is the quick way to prove nothing has drifted.

This is a manually-run maintenance script. It is deliberately not wired into
CI or any build step.

What it does NOT touch: the platform launcher icons under `android/`, `ios/`,
`macos/`, `windows/` and `web/icons/`. Those are generated separately by
`flutter_launcher_icons` -- see `pubspec.yaml` and run `dart run
flutter_launcher_icons`. The notification icon `ic_stat_cairn.png` is a
separate hand-built asset and is not derived from the app icon either.

Requires Pillow (`pip install Pillow`). Pillow's PNG/ICO encoders are
deterministic, so a re-run with an unchanged source icon rewrites the same
bytes.
"""

from __future__ import annotations

import argparse
import hashlib
import io
import math
import struct
import sys
from pathlib import Path

try:
    from PIL import Image, ImageChops, ImageDraw
except ImportError:  # pragma: no cover - dependency hint only
    sys.exit("Pillow is required: pip install Pillow")

ROOT = Path(__file__).resolve().parent.parent

# Sources, hand-drawn and never written by this script.
GLYPH = ROOT / "assets/icon/cairn_foreground.png"   # source of truth, transparent
MONO = ROOT / "assets/icon/cairn_monochrome.png"    # themed layer, transparent

# The full-bleed master. An OUTPUT of this script, not a source -- hence a
# repo-relative key like every other entry in `build()`, not a Path.
MASTER = "assets/icon/cairn_icon.png"

# Geometry of the glyph inside the 1024x1024 foreground canvas. The stack sits
# ~76px above canvas centre; that is intentional in the approved artwork, and
# every square/full-bleed output keeps it. The Android adaptive layers are the
# one exception -- see `recentred_layer()`.
FULL = (336, 192, 688, 660)   # including the soft glow halo
SOLID = (336, 214, 688, 659)  # opaque stones + orb only
SOLID_H = SOLID[3] - SOLID[1]             # 445
SOLID_TOP_OFF = SOLID[1] - FULL[1]        # 22, glow above the top stone
SOLID_CX_OFF = (SOLID[0] + SOLID[2]) / 2 - FULL[0]

# Background per variant. `None` means keep the transparent glyph layer.
#
# LIGHT is the default ground for the mark. The stones are a dark purple
# gradient, so on the old brand purple the darkest stone pixel (#330F5D)
# measured 1.34:1 against flat #590D86 and 1.09:1 against the darkest part of
# the master's vignette -- far under the 3:1 WCAG minimum for graphical
# objects, i.e. effectively invisible. On cream it reaches 14.00:1.
DARK = "#17111C"
AMOLED = "#000000"
DEEP = "#40128B"
LIGHT = "#FAF3F0"    # app cream: master, play store, web, desktop

# A pixel counts as artwork (rather than glow falloff) above this alpha. 128
# reproduces the SOLID box above, which is what the eye reads as the stack.
ALPHA_SOLID = 128

# Android composites the adaptive foreground over the background and then masks
# the result to whatever shape the launcher uses -- circle, squircle, rounded
# square. Only a centred circle of ~61.1% of the canvas survives every shape,
# so that is the conservative target the recentred layers are verified against.
SAFE_ZONE = 0.611

# The .icns type/size set, matching the structure of the original file.
ICNS_TYPES = [
    ("ic07", 128), ("ic08", 256), ("ic09", 512), ("ic10", 1024),
    ("ic11", 32), ("ic12", 64), ("ic13", 256), ("ic14", 512),
]


def _hex(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def compose(size: int, bg: str | None) -> Image.Image:
    """The approved composition at `size`, over `bg` (or left transparent).

    This is a 1:1 reproduction of the app icon's framing -- the glyph lands
    exactly where `cairn_icon.png` has it, so only the background differs.
    """
    glyph = Image.open(GLYPH).convert("RGBA")
    if size != 1024:
        glyph = glyph.resize((size, size), Image.LANCZOS)
    if bg is None:
        return glyph
    base = Image.new("RGBA", (size, size), _hex(bg) + (255,))
    base.alpha_composite(glyph)
    return base


def compose_banner(width: int, height: int, bg: str, solid_height: int) -> Image.Image:
    """Same artwork on a non-square canvas, centred.

    `solid_height` is the on-canvas height of the opaque stack, preserved from
    the previous banners so only the artwork changes, not the layout.
    """
    scale = solid_height / SOLID_H
    art = Image.open(GLYPH).convert("RGBA").crop(FULL)
    art = art.resize((round(art.width * scale), round(art.height * scale)), Image.LANCZOS)
    base = Image.new("RGBA", (width, height), _hex(bg) + (255,))
    base.alpha_composite(
        art,
        (round(width / 2 - SOLID_CX_OFF * scale),
         round(height / 2 - (SOLID_TOP_OFF + SOLID_H / 2) * scale)),
    )
    return base


def _png_bytes(img: Image.Image, mode: str) -> bytes:
    buf = io.BytesIO()
    img.convert(mode).save(buf, format="PNG")
    return buf.getvalue()


def _ico_bytes(sizes: list[int], bg: str) -> bytes:
    # Pillow's ICO writer derives every frame from the base image it is given,
    # so the base must be the LARGEST size or all frames collapse to the
    # smallest one.
    base = compose(1024, bg).resize((max(sizes), max(sizes)), Image.LANCZOS)
    buf = io.BytesIO()
    base.save(buf, format="ICO", sizes=[(s, s) for s in sizes])
    return buf.getvalue()


def _icns_bytes(bg: str) -> bytes:
    master = compose(1024, bg)
    rendered: dict[int, bytes] = {}
    chunks = []
    for name, px in ICNS_TYPES:
        if px not in rendered:
            img = master if px == 1024 else master.resize((px, px), Image.LANCZOS)
            rendered[px] = _png_bytes(img, "RGBA")
        chunks.append((name.encode("ascii"), rendered[px]))
    toc = b"".join(t + struct.pack(">I", len(d) + 8) for t, d in chunks)
    body = b"TOC " + struct.pack(">I", len(toc) + 8) + toc
    body += b"".join(t + struct.pack(">I", len(d) + 8) + d for t, d in chunks)
    return b"icns" + struct.pack(">I", len(body) + 8) + body


def _alpha_bbox(img: Image.Image, threshold: int) -> tuple[int, int, int, int]:
    """Bounding box of pixels above `threshold` alpha (right/lower exclusive)."""
    solid = img.getchannel("A").point(lambda v: 255 if v > threshold else 0)
    box = solid.getbbox()
    if box is None:
        sys.exit("source layer has no pixels above the alpha threshold")
    return box


def recentred_layer(path: Path) -> tuple[Image.Image, int, float, float]:
    """`path`'s artwork translated so its solid bbox centres on the canvas.

    Android only guarantees a centred circle of the adaptive icon survives
    masking, and the approved composition deliberately sits high in the square,
    which on-device reads as off-centre with dead space below. This shifts the
    layer down onto the canvas centre for the Android layers only -- the square
    composition every other platform uses is left exactly as drawn.

    The shift is measured from the artwork, never hardcoded, so it stays correct
    if the mark is ever redrawn. It is a whole-pixel translate on a fresh
    transparent canvas: nothing is resized, resampled or cropped.

    Returns (image, offset, before, after) where `before`/`after` are the signed
    distances from the solid bbox centre to the canvas centre.
    """
    src = Image.open(path).convert("RGBA")
    width, height = src.size
    box = _alpha_bbox(src, ALPHA_SOLID)
    before = height / 2 - (box[1] + box[3]) / 2
    offset = math.floor(before + 0.5)          # whole pixels: translate only
    shifted = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    shifted.paste(src, (0, offset))

    # `paste` silently drops anything pushed off the canvas.
    moved = _alpha_bbox(shifted, 0)
    original = _alpha_bbox(src, 0)
    if (moved[2] - moved[0], moved[3] - moved[1]) != (
            original[2] - original[0], original[3] - original[1]):
        sys.exit(f"{path.name}: shifting by {offset}px would clip the artwork "
                 f"off the {width}x{height} canvas")

    moved_solid = _alpha_bbox(shifted, ALPHA_SOLID)
    after = height / 2 - (moved_solid[1] + moved_solid[3]) / 2
    return shifted, offset, before, after


def safe_zone_spill(img: Image.Image) -> tuple[int, float]:
    """(visible pixels outside Android's safe circle, furthest visible radius).

    Uses every visible pixel, not just the solid ones -- the mask clips the soft
    glow too.
    """
    width, height = img.size
    radius = SAFE_ZONE * min(width, height) / 2
    outside = Image.new("L", (width, height), 255)
    ImageDraw.Draw(outside).ellipse(
        (width / 2 - radius, height / 2 - radius,
         width / 2 + radius, height / 2 + radius), fill=0)
    visible = img.getchannel("A").point(lambda v: 255 if v > 0 else 0)
    spill = sum(ImageChops.multiply(visible, outside).histogram()[1:])

    px = visible.load()
    box = _alpha_bbox(img, 0)
    worst = 0.0
    for y in range(box[1], box[3]):
        dy = (y + 0.5) - height / 2
        for x in range(box[0], box[2]):
            if px[x, y]:
                worst = max(worst, math.hypot((x + 0.5) - width / 2, dy))
    return spill, worst


def android_adaptive_layers() -> dict[str, bytes]:
    """The Android-only recentred foreground/monochrome pair.

    The monochrome layer is measured independently: it carries different padding
    from the foreground, so it gets its own offset rather than inheriting one.
    """
    out: dict[str, bytes] = {}
    radius = SAFE_ZONE * 1024 / 2
    print("Android adaptive layers (recentred for the safe zone):")
    for src, dest in ((GLYPH, "assets/icon/cairn_adaptive_foreground.png"),
                      (MONO, "assets/icon/cairn_adaptive_monochrome.png")):
        img, offset, before, after = recentred_layer(src)
        spill, worst = safe_zone_spill(img)
        if spill:
            sys.exit(
                f"{src.name}: {spill} visible pixel(s) fall outside the "
                f"{SAFE_ZONE:.3f} safe zone (radius {radius:.1f}px) even when "
                f"centred -- furthest is {worst:.1f}px out. The artwork is too "
                f"large to fit; that needs a design decision, not a code fix.")
        print(f"  {src.name}: shift {offset:+d}px, centre offset "
              f"{before:+.1f}px -> {after:+.1f}px, furthest visible pixel "
              f"{worst:.1f}px of {radius:.1f}px safe radius")
        out[dest] = _png_bytes(img, "RGBA")
    print()
    return out


def build() -> dict[str, bytes]:
    """Every derived asset, as repo-relative path -> file bytes."""
    out: dict[str, bytes] = {}

    # The full-bleed master. Every square platform icon (iOS, macOS, Windows,
    # web) is generated from this file by `flutter_launcher_icons`, so it is an
    # output here rather than a hand-maintained file -- that is exactly the
    # manual drift this script exists to prevent.
    master = compose(1024, LIGHT)
    out[MASTER] = _png_bytes(master, "RGB")

    # Play Store. The icon is a straight resize of the master, no recomposition.
    # It resizes the freshly composed master rather than re-reading MASTER off
    # disk, which would lag a run behind whenever the master itself changes.
    out["brand/play-store/play-icon-512.png"] = _png_bytes(
        master.convert("RGB").resize((512, 512), Image.LANCZOS), "RGB")
    out["brand/play-store/feature-graphic-1024x500.png"] = _png_bytes(
        compose_banner(1024, 500, LIGHT, 336), "RGB")
    out["brand/play-store/banner-1280x640.png"] = _png_bytes(
        compose_banner(1280, 640, LIGHT, 348), "RGB")

    # Theme / light / transparent variants, 1:1 with the app icon.
    #
    # NOTE: on any LIGHT ground -- which is now every output except the three
    # dark theme swatches -- the artwork's glowing cream orb measures 1.00:1
    # against the cream, so it is effectively invisible, and its rim only
    # reaches 1.18:1. That is a known, accepted limitation of using the
    # approved artwork unmodified; adapting the orb for light grounds would be
    # a design change. Deliberately left alone here so this script does not
    # quietly diverge from the other variants. Fix it in the artwork, not here.
    for path, bg in [
        ("brand/themes/cairn-dark-1024.png", DARK),
        ("brand/themes/cairn-amoled-1024.png", AMOLED),
        ("brand/themes/cairn-deep-1024.png", DEEP),
        ("brand/light/cairn-light-1024.png", LIGHT),
    ]:
        out[path] = _png_bytes(compose(1024, bg), "RGBA")
    out["brand/transparent/cairn-mark-1024.png"] = _png_bytes(compose(1024, None), "RGBA")

    # Web brand sources.
    out["brand/web/maskable-512.png"] = _png_bytes(compose(512, LIGHT), "RGBA")
    out["brand/web/favicon.ico"] = _ico_bytes([16, 32, 48], LIGHT)

    # Desktop.
    out["brand/desktop/cairn.ico"] = _ico_bytes([16, 24, 32, 48, 64, 128, 256], LIGHT)
    out["brand/desktop/cairn.icns"] = _icns_bytes(LIGHT)

    # The production favicon is a copy of the brand source, not a separate
    # render -- this is the file users actually see.
    out["web/favicon.ico"] = out["brand/web/favicon.ico"]

    # Android-only. Generated in the same pass as everything above, so `--check`
    # covers them, but positioned differently -- see `recentred_layer()`.
    out.update(android_adaptive_layers())

    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true",
                        help="report drift without writing anything")
    args = parser.parse_args()

    for required in (GLYPH, MONO):
        if not required.exists():
            sys.exit(f"missing source artwork: {required.relative_to(ROOT)}")

    assets = build()
    changed = []
    for rel, data in assets.items():
        target = ROOT / rel
        current = target.read_bytes() if target.exists() else None
        state = "unchanged" if current == data else ("new" if current is None else "CHANGED")
        if state != "unchanged":
            changed.append(rel)
        if not args.check:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        print(f"  {state:9} {rel}  ({hashlib.sha256(data).hexdigest()[:12]})")

    if args.check:
        if changed:
            print(f"\n{len(changed)} asset(s) differ from the source artwork:")
            for rel in changed:
                print(f"  - {rel}")
            print("run without --check to regenerate")
            return 1
        print(f"\nall {len(assets)} derived assets are up to date")
        return 0

    print(f"\nwrote {len(assets)} assets ({len(changed)} changed)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
