import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// The one definition of Cairn's card surfaces and tracks.
///
/// This started as a private `_StatsChrome` on the Stats screen and was
/// duplicated per screen on purpose — a per-screen helper meant restyling one
/// screen could not silently restyle another. Once six screens wanted the same
/// values that reasoning inverted: the copies were the only thing standing
/// between the app and a consistent card system, and they had already drifted
/// into three different treatments on screens sitting next to each other.
///
/// Every colour here is a brightness switch rather than one Material slot,
/// because the light and dark boards land on different slots: the card is
/// `#FFFFFF` on cream but `#201829` on the dark ground, and picking a single
/// slot either greys the light card or makes the dark card darker than the
/// page it sits on.
abstract final class CardChrome {
  /// The standard card fill: `#FFFFFF` / `#201829`.
  static Color card(BuildContext context) {
    final colors = context.colors;
    return colors.brightness == Brightness.dark
        ? colors.surfaceContainer
        : colors.surfaceContainerLowest;
  }

  /// The flatter inset panel used for tiles and the journey trail:
  /// `#FBF7F5` / `#2A2035`.
  static Color panel(BuildContext context) {
    final colors = context.colors;
    return colors.brightness == Brightness.dark
        ? colors.surfaceContainerHigh
        : colors.surfaceContainerLow;
  }

  /// The track behind a segmented pill control: `#F2E7E2` / `#2C2237`.
  static Color pickerTrack(BuildContext context) {
    final colors = context.colors;
    return colors.brightness == Brightness.dark
        ? context.tokens.lineSoft
        : colors.surfaceContainerHigh;
  }

  /// The small uppercase heading above a card's content: 12px, 700, 0.6
  /// tracking. Uppercased here so no caller has to remember to.
  static Widget sectionLabel(BuildContext context, String text) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: context.tokens.textMuted,
          ),
    );
  }
}

/// A card in Cairn's card system: 22-radius, filled, flat.
///
/// Flat on purpose — the system used to be shadow-led, and the shadows were
/// dropped because they did not suit the app's soft cream/ink palette. A card
/// is told apart from the page by its fill, the way the pre-redesign cards
/// were.
///
/// Use this instead of Material's [Card] for anything hand-built. [Card] still
/// works — `cardTheme` in `app_theme.dart` is pointed at the same radius,
/// surface and flatness — but this one takes an [onTap] that covers the whole
/// card including its padding.
class CairnCard extends StatelessWidget {
  const CairnCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.radius = 22,
    this.color,
    this.border,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;

  /// Overrides the standard fill — for the flatter [CardChrome.panel] look.
  final Color? color;

  /// An outline on top of the fill. Off by default — the fill alone separates
  /// a card from the page. Reach for it where the border carries meaning, such
  /// as an overdue task's danger tint.
  final BoxBorder? border;

  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);

    Widget content = Padding(padding: padding, child: child);

    if (onTap != null) {
      content = Material(
        type: MaterialType.transparency,
        borderRadius: shape,
        child: InkWell(
          borderRadius: shape,
          onTap: onTap,
          child: content,
        ),
      );
    }

    Widget card = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? CardChrome.card(context),
        borderRadius: shape,
        border: border,
      ),
      child: content,
    );

    if (semanticLabel != null) {
      card = Semantics(
        container: true,
        label: semanticLabel,
        excludeSemantics: true,
        child: card,
      );
    }
    return card;
  }
}
