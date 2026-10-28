import 'package:flutter/material.dart';

/// Identité visuelle SemantiQ.
///
/// Un parti pris : le geste du chercheur qui surligne ses verbatims. Encre
/// indigo sur papier crème, un jaune « surligneur » pour ce que l'analyse
/// fait ressortir, un vert d'eau pour les liens entre les mots.
/// Police : Atkinson Hyperlegible Next.
abstract final class Palette {
  static const ink = Color(0xFF231F45);
  static const paper = Color(0xFFF7F4EC);
  static const surface = Color(0xFFFFFFFF);
  static const slate = Color(0xFF615D78);
  static const rule = Color(0xFFE2DDD0);
  static const marker = Color(0xFFF3C93F);
  static const markerSoft = Color(0xFFFBEDB5);
  static const lagoon = Color(0xFF167A78);
  static const lagoonSoft = Color(0xFFD3EEEC);
  static const alert = Color(0xFFB3261E);

  static const night = Color(0xFF14122A);
  static const nightSurface = Color(0xFF1D1A38);
  static const nightRaised = Color(0xFF282449);
  static const mist = Color(0xFFECEAF5);
  static const nightSlate = Color(0xFFA9A5C2);
  static const nightRule = Color(0xFF38345C);
  static const markerBright = Color(0xFFFFD866);
  static const lagoonBright = Color(0xFF7FD6D2);
  static const alertBright = Color(0xFFFFB4AB);
}

const fontFamily = 'Atkinson';

/// Couleurs propres à l'app, absentes du ColorScheme Material.
@immutable
class Tones extends ThemeExtension<Tones> {
  const Tones({
    required this.marker,
    required this.markerSoft,
    required this.onMarker,
    required this.link,
    required this.linkSoft,
    required this.muted,
    required this.rule,
    required this.raised,
  });

  /// Surligneur : mots et phrases mis en avant par l'analyse.
  final Color marker;
  final Color markerSoft;
  final Color onMarker;

  /// Liens entre les mots (cooccurrences).
  final Color link;
  final Color linkSoft;
  final Color muted;
  final Color rule;
  final Color raised;

  static Tones of(BuildContext context) =>
      Theme.of(context).extension<Tones>()!;

  @override
  Tones copyWith() => this;

  @override
  Tones lerp(Tones? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return Tones(
      marker: l(marker, other.marker),
      markerSoft: l(markerSoft, other.markerSoft),
      onMarker: l(onMarker, other.onMarker),
      link: l(link, other.link),
      linkSoft: l(linkSoft, other.linkSoft),
      muted: l(muted, other.muted),
      rule: l(rule, other.rule),
      raised: l(raised, other.raised),
    );
  }
}

ThemeData buildTheme(Brightness brightness) {
  final light = brightness == Brightness.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: light ? Palette.ink : Palette.markerBright,
    onPrimary: light ? Colors.white : Palette.night,
    primaryContainer: light ? const Color(0xFFE4E1F3) : Palette.nightRaised,
    onPrimaryContainer: light ? Palette.ink : Palette.mist,
    secondary: light ? Palette.lagoon : Palette.lagoonBright,
    onSecondary: light ? Colors.white : Palette.night,
    secondaryContainer: light ? Palette.lagoonSoft : const Color(0xFF1B4746),
    onSecondaryContainer: light ? const Color(0xFF0B403F) : Palette.mist,
    tertiary: light ? const Color(0xFF8A6A00) : Palette.markerBright,
    onTertiary: light ? Colors.white : Palette.night,
    error: light ? Palette.alert : Palette.alertBright,
    onError: light ? Colors.white : Palette.night,
    surface: light ? Palette.paper : Palette.night,
    onSurface: light ? Palette.ink : Palette.mist,
    onSurfaceVariant: light ? Palette.slate : Palette.nightSlate,
    surfaceContainerLowest: light ? Palette.surface : Palette.night,
    surfaceContainerLow: light ? Palette.surface : Palette.nightSurface,
    surfaceContainer: light ? Palette.surface : Palette.nightSurface,
    surfaceContainerHigh: light ? const Color(0xFFF0ECE1) : Palette.nightRaised,
    surfaceContainerHighest:
        light ? const Color(0xFFE9E4D6) : const Color(0xFF322E57),
    outline: light ? const Color(0xFFA9A396) : const Color(0xFF6A6690),
    outlineVariant: light ? Palette.rule : Palette.nightRule,
    inverseSurface: light ? Palette.ink : Palette.mist,
    onInverseSurface: light ? Colors.white : Palette.night,
  );

  final tones = Tones(
    marker: light ? Palette.marker : Palette.markerBright,
    markerSoft: light ? Palette.markerSoft : const Color(0xFF4A3F12),
    onMarker: light ? Palette.ink : Palette.night,
    link: light ? Palette.lagoon : Palette.lagoonBright,
    linkSoft: light ? Palette.lagoonSoft : const Color(0xFF1B4746),
    muted: light ? Palette.slate : Palette.nightSlate,
    rule: light ? Palette.rule : Palette.nightRule,
    raised: light ? Palette.surface : Palette.nightSurface,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: fontFamily,
    scaffoldBackgroundColor: scheme.surface,
    extensions: [tones],
  );
  final text = base.textTheme;
  return base.copyWith(
    textTheme: text.copyWith(
      headlineMedium: text.headlineMedium
          ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      headlineSmall: text.headlineSmall
          ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      bodyLarge: text.bodyLarge?.copyWith(height: 1.45),
      bodyMedium: text.bodyMedium?.copyWith(height: 1.45),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w800,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      color: tones.raised,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: tones.rule),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
            fontFamily: fontFamily, fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tones.raised,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: tones.rule),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: tones.rule),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelStyle: const TextStyle(
          fontFamily: fontFamily, fontWeight: FontWeight.w700, fontSize: 15),
      unselectedLabelStyle: const TextStyle(
          fontFamily: fontFamily, fontWeight: FontWeight.w500, fontSize: 15),
      indicatorColor: tones.marker,
      dividerColor: tones.rule,
      tabAlignment: TabAlignment.start,
    ),
    dividerTheme: DividerThemeData(color: tones.rule, space: 1),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
