import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/interview.dart';
import '../engine/analysis.dart';
import '../engine/quotes.dart';
import '../engine/transcript.dart';
import 'common.dart';
import 'illustrations.dart';
import 'motion.dart';
import 'theme.dart';

const _pad = EdgeInsets.fromLTRB(16, 4, 16, 40);

typedef Section = ({String label, IconData icon, Accent accent});

/// Les cinq rubriques des résultats, chacune dans sa couleur.
const List<Section> sections = [
  (label: 'Résumé', icon: Icons.auto_awesome_rounded, accent: Accent.violet),
  (label: 'Phrases clés', icon: Icons.format_quote_rounded, accent: Accent.coral),
  (label: 'Mots', icon: Icons.bar_chart_rounded, accent: Accent.sun),
  (label: 'Corrélations', icon: Icons.hub_rounded, accent: Accent.mint),
  (label: 'Texte', icon: Icons.article_rounded, accent: Accent.sky),
];

/// Rubriques d'une réunion : le compte rendu remplace le résumé.
const List<Section> meetingSections = [
  (label: 'Compte rendu', icon: Icons.event_note_rounded, accent: Accent.rose),
  (label: 'Phrases clés', icon: Icons.format_quote_rounded, accent: Accent.coral),
  (label: 'Mots', icon: Icons.bar_chart_rounded, accent: Accent.sun),
  (label: 'Corrélations', icon: Icons.hub_rounded, accent: Accent.mint),
  (label: 'Texte', icon: Icons.article_rounded, accent: Accent.sky),
];

/// Barre d'onglets en pastilles colorées, qui suit le balayage entre les
/// rubriques.
class SectionTabBar extends StatefulWidget implements PreferredSizeWidget {
  const SectionTabBar({super.key, this.items = sections});

  final List<Section> items;

  @override
  Size get preferredSize => const Size.fromHeight(62);

  @override
  State<SectionTabBar> createState() => _SectionTabBarState();
}

class _SectionTabBarState extends State<SectionTabBar> {
  late final _keys = List.generate(widget.items.length, (_) => GlobalKey());
  TabController? _controller;
  int _last = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = DefaultTabController.of(context);
    if (c != _controller) {
      _controller?.removeListener(_onChange);
      _controller = c..addListener(_onChange);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    final i = _controller!.index;
    if (i == _last) return;
    _last = i;
    final ctx = _keys[i].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 300),
          curve: appCurve);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = DefaultTabController.of(context);
    return SizedBox(
      height: 62,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
        child: AnimatedBuilder(
          animation: c.animation!,
          builder: (context, _) {
            final pos = c.animation!.value;
            return Row(
              children: [
                for (var i = 0; i < widget.items.length; i++)
                  Padding(
                    key: _keys[i],
                    padding: const EdgeInsets.only(right: 8),
                    child: _Pill(
                      label: widget.items[i].label,
                      icon: widget.items[i].icon,
                      accent: widget.items[i].accent,
                      selected: (1 - (pos - i).abs()).clamp(0.0, 1.0),
                      onTap: () => c.animateTo(i),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Accent accent;

  /// 0 = non sélectionnée, 1 = sélectionnée (valeurs intermédiaires pendant
  /// le balayage).
  final double selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = Color.lerp(accent.soft(context), accent.color, selected)!;
    final fg = Color.lerp(accent.onSoft(context), Colors.white, selected)!;
    return Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: selected > 0.5
              ? [
                  BoxShadow(
                    color: accent.color.withValues(alpha: 0.3 * selected),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: fontFamily,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
    var n = 0;
    Widget step(Widget w) => FadeSlideIn.indexed(n++, child: w);

    return ListView(
      padding: _pad,
      children: [
        step(_StatsRow(analysis: a)),
        if (a.interviewerExcluded || !a.transcript.hasSpeakers)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
            child: Text(
              a.interviewerExcluded
                  ? 'Parole de l\'enquêteur exclue des statistiques.'
                  : 'Locuteurs non indiqués : les questions de l\'enquêteur '
                      'sont comptées avec les réponses.',
              style: t.bodySmall?.copyWith(color: tones.muted),
            ),
          ),
        const SizedBox(height: 18),
        step(ai == null
            ? AiInviteCard(
                title: 'Résumé par IA',
                text: 'Facultatif : un modèle de langage rédige un résumé et '
                    'propose des thèmes illustrés de verbatims. Chaque '
                    'citation est vérifiée dans le texte.',
                running: aiRunning,
                onGenerate: onGenerateAi,
              )
            : _AiSummary(
                interview: interview,
                running: aiRunning,
                onRegenerate: onGenerateAi,
              )),
        if (ai != null && ai.themes.isNotEmpty) ...[
          const SectionTitle('Thèmes proposés', accent: Accent.violet),
          for (var i = 0; i < ai.themes.length; i++)
            step(Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ThemeCard(
                index: i,
                title: ai.themes[i].title,
                description: ai.themes[i].description,
                quotes: ai.themes[i].quotes,
                transcript: interview.text,
              ),
            )),
        ],
        const SectionTitle(
          'Résumé extractif',
          subtitle: 'Les phrases les plus centrales, dans l\'ordre du texte · '
              'calculé sur l\'iPhone',
          accent: Accent.sky,
        ),
        if (a.summary.isEmpty)
          const EmptyState(
            title: 'Texte trop court',
            message: 'Il faut quelques phrases pour en extraire un résumé.',
          )
        else
          step(Card(
            child: Stack(
              children: [
                Positioned(
                  right: 14,
                  top: -14,
                  child: Text(
                    '»',
                    style: TextStyle(
                      fontFamily: displayFamily,
                      fontSize: 110,
                      color: Accent.sky.color.withValues(alpha: 0.15),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final s in a.summary)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: SentenceLine(sentence: s),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          )),
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
    Widget stat(int value, String label, IconData icon, Accent accent) =>
        Expanded(
          child: TintCard(
            accent: accent,
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: accent.onSoft(context)),
                const SizedBox(height: 8),
                AnimatedCount(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: accent.onSoft(context),
                      ),
                ),
                Text(label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: accent.onSoft(context),
                          fontWeight: FontWeight.w700,
                        )),
              ],
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          stat(a.tokenCount, 'mots', Icons.text_fields_rounded, Accent.violet),
          const SizedBox(width: 10),
          stat(a.analyzedSentences.length, 'phrases',
              Icons.short_text_rounded, Accent.coral),
          const SizedBox(width: 10),
          stat(a.transcript.speakers.length, 'locuteurs',
              Icons.groups_rounded, Accent.mint),
        ],
      ),
    );
  }
}

/// Encadré en dégradé qui invite à générer un résumé par IA.
class AiInviteCard extends StatelessWidget {
  const AiInviteCard({
    super.key,
    required this.title,
    required this.text,
    required this.running,
    required this.onGenerate,
  });

  final String title;
  final String text;
  final bool running;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tones = Tones.of(context);
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: Palette.brand),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: tones.raised,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const IconBadge(Icons.auto_awesome_rounded,
                    accent: Accent.violet, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title, style: t.titleLarge),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              text,
              style: t.bodyMedium?.copyWith(color: tones.muted),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: running
                  ? const _Thinking()
                  : GradientButton(
                      label: 'Générer avec l\'IA',
                      icon: Icons.auto_awesome_rounded,
                      onPressed: onGenerate,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thinking extends StatelessWidget {
  const _Thinking();


  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Accent.violet.soft(context),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 46,
            height: 24,
            child: LoopingArt(
              period: const Duration(milliseconds: 1200),
              painter: (t, _) => _WavePainter(t),
            ),
          ),
          const SizedBox(width: 10),
          Text('L\'IA lit l\'entretien…',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Accent.violet.onSoft(context),
                  )),
        ],
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) => paintWave(
        canvas,
        Offset.zero & size,
        bars: 5,
        t: t,
        color: Palette.violet,
        colors: const [
          Palette.violet,
          Palette.rose,
          Palette.coral,
          Palette.sun,
          Palette.mint,
        ],
      );

  @override
  bool shouldRepaint(covariant _WavePainter old) => old.t != t;
}

class _AiSummary extends StatelessWidget {
  const _AiSummary({
    required this.interview,
    required this.running,
    required this.onRegenerate,
  });

  final Interview interview;
  final bool running;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tones = Tones.of(context);
    final ai = interview.ai!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 8, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const IconBadge(Icons.auto_awesome_rounded,
                    accent: Accent.violet, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Résumé par IA', style: t.titleMedium),
                      Text('${ai.provider} · ${ai.model}',
                          style: t.bodySmall?.copyWith(color: tones.muted)),
                    ],
                  ),
                ),
                running
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      )
                    : IconButton(
                        tooltip: 'Régénérer',
                        onPressed: onRegenerate,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: SelectableText(ai.summary, style: t.bodyLarge),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.index,
    required this.title,
    required this.description,
    required this.quotes,
    required this.transcript,
  });

  final int index;
  final String title;
  final String description;
  final List<String> quotes;
  final String transcript;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final accent = Accent.at(index + 1);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 6, color: accent.color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: accent.soft(context),
                            shape: BoxShape.circle,
                          ),
                          child: Text('${index + 1}',
                              style: t.labelLarge
                                  ?.copyWith(color: accent.onSoft(context))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(title, style: t.titleMedium)),
                      ],
                    ),
                    if (description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Text(description,
                            style: t.bodyMedium
                                ?.copyWith(color: Tones.of(context).muted)),
                      ),
                    for (final q in quotes)
                      QuoteTile(quote: q, transcript: transcript, accent: accent),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Citation proposée par l'IA, avec le résultat de sa vérification.
class QuoteTile extends StatelessWidget {
  const QuoteTile({
    super.key,
    required this.quote,
    required this.transcript,
    this.accent = Accent.violet,
  });

  final String quote;
  final String transcript;
  final Accent accent;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tones = Tones.of(context);
    final f = quoteFidelity(quote, transcript);
    final exact = f >= 1;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: exact ? accent.soft(context) : Accent.coral.soft(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            '« $quote »',
            style: t.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
              color: exact ? accent.onSoft(context) : null,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                exact ? Icons.verified_rounded : Icons.warning_amber_rounded,
                size: 15,
                color: exact ? accent.onSoft(context) : tones.danger,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  exact
                      ? 'Retrouvée mot pour mot dans le verbatim'
                      : 'Introuvable telle quelle (${(f * 100).round()} % des '
                          'mots à la suite) : à vérifier avant de la citer',
                  style: t.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: exact ? accent.onSoft(context) : tones.danger,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SentenceLine extends StatelessWidget {
  const SentenceLine({super.key, required this.sentence, this.highlight});

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
            padding: const EdgeInsets.only(bottom: 6),
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
    final ai = interview.ai;
    if (analysis.ranked.isEmpty) {
      return ListView(
        padding: _pad,
        children: const [
          EmptyState(
            title: 'Texte trop court',
            message: 'Ajoutez du texte pour faire ressortir les phrases clés.',
            accent: Accent.coral,
          ),
        ],
      );
    }
    return ListView(
      padding: _pad,
      children: [
        const SectionTitle(
          'Phrases les plus centrales',
          subtitle: 'Celles qui partagent le plus de vocabulaire avec le reste '
              'de l\'entretien (TextRank)',
          accent: Accent.coral,
        ),
        for (var i = 0; i < analysis.ranked.length; i++)
          FadeSlideIn.indexed(
            i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RankedCard(ranked: analysis.ranked[i]),
            ),
          ),
        if (ai != null && ai.keyQuotes.isNotEmpty) ...[
          SectionTitle('Proposées par l\'IA',
              subtitle: ai.provider, accent: Accent.violet),
          for (final q in ai.keyQuotes)
            QuoteTile(quote: q, transcript: interview.text),
        ],
        if (analysis.expressions.isNotEmpty) ...[
          const SectionTitle(
            'Expressions récurrentes',
            subtitle: 'Groupes de mots employés au moins deux fois',
            accent: Accent.mint,
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < analysis.expressions.length; i++)
                Builder(builder: (context) {
                  final e = analysis.expressions[i];
                  final accent = Accent.at(i);
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: accent.soft(context),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text.rich(
                      TextSpan(
                        style: t.bodyMedium?.copyWith(
                          color: accent.onSoft(context),
                          fontWeight: FontWeight.w700,
                        ),
                        children: [
                          TextSpan(text: e.label),
                          TextSpan(
                            text: '  ${e.count}',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ],
      ],
    );
  }
}

class _RankedCard extends StatelessWidget {
  const _RankedCard({required this.ranked});

  final RankedSentence ranked;

  @override
  Widget build(BuildContext context) {
    final tones = Tones.of(context);
    final top = ranked.rank <= 3;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: top
                    ? const LinearGradient(
                        colors: [Palette.coral, Palette.sun],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: top ? null : Accent.coral.soft(context),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${ranked.rank}',
                style: TextStyle(
                  fontFamily: displayFamily,
                  fontSize: 18,
                  color: top ? Colors.white : Accent.coral.onSoft(context),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SentenceLine(sentence: ranked.sentence),
                  const SizedBox(height: 12),
                  GrowBar(
                    value: ranked.score,
                    color: Palette.coral,
                    background: tones.rule,
                    height: 6,
                    gradient: const LinearGradient(
                        colors: [Palette.coral, Palette.sun]),
                  ),
                ],
              ),
            ),
          ],
        ),
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
      return ListView(
        padding: _pad,
        children: const [
          EmptyState(
            title: 'Aucun mot à analyser',
            message: 'Le texte est vide ou ne contient que des mots-outils.',
            accent: Accent.sun,
          ),
        ],
      );
    }
    final max = a.words.first.count;
    return ListView(
      padding: _pad,
      children: [
        const SizedBox(height: 12),
        _Podium(words: a.words.take(3).toList(), onTap: widget.onWordTap),
        SectionTitle(
          'Mots les plus fréquents',
          subtitle: '${a.contentTokenCount} mots pleins · touchez un mot',
          accent: Accent.sun,
          trailing: _Toggle(
            cloud: _cloud,
            onChanged: (v) => setState(() => _cloud = v),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _cloud
              ? _WordCloud(
                  key: const ValueKey('cloud'),
                  words: a.words.take(60).toList(),
                  onTap: widget.onWordTap,
                )
              : Column(
                  key: const ValueKey('list'),
                  children: [
                    for (var i = 0; i < a.words.length; i++)
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => widget.onWordTap(a.words[i]),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 4),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 30,
                                child: Text('${i + 1}',
                                    style: t.bodySmall
                                        ?.copyWith(color: tones.muted)),
                              ),
                              SizedBox(
                                width: 118,
                                child: Text(a.words[i].label,
                                    style: t.bodyLarge?.copyWith(
                                        fontWeight: FontWeight.w700),
                                    overflow: TextOverflow.ellipsis),
                              ),
                              Expanded(
                                child: GrowBar(
                                  value: a.words[i].count / max,
                                  color: Palette.sun,
                                  background: Colors.transparent,
                                  height: 14,
                                  gradient: const LinearGradient(
                                      colors: [Palette.sun, Palette.coral]),
                                ),
                              ),
                              SizedBox(
                                width: 42,
                                child: Text('${a.words[i].count}',
                                    textAlign: TextAlign.right,
                                    style: t.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Les trois mots les plus fréquents, en marches de podium.
class _Podium extends StatelessWidget {
  const _Podium({required this.words, required this.onTap});

  final List<WordStat> words;
  final void Function(WordStat) onTap;

  @override
  Widget build(BuildContext context) {
    const order = [1, 0, 2];
    const heights = [120.0, 96.0, 82.0];
    const accents = [Accent.sun, Accent.violet, Accent.coral];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final i in order)
          if (i < words.length)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FadeSlideIn(
                  delay: Duration(milliseconds: 80 * i),
                  offset: 30,
                  child: Pressable(
                    onTap: () => onTap(words[i]),
                    child: Container(
                      height: heights[i],
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: accents[i].gradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: accents[i].color.withValues(alpha: 0.3),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontFamily: displayFamily,
                              fontSize: 22,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          Column(
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  words[i].label,
                                  style: const TextStyle(
                                    fontFamily: fontFamily,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Text(
                                '× ${words[i].count}',
                                style: TextStyle(
                                  fontFamily: fontFamily,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
      ],
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.cloud, required this.onChanged});

  final bool cloud;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget btn(bool value, IconData icon) {
      final sel = cloud == value;
      return Pressable(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 42,
          height: 36,
          decoration: BoxDecoration(
            color: sel ? Palette.sun : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon,
              size: 20,
              color: sel ? Palette.ink : Accent.sun.onSoft(context)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Accent.sun.soft(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(true, Icons.cloud_rounded),
          btn(false, Icons.format_list_numbered_rounded),
        ],
      ),
    );
  }
}

class _WordCloud extends StatelessWidget {
  const _WordCloud({super.key, required this.words, required this.onTap});

  final List<WordStat> words;
  final void Function(WordStat) onTap;

  @override
  Widget build(BuildContext context) {
    final max = words.first.count;
    final min = words.last.count;
    final rank = {for (var i = 0; i < words.length; i++) words[i].key: i};
    // Ordre alphabétique pour un nuage lisible ; taille selon la fréquence,
    // couleur selon le rang.
    final sorted = [...words]..sort((a, b) => a.label.compareTo(b.label));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 10,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final w in sorted)
              Builder(builder: (context) {
                final r =
                    max == min ? 1.0 : math.sqrt((w.count - min) / (max - min));
                final i = rank[w.key]!;
                final accent = Accent.at(i);
                final color = r > 0.25
                    ? accent.onSoft(context)
                    : Tones.of(context).muted;
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 380 + 12 * (i % 30)),
                  curve: Curves.easeOutBack,
                  builder: (context, v, child) =>
                      Transform.scale(scale: v, child: child),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onTap(w),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: r > 0.6
                          ? BoxDecoration(
                              color: accent.soft(context),
                              borderRadius: BorderRadius.circular(10),
                            )
                          : null,
                      child: Text(
                        w.label,
                        style: TextStyle(
                          fontFamily: r > 0.45 ? displayFamily : fontFamily,
                          fontSize: 14 + 24 * r,
                          fontWeight:
                              r > 0.45 ? FontWeight.w400 : FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
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
    final rank = analysis.words.indexWhere((x) => x.key == wordKey);
    final accent = Accent.at(rank < 0 ? 0 : rank);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(w.label,
                    style: t.headlineMedium?.copyWith(
                        color: accent.onSoft(context))),
              ),
              TextButton.icon(
                onPressed: () => onIgnore(w.label),
                icon: const Icon(Icons.visibility_off_rounded, size: 18),
                label: const Text('Ignorer'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Fact('${w.count}', 'occurrence${w.count > 1 ? 's' : ''}',
                  accent),
              _Fact('${w.sentences.length}',
                  'phrase${w.sentences.length > 1 ? 's' : ''}', Accent.sky),
              if (rank >= 0) _Fact('n° ${rank + 1}', 'du classement', Accent.sun),
            ],
          ),
          if (w.otherForms.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('Formes regroupées : ${w.forms.keys.join(', ')}',
                  style: t.bodyMedium?.copyWith(color: tones.muted)),
            ),
          if (links.isNotEmpty) ...[
            const SectionTitle('Souvent employé avec', accent: Accent.mint),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in links.take(12))
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: tones.linkSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${analysis.labelOf(c.a == wordKey ? c.b : c.a)}  ×${c.together}',
                      style: t.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Accent.mint.onSoft(context),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          SectionTitle('Dans le texte',
              subtitle: '${sentences.length} phrases', accent: Accent.sky),
          for (final s in sentences)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SentenceLine(
                sentence: s,
                highlight: (word) => forms.contains(word),
              ),
            ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.value, this.label, this.accent);

  final String value;
  final String label;
  final Accent accent;

  @override
  Widget build(BuildContext context) {
    final fg = accent.onSoft(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accent.soft(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text.rich(
        TextSpan(
          style: TextStyle(fontFamily: fontFamily, color: fg, fontSize: 14),
          children: [
            TextSpan(
                text: '$value ',
                style: const TextStyle(fontWeight: FontWeight.w900)),
            TextSpan(text: label),
          ],
        ),
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
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 14),
            child: Row(
              children: [
                Container(
                  width: 18,
                  height: 10,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: tones.markerSoft,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Text('Phrases clés surlignées',
                    style: t.bodySmall?.copyWith(color: tones.muted)),
              ],
            ),
          );
        }
        final turn = turns[i - 1];
        final accent = turn.speaker == null ? null : Accent.forKey(turn.speaker!);
        final style = t.bodyLarge?.copyWith(
          color: turn.isInterviewer ? tones.muted : null,
          fontStyle: turn.isInterviewer ? FontStyle.italic : null,
        );
        return Padding(
          padding: EdgeInsets.only(
            bottom: 12,
            left: turn.isInterviewer ? 0 : 18,
            right: turn.isInterviewer ? 18 : 0,
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: turn.isInterviewer || accent == null
                  ? tones.raised
                  : accent.soft(context).withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: tones.rule),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (turn.speaker != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
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
          ),
        );
      },
    );
  }
}
