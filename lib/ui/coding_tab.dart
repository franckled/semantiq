import 'package:flutter/material.dart';

import '../data/interview.dart';
import '../engine/analysis.dart';
import '../engine/coding.dart';
import '../engine/quotes.dart';
import '../engine/transcript.dart';
import 'codebook_screen.dart';
import 'common.dart';
import 'motion.dart';
import 'theme.dart';

/// Codage thématique : le chercheur pose ses codes, phrase après phrase,
/// sur la parole des personnes interrogées. Rien n'est proposé par une
/// machine : les codes sont les siens.
class CodingTab extends StatelessWidget {
  const CodingTab({
    super.key,
    required this.analysis,
    required this.interview,
    required this.store,
  });

  final Analysis analysis;
  final Interview interview;
  final InterviewStore store;

  @override
  Widget build(BuildContext context) {
    final turns = analysis.transcript.turns;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        itemCount: turns.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) return _Header(interview: interview, store: store);
          return _TurnCard(
            turn: turns[i - 1],
            interview: interview,
            store: store,
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.interview, required this.store});

  final Interview interview;
  final InterviewStore store;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tones = Tones.of(context);
    final fg = Accent.violet.onSoft(context);
    final n = interview.codings.length;
    final codes = {for (final k in interview.codings) k.codeId}.length;
    final lost = interview.codings
        .where((k) => quoteFidelity(k.quote, interview.text) < 1)
        .length;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TintCard(
            accent: Accent.violet,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n == 0
                      ? 'Touchez une phrase pour lui poser un code'
                      : '$n extrait${n > 1 ? 's' : ''} codé${n > 1 ? 's' : ''}'
                          ' · $codes code${codes > 1 ? 's' : ''}',
                  style: t.titleMedium?.copyWith(color: fg),
                ),
                const SizedBox(height: 6),
                Text(
                  'Un code nomme l\'idée que porte un extrait : « Attente », '
                  '« Confiance »… Vos codes sont communs à tous vos '
                  'entretiens et se rassemblent dans le livre de codes.',
                  style: t.bodyMedium?.copyWith(color: fg),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                        builder: (_) => CodebookScreen(store: store)),
                  ),
                  icon: const Icon(Icons.menu_book_rounded),
                  label: const Text('Livre de codes'),
                ),
              ],
            ),
          ),
          if (lost > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 16, color: tones.danger),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$lost extrait${lost > 1 ? 's' : ''} codé'
                      '${lost > 1 ? 's' : ''} ne se '
                      '${lost > 1 ? 'retrouvent' : 'retrouve'} plus tel quel '
                      'dans le texte, corrigé depuis. À revoir dans le livre '
                      'de codes.',
                      style: t.bodySmall?.copyWith(color: tones.danger),
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

class _TurnCard extends StatelessWidget {
  const _TurnCard({
    required this.turn,
    required this.interview,
    required this.store,
  });

  final Turn turn;
  final Interview interview;
  final InterviewStore store;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tones = Tones.of(context);
    final style = t.bodyLarge?.copyWith(
      color: turn.isInterviewer ? tones.muted : null,
      fontStyle: turn.isInterviewer ? FontStyle.italic : null,
    );
    return Padding(
      padding: EdgeInsets.only(
        bottom: 12,
        left: turn.isInterviewer ? 0 : 12,
        right: turn.isInterviewer ? 12 : 0,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
        decoration: BoxDecoration(
          color: tones.raised,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tones.rule),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (turn.speaker != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                child: SpeakerChip(turn.speaker!,
                    interviewer: turn.isInterviewer),
              ),
            for (final s in splitSentences(turn.text))
              if (turn.isInterviewer)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
                  child: Text(s, style: style),
                )
              else
                _CodableSentence(
                  text: s,
                  style: style,
                  codes: store.codesOf(interview, s),
                  onTap: () => showCodeSheet(
                    context,
                    store: store,
                    interview: interview,
                    quote: s,
                    speaker: turn.speaker,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _CodableSentence extends StatelessWidget {
  const _CodableSentence({
    required this.text,
    required this.style,
    required this.codes,
    required this.onTap,
  });

  final String text;
  final TextStyle? style;
  final List<Code> codes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final first = codes.isEmpty ? null : Accent.at(codes.first.color);
    return Semantics(
      button: true,
      hint: codes.isEmpty ? 'Poser un code' : 'Modifier les codes',
      child: Pressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: first?.soft(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: style),
              if (codes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final c in codes) CodePill(code: c, selected: true),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Étiquette d'un code, dans sa teinte. Pleine quand le code est posé.
class CodePill extends StatelessWidget {
  const CodePill({
    super.key,
    required this.code,
    this.selected = false,
    this.large = false,
    this.onTap,
  });

  final Code code;
  final bool selected;

  /// Taille confortable pour le doigt (choix d'un code).
  final bool large;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Accent.at(code.color);
    // Fond foncé sous texte blanc : lisible dans les six teintes.
    final bg = selected ? accent.deep : accent.soft(context);
    final fg = selected ? Colors.white : accent.onSoft(context);
    final pill = ConstrainedBox(
      // Dans une feuille de choix, un long libellé passe à la ligne plutôt
      // que d'être coupé.
      constraints: BoxConstraints(maxWidth: large ? double.infinity : 300),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: large ? 14 : 10,
          vertical: large ? 11 : 4,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(large ? 14 : 10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (large) ...[
              Icon(
                selected ? Icons.check_rounded : Icons.add_rounded,
                size: 18,
                color: fg,
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                code.label,
                overflow: large ? null : TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontWeight: FontWeight.w700,
                  fontSize: large ? 15 : 13,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (onTap == null) return pill;
    return Semantics(
      button: true,
      selected: selected,
      child: Pressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: pill,
      ),
    );
  }
}

/// Ouvre la feuille où l'on pose ou retire des codes sur un extrait.
Future<void> showCodeSheet(
  BuildContext context, {
  required InterviewStore store,
  required Interview interview,
  required String quote,
  String? speaker,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => CodeSheet(
      store: store,
      interview: interview,
      quote: quote,
      speaker: speaker,
    ),
  );
}

class CodeSheet extends StatefulWidget {
  const CodeSheet({
    super.key,
    required this.store,
    required this.interview,
    required this.quote,
    this.speaker,
  });

  final InterviewStore store;
  final Interview interview;
  final String quote;
  final String? speaker;

  @override
  State<CodeSheet> createState() => _CodeSheetState();
}

class _CodeSheetState extends State<CodeSheet> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool _has(Code code) => widget.store
      .codesOf(widget.interview, widget.quote)
      .any((c) => c.id == code.id);

  void _toggle(Code code) => widget.store
      .toggleCoding(widget.interview, code, widget.quote, widget.speaker);

  void _create() {
    final label = _name.text.trim();
    if (label.isEmpty) return;
    final code = widget.store.addCode(label);
    if (!_has(code)) _toggle(code);
    _name.clear();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tones = Tones.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) {
            final codes = widget.store.codes;
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Coder cet extrait', style: t.headlineSmall),
                  const SizedBox(height: 10),
                  TintCard(
                    accent: Accent.sun,
                    padding: const EdgeInsets.all(14),
                    child: Text(
                      '« ${widget.quote} »',
                      style: t.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: Accent.sun.onSoft(context),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _name,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _create(),
                          decoration: const InputDecoration(
                            labelText: 'Nouveau code',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: 'Créer ce code et le poser',
                        onPressed: _create,
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (codes.isEmpty)
                    Text(
                      'Pas encore de code. Nommez ci-dessus l\'idée que '
                      'porte cet extrait.',
                      style: t.bodyMedium?.copyWith(color: tones.muted),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in codes)
                          CodePill(
                            code: c,
                            large: true,
                            selected: _has(c),
                            onTap: () => _toggle(c),
                          ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  GradientButton(
                    label: 'Terminé',
                    icon: Icons.check_rounded,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
