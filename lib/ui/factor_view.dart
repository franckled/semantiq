import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/analysis.dart';
import '../engine/factorial.dart';
import 'common.dart';
import 'motion.dart';
import 'network_view.dart';
import 'theme.dart';

/// Rubrique « Corrélations » : le réseau des mots, ou leur projection sur
/// une carte factorielle.
class CorrelationsTab extends StatefulWidget {
  const CorrelationsTab({
    super.key,
    required this.analysis,
    required this.onWordTap,
  });

  final Analysis analysis;
  final void Function(String key) onWordTap;

  @override
  State<CorrelationsTab> createState() => _CorrelationsTabState();
}

class _CorrelationsTabState extends State<CorrelationsTab> {
  bool _map = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: _ModeSwitch(
            map: _map,
            onChanged: (v) => setState(() => _map = v),
          ),
        ),
        Expanded(
          child: _map
              ? FactorTab(
                  analysis: widget.analysis, onWordTap: widget.onWordTap)
              : NetworkTab(
                  analysis: widget.analysis, onWordTap: widget.onWordTap),
        ),
      ],
    );
  }
}

class _ModeSwitch extends StatelessWidget {
  const _ModeSwitch({required this.map, required this.onChanged});

  final bool map;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tones = Tones.of(context);
    final fg = Accent.mint.onSoft(context);
    Widget btn(bool value, IconData icon, String label) {
      final selected = map == value;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          child: Pressable(
            onTap: () => onChanged(value),
            borderRadius: BorderRadius.circular(13),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 40,
              decoration: BoxDecoration(
                color: selected ? tones.raised : Colors.transparent,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: fontFamily,
                        fontSize: 14,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w700,
                        color: fg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Accent.mint.soft(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          btn(false, Icons.hub_rounded, 'Réseau'),
          btn(true, Icons.scatter_plot_rounded, 'Carte factorielle'),
        ],
      ),
    );
  }
}

String _percent(double share) => '${(share * 100).round()} %';

/// Teinte d'un mot selon le quadrant de la carte où il tombe.
Accent _quadrant(FactorWord w) => w.x >= 0
    ? (w.y >= 0 ? Accent.violet : Accent.sky)
    : (w.y >= 0 ? Accent.coral : Accent.mint);

/// Carte factorielle : les mots projetés sur les deux premiers axes d'une
/// analyse des correspondances, puis les mots qui s'opposent sur chaque axe.
class FactorTab extends StatelessWidget {
  const FactorTab({super.key, required this.analysis, required this.onWordTap});

  final Analysis analysis;
  final void Function(String key) onWordTap;

  @override
  Widget build(BuildContext context) {
    const pad = EdgeInsets.fromLTRB(16, 4, 16, 40);
    final t = Theme.of(context).textTheme;
    final tones = Tones.of(context);
    final map = FactorMap.of(analysis);
    if (map == null) {
      return ListView(
        padding: pad,
        children: const [
          EmptyState(
            title: 'Texte trop court pour une carte',
            message: 'L\'analyse factorielle demande au moins quatre mots '
                'employés trois fois chacun, dans plusieurs passages. '
                'Essayez avec un entretien plus long.',
            accent: Accent.mint,
          ),
        ],
      );
    }
    final both = _percent(map.shareX + map.shareY);
    return ListView(
      padding: pad,
      children: [
        const SectionTitle(
          'Carte factorielle',
          subtitle: 'Pincez pour zoomer · touchez un mot pour ses phrases',
          accent: Accent.mint,
        ),
        FadeSlideIn(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: AspectRatio(
              aspectRatio: 1,
              child: _Plot(map: map, onWordTap: onWordTap),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
          child: Text(
            'Axe horizontal : ${_percent(map.shareX)} de l\'inertie · '
            'axe vertical : ${_percent(map.shareY)}',
            style: t.bodySmall?.copyWith(color: tones.muted),
          ),
        ),
        const SectionTitle(
          'Oppositions',
          subtitle: 'Les mots qui pèsent le plus de chaque côté d\'un axe',
          accent: Accent.violet,
        ),
        _AxisCard(
          title: 'Axe horizontal',
          share: map.shareX,
          lowLabel: 'À gauche',
          highLabel: 'À droite',
          low: map.pole(0, positive: false),
          high: map.pole(0, positive: true),
          onWordTap: onWordTap,
        ),
        const SizedBox(height: 12),
        _AxisCard(
          title: 'Axe vertical',
          share: map.shareY,
          lowLabel: 'En bas',
          highLabel: 'En haut',
          low: map.pole(1, positive: false),
          high: map.pole(1, positive: true),
          onWordTap: onWordTap,
        ),
        const SizedBox(height: 16),
        TintCard(
          accent: Accent.mint,
          child: Text(
            'Deux mots proches sont employés dans les mêmes passages. Deux '
            'mots aux extrémités d\'un axe ne se rencontrent presque '
            'jamais : ils signalent deux registres du discours. Les axes '
            'n\'ont pas de nom, c\'est à vous de les interpréter.\n\n'
            'Analyse factorielle des correspondances sur '
            '${map.words.length} mots et ${map.segments} segments de texte '
            'd\'environ ${map.segmentSize} mots. Les deux axes restituent '
            '$both de l\'inertie : le reste ne se voit pas sur la carte.',
            style: t.bodyMedium?.copyWith(color: Accent.mint.onSoft(context)),
          ),
        ),
      ],
    );
  }
}

class _AxisCard extends StatelessWidget {
  const _AxisCard({
    required this.title,
    required this.share,
    required this.lowLabel,
    required this.highLabel,
    required this.low,
    required this.high,
    required this.onWordTap,
  });

  final String title;
  final double share;
  final String lowLabel;
  final String highLabel;
  final List<FactorWord> low;
  final List<FactorWord> high;
  final void Function(String key) onWordTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tones = Tones.of(context);
    Widget pole(String label, List<FactorWord> words, Accent accent) =>
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: t.labelLarge?.copyWith(color: accent.onSoft(context)),
              ),
              const SizedBox(height: 8),
              if (words.isEmpty)
                Text('Aucun mot marquant',
                    style: t.bodySmall?.copyWith(color: tones.muted))
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final w in words)
                      Pressable(
                        onTap: () => onWordTap(w.key),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: accent.soft(context),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            w.label,
                            style: TextStyle(
                              fontFamily: fontFamily,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: accent.onSoft(context),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: t.titleSmall)),
                Text(
                  '${_percent(share)} de l\'inertie',
                  style: t.bodySmall?.copyWith(color: tones.muted),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                pole(lowLabel, low, Accent.coral),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.compare_arrows_rounded,
                      size: 20, color: tones.muted),
                ),
                pole(highLabel, high, Accent.sky),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Plot extends StatefulWidget {
  const _Plot({required this.map, required this.onWordTap});

  final FactorMap map;
  final void Function(String key) onWordTap;

  @override
  State<_Plot> createState() => _PlotState();
}

class _PlotState extends State<_Plot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tones = Tones.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth;
        final layout = _PlotLayout(
          widget.map,
          side,
          colorOf: (w) => _quadrant(w).color,
          textOf: (w) => _quadrant(w).onSoft(context),
        );
        return InteractiveViewer(
          maxScale: 5,
          boundaryMargin: const EdgeInsets.all(80),
          child: GestureDetector(
            onTapUp: (d) {
              final key = layout.hit(d.localPosition);
              if (key != null) widget.onWordTap(key);
            },
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => CustomPaint(
                size: Size(side, side),
                painter: _PlotPainter(
                  layout: layout,
                  progress: Curves.easeOutCubic.transform(_c.value),
                  rule: tones.rule,
                  halo: tones.raised,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Placement des mots dans le carré de la carte : même échelle sur les deux
/// axes, étiquettes posées sans chevauchement en commençant par les mots
/// qui pèsent le plus.
class _PlotLayout {
  _PlotLayout(
    this.map,
    this.side, {
    required Color Function(FactorWord) colorOf,
    required Color Function(FactorWord) textOf,
  }) {
    const pad = 30.0;
    final words = map.words;
    var minX = 0.0, maxX = 0.0, minY = 0.0, maxY = 0.0;
    var most = 1;
    for (final w in words) {
      minX = math.min(minX, w.x);
      maxX = math.max(maxX, w.x);
      minY = math.min(minY, w.y);
      maxY = math.max(maxY, w.y);
      most = math.max(most, w.count);
    }
    final spanX = maxX - minX <= 0 ? 1.0 : maxX - minX;
    final spanY = maxY - minY <= 0 ? 1.0 : maxY - minY;
    final room = math.max(1.0, side - 2 * pad);
    final scale = math.min(room / spanX, room / spanY);
    final cx = (minX + maxX) / 2;
    final cy = (minY + maxY) / 2;
    Offset place(double x, double y) =>
        Offset(side / 2 + (x - cx) * scale, side / 2 - (y - cy) * scale);

    origin = place(0, 0);
    for (final w in words) {
      points.add(place(w.x, w.y));
      radii.add(3.5 + 5.5 * math.sqrt(w.count / most));
      colors.add(colorOf(w));
      labels.add(null);
      labelAt.add(Offset.zero);
    }

    final order = [for (var i = 0; i < words.length; i++) i]
      ..sort((a, b) => (words[b].contribX + words[b].contribY)
          .compareTo(words[a].contribX + words[a].contribY));
    final bounds = Rect.fromLTWH(2, 2, side - 4, side - 4);
    final taken = <Rect>[];
    for (final i in order) {
      final tp = TextPainter(
        text: TextSpan(
          text: words[i].label,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: textOf(words[i]),
          ),
        ),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();
      final p = points[i];
      final r = radii[i];
      final spots = [
        Offset(p.dx + r + 3, p.dy - tp.height / 2),
        Offset(p.dx - r - 3 - tp.width, p.dy - tp.height / 2),
        Offset(p.dx - tp.width / 2, p.dy - r - 2 - tp.height),
        Offset(p.dx - tp.width / 2, p.dy + r + 2),
      ];
      for (final spot in spots) {
        final rect = spot & tp.size;
        if (rect.left < bounds.left ||
            rect.top < bounds.top ||
            rect.right > bounds.right ||
            rect.bottom > bounds.bottom) {
          continue;
        }
        if (taken.any((o) => o.overlaps(rect.inflate(1)))) continue;
        taken.add(rect);
        labels[i] = tp;
        labelAt[i] = spot;
        break;
      }
    }
  }

  final FactorMap map;
  final double side;
  late final Offset origin;
  final List<Offset> points = [];
  final List<double> radii = [];
  final List<Color> colors = [];

  /// Étiquette de chaque mot, ou null si elle n'a pas trouvé de place.
  final List<TextPainter?> labels = [];
  final List<Offset> labelAt = [];

  /// Mot le plus proche du point touché, s'il y en a un à portée de doigt.
  String? hit(Offset at) {
    String? best;
    var bestDistance = 26.0;
    for (var i = 0; i < points.length; i++) {
      final d = (points[i] - at).distance;
      if (d < bestDistance) {
        bestDistance = d;
        best = map.words[i].key;
      }
    }
    return best;
  }
}

class _PlotPainter extends CustomPainter {
  const _PlotPainter({
    required this.layout,
    required this.progress,
    required this.rule,
    required this.halo,
  });

  final _PlotLayout layout;

  /// 0 = tous les mots à l'origine, 1 = à leur place.
  final double progress;
  final Color rule;
  final Color halo;

  @override
  void paint(Canvas canvas, Size size) {
    final o = layout.origin;
    final axis = Paint()
      ..color = rule
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(0, o.dy), Offset(size.width, o.dy), axis);
    canvas.drawLine(Offset(o.dx, 0), Offset(o.dx, size.height), axis);

    Offset at(int i) => Offset.lerp(o, layout.points[i], progress)!;

    final ring = Paint()
      ..color = halo
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (var i = 0; i < layout.points.length; i++) {
      final p = at(i);
      canvas.drawCircle(
          p, layout.radii[i], Paint()..color = layout.colors[i].withValues(alpha: 0.9));
      canvas.drawCircle(p, layout.radii[i], ring);
    }

    final opacity = ((progress - 0.4) / 0.6).clamp(0.0, 1.0);
    if (opacity <= 0) return;
    canvas.saveLayer(
      Offset.zero & size,
      Paint()..color = Colors.white.withValues(alpha: opacity),
    );
    for (var i = 0; i < layout.points.length; i++) {
      final tp = layout.labels[i];
      if (tp == null) continue;
      final shift = at(i) - layout.points[i];
      tp.paint(canvas, layout.labelAt[i] + shift);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PlotPainter old) =>
      old.progress != progress || old.layout != layout || old.rule != rule;
}
