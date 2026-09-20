// app_theme.dart
//
// Palette extracted from the blueebeettle.in stylesheet, mapped to Material 3.
//
// FROM THE SITE (verbatim):
//   #FAF3F0  body background        warm cream
//   #590D86  headings, tagline, button label, shadow
//   #661694  button outline
//   #40128B  warning bar background
//   #BA7DD6  "about" band background
//   black / white  text
//   Raleway (body) + Bricolage Grotesque (display)
//
// ADDED (the site defines none of these, an app needs all of them):
//   neutrals, borders, muted text, semantic states, chart series, heatmap ramp,
//   and an entire dark theme.
//
// CONTRAST (WCAG AA needs 4.5:1 for body text, 3:1 for large text and UI edges):
//   #590D86 on #FAF3F0 ....... 10.48:1   safe anywhere
//   #40128B on #FAF3F0 ....... 11.41:1   safe anywhere
//   #661694 on #FAF3F0 ........ 9.08:1   safe anywhere
//   #BA7DD6 on #FAF3F0 ........ 2.74:1   FILL ONLY — never text or thin marks
//   black   on #BA7DD6 ........ 6.99:1   the site's own usage, fine
//   white   on #590D86 ....... 11.50:1   safe
//
// The one trap: #590D86 scores 1.61:1 on a dark ground, so the brand purple
// CANNOT carry over into dark mode. Dark mode leads with a lightened purple
// (#C08FE8, 7.35:1) and demotes #40128B to a container fill.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Raw palette
// ─────────────────────────────────────────────────────────────────────────────

abstract final class BrandColors {
  // From the site
  static const cream = Color(0xFFFAF3F0);
  static const purple = Color(0xFF590D86);
  static const purpleOutline = Color(0xFF661694);
  static const violetDeep = Color(0xFF40128B);
  static const lavender = Color(0xFFBA7DD6);

  // Derived light neutrals — warm, biased toward the purple so they read as
  // chosen rather than inherited grey.
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceLow = Color(0xFFF2E7E2);
  static const lightSurfaceHigh = Color(0xFFFBF7F5);
  static const lightLine = Color(0xFFE2D3D6);
  static const lightLineSoft = Color(0xFFEFE3E0);
  static const lightText = Color(0xFF17101F); // 16.94:1
  static const lightTextSecondary = Color(0xFF4A3B55); //  9.35:1
  static const lightTextMuted = Color(0xFF7A6885); //  4.62:1
  static const lavenderTint = Color(0xFFEDDCF5); // chip / container fill

  // Derived dark theme — no equivalent on the site.
  static const darkGround = Color(0xFF17111C);
  static const darkSurface = Color(0xFF201829);
  static const darkSurfaceHigh = Color(0xFF2A2035);
  static const darkLine = Color(0xFF3A2E47);
  static const darkLineSoft = Color(0xFF2C2237);
  static const darkPurple = Color(0xFFC08FE8); // 7.35:1 — the dark-mode lead
  static const darkText = Color(0xFFF3EBF0); // 15.84:1
  static const darkTextSecondary = Color(0xFFC4B6CE); //  9.64:1
  static const darkTextMuted = Color(0xFF9385A0); //  5.38:1
}

// ─────────────────────────────────────────────────────────────────────────────
// App-specific tokens Material 3 has no slot for
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.success,
    required this.warning,
    required this.danger,
    required this.textSecondary,
    required this.textMuted,
    required this.lineSoft,
    required this.series,
    required this.heatmap,
  });

  /// Reserved for state. Never use these decoratively — the moment green means
  /// "a category" as well as "good", every stats screen becomes unreadable.
  final Color success;
  final Color warning;
  final Color danger;

  final Color textSecondary;
  final Color textMuted;
  final Color lineSoft;

  /// Six categorical chart series, purple-led, roughly constant in perceived
  /// lightness so no single series shouts.
  final List<Color> series;

  /// Sequential ramp for the contribution heatmap, empty → maximum.
  final List<Color> heatmap;

  static const light = AppTokens(
    success: Color(0xFF1B6E51), // 5.64:1 on cream
    warning: Color(0xFF9A620F), // 4.64:1 on cream
    danger: Color(0xFFB3261E), // 5.96:1 on cream
    textSecondary: BrandColors.lightTextSecondary,
    textMuted: BrandColors.lightTextMuted,
    lineSoft: BrandColors.lightLineSoft,
    series: [
      Color(0xFF590D86), // brand purple
      Color(0xFF2B62A8), // blue
      Color(0xFF157F73), // teal
      Color(0xFF9A620F), // amber
      Color(0xFFB03A5B), // rose
      Color(0xFF6B7A2E), // olive
    ],
    heatmap: [
      Color(0xFFEDE3DE), // empty — a shade under the ground so cells read
      Color(0xFFE0C9F0),
      Color(0xFFC194DF),
      Color(0xFF8B3FAE),
      Color(0xFF590D86), // maximum
    ],
  );

  static const dark = AppTokens(
    success: Color(0xFF5FD3A6), // 10.02:1 on the dark ground
    warning: Color(0xFFE8B54D), //  9.84:1
    danger: Color(0xFFF08A80), //  7.63:1
    textSecondary: BrandColors.darkTextSecondary,
    textMuted: BrandColors.darkTextMuted,
    lineSoft: BrandColors.darkLineSoft,
    series: [
      Color(0xFFC08FE8),
      Color(0xFF7FB3F0),
      Color(0xFF5FD3BE),
      Color(0xFFE8B54D),
      Color(0xFFF090A8),
      Color(0xFFB9CC72),
    ],
    heatmap: [
      Color(0xFF241C2E),
      Color(0xFF3A1F5C),
      Color(0xFF55238A),
      Color(0xFF7B45B5),
      Color(0xFFC08FE8),
    ],
  );

  @override
  AppTokens copyWith({
    Color? success,
    Color? warning,
    Color? danger,
    Color? textSecondary,
    Color? textMuted,
    Color? lineSoft,
    List<Color>? series,
    List<Color>? heatmap,
  }) {
    return AppTokens(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      lineSoft: lineSoft ?? this.lineSoft,
      series: series ?? this.series,
      heatmap: heatmap ?? this.heatmap,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    List<Color> lerpList(List<Color> a, List<Color> b) => [
          for (var i = 0; i < a.length; i++) Color.lerp(a[i], b[i], t)!,
        ];
    return AppTokens(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      lineSoft: Color.lerp(lineSoft, other.lineSoft, t)!,
      series: lerpList(series, other.series),
      heatmap: lerpList(heatmap, other.heatmap),
    );
  }
}

/// `context.tokens.success` instead of the full lookup every time.
extension AppTokensX on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
  ColorScheme get colors => Theme.of(this).colorScheme;
}

// ─────────────────────────────────────────────────────────────────────────────
// Colour schemes
// ─────────────────────────────────────────────────────────────────────────────

const _lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: BrandColors.purple,
  onPrimary: Colors.white,
  primaryContainer: BrandColors.lavenderTint,
  onPrimaryContainer: BrandColors.violetDeep,
  secondary: BrandColors.lavender,
  onSecondary: Color(0xFF1A0A22),
  secondaryContainer: BrandColors.lavenderTint,
  onSecondaryContainer: BrandColors.violetDeep,
  tertiary: BrandColors.violetDeep,
  onTertiary: Colors.white,
  tertiaryContainer: Color(0xFFDCCCF2),
  onTertiaryContainer: BrandColors.violetDeep,
  error: Color(0xFFB3261E),
  onError: Colors.white,
  errorContainer: Color(0xFFF9DEDC),
  onErrorContainer: Color(0xFF690005),
  surface: BrandColors.cream,
  onSurface: BrandColors.lightText,
  surfaceDim: Color(0xFFE9DDD8),
  surfaceBright: Color(0xFFFFFBF9),
  surfaceContainerLowest: BrandColors.lightSurface,
  surfaceContainerLow: BrandColors.lightSurfaceHigh,
  surfaceContainer: Color(0xFFF6ECE8),
  surfaceContainerHigh: BrandColors.lightSurfaceLow,
  surfaceContainerHighest: Color(0xFFEDE0DA),
  onSurfaceVariant: BrandColors.lightTextSecondary,
  outline: BrandColors.lightLine,
  outlineVariant: BrandColors.lightLineSoft,
  shadow: BrandColors.purple, // the site's own lifted-button shadow colour
  scrim: Color(0xFF000000),
  inverseSurface: Color(0xFF2E2233),
  onInverseSurface: BrandColors.cream,
  inversePrimary: BrandColors.darkPurple,
);

const _darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: BrandColors.darkPurple,
  onPrimary: Color(0xFF230A38),
  primaryContainer: BrandColors.violetDeep, // #40128B finally earns its keep
  onPrimaryContainer: Color(0xFFEBDCF7),
  secondary: BrandColors.lavender,
  onSecondary: Color(0xFF230A38),
  secondaryContainer: Color(0xFF3D2354),
  onSecondaryContainer: Color(0xFFE8D6F3),
  tertiary: Color(0xFFA789E8),
  onTertiary: Color(0xFF1E0B3A),
  tertiaryContainer: Color(0xFF33176B),
  onTertiaryContainer: Color(0xFFE2D8F8),
  error: Color(0xFFF08A80),
  onError: Color(0xFF3F0A07),
  errorContainer: Color(0xFF6E2018),
  onErrorContainer: Color(0xFFFBDAD6),
  surface: BrandColors.darkGround,
  onSurface: BrandColors.darkText,
  surfaceDim: Color(0xFF120D17),
  surfaceBright: Color(0xFF322838),
  surfaceContainerLowest: Color(0xFF120D17),
  surfaceContainerLow: Color(0xFF1C1522),
  surfaceContainer: BrandColors.darkSurface,
  surfaceContainerHigh: BrandColors.darkSurfaceHigh,
  surfaceContainerHighest: Color(0xFF352A41),
  onSurfaceVariant: BrandColors.darkTextSecondary,
  outline: BrandColors.darkLine,
  outlineVariant: BrandColors.darkLineSoft,
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
  inverseSurface: BrandColors.cream,
  onInverseSurface: BrandColors.lightText,
  inversePrimary: BrandColors.purple,
);

// ─────────────────────────────────────────────────────────────────────────────
// Typography — Bricolage Grotesque for display, Raleway for everything else
// ─────────────────────────────────────────────────────────────────────────────

TextTheme _textTheme(ColorScheme scheme) {
  final display = GoogleFonts.bricolageGrotesqueTextTheme();
  final body = GoogleFonts.ralewayTextTheme();

  // Stats screens live or die on aligned digits.
  const tabular = [FontFeature.tabularFigures()];

  return TextTheme(
    displayLarge: display.displayLarge?.copyWith(
        fontWeight: FontWeight.w700, letterSpacing: -0.5, height: 1.08),
    displayMedium: display.displayMedium
        ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4),
    displaySmall:
        display.displaySmall?.copyWith(fontWeight: FontWeight.w600),
    headlineLarge: display.headlineLarge
        ?.copyWith(fontWeight: FontWeight.w600, height: 1.15),
    headlineMedium:
        display.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
    headlineSmall:
        display.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
    titleLarge: body.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    titleMedium: body.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    titleSmall: body.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    bodyLarge: body.bodyLarge?.copyWith(height: 1.55),
    bodyMedium: body.bodyMedium?.copyWith(height: 1.55),
    bodySmall: body.bodySmall?.copyWith(height: 1.45),
    labelLarge: body.labelLarge
        ?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.3),
    labelMedium: body.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        fontFeatures: tabular),
    labelSmall: body.labelSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 1.0,
        fontFeatures: tabular),
  ).apply(
    bodyColor: scheme.onSurface,
    // Material 3 puts headings on onSurface, not on the brand colour. The
    // purple stays where it earns attention — the app bar title, active
    // controls, figures that are the point of a screen. Twenty purple headings
    // on one screen is what made the stats pages shout.
    displayColor: scheme.onSurface,
  );
}

/// Big numbers on stat tiles — display face, tabular figures, never wrapping.
TextStyle statFigure(BuildContext context) =>
    GoogleFonts.bricolageGrotesque(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      height: 1.05,
      letterSpacing: -0.5,
      color: context.colors.onSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

// ─────────────────────────────────────────────────────────────────────────────
// Themes
// ─────────────────────────────────────────────────────────────────────────────

ThemeData _build(ColorScheme scheme, AppTokens tokens) {
  final text = _textTheme(scheme);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: text,
    extensions: [tokens],
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      foregroundColor: scheme.primary,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: text.headlineSmall?.copyWith(color: scheme.primary),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),

    // ── Buttons ─────────────────────────────────────────────────────────
    // Material 3 buttons are stadium-shaped with a 40dp minimum height.
    // The site's 3px-outlined 10px-radius button was a web button; it is
    // replaced here because the app follows Material, not the marketing page.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: const StadiumBorder(),
        minimumSize: const Size(64, 44),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        textStyle: text.labelLarge,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: const StadiumBorder(),
        minimumSize: const Size(64, 44),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        backgroundColor: scheme.surfaceContainerLow,
        foregroundColor: scheme.primary,
        elevation: 1,
        textStyle: text.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.primary,
        side: BorderSide(color: scheme.outline),
        shape: const StadiumBorder(),
        minimumSize: const Size(64, 44),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        textStyle: text.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        shape: const StadiumBorder(),
        minimumSize: const Size(48, 44),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        textStyle: text.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: scheme.onSurfaceVariant,
        minimumSize: const Size(44, 44),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        side: BorderSide(color: scheme.outline),
        shape: const StadiumBorder(),
        selectedBackgroundColor: scheme.secondaryContainer,
        selectedForegroundColor: scheme.onSecondaryContainer,
        foregroundColor: scheme.onSurface,
        minimumSize: const Size(48, 40),
        textStyle: text.labelLarge,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      elevation: 3,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),

    // ── Containers ──────────────────────────────────────────────────────
    // M3 shape scale: xs 4, sm 8, md 12, lg 16, xl 28.
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(28)),
      ),
      titleTextStyle: text.headlineSmall?.copyWith(color: scheme.onSurface),
      contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: scheme.onSurfaceVariant,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      iconColor: scheme.onSurfaceVariant,
      titleTextStyle: text.bodyLarge,
      subtitleTextStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
    ),

    // ── Chips ───────────────────────────────────────────────────────────
    chipTheme: ChipThemeData(
      backgroundColor: Colors.transparent,
      selectedColor: scheme.secondaryContainer,
      side: BorderSide(color: scheme.outline),
      labelStyle: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
      secondaryLabelStyle:
          text.labelLarge?.copyWith(color: scheme.onSecondaryContainer),
      checkmarkColor: scheme.onSecondaryContainer,
      showCheckmark: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),

    // ── Input ───────────────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: scheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      labelStyle: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
    ),

    // ── Navigation ──────────────────────────────────────────────────────
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainer,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.secondaryContainer,
      indicatorShape: const StadiumBorder(),
      elevation: 0,
      height: 76,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => text.labelMedium?.copyWith(
          color: states.contains(WidgetState.selected)
              ? scheme.onSurface
              : scheme.onSurfaceVariant,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 24,
          color: states.contains(WidgetState.selected)
              ? scheme.onSecondaryContainer
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: scheme.primary,
      unselectedLabelColor: scheme.onSurfaceVariant,
      indicatorColor: scheme.primary,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: scheme.outlineVariant,
      labelStyle: text.titleSmall,
    ),

    // ── Feedback ────────────────────────────────────────────────────────
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
      circularTrackColor: scheme.surfaceContainerHighest,
      linearMinHeight: 4,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.inverseSurface,
      contentTextStyle:
          text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
      actionTextColor: scheme.inversePrimary,
      behavior: SnackBarBehavior.floating,
      elevation: 3,
      // M3 snackbars use the extra-small shape, not a pill.
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(4)),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(4),
      ),
      textStyle: text.bodySmall?.copyWith(color: scheme.onInverseSurface),
    ),

    // ── Selection controls ──────────────────────────────────────────────
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.outline),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.surfaceContainerHighest),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? Colors.transparent
              : scheme.outline),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      side: BorderSide(color: scheme.onSurfaceVariant, width: 2),
      fillColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? scheme.primary
              : Colors.transparent),
      checkColor: WidgetStatePropertyAll(scheme.onPrimary),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: scheme.primary,
      inactiveTrackColor: scheme.surfaceContainerHighest,
      thumbColor: scheme.primary,
      overlayColor: scheme.primary.withValues(alpha: 0.12),
    ),
  );
}

abstract final class AppTheme {
  static ThemeData get light => _build(_lightScheme, AppTokens.light);
  static ThemeData get dark => _build(_darkScheme, AppTokens.dark);
}

// Usage:
//   MaterialApp(
//     theme: AppTheme.light,
//     darkTheme: AppTheme.dark,
//     themeMode: ThemeMode.system,
//   )
//
// pubspec.yaml:
//   dependencies:
//     google_fonts: ^6.2.1
