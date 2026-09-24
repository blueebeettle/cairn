# Claude outputs — Cairn motivation redesign

Everything produced during the UI/UX redesign work, saved here for reference alongside the code.

## implementation-spec/

`Cairn-Redesign-Implementation-Spec.md` — the paste-ready, screen-by-screen implementation spec for Antigravity. References real files/classes/tokens in this repo. The live, editable version (with working section links) is at:
https://claude.ai/artifact/MZxP39UDFZUCLY2kbGeqCu

## designs/

The 10 approved mockup boards (5 screens × light/dark) as static HTML files, plus `canvas.json` (the layout index). Each `.dc.html` will render its visuals directly in a browser, though a couple of editor-only affordances (from `support.js`, not included here) won't be active outside the live canvas. For the interactive, always-current version — open, comment, or keep iterating — use the canvas:
https://claude.ai/artifact/WGDmX4UN4GcNHU19BdLXZ9

Screens: Today, Milestone celebration, Habits list, Tasks, Stats — each with a `.dc.html` (light) and `.Dark.dc.html` (dark) pair.

## icons/

The regenerated app-icon assets (cairn glyph, replacing the old flame icon):

- `cairn_icon.png` — master/flat icon (iOS, Windows, pre-Android-8 fallback)
- `cairn_foreground.png` — Android adaptive-icon foreground layer (transparent)
- `cairn_monochrome.png` — Android 13+ themed-icon layer (single white shape, transparent)
- `cairn_background.png` — flat swatch matching `adaptive_icon_background` (currently unused by `flutter_launcher_icons`, kept for parity)
- `splash_icon.png` — transparent glyph (currently unreferenced in the app, kept for parity)

These are already copied into `assets/icon/` (overwriting the old flame-icon files) — that's the copy `flutter_launcher_icons` actually reads. This folder just keeps a labeled reference set alongside the rest of the redesign output.

**Still needed:** run `dart run flutter_launcher_icons` from the project root to regenerate the platform-specific files (`android/app/src/main/res/mipmap-*`, `ios/Runner/Assets.xcassets/AppIcon.appiconset`, etc.) from the new source images in `assets/icon/`.
