# Cairn icon pack

Four stacked stones with a lavender cap. Generated from one geometry definition,
so every file here is the same shape — none of it was traced or redrawn.

**Colours**

| | hex | used for |
|---|---|---|
| Brand purple | `#590D86` | the ground |
| Cream | `#FAF3F0` | the three lower stones |
| Lavender | `#BA7DD6` | the cap stone |
| Mid purple | `#8B3FAE` | the cap on light backgrounds only — lavender disappears on cream |

Contrast, measured: cream on purple **10.5:1**, purple on cream **10.5:1**,
lavender cap on purple **3.8:1**. The last is the weakest relationship in the
mark. Fine for a decorative shape, but do not use lavender for text on purple.

---

## `source/` — start here

| file | what it is |
|---|---|
| `cairn.svg` | **The master.** Vector, purple ground. Scales to anything, editable in any vector tool. |
| `cairn-mark.svg` | Just the stones, transparent. Put it on any background. |
| `cairn-light.svg` | Purple stones on cream, for light contexts. |
| `cairn-monochrome.svg` | Solid black silhouette, for Android themed icons and stencils. |
| `cairn-simplified.svg` | Two stones instead of four — see *Small sizes* below. |

If you only keep one file, keep `cairn.svg`. Everything else here is rendered
from it and can be regenerated.

---

## Small sizes — worth knowing

**The full four-stone mark does not survive 16px.** The gaps between stones fall
below one pixel and it turns into a blob. That was checked, not assumed.

So the tiny sizes use a simplified two-stone version: same colours, same idea,
readable where the full stack is not. The crossover is at 24px — the full mark
is used from 32px up, where it is clearly legible.

This is already handled inside `favicon.ico` and `cairn.ico`, which contain
different artwork per size. You do not need to do anything about it; it is
documented so the difference does not look like a mistake later.

---

## `android/` — what the app uses

| file | where it goes |
|---|---|
| `cairn_icon.png` | `flutter_launcher_icons` → `image_path` |
| `cairn_foreground.png` | → `adaptive_icon_foreground` (transparent) |
| `cairn_background.png` | → `adaptive_icon_background` (**new — the project only had a colour before**) |
| `cairn_monochrome.png` | → `adaptive_icon_monochrome`, for Android 13+ themed icons |
| `mipmap/*.png` | Pre-rendered densities, only if you ever place them by hand |

The project's three existing assets are byte-for-byte equivalent to these — the
regenerated versions differ by an average of 0.09/255 per channel, which is
anti-aliasing on the rounded corners and nothing else. **The background is the
one genuinely new file.**

Content sits between 24.7% and 77.3% of the canvas, inside the adaptive icon's
safe zone (16.7%–83.3%), so no launcher mask can clip a stone.

---

## `play-store/` — for later

| file | size | note |
|---|---|---|
| `play-icon-512.png` | 512×512 | RGB, no alpha — Play rejects transparency on the store icon, and adds its own rounded corners |
| `feature-graphic-1024x500.png` | 1024×500 | Centred mark on purple |
| `banner-1280x640.png` | 1280×640 | Social / README header |

**The feature graphic has no wordmark.** Cairn's display face is Bricolage
Grotesque, which was not available here, and setting the name in the wrong
typeface would establish the wrong look and have to be redone. Add "Cairn" in
Bricolage Grotesque before this goes to Play. It is fine as-is for anything else.

---

## `themes/` — colour variants

Five grounds. The stones stay cream on every dark ground; only the cap changes,
to the accent that theme actually uses in the app.

| variant | ground | from | stones | cap |
|---|---|---|---|---|
| `purple` | `#590D86` | `BrandColors.purple` — **the brand mark, use this by default** | 10.5:1 | 3.8:1 |
| `deep` | `#40128B` | `BrandColors.violetDeep` | 11.4:1 | 4.2:1 |
| `dark` | `#17111C` | `BrandColors.darkGround` — matches the app's dark theme | 16.9:1 | 7.4:1 |
| `amoled` | `#000000` | true black, for OLED | 19.1:1 | 8.3:1 |
| `cream` | `#FAF3F0` | `BrandColors.cream` | 10.5:1 | 5.6:1 |

Ratios are measured, not estimated. On the dark and AMOLED variants the cap uses
`BrandColors.darkPurple` `#C08FE8` — the same accent the dark theme uses — which
is why those two have far better cap contrast than the brand mark does.

**These do not change the launcher icon.** Android app icons are fixed; they do
not follow the system theme. The only launcher icon that adapts is the
monochrome layer, which Android 13+ tints from the wallpaper, and that is
already wired. Use these variants inside the app — splash, About, empty states —
and anywhere a purple square would fight the surface behind it.

---

## `android/notification/` — required, and previously missing

**This was a real bug, not a nicety.**

Android draws the status-bar small icon from the **alpha channel only** and
throws the colour away. `cairn_icon.png` is a full-bleed opaque square, so used
as a notification icon it renders as a **solid white square** — the classic
Android white-blob bug. The timer's foreground notification ships today with no
icon configured, so that is what it is doing now, and the task reminders coming
in round 2 would have done the same.

The fix is a white silhouette on transparent, which is what these are. They use
the simplified two-stone mark: the displayed size is 24dp at every density, and
the four-stone stack no longer reads at that size — the same limit that makes
the 16px favicon simplified. `ic_stat_cairn-fullmark-96.png` is included so you
can see the difference for yourself.

**Wiring it up:**

1. Copy the five `drawable-*/ic_stat_cairn.png` files into
   `android/app/src/main/res/` — that folder does not exist yet, create it.
2. In `AndroidManifest.xml`, inside `<application>`:

```xml
<meta-data
    android:name="dev.beetlebyte.cairn.service.CAIRN_ICON"
    android:resource="@drawable/ic_stat_cairn" />
```

3. In `timer_foreground_service.dart`, pass it to `startService`:

```dart
notificationIcon: const NotificationIcon(
  metaDataName: 'dev.beetlebyte.cairn.service.CAIRN_ICON',
  backgroundColor: Color(0xFF590D86),
),
```

4. For `flutter_local_notifications` (task reminders):
   `AndroidInitializationSettings('ic_stat_cairn')`.

---

## `android/splash/` — Android 12+ splash screen

The splash API gives a 288dp canvas and shows the icon within the middle 192dp,
so the artwork here is drawn at two-thirds with transparent margin. Dropping a
full-bleed icon in instead gets it cropped by the system's circular mask.

---

## `ios/`

`AppIcon-1024.png` plus every size Xcode asks for. All RGB with no alpha —
App Store Connect rejects an icon with an alpha channel, which is the single
most common iOS icon rejection.

## `desktop/`

`cairn.ico` (16→256, mixed artwork per size) for Windows, `cairn.icns` for
macOS, and plain PNGs at 256/512/1024.

## `web/`

`favicon.ico` (16/32/48, mixed artwork), PNG favicons, `apple-touch-icon-180.png`,
and `maskable-192/512.png` — the maskable pair is shrunk to 80% so that a PWA
launcher mask cannot crop it.

## `transparent/` and `light/`

Alpha-channel PNGs at 256/512/1024: the mark in cream, black and white, plus the
purple-on-cream light variant. These are for slides, documentation and anywhere
the purple square would fight the page.

---

## Regenerating

Everything derives from the geometry in `cairn.svg`: four rounded rectangles in
a 100×100 box.

```
bottom stone   x 27.0   y 64.0   w 46.0   h 13.0   r 6.0
               x 33.0   y 50.0   w 37.0   h 12.0   r 5.5
               x 34.5   y 38.0   w 29.0   h 10.0   r 5.0
cap stone      x 42.0   y 25.0   w 18.0   h 11.0   r 5.5
```

Simplified mark, for 24px and below:

```
base           x 18.0   y 56.0   w 64.0   h 21.0   r 10.5
cap            x 33.0   y 24.0   w 34.0   h 21.0   r 10.5
```
