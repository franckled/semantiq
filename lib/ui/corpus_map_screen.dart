import 'dart:isolate';

import 'package:flutter/material.dart';

import '../data/interview.dart';
import '../engine/analysis.dart';
import '../engine/factorial.dart';
import '../services/settings.dart';
import 'app_scope.dart';
import 'common.dart';
import 'factor_view.dart';
import 'illustrations.dart';
import 'motion.dart';
import 'theme.dart';

/// Lance le calcul dans un isolat séparé, sans rien capturer de l'interface.
Future<CorpusMap?> _run(List<CorpusText> texts, AnalysisOptions options) =>
    Isolate.run(() => buildCorpusMap(texts, options));

/// Carte factorielle du corpus : les mots et les entretiens projetés
/// ensemble, pour voir ce qui rapproche ou oppose les entretiens.
class CorpusMapScreen extends StatefulWidget {
  const CorpusMapScreen({super.key, required this.store});

  final InterviewStore store;

  @override
  State<CorpusMapScreen> createState() => _CorpusMapScreenState();
}

class _CorpusMapScreenState extends State<CorpusMapScreen> {
  Future<CorpusMap?>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _compute(AppScope.of(context).settings);
  }

  Future<CorpusMap?> _compute(Settings s) {
    // Entretiens de recherche, dans l'ordre où ils ont été menés.
    final interviews = widget.store.items.where((i) => !i.isMeeting).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final texts = <CorpusText>[
      for (final i in interviews) (id: i.id, title: i.title, text: i.text),
    ];
    final options = AnalysisOptions(
      excludeInterviewer: s.excludeInterviewer,
      groupForms: s.groupForms,
      interviewerLabels: s.interviewerLabels,
      extraStopwords: {
        ...s.globalStopwordSet,
        for (final i in interviews) ...splitWords(i.stopwords),
      },
    );
    return _run(texts, options);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Carte du corpus')),
      body: Backdrop(
        variant: 2,
        child: SafeArea(
          top: false,
          bottom: false,
          child: FutureBuilder<CorpusMap?>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ListeningArt(size: 150),
                      const SizedBox(height: 12),
                      Text('Analyse du corpus…',
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                );
              }
              return CorpusMapView(corpus: snapshot.data);
            },
          ),
        ),
      ),
    );
  }
}

/// Contenu de la carte du corpus, sans la barre de titre. [corpus] est
/// null quand le corpus ne permet pas de la calculer.
class CorpusMapView extends StatelessWidget {
  const CorpusMapView({super.key, required this.corpus});

  final CorpusMap? corpus;

  @override
  Widget build(BuildContext context) {
    final pad = EdgeInsets.fromLTRB(
        16, 4, 16, 40 + MediaQuery.paddingOf(context).bottom);
    final t = Theme.of(context).textTheme;
    final tones = Tones.of(context);
    final c = corpus;
    if (c == null) {
      return ListView(
        padding: pad,
        children: const [
          EmptyState(
            title: 'Corpus trop mince pour une carte',
            message: 'Il faut au moins trois entretiens, et quelques mots '
                'employés trois fois ou plus. Avec deux entretiens, un seul '
                'axe existe : il n\'y a pas de carte à dessiner.',
            accent: Accent.mint,
          ),
        ],
      );
    }
    final map = c.map;
    final both = factorPercent(map.shareX + map.shareY);
    void open(String key) => _showWord(context, c, key);
    List<String> titles(int axis, bool positive) =>
        [for (final d in c.side(axis, positive: positive)) d.title];

    return ListView(
      padding: pad,
      children: [
        const SectionTitle(
          'Mots et entretiens',
          subtitle: 'Pincez pour zoomer · touchez un mot pour sa répartition',
          accent: Accent.mint,
        ),
        FadeSlideIn(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: AspectRatio(
              aspectRatio: 1,
              child: FactorPlot(
                map: map,
                documents: c.documents,
                onWordTap: open,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
          child: Text(
            'Carrés : les entretiens · ronds : les mots, plus gros quand ils '
            'sont fréquents, pâles quand ils sont mal représentés\n'
            'Axe horizontal : ${factorPercent(map.shareX)} de l\'inertie · '
            'axe vertical : ${factorPercent(map.shareY)}',
            style: t.bodySmall?.copyWith(color: tones.muted),
          ),
        ),
        const SectionTitle(
          'Oppositions',
          subtitle: 'Les entretiens et les mots de chaque côté d\'un axe',
          accent: Accent.violet,
        ),
        FactorAxisCard(
          title: 'Axe horizontal',
          share: map.shareX,
          lowLabel: 'À gauche',
          highLabel: 'À droite',
          low: map.pole(0, positive: false),
          high: map.pole(0, positive: true),
          lowDocuments: titles(0, false),
          highDocuments: titles(0, true),
          onWordTap: open,
        ),
        const SizedBox(height: 12),
        FactorAxisCard(
          title: 'Axe vertical',
          share: map.shareY,
          lowLabel: 'En bas',
          highLabel: 'En haut',
          low: map.pole(1, positive: false),
          high: map.pole(1, positive: true),
          lowDocuments: titles(1, false),
          highDocuments: titles(1, true),
          onWordTap: open,
        ),
        FactorScree(map: map),
        FactorReliability(map: map, onWordTap: open),
        const SizedBox(height: 16),
        TintCard(
          accent: Accent.mint,
          child: Text(
            'Un mot se place près des entretiens qui l\'emploient plus que '
            'les autres ; au centre, les mots communs à tous. Deux '
            'entretiens proches partagent leur vocabulaire, deux entretiens '
            'opposés sur un axe ne parlent pas avec les mêmes mots. La carte '
            'compare des vocabulaires, pas des opinions : c\'est à vous de '
            'l\'interpréter.\n\n'
            'Analyse factorielle des correspondances sur '
            '${map.words.length} mots et ${c.documents.length} entretiens. '
            'Les deux axes restituent $both de l\'inertie.',
            style: t.bodyMedium?.copyWith(color: Accent.mint.onSoft(context)),
          ),
        ),
      ],
    );
  }
}

/// Répartition d'un mot entre les entretiens du corpus.
void _showWord(BuildContext context, CorpusMap corpus, String key) {
  final counts = corpus.counts[key];
  if (counts == null) return;
  var label = key;
  double? quality;
  for (final w in corpus.map.words) {
    if (w.key == key) {
      label = w.label;
      quality = w.quality;
    }
  }
  final total = counts.fold<int>(0, (a, b) => a + b);
  final most = counts.fold<int>(1, (a, b) => b > a ? b : a);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      final t = Theme.of(ctx).textTheme;
      final tones = Tones.of(ctx);
      return ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.8),
        child: SafeArea(
          top: false,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Text(label, style: t.headlineMedium),
              const SizedBox(height: 4),
              Text(
                '$total occurrence${total > 1 ? 's' : ''} dans le corpus'
                '${quality == null ? '' : ' · cos² ${quality.toStringAsFixed(2).replaceAll('.', ',')}'}',
                style: t.bodyMedium?.copyWith(color: tones.muted),
              ),
              if (quality != null && quality < FactorMap.faintBelow)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Mot mal représenté sur la carte : sa position y est '
                    'peu fiable.',
                    style: t.bodySmall?.copyWith(color: tones.danger),
                  ),
                ),
              const SizedBox(height: 16),
              for (var j = 0; j < corpus.documents.length; j++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              corpus.documents[j].title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.titleSmall,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('${counts[j]}',
                              style: t.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      GrowBar(
                        value: counts[j] / most,
                        color: Palette.mint,
                        background: tones.rule,
                        height: 10,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
