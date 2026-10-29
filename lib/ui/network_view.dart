import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/analysis.dart';
import 'common.dart';
import 'motion.dart';
import 'theme.dart';

/// Réseau de cooccurrences : les mots employés dans les mêmes phrases sont
/// reliés, d'autant plus fortement qu'ils vont souvent ensemble. Les mots
/// très liés entre eux forment des familles, chacune dans sa couleur.
class NetworkTab extends StatelessWidget {
  const NetworkTab({super.key, required this.analysis, required this.onWordTap});

  final Analysis analysis;
  final void Function(String key) onWordTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tones = Tones.of(context);
    final a = analysis;
    if (a.correlations.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: const [
          EmptyState(
            title: 'Pas encore de liens',
            message: 'Il faut des mots présents dans au moins trois phrases et '
                'réunis dans au moins deux. Essayez avec un entretien plus '
                'long.',
            accent: Accent.mint,
          ),
        ],
      );
    }
    final layout = _Layout.cached(a);
    final maxPmi = a.correlations.take(40).map((c) => c.pmi).reduce(math.max);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      children: [
        const SectionTitle(
          'Réseau des mots',
          subtitle: 'Pincez pour zoomer · touchez un mot pour ses phrases',
          accent: Accent.mint,
        ),
        FadeSlideIn(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: AspectRatio(
              aspectRatio: 1,
              child: _Graph(layout: layout, onWordTap: onWordTap),
            ),
          ),
        ),
        if (layout.families.length > 1) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var f = 0; f < layout.families.length && f < 6; f++)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Accent.at(f).soft(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: Accent.at(f).color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        layout.families[f].take(3).join(' · '),
                        style: t.bodySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Accent.at(f).onSoft(context),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
        const SectionTitle(
          'Paires les plus associées',
          subtitle: 'Affinité : 1 = deux fois plus souvent ensemble que par '
              'hasard, 2 = quatre fois plus',
          accent: Accent.mint,
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < a.correlations.length && i < 40; i++) ...[
                if (i > 0) Divider(height: 1, color: tones.rule, indent: 16),
                _PairRow(
                  analysis: a,
                  c: a.correlations[i],
                  maxPmi: maxPmi,
                  colorA: layout.colorOf(a.correlations[i].a),
                  colorB: layout.colorOf(a.correlations[i].b),
                  onTap: () => _showPair(context, a, a.correlations[i]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showPair(BuildContext context, Analysis a, Correlation c) {
    final formsA = a.word(c.a)?.forms.keys.toSet() ?? {};
    final formsB = a.word(c.b)?.forms.keys.toSet() ?? {};
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (ctx, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
          children: [
            Text('${a.labelOf(c.a)} & ${a.labelOf(c.b)}',
                style: Theme.of(ctx).textTheme.headlineMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Badge('${c.together} phrases communes', Accent.mint),
                _Badge('affinité ${c.pmi.toStringAsFixed(2)}', Accent.violet),
                _Badge('Jaccard ${c.jaccard.toStringAsFixed(2)}', Accent.sky),
              ],
            ),
            const SizedBox(height: 18),
            for (final i in c.sentences)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: HighlightedText(
                  a.transcript.sentences[i].text,
                  matches: (w) => formsA.contains(w) || formsB.contains(w),
                  style: Theme.of(ctx).textTheme.bodyLarge,
                  highlight: Tones.of(ctx).linkSoft,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.accent);

  final String label;
  final Accent accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: accent.soft(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w800,
            color: accent.onSoft(context),
          )),
    );
  }
}

class _PairRow extends StatelessWidget {
  const _PairRow({
    required this.analysis,
    required this.c,
    required this.maxPmi,
    required this.colorA,
    required this.colorB,
    required this.onTap,
  });

  final Analysis analysis;
  final Correlation c;
  final double maxPmi;
  final Color colorA;
  final Color colorB;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tones = Tones.of(context);
    Widget dot(Color c) => Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        );
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                dot(colorA),
                Flexible(
                  child: Text(analysis.labelOf(c.a),
                      style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.link_rounded, size: 18, color: tones.muted),
                ),
                dot(colorB),
                Flexible(
                  child: Text(analysis.labelOf(c.b),
                      style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis),
                ),
                const Spacer(),
                Text('×${c.together}',
                    style: t.bodyMedium?.copyWith(
                        color: tones.muted, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            GrowBar(
              value: maxPmi == 0 ? 0 : c.pmi / maxPmi,
              color: Palette.mint,
              background: tones.rule,
              height: 5,
              gradient: LinearGradient(colors: [colorA, colorB]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Graph extends StatefulWidget {
  const _Graph({required this.layout, required this.onWordTap});

  final _Layout layout;
  final void Function(String key) onWordTap;

  @override
  State<_Graph> createState() => _GraphState();
}

class _GraphState extends State<_Graph> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tones = Tones.of(context);
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, c) {
        final side = c.maxWidth;
        return InteractiveViewer(
          maxScale: 4,
          boundaryMargin: const EdgeInsets.all(80),
          child: GestureDetector(
            onTapUp: (d) {
              final key = widget.layout.hit(d.localPosition, side);
              if (key != null) widget.onWordTap(key);
            },
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => CustomPaint(
                size: Size(side, side),
                painter: _GraphPainter(
                  layout: widget.layout,
                  progress: Curves.easeOutCubic.transform(_c.value),
                  text: scheme.onSurface,
                  halo: tones.raised,
                  neutral: tones.muted,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Node {
  _Node(this.key, this.label, this.weight);
  final String key;
  final String label;

  /// Fréquence relative (0 à 1).
  final double weight;
  double x = 0;
  double y = 0;

  /// Famille de mots (0 = la plus grande).
  int family = 0;
}

class _Edge {
  const _Edge(this.a, this.b, this.strength);
  final int a;
  final int b;

  /// Force relative (0 à 1).
  final double strength;
}

/// Placement des mots par la méthode de Fruchterman et Reingold (les liens
/// rapprochent, tous les mots se repoussent) et regroupement en familles par
/// propagation d'étiquettes.
class _Layout {
  _Layout(this.nodes, this.edges, this.families);

  final List<_Node> nodes;
  final List<_Edge> edges;

  /// Mots de chaque famille, du plus fréquent au moins fréquent.
  final List<List<String>> families;

  Color colorOf(String key) {
    for (final n in nodes) {
      if (n.key == key) return Accent.at(n.family).color;
    }
    return Palette.mint;
  }

  static final _cache = Expando<_Layout>('layout');

  /// Placement calculé une fois par analyse.
  static _Layout cached(Analysis a) => _cache[a] ??= compute(a);

  static _Layout compute(Analysis a) {
    final keys = <String>{
      for (final c in a.correlations) ...[c.a, c.b],
    };
    final words = a.networkWords.where((w) => keys.contains(w.key)).toList();
    if (words.isEmpty) return _Layout(const [], const [], const []);
    final maxCount = words.map((w) => w.count).reduce(math.max);
    final nodes = [
      for (final w in words) _Node(w.key, w.label, w.count / maxCount),
    ];
    final index = {for (var i = 0; i < nodes.length; i++) nodes[i].key: i};
    double force(Correlation c) => c.pmi * math.log(1 + c.together);
    final maxForce = a.correlations.map(force).reduce(math.max);
    final edges = [
      for (final c in a.correlations)
        if (index.containsKey(c.a) && index.containsKey(c.b))
          _Edge(index[c.a]!, index[c.b]!, force(c) / maxForce),
    ];
    final n = nodes.length;

    // Familles : chaque mot adopte l'étiquette la plus soutenue par ses
    // voisins (propagation d'étiquettes, ordre déterministe).
    final label = List<int>.generate(n, (i) => i);
    for (var iter = 0; iter < 15; iter++) {
      var changed = false;
      for (var i = 0; i < n; i++) {
        final score = <int, double>{};
        for (final e in edges) {
          if (e.a == i) score[label[e.b]] = (score[label[e.b]] ?? 0) + e.strength;
          if (e.b == i) score[label[e.a]] = (score[label[e.a]] ?? 0) + e.strength;
        }
        if (score.isEmpty) continue;
        var best = label[i];
        var bestScore = score[best] ?? 0;
        score.forEach((l, s) {
          if (s > bestScore + 1e-9 || (s == bestScore && l < best)) {
            best = l;
            bestScore = s;
          }
        });
        if (best != label[i]) {
          label[i] = best;
          changed = true;
        }
      }
      if (!changed) break;
    }
    final groups = <int, List<int>>{};
    for (var i = 0; i < n; i++) {
      groups.putIfAbsent(label[i], () => []).add(i);
    }
    final ordered = groups.values.toList()
      ..sort((x, y) => y.length.compareTo(x.length));
    final families = <List<String>>[];
    for (var f = 0; f < ordered.length; f++) {
      final members = ordered[f]..sort((x, y) => nodes[y].weight.compareTo(nodes[x].weight));
      for (final m in members) {
        nodes[m].family = f;
      }
      families.add([for (final m in members) nodes[m].label]);
    }

    // Position initiale déterministe : un cercle, les plus fréquents au
    // centre.
    for (var i = 0; i < n; i++) {
      final angle = 2 * math.pi * i / n;
      final r = 0.15 + 0.3 * (1 - nodes[i].weight);
      nodes[i].x = 0.5 + r * math.cos(angle);
      nodes[i].y = 0.5 + r * math.sin(angle);
    }
    final k = math.sqrt(1 / n) * 0.8;
    var temp = 0.1;
    for (var iter = 0; iter < 300; iter++) {
      final dx = List<double>.filled(n, 0);
      final dy = List<double>.filled(n, 0);
      for (var i = 0; i < n; i++) {
        for (var j = i + 1; j < n; j++) {
          var ex = nodes[i].x - nodes[j].x;
          var ey = nodes[i].y - nodes[j].y;
          var d = math.sqrt(ex * ex + ey * ey);
          if (d < 1e-4) {
            ex = 1e-3 * (i - j);
            ey = 1e-3;
            d = 1e-3;
          }
          final rep = k * k / d;
          dx[i] += ex / d * rep;
          dy[i] += ey / d * rep;
          dx[j] -= ex / d * rep;
          dy[j] -= ey / d * rep;
        }
      }
      for (final e in edges) {
        final ex = nodes[e.a].x - nodes[e.b].x;
        final ey = nodes[e.a].y - nodes[e.b].y;
        final d = math.max(1e-4, math.sqrt(ex * ex + ey * ey));
        final att = d * d / k * (0.3 + e.strength);
        dx[e.a] -= ex / d * att;
        dy[e.a] -= ey / d * att;
        dx[e.b] += ex / d * att;
        dy[e.b] += ey / d * att;
      }
      for (var i = 0; i < n; i++) {
        dx[i] += (0.5 - nodes[i].x) * 0.05;
        dy[i] += (0.5 - nodes[i].y) * 0.05;
        final len = math.max(1e-6, math.sqrt(dx[i] * dx[i] + dy[i] * dy[i]));
        final step = math.min(len, temp);
        nodes[i].x += dx[i] / len * step;
        nodes[i].y += dy[i] / len * step;
      }
      temp = math.max(0.002, temp * 0.985);
    }

    // Recadrage dans [0.1, 0.9].
    final xs = nodes.map((n) => n.x);
    final ys = nodes.map((n) => n.y);
    final minX = xs.reduce(math.min), maxX = xs.reduce(math.max);
    final minY = ys.reduce(math.min), maxY = ys.reduce(math.max);
    final span = math.max(1e-6, math.max(maxX - minX, maxY - minY));
    for (final node in nodes) {
      node.x = 0.1 +
          0.8 * (node.x - minX) / span +
          0.4 * (1 - (maxX - minX) / span);
      node.y = 0.1 +
          0.8 * (node.y - minY) / span +
          0.4 * (1 - (maxY - minY) / span);
    }
    return _Layout(nodes, edges, families);
  }

  static double radius(_Node n) => 6 + 14 * math.sqrt(n.weight);

  String? hit(Offset p, double side) {
    String? best;
    var bestD = double.infinity;
    for (final n in nodes) {
      final d = (Offset(n.x * side, n.y * side) - p).distance;
      if (d < radius(n) + 22 && d < bestD) {
        best = n.key;
        bestD = d;
      }
    }
    return best;
  }
}

class _GraphPainter extends CustomPainter {
  _GraphPainter({
    required this.layout,
    required this.progress,
    required this.text,
    required this.halo,
    required this.neutral,
  });

  final _Layout layout;

  /// Avancement de l'animation d'apparition (0 à 1).
  final double progress;
  final Color text;
  final Color halo;
  final Color neutral;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final nodes = layout.nodes;
    // Les mots partent du centre et rejoignent leur place.
    Offset pos(_Node n) => Offset(
          (0.5 + (n.x - 0.5) * progress) * s,
          (0.5 + (n.y - 0.5) * progress) * s,
        );

    final edgesSorted = [...layout.edges]
      ..sort((a, b) => a.strength.compareTo(b.strength));
    for (final e in edgesSorted) {
      final a = nodes[e.a];
      final b = nodes[e.b];
      final same = a.family == b.family;
      final color = same ? Accent.at(a.family).color : neutral;
      final p1 = pos(a);
      final p2 = pos(b);
      // Lien légèrement courbé, plus élégant qu'un trait droit.
      final mid = Offset.lerp(p1, p2, 0.5)!;
      final normal = Offset(-(p2.dy - p1.dy), p2.dx - p1.dx) * 0.08;
      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..quadraticBezierTo(mid.dx + normal.dx, mid.dy + normal.dy, p2.dx, p2.dy);
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(
              alpha: progress * (same ? 0.25 + 0.55 * e.strength : 0.18))
          ..strokeWidth = 1 + 4 * e.strength
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
    for (final n in nodes) {
      final c = pos(n);
      final r = _Layout.radius(n) * progress;
      final color = Accent.at(n.family).color;
      canvas.drawCircle(
        c,
        r + 4,
        Paint()..color = color.withValues(alpha: 0.18),
      );
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [Color.lerp(color, Colors.white, 0.35)!, color],
            center: const Alignment(-0.3, -0.4),
          ).createShader(Rect.fromCircle(center: c, radius: math.max(r, 0.1))),
      );
      if (progress < 0.3) continue;
      final tp = TextPainter(
        text: TextSpan(
          text: n.label,
          style: TextStyle(
            fontFamily: n.weight > 0.45 ? displayFamily : fontFamily,
            color: text.withValues(alpha: ((progress - 0.3) / 0.7).clamp(0, 1)),
            fontSize: 11 + 7 * n.weight,
            fontWeight: n.weight > 0.45 ? FontWeight.w400 : FontWeight.w700,
            shadows: [
              Shadow(color: halo, blurRadius: 3),
              Shadow(color: halo, blurRadius: 6),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c + Offset(-tp.width / 2, r + 3));
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPainter old) =>
      old.layout != layout ||
      old.progress != progress ||
      old.text != text ||
      old.halo != halo;
}
