#!/usr/bin/env python3
"""Regenerate every derived brand asset from the approved Cairn app icon.

`assets/icon/cairn_icon.png` is the single source of truth. Everything under
`brand/` (plus the production favicon at `web/favicon.ico`) is derived from it
and must never be edited by hand -- they were hand-built once and silently
drifted a whole design generation behind the app icon, which no filename or
config check catches.

Run this whenever `assets/icon/cairn_icon.png` changes:

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
import struct
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:  # pragma: no cover - dependency hint only
    sys.exit("Pillow is required: pip install Pillow")

ROOT = Path(__file__).resolve().parent.parent

MASTER = ROOT / "assets/icon/cairn_icon.png"        # approved icon, full bleed
GLYPH = ROOT / "assets/icon/cairn_foreground.png"   # same artwork, transparent

# Geometry of the glyph inside the 1024x1024 foreground canvas. The stack sits
# ~76px above canvas centre; that is intentional in the approved artwork.
FULL = (336, 192, 688, 660)   # including the soft glow halo
SOLID = (336, 214, 688, 659)  # opaque stones + orb only
SOLID_H = SOLID[3] - SOLID[1]             # 445
SOLID_TOP_OFF = SOLID[1] - FULL[1]        # 22, glow above the top stone
SOLID_CX_OFF = (SOLID[0] + SOLID[2]) / 2 - FULL[0]

# Background per variant. `None` means keep the transparent glyph layer.
PURPLE = "#590D86"   # brand purple: play store, web, desktop
DARK = "#17111C"
AMOLED = "#000000"
DEEP = "#40128B"
LIGHT = "#FAF3F0"    # app cream

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


def build() -> dict[str, bytes]:
    """Every derived asset, as repo-relative path -> file bytes."""
    out: dict[str, bytes] = {}

    # Play Store. The icon is a straight resize of the master, no recomposition.
    out["brand/play-store/play-icon-512.png"] = _png_bytes(
        Image.open(MASTER).convert("RGB").resize((512, 512), Image.LANCZOS), "RGB")
    out["brand/play-store/feature-graphic-1024x500.png"] = _png_bytes(
        compose_banner(1024, 500, PURPLE, 336), "RGB")
    out["brand/play-store/banner-1280x640.png"] = _png_bytes(
        compose_banner(1280, 640, PURPLE, 348), "RGB")

    # Theme / light / transparent variants, 1:1 with the app icon.
    #
    # NOTE: on the light background the cream orb measures 1.00:1 against the
    # cream ground -- it is effectively invisible, and its rim only reaches
    # 1.18:1. That is a known, accepted limitation of using the approved
    # artwork unmodified; adapting the orb for light grounds would be a design
    # change. Deliberately left alone here so this script does not quietly
    # diverge from the other variants. Fix it in the source artwork, not here.
    for path, bg in [
        ("brand/themes/cairn-dark-1024.png", DARK),
        ("brand/themes/cairn-amoled-1024.png", AMOLED),
        ("brand/themes/cairn-deep-1024.png", DEEP),
        ("brand/light/cairn-light-1024.png", LIGHT),
    ]:
        out[path] = _png_bytes(compose(1024, bg), "RGBA")
    out["brand/transparent/cairn-mark-1024.png"] = _png_bytes(compose(1024, None), "RGBA")

    # Web brand sources.
    out["brand/web/maskable-512.png"] = _png_bytes(compose(512, PURPLE), "RGBA")
    out["brand/web/favicon.ico"] = _ico_bytes([16, 32, 48], PURPLE)

    # Desktop.
    out["brand/desktop/cairn.ico"] = _ico_bytes([16, 24, 32, 48, 64, 128, 256], PURPLE)
    out["brand/desktop/cairn.icns"] = _icns_bytes(PURPLE)

    # The production favicon is a copy of the brand source, not a separate
    # render -- this is the file users actually see.
    out["web/favicon.ico"] = out["brand/web/favicon.ico"]

    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true",
                        help="report drift without writing anything")
    args = parser.parse_args()

    for required in (MASTER, GLYPH):
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
