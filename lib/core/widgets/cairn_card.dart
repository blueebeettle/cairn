import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// The one definition of Cairn's card surfaces and tracks, shared so every
/// screen's cards stay consistent.
///
/// Every colour here is a brightness switch rather than one Material slot,
/// because light and dark land on different slots: the card is `#FFFFFF` on
/// cream but `#201829` on the dark ground, and any single slot either greys the
/// light card or makes the dark card darker than the page it sits on.
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

/// A card in Cairn's card system: 22-radius, filled, flat. Flat on purpose:
/// shadows didn't suit the soft cream/ink palette, so a card is told apart from
/// the page by its fill.
///
/// Use this instead of Material's [Card] for anything hand-built. [Card] still
/// works (`cardTheme` in `app_theme.dart` is pointed at the same radius,
/// surface and flatness), but this one takes an [onTap] that covers the whole
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

  /// An outline on top of the fill. Off by default, since the fill alone
  /// separates a card from the page. Use it where the border carries meaning,
  /// such as an overdue task's danger tint.
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
