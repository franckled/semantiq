import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/analysis.dart';
import 'common.dart';
import 'theme.dart';

/// Réseau de cooccurrences : les mots employés dans les mêmes phrases sont
/// reliés, d'autant plus fortement qu'ils vont souvent ensemble.
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
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Pas assez de texte pour mesurer des cooccurrences : il faut des '
            'mots présents dans au moins trois phrases et réunis dans au moins '
            'deux.',
            style: t.bodyMedium?.copyWith(color: tones.muted),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        const SectionTitle(
          'Réseau des mots',
          subtitle: 'Pincez pour zoomer · touchez un mot pour ses phrases',
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: AspectRatio(
            aspectRatio: 1,
            child: _Graph(analysis: a, onWordTap: onWordTap),
          ),
        ),
        const SectionTitle(
          'Paires les plus associées',
          subtitle: 'Affinité : 1 = deux fois plus souvent ensemble que par '
              'hasard, 2 = quatre fois plus',
        ),
        for (final c in a.correlations.take(40))
          InkWell(
            onTap: () => _showPair(context, a, c),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9),
              child: Row(
                children: [
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: t.bodyLarge,
                        children: [
                          TextSpan(
                              text: a.labelOf(c.a),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          TextSpan(
                              text: '  —  ',
                              style: TextStyle(color: tones.link)),
                          TextSpan(
                              text: a.labelOf(c.b),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    '×${c.together} · ${c.pmi.toStringAsFixed(1)}',
                    style: t.bodyMedium?.copyWith(color: tones.muted),
                  ),
                ],
              ),
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
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.95,
        builder: (ctx, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            Text('${a.labelOf(c.a)} — ${a.labelOf(c.b)}',
                style: Theme.of(ctx).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'Ensemble dans ${c.together} phrases · affinité '
              '${c.pmi.toStringAsFixed(2)} · Jaccard '
              '${c.jaccard.toStringAsFixed(2)}',
              style: Theme.of(ctx)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Tones.of(ctx).muted),
            ),
            const SizedBox(height: 16),
            for (final i in c.sentences)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: HighlightedText(
                  a.transcript.sentences[i].text,
                  matches: (w) => formsA.contains(w) || formsB.contains(w),
                  style: Theme.of(ctx).textTheme.bodyLarge,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Graph extends StatefulWidget {
  const _Graph({required this.analysis, required this.onWordTap});

  final Analysis analysis;
  final void Function(String key) onWordTap;

  @override
  State<_Graph> createState() => _GraphState();
}

class _GraphState extends State<_Graph> {
  late _Layout _layout = _Layout.compute(widget.analysis);

  @override
  void didUpdateWidget(covariant _Graph old) {
    super.didUpdateWidget(old);
    if (old.analysis != widget.analysis) {
      _layout = _Layout.compute(widget.analysis);
    }
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
              final key = _layout.hit(d.localPosition, side);
              if (key != null) widget.onWordTap(key);
            },
            child: CustomPaint(
              size: Size(side, side),
              painter: _GraphPainter(
                layout: _layout,
                edge: tones.link,
                node: tones.marker,
                nodeSoft: tones.markerSoft,
                text: scheme.onSurface,
                halo: tones.raised,
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
}

class _Edge {
  const _Edge(this.a, this.b, this.strength);
  final int a;
  final int b;

  /// Force relative (0 à 1).
  final double strength;
}

/// Placement des mots par la méthode de Fruchterman et Reingold : les liens
/// rapprochent, tous les mots se repoussent.
class _Layout {
  _Layout(this.nodes, this.edges);

  final List<_Node> nodes;
  final List<_Edge> edges;

  static _Layout compute(Analysis a) {
    // Mots qui ont au moins un lien.
    final keys = <String>{
      for (final c in a.correlations) ...[c.a, c.b],
    };
    final words = a.networkWords.where((w) => keys.contains(w.key)).toList();
    if (words.isEmpty) return _Layout(const [], const []);
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

    // Position initiale déterministe : un cercle, les plus fréquents au
    // centre.
    final n = nodes.length;
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
        // Légère gravité vers le centre pour garder le graphe compact.
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
      node.x = 0.1 + 0.8 * (node.x - minX) / span +
          0.4 * (1 - (maxX - minX) / span);
      node.y = 0.1 + 0.8 * (node.y - minY) / span +
          0.4 * (1 - (maxY - minY) / span);
    }
    return _Layout(nodes, edges);
  }

  static double radius(_Node n) => 5 + 13 * math.sqrt(n.weight);

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
    required this.edge,
    required this.node,
    required this.nodeSoft,
    required this.text,
    required this.halo,
  });

  final _Layout layout;
  final Color edge;
  final Color node;
  final Color nodeSoft;
  final Color text;
  final Color halo;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final nodes = layout.nodes;
    final edgesSorted = [...layout.edges]
      ..sort((a, b) => a.strength.compareTo(b.strength));
    for (final e in edgesSorted) {
      final a = nodes[e.a];
      final b = nodes[e.b];
      canvas.drawLine(
        Offset(a.x * s, a.y * s),
        Offset(b.x * s, b.y * s),
        Paint()
          ..color = edge.withValues(alpha: 0.15 + 0.6 * e.strength)
          ..strokeWidth = 0.8 + 3.5 * e.strength
          ..strokeCap = StrokeCap.round,
      );
    }
    for (final n in nodes) {
      final c = Offset(n.x * s, n.y * s);
      final r = _Layout.radius(n);
      canvas.drawCircle(c, r, Paint()..color = n.weight > 0.5 ? node : nodeSoft);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = node
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: n.label,
          style: TextStyle(
            fontFamily: fontFamily,
            color: text,
            fontSize: 11 + 5 * n.weight,
            fontWeight: n.weight > 0.4 ? FontWeight.w800 : FontWeight.w600,
            shadows: [Shadow(color: halo, blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c + Offset(-tp.width / 2, r + 2));
    }
  }

  @override
  bool shouldRepaint(covariant _GraphPainter old) =>
      old.layout != layout || old.edge != edge || old.text != text;
}
