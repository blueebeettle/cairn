import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The shared stone-stack glyph behind the Cairn redesign.
///
/// The same widget backs Today's "Grow your cairn" card, the milestone
/// celebration, the Habits-list milestone card and the Stats "Your journey"
/// trail — only [stoneCount], [scale], [showMarker] and [opacity] change.
///
/// Geometry is lifted verbatim from the approved mockups: the four full-size
/// stones and the marker come from the "Grow your cairn" card in
/// `claude-outputs/designs/Today.dc.html` (wrapper 76x86), and the reduced
/// stone counts at small scales are the same shapes as the seven mini
/// instances in the "Your journey" trail of `claude-outputs/designs/Stats.dc.html`.
///
/// The silhouette is deliberately irregular — alternating rotations, offsets
/// that do not line up, visible gaps with a contact shadow in each gap, and a
/// *detached* marker floating above the top stone. A symmetric, continuously
/// tapering stack was rejected in review for reading as a single blob, so
/// nothing here should be "tidied up" into an even taper.
class CairnGlyph extends StatelessWidget {
  const CairnGlyph({
    super.key,
    required this.stoneCount,
    this.scale = 1.0,
    this.showMarker = true,
    this.opacity = 1.0,
  });

  /// How many stones are "grown" so far. Clamped to 0-4; 0 renders an empty box
  /// of the same size, so a growing glyph never shifts the layout around it.
  final int stoneCount;

  /// 1.0 is the Today-card size (76x86 logical pixels). The box keeps that
  /// aspect at every scale so a row of glyphs at different scales bottom-aligns
  /// cleanly — which is what the Stats trail needs.
  final double scale;

  /// The glowing top disc. Off for the muted/faded trail stones.
  final bool showMarker;

  final double opacity;

  /// Natural size of the glyph at [scale] 1.0.
  static const double baseWidth = 76;
  static const double baseHeight = 86;

  /// The four stone fills, bottom to top. Intentionally identical in light and
  /// dark: they are decorative, and all four read fine on either ground.
  static const List<Color> stoneFills = <Color>[
    Color(0xFF40128B),
    Color(0xFF590D86),
    Color(0xFF8B3FAE),
    Color(0xFFBA7DD6),
  ];

  /// Stones bottom-to-top, straight off the mockup CSS.
  static const List<_Stone> _stones = <_Stone>[
    _Stone(
      bottom: 0,
      left: 4,
      width: 60,
      height: 16,
      topRadius: 8,
      bottomRadius: 14,
      rotationDegrees: -2,
    ),
    _Stone(
      bottom: 19,
      left: 12,
      width: 46,
      height: 15,
      topRadius: 7,
      bottomRadius: 12,
      rotationDegrees: 3,
    ),
    _Stone(
      bottom: 37,
      left: 22,
      width: 32,
      height: 13,
      topRadius: 6,
      bottomRadius: 10,
      rotationDegrees: -4,
    ),
    _Stone(
      bottom: 53,
      left: 28,
      width: 20,
      height: 11,
      topRadius: 5,
      bottomRadius: 8,
      rotationDegrees: 5,
    ),
  ];

  /// Contact shadow sitting in the gap *below* stone `index + 1`. Sells the
  /// stacking without real shadows, exactly as the mockup does.
  static const List<_Contact> _contacts = <_Contact>[
    _Contact(
        bottom: 15,
        left: 14,
        width: 42,
        height: 3,
        lightAlpha: 0.08,
        darkAlpha: 0.28),
    _Contact(
        bottom: 33,
        left: 20,
        width: 32,
        height: 3,
        lightAlpha: 0.10,
        darkAlpha: 0.30),
    _Contact(
        bottom: 49,
        left: 28,
        width: 22,
        height: 2.5,
        lightAlpha: 0.10,
        darkAlpha: 0.30),
  ];

  static const double _markerSize = 14;

  /// Gap between the top stone and the marker — the "detached" part.
  static const double _markerGap = 4;

  /// A CSS blur-radius r spreads over sigma = r / 2, and Flutter's BoxShadow
  /// converts blurRadius to sigma with a factor of 0.57735. So a CSS blur of r
  /// is a Flutter blurRadius of r / 2 / 0.57735, i.e. r * 0.866.
  static double _cssBlur(double cssRadius) => cssRadius * 0.866;

  /// The marker's ring + glow, on their own.
  ///
  /// Exposed so other surfaces can mark "now" with the same device instead of
  /// inventing a second glow — the Today week strip's today column uses it.
  static List<BoxShadow> markerHalo(BuildContext context, {double scale = 1.0}) {
    final palette = _CairnPalette.of(context);
    return [
      // Soft glow first so the tight ring paints over it.
      BoxShadow(
        color: palette.markerGlow,
        blurRadius: _cssBlur(14) * scale,
        spreadRadius: 4 * scale,
      ),
      BoxShadow(
        color: palette.markerRing,
        spreadRadius: 3 * scale,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final palette = _CairnPalette.of(context);
    final count = stoneCount.clamp(0, _stones.length);

    final layers = <Widget>[];

    for (var i = 0; i < count; i++) {
      // The contact shadow belongs to the stone above it, so it only appears
      // once that stone exists.
      if (i > 0) {
        final contact = _contacts[i - 1];
        layers.add(
          Positioned(
            left: contact.left * scale,
            bottom: contact.bottom * scale,
            width: contact.width * scale,
            height: contact.height * scale,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: palette.contact.withValues(
                  alpha: palette.isDark ? contact.darkAlpha : contact.lightAlpha,
                ),
                borderRadius: BorderRadius.circular(2 * scale),
              ),
            ),
          ),
        );
      }

      final stone = _stones[i];
      layers.add(
        Positioned(
          left: stone.left * scale,
          bottom: stone.bottom * scale,
          width: stone.width * scale,
          height: stone.height * scale,
          child: Transform.rotate(
            angle: stone.rotationDegrees * math.pi / 180,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: stoneFills[i],
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(stone.topRadius * scale),
                  bottom: Radius.circular(stone.bottomRadius * scale),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (showMarker && count > 0) {
      final top = _stones[count - 1];
      final size = _markerSize * scale;
      // Centred on the top stone, floating a small gap above it.
      layers.add(
        Positioned(
          left: (top.left + top.width / 2) * scale - size / 2,
          bottom: (top.bottom + top.height + _markerGap) * scale,
          width: size,
          height: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: palette.markerCore,
              shape: BoxShape.circle,
              boxShadow: markerHalo(context, scale: scale),
            ),
          ),
        ),
      );
    }

    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: SizedBox(
        width: baseWidth * scale,
        height: baseHeight * scale,
        // Rotations and the marker glow both spill past their Positioned boxes.
        child: Stack(clipBehavior: Clip.none, children: layers),
      ),
    );
  }
}

@immutable
class _Stone {
  const _Stone({
    required this.bottom,
    required this.left,
    required this.width,
    required this.height,
    required this.topRadius,
    required this.bottomRadius,
    required this.rotationDegrees,
  });

  final double bottom;
  final double left;
  final double width;
  final double height;
  final double topRadius;
  final double bottomRadius;
  final double rotationDegrees;
}

@immutable
class _Contact {
  const _Contact({
    required this.bottom,
    required this.left,
    required this.width,
    required this.height,
    required this.lightAlpha,
    required this.darkAlpha,
  });

  final double bottom;
  final double left;
  final double width;
  final double height;
  final double lightAlpha;
  final double darkAlpha;
}

/// Everything except the four stone fills comes from the theme.
///
/// A few roles genuinely differ by brightness in the mockups, so they are
/// resolved here once rather than re-guessed at each call site:
///   * marker core — the brightest neutral in each palette: `surface` (cream
///     #FAF3F0) in light, `onSurface` (#F3EBF0) in dark.
///   * marker ring — `secondaryContainer` (#EDDCF5) in light; dark leads with
///     the lightened purple instead, `primary` at 40%.
///   * marker glow — `secondary` (lavender) at 45% in light, `primary` at 55%
///     in dark, matching the two mockup boards.
///   * contact — `onSurface` (#17101F) in light, `scrim` (black) in dark;
///     light's `shadow` role is the brand purple, which would tint the gaps.
@immutable
class _CairnPalette {
  const _CairnPalette({
    required this.isDark,
    required this.markerCore,
    required this.markerRing,
    required this.markerGlow,
    required this.contact,
  });

  factory _CairnPalette.of(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    return _CairnPalette(
      isDark: isDark,
      markerCore: isDark ? scheme.onSurface : scheme.surface,
      markerRing: isDark
          ? scheme.primary.withValues(alpha: 0.40)
          : scheme.secondaryContainer,
      markerGlow: isDark
          ? scheme.primary.withValues(alpha: 0.55)
          : scheme.secondary.withValues(alpha: 0.45),
      contact: isDark ? scheme.scrim : scheme.onSurface,
    );
  }

  final bool isDark;
  final Color markerCore;
  final Color markerRing;
  final Color markerGlow;
  final Color contact;
}
