import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Illustrations de l'app, dessinées en code : nettes à toutes les tailles,
/// adaptées au thème clair et sombre, sans fichier image à charger.

// --- Outils -------------------------------------------------------------------

/// Bulle de dialogue : rectangle arrondi et sa pointe, en bas à gauche ou
/// à droite.
Path bubblePath(Rect r, {double radius = 18, bool tailLeft = true}) {
  final body = Path()
    ..addRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)));
  final w = r.width;
  final h = r.height;
  // Pointe dessinée côté gauche, puis retournée si besoin.
  final a = Offset(w * 0.16, h - 2);
  final tip = Offset(w * 0.08, h + h * 0.24);
  final b = Offset(w * 0.36, h - 2);
  Offset place(Offset o) =>
      tailLeft ? r.topLeft + o : Offset(r.right - o.dx, r.top + o.dy);
  final tail = Path()
    ..moveTo(place(a).dx, place(a).dy)
    ..quadraticBezierTo(place(Offset(w * 0.17, h + h * 0.12)).dx,
        place(Offset(w * 0.17, h + h * 0.12)).dy, place(tip).dx, place(tip).dy)
    ..quadraticBezierTo(place(Offset(w * 0.26, h + h * 0.1)).dx,
        place(Offset(w * 0.26, h + h * 0.1)).dy, place(b).dx, place(b).dy)
    ..close();
  return Path.combine(PathOperation.union, body, tail);
}

/// Étoile à quatre branches (étincelle).
Path sparklePath(Offset c, double r) {
  final p = Path()..moveTo(c.dx, c.dy - r);
  const k = 0.22;
  p
    ..quadraticBezierTo(c.dx + r * k, c.dy - r * k, c.dx + r, c.dy)
    ..quadraticBezierTo(c.dx + r * k, c.dy + r * k, c.dx, c.dy + r)
    ..quadraticBezierTo(c.dx - r * k, c.dy + r * k, c.dx - r, c.dy)
    ..quadraticBezierTo(c.dx - r * k, c.dy - r * k, c.dx, c.dy - r)
    ..close();
  return p;
}

/// Barres d'une onde sonore, centrées verticalement dans [r].
void paintWave(
  Canvas canvas,
  Rect r, {
  required int bars,
  required double t,
  required Color color,
  double minFactor = 0.25,
  List<Color>? colors,
}) {
  final gap = r.width / (bars * 2 - 1);
  for (var i = 0; i < bars; i++) {
    final phase = i * 0.9 + t * 2 * math.pi;
    final base = 0.5 + 0.5 * math.sin(i * 1.7 + 0.6);
    final h = r.height *
        (minFactor + (1 - minFactor) * (0.55 * base + 0.45 * (0.5 + 0.5 * math.sin(phase))));
    final x = r.left + i * 2 * gap;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, r.center.dy - h / 2, gap, h),
        Radius.circular(gap / 2),
      ),
      Paint()..color = colors == null ? color : colors[i % colors.length],
    );
  }
}

/// Anime en boucle un dessin dépendant de t ∈ [0, 1[. Immobile quand
/// l'utilisateur a demandé de réduire les animations.
class LoopingArt extends StatefulWidget {
  const LoopingArt({
    super.key,
    required this.painter,
    this.period = const Duration(seconds: 6),
    this.size,
  });

  final CustomPainter Function(double t, BuildContext context) painter;
  final Duration period;
  final Size? size;

  @override
  State<LoopingArt> createState() => _LoopingArtState();
}

class _LoopingArtState extends State<LoopingArt>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          size: widget.size ?? Size.infinite,
          painter: widget.painter(_c.value, context),
        ),
      ),
    );
  }
}

// --- Fond ---------------------------------------------------------------------

/// Taches de couleur floues derrière le contenu d'un écran.
class Backdrop extends StatelessWidget {
  const Backdrop({super.key, required this.child, this.variant = 0});

  final Widget child;

  /// Change la disposition des taches d'un écran à l'autre.
  final int variant;

  @override
  Widget build(BuildContext context) {
    final tones = Tones.of(context);
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _BackdropPainter(tones.backdrop, variant),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.colors, this.variant);

  final List<Color> colors;
  final int variant;

  @override
  void paint(Canvas canvas, Size size) {
    final spots = switch (variant % 3) {
      0 => const [(0.95, 0.02, 0.75), (-0.1, 0.35, 0.6), (0.8, 0.9, 0.7)],
      1 => const [(0.05, 0.0, 0.7), (1.05, 0.45, 0.6), (0.3, 1.0, 0.7)],
      _ => const [(0.5, -0.1, 0.8), (1.0, 0.7, 0.55), (-0.1, 0.8, 0.6)],
    };
    for (var i = 0; i < spots.length; i++) {
      final (x, y, r) = spots[i];
      final c = Offset(x * size.width, y * size.height);
      final radius = r * size.width;
      canvas.drawCircle(
        c,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [colors[i % colors.length], colors[i % colors.length].withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: c, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter old) =>
      old.colors != colors || old.variant != variant;
}

// --- Illustration d'accueil ---------------------------------------------------

/// Deux bulles de dialogue, une onde sonore et des étincelles : la parole
/// qui devient matière à analyser.
class HeroArt extends StatelessWidget {
  const HeroArt({super.key, this.size = const Size(170, 140)});

  final Size size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.fromSize(
      size: size,
      child: LoopingArt(
        period: const Duration(seconds: 5),
        painter: (t, context) => _HeroPainter(
          t,
          Theme.of(context).brightness == Brightness.dark,
        ),
      ),
    );
  }
}

class _HeroPainter extends CustomPainter {
  _HeroPainter(this.t, this.dark);

  final double t;
  final bool dark;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final bob = math.sin(t * 2 * math.pi);
    final bob2 = math.sin(t * 2 * math.pi + 1.8);

    // Soleil
    canvas.drawCircle(Offset(w * 0.14, h * 0.2 + bob2 * 3), w * 0.075,
        Paint()..color = Palette.sun);

    // Grande bulle (dégradé violet → rose) et son onde
    final big = Rect.fromLTWH(w * 0.06, h * 0.3 + bob * 3, w * 0.62, h * 0.44);
    final bigPath = bubblePath(big, radius: w * 0.09);
    canvas.drawShadow(bigPath, Palette.violet.withValues(alpha: 0.6), 8, false);
    canvas.drawPath(
      bigPath,
      Paint()
        ..shader = const LinearGradient(
          colors: [Palette.violet, Palette.rose],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(big),
    );
    paintWave(
      canvas,
      Rect.fromCenter(
          center: big.center, width: big.width * 0.56, height: big.height * 0.52),
      bars: 7,
      t: t,
      color: Colors.white,
    );

    // Petite bulle corail, à droite, avec trois points
    final small =
        Rect.fromLTWH(w * 0.58, h * 0.08 - bob * 2.5, w * 0.36, h * 0.28);
    final smallPath = bubblePath(small, radius: w * 0.07, tailLeft: false);
    canvas.drawShadow(smallPath, Palette.coral.withValues(alpha: 0.6), 6, false);
    canvas.drawPath(smallPath, Paint()..color = Palette.coral);
    for (var i = 0; i < 3; i++) {
      final p = (math.sin(t * 2 * math.pi * 2 - i * 0.9) + 1) / 2;
      canvas.drawCircle(
        Offset(small.left + small.width * (0.28 + i * 0.22), small.center.dy),
        small.height * (0.08 + 0.04 * p),
        Paint()..color = Colors.white.withValues(alpha: 0.6 + 0.4 * p),
      );
    }

    // Étiquette de mot (menthe) en bas à droite
    final chip = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.62, h * 0.74 + bob2 * 2, w * 0.32, h * 0.13),
      Radius.circular(h * 0.065),
    );
    canvas.drawRRect(chip, Paint()..color = Palette.mint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(chip.left + chip.width * 0.16, chip.center.dy - 2.5,
            chip.width * 0.5, 5),
        const Radius.circular(3),
      ),
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(Offset(chip.right - chip.width * 0.17, chip.center.dy),
        3.5, Paint()..color = Colors.white);

    // Étincelles
    final twinkle = (math.sin(t * 2 * math.pi * 2) + 1) / 2;
    canvas.drawPath(sparklePath(Offset(w * 0.5, h * 0.14), 6 + 3 * twinkle),
        Paint()..color = Palette.sky);
    canvas.drawPath(
        sparklePath(Offset(w * 0.9, h * 0.52), 4 + 3 * (1 - twinkle)),
        Paint()..color = Palette.sun);
    canvas.drawPath(
        sparklePath(Offset(w * 0.1, h * 0.9), 4 + 2 * twinkle),
        Paint()..color = Palette.mint);
  }

  @override
  bool shouldRepaint(covariant _HeroPainter old) =>
      old.t != t || old.dark != dark;
}

// --- Vignettes d'action -------------------------------------------------------

enum TileArtKind { audio, paste, sample, empty }

/// Petite illustration blanche, posée sur une tuile colorée.
class TileArt extends StatelessWidget {
  const TileArt(this.kind, {super.key, this.size = 64});

  final TileArtKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _TilePainter(kind)),
    );
  }
}

class _TilePainter extends CustomPainter {
  _TilePainter(this.kind);

  final TileArtKind kind;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final white = Paint()..color = Colors.white;
    final soft = Paint()..color = Colors.white.withValues(alpha: 0.35);
    switch (kind) {
      case TileArtKind.audio:
        canvas.drawCircle(s.center(Offset.zero), w * 0.48, soft);
        canvas.drawCircle(s.center(Offset.zero), w * 0.34,
            Paint()..color = Colors.white.withValues(alpha: 0.5));
        paintWave(
          canvas,
          Rect.fromCenter(
              center: s.center(Offset.zero), width: w * 0.46, height: w * 0.36),
          bars: 5,
          t: 0.15,
          color: Colors.white,
          minFactor: 0.35,
        );
      case TileArtKind.paste:
        final page = RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.18, w * 0.08, w * 0.64, w * 0.84),
          Radius.circular(w * 0.1),
        );
        canvas.drawRRect(page.shift(Offset(w * 0.06, w * 0.04)), soft);
        canvas.drawRRect(page, white);
        final ink = Paint()..color = Palette.ink.withValues(alpha: 0.18);
        for (var i = 0; i < 4; i++) {
          final y = w * (0.26 + i * 0.16);
          final len = i == 3 ? 0.3 : 0.44;
          if (i == 1) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(w * 0.27, y - w * 0.045, w * 0.46, w * 0.09),
                Radius.circular(w * 0.04),
              ),
              Paint()..color = Palette.sun,
            );
          }
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(w * 0.29, y - w * 0.018, w * len, w * 0.036),
              Radius.circular(w * 0.02),
            ),
            ink,
          );
        }
      case TileArtKind.sample:
        final back = Rect.fromLTWH(w * 0.32, w * 0.1, w * 0.6, w * 0.42);
        canvas.drawPath(bubblePath(back, radius: w * 0.12, tailLeft: false), soft);
        final front = Rect.fromLTWH(w * 0.06, w * 0.36, w * 0.62, w * 0.42);
        canvas.drawPath(bubblePath(front, radius: w * 0.12), white);
        final tp = TextPainter(
          text: TextSpan(
            text: '«',
            style: TextStyle(
              fontFamily: displayFamily,
              fontSize: w * 0.42,
              color: Palette.violet,
              height: 1,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas,
            front.center - Offset(tp.width / 2, tp.height / 2 - w * 0.02));
        canvas.drawPath(sparklePath(Offset(w * 0.82, w * 0.78), w * 0.1), white);
      case TileArtKind.empty:
        final page = RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.12, w * 0.12, w * 0.56, w * 0.7),
          Radius.circular(w * 0.1),
        );
        canvas.drawRRect(page, soft);
        final c = Offset(w * 0.6, w * 0.58);
        canvas.drawCircle(
          c,
          w * 0.2,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 0.07,
        );
        canvas.drawLine(
          c + Offset(w * 0.14, w * 0.14),
          c + Offset(w * 0.3, w * 0.3),
          Paint()
            ..color = Colors.white
            ..strokeWidth = w * 0.09
            ..strokeCap = StrokeCap.round,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _TilePainter old) => old.kind != kind;
}

// --- Écoute (transcription) ---------------------------------------------------

/// Ondes concentriques et barres sonores qui battent pendant la
/// transcription.
class ListeningArt extends StatelessWidget {
  const ListeningArt({super.key, this.size = 220, this.progress});

  final double size;

  /// Avancement (0 à 1), dessiné en anneau ; null = indéterminé.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final tones = Tones.of(context);
    return SizedBox.square(
      dimension: size,
      child: LoopingArt(
        period: const Duration(milliseconds: 2400),
        painter: (t, context) => _ListeningPainter(t, progress, tones.rule),
      ),
    );
  }
}

class _ListeningPainter extends CustomPainter {
  _ListeningPainter(this.t, this.progress, this.track);

  final double t;
  final double? progress;
  final Color track;

  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = s.width / 2;

    // Ondes qui s'éloignent
    for (var i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1;
      canvas.drawCircle(
        c,
        r * (0.42 + 0.5 * p),
        Paint()
          ..color = Palette.violet.withValues(alpha: 0.22 * (1 - p))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    // Anneau d'avancement
    final ring = Rect.fromCircle(center: c, radius: r * 0.47);
    canvas.drawArc(
      ring,
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7,
    );
    final sweep = progress == null ? 0.7 : 2 * math.pi * progress!.clamp(0, 1);
    final start = progress == null ? t * 2 * math.pi : -math.pi / 2;
    canvas.drawArc(
      ring,
      start,
      sweep,
      false,
      Paint()
        ..shader = SweepGradient(
          colors: const [Palette.violet, Palette.rose, Palette.coral, Palette.violet],
          transform: GradientRotation(start),
        ).createShader(ring)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 7,
    );

    // Disque central et onde colorée
    final disk = Rect.fromCircle(center: c, radius: r * 0.38);
    canvas.drawCircle(
      c,
      r * 0.38,
      Paint()
        ..shader = const LinearGradient(
          colors: [Palette.violet, Palette.rose],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(disk),
    );
    paintWave(
      canvas,
      Rect.fromCenter(center: c, width: r * 0.42, height: r * 0.34),
      bars: 5,
      t: t,
      color: Colors.white,
      minFactor: 0.2,
    );
  }

  @override
  bool shouldRepaint(covariant _ListeningPainter old) =>
      old.t != t || old.progress != progress;
}

// --- Avatar d'entretien -------------------------------------------------------

/// Pastille colorée d'un entretien : sa teinte et une mini-bulle.
class InterviewAvatar extends StatelessWidget {
  const InterviewAvatar({super.key, required this.accent, this.size = 52});

  final Accent accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: accent.gradient,
        borderRadius: BorderRadius.circular(size * 0.32),
        boxShadow: [
          BoxShadow(
            color: accent.color.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: CustomPaint(painter: _AvatarPainter()),
    );
  }
}

class _AvatarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final b = Rect.fromLTWH(w * 0.2, w * 0.24, w * 0.6, w * 0.42);
    canvas.drawPath(bubblePath(b, radius: w * 0.13),
        Paint()..color = Colors.white);
    paintWave(
      canvas,
      Rect.fromCenter(center: b.center, width: b.width * 0.56, height: b.height * 0.5),
      bars: 4,
      t: 0.2,
      color: Palette.ink.withValues(alpha: 0.55),
      minFactor: 0.4,
    );
  }

  @override
  bool shouldRepaint(covariant _AvatarPainter old) => false;
}

/// Pastille ronde colorée portant une icône (réglages, rubriques…).
class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, required this.accent, this.size = 40});

  final IconData icon;
  final Accent accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.soft(context),
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      child: Icon(icon, size: size * 0.52, color: accent.onSoft(context)),
    );
  }
}
