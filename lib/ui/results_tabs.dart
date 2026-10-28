import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/interview.dart';
import '../engine/analysis.dart';
import '../engine/quotes.dart';
import '../engine/transcript.dart';
import 'common.dart';
import 'theme.dart';

const _pad = EdgeInsets.fromLTRB(16, 4, 16, 32);

// --- Résumé ------------------------------------------------------------------

class SummaryTab extends StatelessWidget {
  const SummaryTab({
    super.key,
    required this.analysis,
    required this.interview,
    required this.aiRunning,
    required this.onGenerateAi,
  });

  final Analysis analysis;
  final Interview interview;
  final bool aiRunning;
  final VoidCallback onGenerateAi;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tones = Tones.of(context);
    final ai = interview.ai;
    final a = analysis;

    return ListView(
      padding: _pad,
      children: [
        _StatsRow(analysis: a),
        SectionTitle(
          'Résumé par IA',
          subtitle: ai == null
              ? 'Rédigé par le modèle choisi dans les réglages'
              : '${ai.provider} · ${ai.model}',
          trailing: aiRunning
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5))
              : TextButton.icon(
                  onPressed: onGenerateAi,
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: Text(ai == null ? 'Générer' : 'Régénérer'),
                ),
        ),
        if (ai == null)
          Text(
            'Facultatif : un modèle de langage rédige un résumé et propose '
            'des thèmes illustrés de verbatims. Chaque citation est vérifiée '
            'dans le texte.',
            style: t.bodyMedium?.copyWith(color: tones.muted),
          )
        else ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(ai.summary, style: t.bodyLarge),
            ),
          ),
          if (ai.themes.isNotEmpty) ...[
            const SectionTitle('Thèmes proposés'),
            for (final theme in ai.themes)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(theme.title, style: t.titleMedium),
                        if (theme.description.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 6),
                            child: Text(theme.description,
                                style: t.bodyMedium
                                    ?.copyWith(color: tones.muted)),
                          ),
                        for (final q in theme.quotes)
                          QuoteTile(quote: q, transcript: interview.text),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ],
        const SectionTitle(
          'Résumé extractif',
          subtitle: 'Phrases les plus centrales, dans l\'ordre du texte · '
              'calculé sur l\'appareil',
        ),
        if (a.summary.isEmpty)
          Text('Texte trop court pour en extraire un résumé.',
              style: t.bodyMedium?.copyWith(color: tones.muted))
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final s in a.summary)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SentenceLine(sentence: s),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.analysis});

  final Analysis analysis;

  @override
  Widget build(BuildContext context) {
    final a = analysis;
    final tones = Tones.of(context);
    final t = Theme.of(context).textTheme;
    Widget stat(String value, String label) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: t.headlineSmall),
              Text(label, style: t.bodySmall?.copyWith(color: tones.muted)),
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              stat('${a.tokenCount}', 'mots'),
              stat('${a.analyzedSentences.length}', 'phrases'),
              stat('${a.transcript.speakers.length}', 'locuteurs'),
            ],
          ),
          if (a.interviewerExcluded)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Parole de l\'enquêteur exclue des statistiques.',
                style: t.bodySmall?.copyWith(color: tones.muted),
              ),
            )
          else if (!a.transcript.hasSpeakers)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Locuteurs non indiqués : les questions de l\'enquêteur sont '
                'comptées avec les réponses.',
                style: t.bodySmall?.copyWith(color: tones.muted),
              ),
            ),
        ],
      ),
    );
  }
}

/// Citation proposée par l'IA, avec le résultat de sa vérification.
class QuoteTile extends StatelessWidget {
  const QuoteTile({super.key, required this.quote, required this.transcript});

  final String quote;
  final String transcript;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tones = Tones.of(context);
    final scheme = Theme.of(context).colorScheme;
    final f = quoteFidelity(quote, transcript);
    final exact = f >= 1;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 20,
            margin: const EdgeInsets.only(top: 3, right: 10),
            color: exact ? tones.marker : scheme.error,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText('« $quote »',
                    style: t.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
                if (!exact)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Introuvable telle quelle dans le verbatim '
                      '(${(f * 100).round()} % des mots retrouvés à la suite) : '
                      'à vérifier avant de la citer.',
                      style: t.bodySmall?.copyWith(color: scheme.error),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SentenceLine extends StatelessWidget {
  const _SentenceLine({required this.sentence, this.highlight});

  final Sentence sentence;
  final bool Function(String word)? highlight;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final h = highlight;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sentence.speaker != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: SpeakerChip(sentence.speaker!,
                interviewer: sentence.isInterviewer),
          ),
        if (h == null)
          SelectableText(sentence.text, style: t.bodyLarge)
        else
          HighlightedText(sentence.text, matches: h, style: t.bodyLarge),
      ],
    );
  }
}

// --- Phrases clés ------------------------------------------------------------

class KeySentencesTab extends StatelessWidget {
  const KeySentencesTab({
    super.key,
    required this.analysis,
    required this.interview,
  });

  final Analysis analysis;
  final Interview interview;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tones = Tones.of(context);
    final ai = interview.ai;
    return ListView(
      padding: _pad,
      children: [
        const SectionTitle(
          'Phrases les plus centrales',
          subtitle: 'Celles qui partagent le plus de vocabulaire avec le reste '
              'de l\'entretien (TextRank)',
        ),
        if (analysis.ranked.isEmpty)
          Text('Texte trop court.',
              style: t.bodyMedium?.copyWith(color: tones.muted)),
        for (final r in analysis.ranked)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 30,
                      child: Text('${r.rank}',
                          style: t.titleLarge?.copyWith(color: tones.muted)),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SentenceLine(sentence: r.sentence),
                          const SizedBox(height: 8),
                          _ScoreBar(value: r.score),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (ai != null && ai.keyQuotes.isNotEmpty) ...[
          SectionTitle('Proposées par l\'IA', subtitle: ai.provider),
          for (final q in ai.keyQuotes)
            QuoteTile(quote: q, transcript: interview.text),
        ],
        if (analysis.expressions.isNotEmpty) ...[
          const SectionTitle(
            'Expressions récurrentes',
            subtitle: 'Groupes de mots employés au moins deux fois',
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in analysis.expressions)
                Chip(
                  label: Text('${e.label}  ${e.count}'),
                  side: BorderSide(color: tones.rule),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final tones = Tones.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1).toDouble(),
        minHeight: 5,
        color: tones.marker,
        backgroundColor: tones.markerSoft,
      ),
    );
  }
}

// --- Mots --------------------------------------------------------------------

class WordsTab extends StatefulWidget {
  const WordsTab({super.key, required this.analysis, required this.onWordTap});

  final Analysis analysis;
  final void Function(WordStat word) onWordTap;

  @override
  State<WordsTab> createState() => _WordsTabState();
}

class _WordsTabState extends State<WordsTab> {
  bool _cloud = true;

  @override
  Widget build(BuildContext context) {
    final a = widget.analysis;
    final t = Theme.of(context).textTheme;
    final tones = Tones.of(context);
    if (a.words.isEmpty) {
      return Center(
        child: Text('Aucun mot à analyser.',
            style: t.bodyMedium?.copyWith(color: tones.muted)),
      );
    }
    final max = a.words.first.count;
    return ListView(
      padding: _pad,
      children: [
        SectionTitle(
          'Mots les plus fréquents',
          subtitle: '${a.contentTokenCount} mots pleins · touchez un mot pour '
              'voir ses phrases',
          trailing: SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: true, icon: Icon(Icons.cloud_outlined)),
              ButtonSegment(value: false, icon: Icon(Icons.list)),
            ],
            selected: {_cloud},
            onSelectionChanged: (s) => setState(() => _cloud = s.first),
          ),
        ),
        if (_cloud)
          _WordCloud(words: a.words.take(60).toList(), onTap: widget.onWordTap)
        else
          for (var i = 0; i < a.words.length; i++)
            InkWell(
              onTap: () => widget.onWordTap(a.words[i]),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    SizedBox(
                      width: 34,
                      child: Text('${i + 1}',
                          style: t.bodySmall?.copyWith(color: tones.muted)),
                    ),
                    SizedBox(
                      width: 120,
                      child: Text(a.words[i].label,
                          style: t.bodyLarge,
                          overflow: TextOverflow.ellipsis),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, c) => Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            height: 14,
                            width: math.max(
                                4.0, c.maxWidth * a.words[i].count / max),
                            decoration: BoxDecoration(
                              color: tones.marker,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text('${a.words[i].count}',
                          textAlign: TextAlign.right,
                          style: t.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _WordCloud extends StatelessWidget {
  const _WordCloud({required this.words, required this.onTap});

  final List<WordStat> words;
  final void Function(WordStat) onTap;

  @override
  Widget build(BuildContext context) {
    final tones = Tones.of(context);
    final scheme = Theme.of(context).colorScheme;
    final max = words.first.count;
    final min = words.last.count;
    // Ordre alphabétique pour un nuage lisible, taille selon la fréquence.
    final sorted = [...words]..sort((a, b) => a.label.compareTo(b.label));
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final w in sorted)
          Builder(builder: (context) {
            final r = max == min
                ? 1.0
                : math.sqrt((w.count - min) / (max - min));
            final top = r > 0.6;
            return InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => onTap(w),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: top
                    ? BoxDecoration(
                        color: tones.markerSoft,
                        borderRadius: BorderRadius.circular(6),
                      )
                    : null,
                child: Text(
                  w.label,
                  style: TextStyle(
                    fontSize: 14 + 22 * r,
                    fontWeight: r > 0.3 ? FontWeight.w800 : FontWeight.w500,
                    color: Color.lerp(tones.muted, scheme.onSurface, r),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

/// Fiche d'un mot : formes, phrases où il apparaît, mots associés.
class WordSheet extends StatelessWidget {
  const WordSheet({
    super.key,
    required this.analysis,
    required this.wordKey,
    required this.onIgnore,
  });

  final Analysis analysis;
  final String wordKey;
  final void Function(String label) onIgnore;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tones = Tones.of(context);
    final w = analysis.word(wordKey);
    if (w == null) return const SizedBox(height: 200);
    final forms = w.forms.keys.toSet();
    final links = analysis.correlationsOf(wordKey);
    final sentences = [
      for (final i in w.sentences) analysis.transcript.sentences[i],
    ];

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Row(
            children: [
              Expanded(child: Text(w.label, style: t.headlineSmall)),
              TextButton.icon(
                onPressed: () => onIgnore(w.label),
                icon: const Icon(Icons.block, size: 18),
                label: const Text('Ignorer'),
              ),
            ],
          ),
          Text(
            '${w.count} occurrence${w.count > 1 ? 's' : ''} dans '
            '${w.sentences.length} phrase${w.sentences.length > 1 ? 's' : ''}'
            '${w.otherForms.isEmpty ? '' : ' · formes : ${w.forms.keys.join(', ')}'}',
            style: t.bodyMedium?.copyWith(color: tones.muted),
          ),
          if (links.isNotEmpty) ...[
            const SectionTitle('Souvent employé avec'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in links.take(12))
                  Chip(
                    backgroundColor: tones.linkSoft,
                    side: BorderSide.none,
                    label: Text(
                        '${analysis.labelOf(c.a == wordKey ? c.b : c.a)}  '
                        '×${c.together}'),
                  ),
              ],
            ),
          ],
          SectionTitle('Dans le texte', subtitle: '${sentences.length} phrases'),
          for (final s in sentences)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _SentenceLine(
                sentence: s,
                highlight: (word) => forms.contains(word),
              ),
            ),
        ],
      ),
    );
  }
}

// --- Texte -------------------------------------------------------------------

class TextTab extends StatelessWidget {
  const TextTab({super.key, required this.analysis});

  final Analysis analysis;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tones = Tones.of(context);
    final turns = analysis.transcript.turns;
    final key = {for (final r in analysis.ranked) r.sentence.text};
    return ListView.builder(
      padding: _pad,
      itemCount: turns.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
            child: Text(
              'Les phrases clés sont surlignées.',
              style: t.bodySmall?.copyWith(color: tones.muted),
            ),
          );
        }
        final turn = turns[i - 1];
        final style = t.bodyLarge?.copyWith(
          color: turn.isInterviewer ? tones.muted : null,
        );
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (turn.speaker != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: SpeakerChip(turn.speaker!,
                      interviewer: turn.isInterviewer),
                ),
              Text.rich(
                TextSpan(
                  style: style,
                  children: [
                    for (final s in splitSentences(turn.text))
                      TextSpan(
                        text: '$s ',
                        style: key.contains(s)
                            ? TextStyle(backgroundColor: tones.markerSoft)
                            : null,
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
