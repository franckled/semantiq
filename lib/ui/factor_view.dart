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

/// Part d'inertie en pourcentage arrondi.
String factorPercent(double share) => '${(share * 100).round()} %';

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
    final both = factorPercent(map.shareX + map.shareY);
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
              child: FactorPlot(map: map, onWordTap: onWordTap),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
          child: Text(
            'Axe horizontal : ${factorPercent(map.shareX)} de l\'inertie · '
            'axe vertical : ${factorPercent(map.shareY)}',
            style: t.bodySmall?.copyWith(color: tones.muted),
          ),
        ),
        const SectionTitle(
          'Oppositions',
          subtitle: 'Les mots qui pèsent le plus de chaque côté d\'un axe',
          accent: Accent.violet,
        ),
        FactorAxisCard(
          title: 'Axe horizontal',
          share: map.shareX,
          lowLabel: 'À gauche',
          highLabel: 'À droite',
          low: map.pole(0, positive: false),
          high: map.pole(0, positive: true),
          onWordTap: onWordTap,
        ),
        const SizedBox(height: 12),
        FactorAxisCard(
          title: 'Axe vertical',
          share: map.shareY,
          lowLabel: 'En bas',
          highLabel: 'En haut',
          low: map.pole(1, positive: false),
          high: map.pole(1, positive: true),
          onWordTap: onWordTap,
        ),
        FactorScree(map: map),
        FactorReliability(map: map, onWordTap: onWordTap),
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

/// Les mots (et, pour un corpus, les entretiens) de chaque côté d'un axe.
class FactorAxisCard extends StatelessWidget {
  const FactorAxisCard({
    required this.title,
    required this.share,
    required this.lowLabel,
    required this.highLabel,
    required this.low,
    required this.high,
    required this.onWordTap,
    this.lowDocuments = const [],
    this.highDocuments = const [],
  });

  final String title;
  final double share;
  final String lowLabel;
  final String highLabel;
  final List<FactorWord> low;
  final List<FactorWord> high;

  /// Entretiens situés de chaque côté (carte du corpus seulement).
  final List<String> lowDocuments;
  final List<String> highDocuments;
  final void Function(String key) onWordTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tones = Tones.of(context);
    Widget pole(String label, List<FactorWord> words, List<String> documents,
            Accent accent) =>
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: t.labelLarge?.copyWith(color: accent.onSoft(context)),
              ),
              for (final d in documents)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.onSurface,
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          d,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
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
                  '${factorPercent(share)} de l\'inertie',
                  style: t.bodySmall?.copyWith(color: tones.muted),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                pole(lowLabel, low, lowDocuments, Accent.coral),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.compare_arrows_rounded,
                      size: 20, color: tones.muted),
                ),
                pole(highLabel, high, highDocuments, Accent.sky),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Éboulis des valeurs propres et critère du coude : ce que les deux axes
/// de la carte restituent, et s'il faudrait en lire davantage.
class FactorScree extends StatelessWidget {
  const FactorScree({super.key, required this.map});

  final FactorMap map;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tones = Tones.of(context);
    final spectrum = map.spectrum;
    if (spectrum.isEmpty) return const SizedBox.shrink();
    final elbow = map.elbow;
    final shown = spectrum.take(10).toList();
    final top = shown.first;
    final both = factorPercent(map.shareX + map.shareY);

    final String verdict;
    if (elbow == null) {
      verdict = 'Ce tableau ne porte que ${spectrum.length} '
          'axe${spectrum.length > 1 ? 's' : ''} : il n\'y a pas de coude à '
          'chercher. La carte en montre deux, soit $both de l\'inertie.';
    } else if (elbow <= 2) {
      verdict = 'La courbe se casse après l\'axe $elbow : selon ce critère, '
          'les deux axes de la carte suffisent à lire la structure '
          'principale. Ils restituent $both de l\'inertie.';
    } else {
      verdict = 'La courbe se casse après l\'axe $elbow : il faudrait lire '
          '$elbow axes, et la carte n\'en montre que deux ($both de '
          'l\'inertie). Une partie de la structure ne s\'y voit pas.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          'Éboulis des valeurs propres',
          subtitle: 'Part de l\'inertie portée par chaque axe, en %'
              '${spectrum.length > shown.length ? ' · dix premiers axes sur ${spectrum.length}' : ''}',
          accent: Accent.sun,
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 150,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var k = 0; k < shown.length; k++)
                        Expanded(
                          child: _ScreeBar(
                            axis: k + 1,
                            share: shown[k],
                            height: shown[k] / top,
                            kept: elbow != null && k < elbow,
                            // La cassure tombe juste après cette barre.
                            last: elbow != null && k == elbow - 1,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(verdict, style: t.bodyMedium),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Le critère du coude est un repère de lecture, pas un '
                    'test statistique : il ne dit pas si la structure est '
                    'due au hasard.',
                    style: t.bodySmall?.copyWith(color: tones.muted),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ScreeBar extends StatelessWidget {
  const _ScreeBar({
    required this.axis,
    required this.share,
    required this.height,
    required this.kept,
    required this.last,
  });

  final int axis;
  final double share;

  /// Hauteur relative à la plus haute barre (0 à 1).
  final double height;

  /// Axe situé avant le coude.
  final bool kept;

  /// Dernier axe avant le coude.
  final bool last;

  @override
  Widget build(BuildContext context) {
    final tones = Tones.of(context);
    final fg = kept ? Accent.sun.onSoft(context) : tones.muted;
    final percent = share * 100;
    TextStyle label(FontWeight weight) => TextStyle(
          fontFamily: fontFamily,
          fontSize: 11,
          fontWeight: weight,
          color: fg,
        );
    return Semantics(
      label: 'Axe $axis : ${factorPercent(share)} de l\'inertie'
          '${last ? ', coude après cet axe' : ''}',
      excludeSemantics: true,
      child: Container(
        // Le trait marque la cassure de la courbe.
        decoration: BoxDecoration(
          border: last
              ? Border(right: BorderSide(color: tones.danger, width: 2))
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          children: [
            Text(
              percent >= 9.5
                  ? percent.round().toString()
                  : percent.toStringAsFixed(1).replaceAll('.', ','),
              maxLines: 1,
              overflow: TextOverflow.clip,
              softWrap: false,
              style: label(FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: height.clamp(0.02, 1.0),
                  widthFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: kept ? Palette.sun : tones.rule,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text('$axis', style: label(FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

/// Nombre décimal à la française (virgule), avec [digits] décimales.
String _decimal(double x, int digits) =>
    x.toStringAsFixed(digits).replaceAll('.', ',');

/// Valeur p lisible : « p < 0,001 » ou « p = 0,042 ».
String formatPValue(double p) =>
    p < 0.001 ? 'p < 0,001' : 'p = ${_decimal(p, 3)}';

/// Solidité de la carte : test du khi-deux d'indépendance du tableau et
/// qualité de représentation (cos²) de chaque mot dans le plan.
class FactorReliability extends StatelessWidget {
  const FactorReliability({
    super.key,
    required this.map,
    required this.onWordTap,
  });

  final FactorMap map;
  final void Function(String key) onWordTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tones = Tones.of(context);
    final significant = map.pValue < 0.05;
    final accent = significant ? Accent.mint : Accent.coral;
    final poor = map.poorlyShown;
    final good = map.words.length - poor.length;
    final stats = 'Khi² = ${_decimal(map.chi2, 1)} · ddl = ${map.degrees} · '
        '${formatPValue(map.pValue)}';

    Widget heading(IconData icon, String text, Color color) => Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: t.titleSmall)),
          ],
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle(
          'Solidité du modèle',
          subtitle: 'La carte décrit-elle autre chose que du hasard ? '
              'Chaque mot y est-il bien placé ?',
          accent: Accent.violet,
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heading(
                  significant
                      ? Icons.check_circle_rounded
                      : Icons.help_rounded,
                  'Test du khi-deux d\'indépendance',
                  accent.color,
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: accent.soft(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    stats,
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontWeight: FontWeight.w800,
                      color: accent.onSoft(context),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  significant
                      ? 'Les mots ne se répartissent pas au hasard entre '
                          '${map.segmentSize == 0 ? 'les entretiens' : 'les passages'} : '
                          'la carte décrit une structure réelle du '
                          'vocabulaire.'
                      : 'L\'écart à une répartition au hasard n\'est pas '
                          'significatif : la carte peut refléter du bruit. '
                          'À lire avec prudence, ou avec plus de texte.',
                  style: t.bodyMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  map.permuted
                      ? 'Effectifs trop faibles pour la loi du khi-deux '
                          '(${factorPercent(map.smallExpected)} des effectifs '
                          'attendus sont inférieurs à 5) : la valeur p est '
                          'obtenue par permutation, sur 999 tirages au hasard. '
                          'Elle reste indicative : les mots d\'un même passage '
                          'ne sont pas des tirages indépendants.'
                      : 'Indicatif : les mots d\'un même passage ne sont pas '
                          'des tirages indépendants.',
                  style: t.bodySmall?.copyWith(color: tones.muted),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1, color: tones.rule),
                ),
                heading(
                  Icons.center_focus_strong_rounded,
                  'Qualité de représentation (cos²)',
                  Palette.violet,
                ),
                const SizedBox(height: 10),
                Text(
                  poor.isEmpty
                      ? 'Les ${map.words.length} mots sont bien représentés '
                          'dans le plan : leur position est fiable.'
                      : '$good mots sur ${map.words.length} sont bien '
                          'représentés dans le plan. Les ${poor.length} '
                          'autres (cos² < ${_decimal(FactorMap.faintBelow, 1)}) '
                          'apparaissent pâles sur la carte : leur position '
                          'dépend surtout d\'axes qu\'elle ne montre pas.',
                  style: t.bodyMedium,
                ),
                if (poor.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final w in poor)
                        Pressable(
                          onTap: () => onWordTap(w.key),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(color: tones.rule),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${w.label} · ${_decimal(w.quality, 2)}',
                              style: TextStyle(
                                fontFamily: fontFamily,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: tones.muted,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'Le cos² mesure la part de la position d\'un mot que le '
                  'plan restitue : 1 = parfaitement, 0 = pas du tout.',
                  style: t.bodySmall?.copyWith(color: tones.muted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// La carte elle-même : mots en pastilles rondes, entretiens en carrés.
class FactorPlot extends StatefulWidget {
  const FactorPlot({
    super.key,
    required this.map,
    required this.onWordTap,
    this.documents = const [],
  });

  final FactorMap map;
  final List<FactorDocument> documents;
  final void Function(String key) onWordTap;

  @override
  State<FactorPlot> createState() => _FactorPlotState();
}

class _FactorPlotState extends State<FactorPlot>
    with SingleTickerProviderStateMixin {
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
    final ink = Theme.of(context).colorScheme.onSurface;
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.maxWidth;
        final layout = _PlotLayout(
          widget.map,
          widget.documents,
          side,
          ink: ink,
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

/// Un repère de la carte : un mot, plusieurs mots au même endroit, ou un
/// entretien.
class _Mark {
  _Mark({
    required this.at,
    required this.radius,
    required this.color,
    required this.textColor,
    required this.label,
    this.key,
    this.document = false,
    this.faint = false,
  });

  final Offset at;
  double radius;
  final Color color;
  final Color textColor;

  /// Libellés réunis ici (plusieurs quand des mots se superposent).
  final List<String> label;

  /// Clé du mot à ouvrir quand on touche le repère ; null pour un entretien.
  final String? key;
  final bool document;

  /// Mot mal représenté dans le plan : dessiné pâle.
  bool faint;

  TextPainter? text;
  Offset textAt = Offset.zero;

  String get caption {
    if (document) {
      final title = label.first;
      return title.length > 20 ? '${title.substring(0, 19)}…' : title;
    }
    if (label.length <= 2) return label.join(', ');
    return '${label.take(2).join(', ')} +${label.length - 2}';
  }
}

/// Placement des repères dans le carré de la carte : même échelle sur les
/// deux axes, mots superposés réunis, étiquettes posées sans chevauchement
/// en commençant par les entretiens puis par les mots qui pèsent le plus.
class _PlotLayout {
  _PlotLayout(
    FactorMap map,
    List<FactorDocument> documents,
    double side, {
    required Color ink,
    required Color Function(FactorWord) colorOf,
    required Color Function(FactorWord) textOf,
  }) {
    const pad = 30.0;
    final words = map.words;
    var minX = 0.0, maxX = 0.0, minY = 0.0, maxY = 0.0;
    var most = 1;
    void widen(double x, double y) {
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, y);
      maxY = math.max(maxY, y);
    }

    for (final w in words) {
      widen(w.x, w.y);
      most = math.max(most, w.count);
    }
    for (final d in documents) {
      widen(d.x, d.y);
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
    for (final d in documents) {
      marks.add(_Mark(
        at: place(d.x, d.y),
        radius: 5.5,
        color: ink,
        textColor: ink,
        label: [d.title],
        document: true,
      ));
    }
    final order = [for (var i = 0; i < words.length; i++) i]
      ..sort((a, b) => (words[b].contribX + words[b].contribY)
          .compareTo(words[a].contribX + words[a].contribY));
    for (final i in order) {
      final w = words[i];
      final at = place(w.x, w.y);
      final radius = 3.5 + 5.5 * math.sqrt(w.count / most);
      _Mark? same;
      for (final m in marks) {
        if (!m.document && (m.at - at).distance < 2) {
          same = m;
          break;
        }
      }
      final faint = w.quality < FactorMap.faintBelow;
      if (same != null) {
        same.label.add(w.label);
        same.radius = math.max(same.radius, radius);
        same.faint = same.faint && faint;
      } else {
        marks.add(_Mark(
          at: at,
          radius: radius,
          color: colorOf(w),
          textColor: textOf(w),
          label: [w.label],
          key: w.key,
          faint: faint,
        ));
      }
    }

    final bounds = Rect.fromLTWH(2, 2, side - 4, side - 4);
    // Une étiquette ne recouvre ni une autre étiquette ni un autre repère.
    final taken = <Rect>[
      for (final m in marks) Rect.fromCircle(center: m.at, radius: m.radius),
    ];
    for (final m in marks) {
      final tp = TextPainter(
        text: TextSpan(
          text: m.caption,
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: m.document ? FontWeight.w800 : FontWeight.w700,
            color: m.faint
                ? m.textColor.withValues(alpha: 0.45)
                : m.textColor,
          ),
        ),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();
      final p = m.at;
      final r = m.radius;
      final spots = [
        Offset(p.dx + r + 3, p.dy - tp.height / 2),
        Offset(p.dx - r - 3 - tp.width, p.dy - tp.height / 2),
        Offset(p.dx - tp.width / 2, p.dy - r - 2 - tp.height),
        Offset(p.dx - tp.width / 2, p.dy + r + 2),
        Offset(p.dx + r, p.dy - r - tp.height),
        Offset(p.dx + r, p.dy + r),
        Offset(p.dx - r - tp.width, p.dy - r - tp.height),
        Offset(p.dx - r - tp.width, p.dy + r),
      ];
      for (final spot in spots) {
        final rect = spot & tp.size;
        if (rect.left < bounds.left ||
            rect.top < bounds.top ||
            rect.right > bounds.right ||
            rect.bottom > bounds.bottom) {
          continue;
        }
        if (taken.any((o) => o.overlaps(rect))) continue;
        taken.add(rect);
        m.text = tp;
        m.textAt = spot;
        break;
      }
    }
  }

  late final Offset origin;

  /// Les entretiens d'abord, puis les mots du plus au moins contributif.
  final List<_Mark> marks = [];

  /// Mot le plus proche du point touché, s'il y en a un à portée de doigt.
  String? hit(Offset at) {
    String? best;
    var bestDistance = 26.0;
    for (final m in marks) {
      if (m.key == null) continue;
      final d = (m.at - at).distance;
      if (d < bestDistance) {
        bestDistance = d;
        best = m.key;
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

  /// 0 = tous les repères à l'origine, 1 = à leur place.
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

    Offset at(_Mark m) => Offset.lerp(o, m.at, progress)!;

    final ring = Paint()
      ..color = halo
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    // Les mots d'abord, les entretiens par-dessus.
    for (final m in layout.marks.reversed) {
      final p = at(m);
      if (m.document) {
        final square = RRect.fromRectAndRadius(
          Rect.fromCircle(center: p, radius: m.radius),
          const Radius.circular(3),
        );
        canvas.drawRRect(square, Paint()..color = m.color);
        canvas.drawRRect(square, ring);
      } else {
        canvas.drawCircle(p, m.radius,
            Paint()..color = m.color.withValues(alpha: m.faint ? 0.3 : 0.9));
        canvas.drawCircle(p, m.radius, ring);
      }
    }

    final opacity = ((progress - 0.4) / 0.6).clamp(0.0, 1.0);
    if (opacity <= 0) return;
    canvas.saveLayer(
      Offset.zero & size,
      Paint()..color = Colors.white.withValues(alpha: opacity),
    );
    for (final m in layout.marks) {
      final tp = m.text;
      if (tp == null) continue;
      tp.paint(canvas, m.textAt + (at(m) - m.at));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PlotPainter old) =>
      old.progress != progress || old.layout != layout || old.rule != rule;
}
