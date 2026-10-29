import 'french.dart';

/// Libellés reconnus comme désignant l'enquêteur (comparés sans accents ni
/// majuscules). L'utilisateur peut en ajouter dans les réglages.
const Set<String> defaultInterviewerLabels = {
  'e', 'enq', 'enqueteur', 'enquetrice', 'interviewer', 'intervieweur',
  'intervieweuse', 'i', 'q', 'chercheur', 'chercheuse', 'investigateur',
  'investigatrice', 'moi', 'question',
};

/// Un tour de parole : ce qu'un locuteur dit entre deux changements.
class Turn {
  const Turn({
    required this.index,
    required this.speaker,
    required this.isInterviewer,
    required this.text,
  });

  final int index;

  /// Libellé tel qu'écrit (« E », « P1 », « Dr Martin »), ou null si le
  /// texte n'indique pas les locuteurs.
  final String? speaker;
  final bool isInterviewer;
  final String text;
}

/// Une phrase du verbatim, rattachée à son tour de parole.
class Sentence {
  const Sentence({
    required this.index,
    required this.turn,
    required this.text,
    required this.speaker,
    required this.isInterviewer,
  });

  final int index;
  final int turn;
  final String text;
  final String? speaker;
  final bool isInterviewer;
}

/// Verbatim découpé en tours de parole et en phrases.
class Transcript {
  const Transcript(this.turns, this.sentences);

  final List<Turn> turns;
  final List<Sentence> sentences;

  /// Vrai si au moins un tour est attribué à un locuteur.
  bool get hasSpeakers => turns.any((t) => t.speaker != null);

  /// Vrai si l'enquêteur a été repéré, ce qui permet de l'exclure des
  /// statistiques.
  bool get hasInterviewer => turns.any((t) => t.isInterviewer);

  /// Locuteurs distincts, dans l'ordre d'apparition.
  List<String> get speakers {
    final seen = <String>[];
    for (final t in turns) {
      final s = t.speaker;
      if (s != null && !seen.contains(s)) seen.add(s);
    }
    return seen;
  }
}

final RegExp _labelLine = RegExp(
  r"^\s*[\[(]?([A-Za-zÀ-ÖØ-öø-ÿ][0-9A-Za-zÀ-ÖØ-öø-ÿ.' -]{0,23}?)[\])]?\s*[:：]\s*(.*)$",
);

/// Normalise un libellé de locuteur pour la comparaison.
String normalizeLabel(String label) =>
    stripAccents(label.toLowerCase()).replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Découpe [raw] en tours de parole puis en phrases.
///
/// Une ligne commençant par « Libellé : » ouvre un tour. Un libellé est
/// retenu s'il compte au plus trois mots et s'il est soit un libellé
/// d'enquêteur connu, soit porteur d'un chiffre (P1, Patient 2), soit
/// utilisé au moins deux fois dans le texte : cela évite de prendre
/// « Le souci c'est que : » pour un locuteur.
Transcript parseTranscript(
  String raw, {
  Set<String> interviewerLabels = defaultInterviewerLabels,
}) {
  final known = interviewerLabels.map(normalizeLabel).toSet();
  final lines = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');

  // Premier passage : libellés candidats et leur fréquence.
  final counts = <String, int>{};
  for (final line in lines) {
    final m = _labelLine.firstMatch(line);
    if (m == null) continue;
    final label = m.group(1)!.trim();
    if (label.split(RegExp(r'\s+')).length > 3) continue;
    counts[normalizeLabel(label)] = (counts[normalizeLabel(label)] ?? 0) + 1;
  }
  bool accepted(String label) {
    final n = normalizeLabel(label);
    if (n.isEmpty) return false;
    if (label.split(RegExp(r'\s+')).length > 3) return false;
    if (known.contains(n)) return true;
    if (RegExp(r'[0-9]').hasMatch(n)) return true;
    return (counts[n] ?? 0) >= 2;
  }

  // Second passage : regroupement des lignes en tours.
  final turns = <Turn>[];
  String? speaker;
  final buffer = StringBuffer();

  void flush() {
    final text = buffer.toString().trim();
    buffer.clear();
    if (text.isEmpty) return;
    final who = speaker;
    turns.add(Turn(
      index: turns.length,
      speaker: who,
      isInterviewer: who != null && known.contains(normalizeLabel(who)),
      text: text,
    ));
  }

  for (final line in lines) {
    // Repères de l'enregistrement (« ★ Moment marqué ») : hors analyse.
    if (line.trimLeft().startsWith('★')) continue;
    final m = _labelLine.firstMatch(line);
    if (m != null && accepted(m.group(1)!.trim())) {
      flush();
      speaker = m.group(1)!.trim();
      buffer.write(m.group(2));
    } else {
      if (line.trim().isEmpty) {
        // Une ligne vide sans libellé sépare les paragraphes d'un même
        // locuteur ; on garde le locuteur courant.
        buffer.write('\n');
        continue;
      }
      if (buffer.isNotEmpty) buffer.write('\n');
      buffer.write(line);
    }
  }
  flush();

  final sentences = <Sentence>[];
  for (final t in turns) {
    for (final s in splitSentences(t.text)) {
      sentences.add(Sentence(
        index: sentences.length,
        turn: t.index,
        text: s,
        speaker: t.speaker,
        isInterviewer: t.isInterviewer,
      ));
    }
  }
  return Transcript(turns, sentences);
}

final RegExp _sentenceEnd = RegExp(r'(?<=[.!?…])\s+|\n+');

/// Découpe un texte en phrases (ponctuation forte ou retour à la ligne).
List<String> splitSentences(String text) {
  return text
      .split(_sentenceEnd)
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty && RegExp(r'[0-9A-Za-zÀ-ÿ]').hasMatch(s))
      .toList();
}
