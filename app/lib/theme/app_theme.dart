import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// One visual language for the whole app: a flat, bordered "reading
/// room" — warm oat background, hairline-bordered paper tiles, one calm
/// accent (Forest) and one precious reward accent (Amber, reserved for
/// streaks/level-ups only). Every widget reads colors and text styles
/// from `Theme.of(context)`; nothing is hardcoded at the call site.
class AppTheme {
  AppTheme._();

  // Light — "reading room."
  static const _oat      = Color(0xFFF1EFE9); // app background
  static const _paper    = Color(0xFFF8F6F1); // bento tiles, raised
  static const _ink      = Color(0xFF1E2420); // primary text
  static const _inkMuted = Color(0xFF5B645C); // secondary text/labels
  static const _hairline = Color(0xFFDAD6CC); // 1px dividers/borders
  static const _forest   = Color(0xFF2C4A3D); // calm accent: actions, positive
  static const _amber    = Color(0xFFC6742F); // reward accent: streaks/level-ups ONLY

  // Dark — structured for a later drop-in; same roles, inverted ground.
  static const _oatDark      = Color(0xFF1B1E1A);
  static const _paperDark    = Color(0xFF232722);
  static const _inkDark      = Color(0xFFEDEBE4);
  static const _inkMutedDark = Color(0xFF9CA39B);
  static const _hairlineDark = Color(0xFF383D37);
  static const _forestDark   = Color(0xFF7CA697);
  static const _amberDark    = Color(0xFFE0975C);

  /// Minimum height for anything tappable. Larger than Material's 48 on
  /// purpose: one-handed, in a hurry.
  static const tapTarget = 56.0;

  /// The two sanctioned corner radii. Nothing else.
  static const radiusTile = 16.0;
  static const radiusControl = 10.0;

  /// The spacing scale. No arbitrary paddings — always one of these six.
  static const space4 = 4.0;
  static const space8 = 8.0;
  static const space12 = 12.0;
  static const space16 = 16.0;
  static const space24 = 24.0;
  static const space32 = 32.0;

  /// Outer page margin. Alias of [space24] — kept as its own name since
  /// it's used at nearly every screen edge.
  static const gutter = space24;

  /// Content never exceeds this. Without it the layout stretches to the
  /// window width on web and desktop and reads as empty.
  static const maxContentWidth = 560.0;

  static const motion = Duration(milliseconds: 180);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final isLight = b == Brightness.light;

    final oat = isLight ? _oat : _oatDark;
    final paper = isLight ? _paper : _paperDark;
    final ink = isLight ? _ink : _inkDark;
    final inkMuted = isLight ? _inkMuted : _inkMutedDark;
    final hairline = isLight ? _hairline : _hairlineDark;
    final forest = isLight ? _forest : _forestDark;
    final amber = isLight ? _amber : _amberDark;

    // Material still needs an `error` role internally (form field error
    // borders, etc). Per the "no red anywhere" rule this maps to Ink,
    // not a third hue — a validation message reads as an attention cue,
    // not a failure state.
    final scheme = ColorScheme(
      brightness: b,
      primary: forest,
      onPrimary: paper,
      primaryContainer: isLight ? const Color(0xFFDCE6E0) : const Color(0xFF2E4238),
      onPrimaryContainer: ink,
      secondary: inkMuted,
      onSecondary: paper,
      error: ink,
      onError: paper,
      surface: oat,
      onSurface: ink,
      surfaceContainerHighest: paper,
      surfaceContainerHigh: paper,
      onSurfaceVariant: inkMuted,
      outlineVariant: hairline,
      outline: hairline,
    );

    // Tabular figures everywhere a number might land (streak, accuracy %,
    // reps, the weekly grid, target score) so digits don't jitter as they
    // change. A no-op on non-numeric text, so it's safe to apply to every
    // style rather than tracking down each numeric call site.
    const numerals = [FontFeature.tabularFigures()];

    final textTheme = TextTheme(
      // display — the one big number per screen (streak, score). Set
      // heavier and larger than a default hero would be, with the tight
      // tracking/line-height serif display sizes need or they read as
      // loose and accidental rather than deliberately set.
      displayLarge: GoogleFonts.fraunces(
        fontSize: 40, fontWeight: FontWeight.w700, height: 1.08,
        letterSpacing: -1.2, color: ink, fontFeatures: numerals),
      displayMedium: GoogleFonts.fraunces(
        fontSize: 40, fontWeight: FontWeight.w700, height: 1.08,
        letterSpacing: -1.2, color: ink, fontFeatures: numerals),
      displaySmall: GoogleFonts.fraunces(
        fontSize: 40, fontWeight: FontWeight.w700, height: 1.08,
        letterSpacing: -1.2, color: ink, fontFeatures: numerals),
      // headline — screen titles, section-defining moments. A clear step
      // down from display in both size and weight, still confident.
      headlineLarge: GoogleFonts.fraunces(
        fontSize: 28, fontWeight: FontWeight.w600, height: 1.15,
        letterSpacing: -0.5, color: ink, fontFeatures: numerals),
      headlineMedium: GoogleFonts.fraunces(
        fontSize: 28, fontWeight: FontWeight.w600, height: 1.15,
        letterSpacing: -0.5, color: ink, fontFeatures: numerals),
      headlineSmall: GoogleFonts.fraunces(
        fontSize: 28, fontWeight: FontWeight.w600, height: 1.15,
        letterSpacing: -0.5, color: ink, fontFeatures: numerals),
      // title — tile headings.
      titleLarge: GoogleFonts.inter(
        fontSize: 18, fontWeight: FontWeight.w600, height: 1.3,
        color: ink, fontFeatures: numerals),
      titleMedium: GoogleFonts.inter(
        fontSize: 18, fontWeight: FontWeight.w600, height: 1.3,
        color: ink, fontFeatures: numerals),
      titleSmall: GoogleFonts.inter(
        fontSize: 18, fontWeight: FontWeight.w600, height: 1.3,
        color: ink, fontFeatures: numerals),
      // body — default text, comfortable line-height, normal spacing.
      // bodyMedium is the same step recolored to Ink-muted for secondary/
      // supporting lines — never invent a lighter gray at the call site.
      bodyLarge: GoogleFonts.inter(
        fontSize: 15, fontWeight: FontWeight.w400, height: 1.5,
        color: ink, fontFeatures: numerals),
      bodyMedium: GoogleFonts.inter(
        fontSize: 15, fontWeight: FontWeight.w400, height: 1.5,
        color: inkMuted, fontFeatures: numerals),
      bodySmall: GoogleFonts.inter(
        fontSize: 15, fontWeight: FontWeight.w400, height: 1.5,
        color: ink, fontFeatures: numerals),
      // label — metadata, captions, tile labels. Smaller than body with
      // positive tracking, so an uppercase label like "HOW YOU'RE DOING"
      // reads as a quiet caption instead of a shout.
      labelMedium: GoogleFonts.inter(
        fontSize: 12, fontWeight: FontWeight.w500, height: 1.3,
        letterSpacing: 0.8, color: inkMuted, fontFeatures: numerals),
      labelSmall: GoogleFonts.inter(
        fontSize: 12, fontWeight: FontWeight.w500, height: 1.3,
        letterSpacing: 0.8, color: inkMuted, fontFeatures: numerals),
      // button — labelLarge is Material's default button text slot.
      labelLarge: GoogleFonts.inter(
        fontSize: 15, fontWeight: FontWeight.w600, height: 1.2,
        color: ink, fontFeatures: numerals),
    );

    final outlineBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusControl),
      borderSide: BorderSide(color: hairline),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      dividerColor: hairline,
      textTheme: textTheme,
      extensions: [
        AppTokens(amber: amber),
      ],
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size.fromHeight(tapTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusControl),
          ),
          textStyle: textTheme.labelLarge?.copyWith(color: scheme.onPrimary),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: hairline),
          minimumSize: const Size.fromHeight(tapTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusControl),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(0, tapTarget),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusControl),
          ),
          textStyle: textTheme.labelLarge?.copyWith(color: scheme.primary),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: paper,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: space16, vertical: space16),
        border: outlineBorder,
        enabledBorder: outlineBorder,
        focusedBorder: outlineBorder.copyWith(
          borderSide: BorderSide(color: forest, width: 1.5),
        ),
        errorBorder: outlineBorder.copyWith(
          borderSide: BorderSide(color: ink),
        ),
        focusedErrorBorder: outlineBorder.copyWith(
          borderSide: BorderSide(color: ink, width: 1.5),
        ),
        labelStyle: textTheme.bodyLarge?.copyWith(color: inkMuted),
        hintStyle: textTheme.bodyLarge?.copyWith(color: inkMuted),
        errorStyle: textTheme.labelMedium?.copyWith(color: ink),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: paper,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: hairline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusControl),
        ),
        labelStyle: textTheme.labelLarge?.copyWith(color: ink),
        padding: const EdgeInsets.symmetric(
          horizontal: space12, vertical: space8),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: hairline,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
        valueIndicatorColor: scheme.primary,
        valueIndicatorTextStyle: textTheme.labelLarge?.copyWith(color: paper),
      ),
    );
  }
}

/// Custom design tokens that don't fit a standard [ColorScheme]/[TextTheme]
/// slot. Kept deliberately small and explicit — [amber] is exposed only
/// here, not wired into any component theme, so it can never leak onto a
/// default Material widget. Reference it directly only where the design
/// spec says amber belongs: the streak hero number and earned badges.
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({required this.amber});

  final Color amber;

  @override
  AppTokens copyWith({Color? amber}) => AppTokens(amber: amber ?? this.amber);

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(amber: Color.lerp(amber, other.amber, t) ?? amber);
  }
}

/// Centres and width-limits page content. Wrap every screen body in this
/// or the layout stretches on web.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: AppTheme.maxContentWidth),
          child: child,
        ),
      );
}
