import 'package:flutter/material.dart';

/// Identité visuelle SemantiQ : « l'atelier du chercheur ».
///
/// Un fond papier chaud, une encre nuit, et un spectre de six couleurs
/// franches qui donnent à chaque entretien, chaque rubrique et chaque
/// locuteur sa propre teinte. Titres en DM Serif Display (élégance), texte
/// en Atkinson Hyperlegible Next (lisibilité).
abstract final class Palette {
  static const ink = Color(0xFF1D1838);
  static const paper = Color(0xFFFBF8F4);
  static const surface = Color(0xFFFFFFFF);
  static const muted = Color(0xFF6E6A85);
  static const rule = Color(0xFFECE6DD);
  static const danger = Color(0xFFE5484D);

  static const night = Color(0xFF121022);
  static const nightSurface = Color(0xFF1C1934);
  static const nightRaised = Color(0xFF25213F);
  static const mist = Color(0xFFF1EEFA);
  static const nightMuted = Color(0xFFA8A3C4);
  static const nightRule = Color(0xFF332E52);
  static const dangerBright = Color(0xFFFF8589);

  // Spectre
  static const violet = Color(0xFF6C4DF6);
  static const coral = Color(0xFFFF6B5B);
  static const sun = Color(0xFFFFB930);
  static const mint = Color(0xFF12B89A);
  static const sky = Color(0xFF3D9BFF);
  static const rose = Color(0xFFFF6FAE);

  /// Dégradé de la marque.
  static const brand = [violet, rose, coral];
}

const fontFamily = 'Atkinson';
const displayFamily = 'DMSerif';

/// Une couleur du spectre et ses déclinaisons.
@immutable
class Accent {
  const Accent(this.color, this.lightSoft, this.darkSoft, this.deep);

  /// Couleur franche (pastilles, icônes, barres).
  final Color color;
  final Color lightSoft;
  final Color darkSoft;

  /// Version foncée, lisible sur le fond doux.
  final Color deep;

  Color soft(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkSoft : lightSoft;

  Color onSoft(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? color : deep;

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color, Color.lerp(color, Colors.white, 0.25)!],
      );

  static const violet = Accent(
      Palette.violet, Color(0xFFECE7FF), Color(0xFF2E2560), Color(0xFF4A2FD0));
  static const coral = Accent(
      Palette.coral, Color(0xFFFFE6E2), Color(0xFF4A2421), Color(0xFFC23B2C));
  static const sun = Accent(
      Palette.sun, Color(0xFFFFF1D2), Color(0xFF473817), Color(0xFF946200));
  static const mint = Accent(
      Palette.mint, Color(0xFFD9F5EF), Color(0xFF143E38), Color(0xFF0A7A66));
  static const sky = Accent(
      Palette.sky, Color(0xFFDEEDFF), Color(0xFF17345A), Color(0xFF1C6CCB));
  static const rose = Accent(
      Palette.rose, Color(0xFFFFE3F0), Color(0xFF4A1F36), Color(0xFFC23779));

  static const all = [violet, coral, mint, sun, sky, rose];

  /// Teinte stable pour un identifiant (entretien, locuteur…).
  static Accent forKey(String key) {
    var h = 0;
    for (final c in key.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return all[h % all.length];
  }

  static Accent at(int i) => all[i % all.length];
}

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
    required this.backdrop,
    required this.danger,
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

  /// Taches de couleur du fond, très diluées.
  final List<Color> backdrop;
  final Color danger;

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
      backdrop: [
        for (var i = 0; i < backdrop.length; i++)
          l(backdrop[i], other.backdrop[i % other.backdrop.length]),
      ],
      danger: l(danger, other.danger),
    );
  }
}

ThemeData buildTheme(Brightness brightness) {
  final light = brightness == Brightness.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: Palette.violet,
    onPrimary: Colors.white,
    primaryContainer: light ? Accent.violet.lightSoft : Accent.violet.darkSoft,
    onPrimaryContainer: light ? Accent.violet.deep : Palette.mist,
    secondary: Palette.coral,
    onSecondary: Colors.white,
    secondaryContainer: light ? Accent.coral.lightSoft : Accent.coral.darkSoft,
    onSecondaryContainer: light ? Accent.coral.deep : Palette.mist,
    tertiary: Palette.mint,
    onTertiary: Colors.white,
    error: light ? Palette.danger : Palette.dangerBright,
    onError: light ? Colors.white : Palette.night,
    surface: light ? Palette.paper : Palette.night,
    onSurface: light ? Palette.ink : Palette.mist,
    onSurfaceVariant: light ? Palette.muted : Palette.nightMuted,
    surfaceContainerLowest: light ? Palette.surface : Palette.night,
    surfaceContainerLow: light ? Palette.surface : Palette.nightSurface,
    surfaceContainer: light ? Palette.surface : Palette.nightSurface,
    surfaceContainerHigh: light ? const Color(0xFFF5F0E8) : Palette.nightRaised,
    surfaceContainerHighest:
        light ? const Color(0xFFEFE9DF) : const Color(0xFF2E2A4C),
    outline: light ? const Color(0xFFCFC7BA) : const Color(0xFF59537E),
    outlineVariant: light ? Palette.rule : Palette.nightRule,
    inverseSurface: light ? Palette.ink : Palette.mist,
    onInverseSurface: light ? Colors.white : Palette.night,
  );

  final tones = Tones(
    marker: Palette.sun,
    markerSoft: light ? const Color(0xFFFFEBB0) : const Color(0xFF5A4614),
    onMarker: light ? Palette.ink : Palette.mist,
    link: Palette.mint,
    linkSoft: light ? Accent.mint.lightSoft : Accent.mint.darkSoft,
    muted: light ? Palette.muted : Palette.nightMuted,
    rule: light ? Palette.rule : Palette.nightRule,
    raised: light ? Palette.surface : Palette.nightSurface,
    backdrop: light
        ? const [Color(0x226C4DF6), Color(0x1FFF6FAE), Color(0x1A12B89A)]
        : const [Color(0x336C4DF6), Color(0x22FF6FAE), Color(0x1F12B89A)],
    danger: light ? Palette.danger : Palette.dangerBright,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: fontFamily,
    scaffoldBackgroundColor: scheme.surface,
    splashFactory: InkSparkle.splashFactory,
    extensions: [tones],
  );
  final text = base.textTheme;
  TextStyle? display(TextStyle? s, double size) => s?.copyWith(
        fontFamily: displayFamily,
        fontWeight: FontWeight.w400,
        fontSize: size,
        height: 1.1,
        letterSpacing: -0.2,
      );

  return base.copyWith(
    textTheme: text.copyWith(
      displaySmall: display(text.displaySmall, 38),
      headlineLarge: display(text.headlineLarge, 34),
      headlineMedium: display(text.headlineMedium, 30),
      headlineSmall: display(text.headlineSmall, 25),
      titleLarge: text.titleLarge
          ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.2),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      bodyLarge: text.bodyLarge?.copyWith(height: 1.5),
      bodyMedium: text.bodyMedium?.copyWith(height: 1.45),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
      },
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(
        fontFamily: displayFamily,
        fontWeight: FontWeight.w400,
        fontSize: 24,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      color: tones.raised,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: tones.rule),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(
            fontFamily: fontFamily, fontWeight: FontWeight.w800, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 50),
        side: BorderSide(color: tones.rule, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
            fontFamily: fontFamily, fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: const TextStyle(
            fontFamily: fontFamily, fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tones.raised,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: tones.rule),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: tones.rule),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Palette.violet, width: 2),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: tones.raised,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titleTextStyle: text.headlineSmall?.copyWith(
        fontFamily: displayFamily,
        fontSize: 24,
        color: scheme.onSurface,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: light ? Palette.paper : Palette.nightSurface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
    ),
    chipTheme: ChipThemeData(
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      labelStyle: const TextStyle(
          fontFamily: fontFamily, fontWeight: FontWeight.w700, fontSize: 14),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Palette.mint : null),
    ),
    dividerTheme: DividerThemeData(color: tones.rule, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: light ? Palette.ink : Palette.mist,
      contentTextStyle: TextStyle(
        fontFamily: fontFamily,
        fontWeight: FontWeight.w600,
        color: light ? Colors.white : Palette.night,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: Palette.violet),
  );
}
