import 'ai_result.dart';
import 'analysis.dart';
import 'french.dart';
import 'quotes.dart';
import 'transcript.dart';

/// Rapport d'analyse en Markdown, lisible tel quel ou importable dans un
/// traitement de texte.
String buildReport({
  required String title,
  required String text,
  required Analysis analysis,
  AiResult? ai,
  DateTime? date,
}) {
  final b = StringBuffer();
  final d = date ?? DateTime.now();
  b.writeln('# $title');
  b.writeln();
  b.writeln('Analyse produite le ${_date(d)} avec SemantiQ.');
  b.writeln();
  b.writeln('- Mots analysés : ${analysis.tokenCount} '
      '(${analysis.contentTokenCount} mots pleins)');
  b.writeln('- Phrases analysées : ${analysis.analyzedSentences.length}');
  if (analysis.transcript.hasSpeakers) {
    b.writeln('- Locuteurs : ${analysis.transcript.speakers.join(', ')}');
  }
  if (analysis.interviewerExcluded) {
    b.writeln("- Parole de l'enquêteur exclue des statistiques");
  }
  b.writeln();

  if (ai != null) {
    b.writeln('## Résumé (IA : ${ai.provider}, ${ai.model})');
    b.writeln();
    b.writeln(ai.summary);
    b.writeln();
    if (ai.themes.isNotEmpty) {
      b.writeln('### Thèmes');
      b.writeln();
      for (final t in ai.themes) {
        b.writeln('**${t.title}** — ${t.description}');
        b.writeln();
        for (final q in t.quotes) {
          b.writeln('> « $q »${_fidelityNote(q, text)}');
          b.writeln();
        }
      }
    }
  }

  b.writeln('## Résumé extractif');
  b.writeln();
  b.writeln('Phrases les plus centrales du verbatim, dans leur ordre '
      "d'apparition (méthode TextRank).");
  b.writeln();
  for (final s in analysis.summary) {
    b.writeln('- ${_who(s)}${s.text}');
  }
  b.writeln();

  b.writeln('## Phrases clés');
  b.writeln();
  for (final r in analysis.ranked) {
    b.writeln('${r.rank}. ${_who(r.sentence)}« ${r.sentence.text} » '
        '(score ${r.score.toStringAsFixed(2)})');
  }
  if (ai != null && ai.keyQuotes.isNotEmpty) {
    b.writeln();
    b.writeln("Proposées par l'IA :");
    b.writeln();
    for (final q in ai.keyQuotes) {
      b.writeln('- « $q »${_fidelityNote(q, text)}');
    }
  }
  b.writeln();

  b.writeln('## Mots les plus fréquents');
  b.writeln();
  b.writeln('| Rang | Mot | Occurrences | Phrases | Formes regroupées |');
  b.writeln('|---:|---|---:|---:|---|');
  var rank = 0;
  for (final w in analysis.words.take(50)) {
    rank++;
    b.writeln('| $rank | ${w.label} | ${w.count} | ${w.sentences.length} | '
        '${w.otherForms.join(', ')} |');
  }
  b.writeln();

  if (analysis.expressions.isNotEmpty) {
    b.writeln('## Expressions récurrentes');
    b.writeln();
    for (final e in analysis.expressions.take(25)) {
      b.writeln('- ${e.label} (${e.count})');
    }
    b.writeln();
  }

  if (analysis.correlations.isNotEmpty) {
    b.writeln('## Cooccurrences');
    b.writeln();
    b.writeln('Mots employés dans les mêmes phrases plus souvent que le '
        'hasard ne le voudrait. Affinité = log2 du rapport entre la '
        'fréquence observée et la fréquence attendue (1 = deux fois plus, '
        '2 = quatre fois plus).');
    b.writeln();
    b.writeln('| Mot | Mot | Phrases communes | Affinité | Jaccard |');
    b.writeln('|---|---|---:|---:|---:|');
    for (final c in analysis.correlations.take(40)) {
      b.writeln('| ${analysis.labelOf(c.a)} | ${analysis.labelOf(c.b)} | '
          '${c.together} | ${c.pmi.toStringAsFixed(2)} | '
          '${c.jaccard.toStringAsFixed(2)} |');
    }
    b.writeln();
  }

  b.writeln('## Verbatim');
  b.writeln();
  for (final t in analysis.transcript.turns) {
    final who = t.speaker == null ? '' : '**${t.speaker}** : ';
    b.writeln('$who${t.text}');
    b.writeln();
  }
  return b.toString();
}

/// Corpus au format IRaMuTeQ : une ligne étoilée par entretien, suivie du
/// texte. Les variables étoilées permettent ensuite de comparer les
/// entretiens entre eux (classification de Reinert, AFC…).
///
/// [onlyInterviewees] retire les tours de l'enquêteur quand ils sont
/// repérés.
String buildIramuteq(
  List<({String id, String text, Map<String, String> variables})> interviews, {
  bool onlyInterviewees = true,
  Set<String> interviewerLabels = defaultInterviewerLabels,
}) {
  final b = StringBuffer();
  for (final it in interviews) {
    final vars = <String>['*entretien_${_slug(it.id)}'];
    it.variables.forEach((k, v) {
      if (k.trim().isNotEmpty && v.trim().isNotEmpty) {
        vars.add('*${_slug(k)}_${_slug(v)}');
      }
    });
    b.writeln('**** ${vars.join(' ')}');
    final t = parseTranscript(it.text, interviewerLabels: interviewerLabels);
    for (final turn in t.turns) {
      if (onlyInterviewees && turn.isInterviewer) continue;
      b.writeln(_iramuteqClean(turn.text));
    }
    b.writeln();
  }
  return b.toString();
}

/// Tableau des fréquences (CSV, séparateur point-virgule pour Excel
/// français).
String buildFrequencyCsv(Analysis analysis) {
  final b = StringBuffer('mot;occurrences;phrases;formes\n');
  for (final w in analysis.words) {
    b.writeln('${_csv(w.label)};${w.count};${w.sentences.length};'
        '${_csv(w.forms.keys.join(' '))}');
  }
  return b.toString();
}

String _fidelityNote(String quote, String text) {
  final f = quoteFidelity(quote, text);
  if (f >= 1) return '';
  return ' ⚠ citation introuvable telle quelle dans le verbatim '
      '(${(f * 100).round()} % des mots retrouvés à la suite)';
}

String _who(Sentence s) => s.speaker == null ? '' : '${s.speaker} : ';

String _date(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Les variables IRaMuTeQ n'admettent ni espace ni caractère spécial.
String _slug(String s) =>
    stripAccents(s.trim().toLowerCase()).replaceAll(RegExp(r'[^0-9a-z]+'), '');

/// IRaMuTeQ réserve l'astérisque et interprète « - » en début de ligne.
String _iramuteqClean(String s) =>
    s.replaceAll('*', ' ').replaceAll(RegExp(r'^\s*-+\s*', multiLine: true), '');

String _csv(String s) =>
    s.contains(';') || s.contains('"') ? '"${s.replaceAll('"', '""')}"' : s;
