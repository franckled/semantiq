import 'dart:math' as math;

import 'french.dart';
import 'transcript.dart';

/// Réglages de l'analyse lexicale.
class AnalysisOptions {
  const AnalysisOptions({
    this.excludeInterviewer = true,
    this.groupForms = true,
    this.extraStopwords = const {},
    this.interviewerLabels = defaultInterviewerLabels,
    this.summarySentences = 6,
    this.keySentences = 12,
    this.maxWords = 150,
    this.networkWords = 40,
  });

  /// Ne compter que la parole des personnes interrogées quand l'enquêteur
  /// est repéré dans le texte.
  final bool excludeInterviewer;

  /// Regrouper pluriels, féminins et conjugaisons (« patient »,
  /// « patiente », « patients ») sous une même entrée.
  final bool groupForms;

  /// Mots à ignorer en plus des mots-outils (prénoms, lieux…), en minuscules.
  final Set<String> extraStopwords;
  final Set<String> interviewerLabels;
  final int summarySentences;
  final int keySentences;

  /// Nombre de mots gardés dans le tableau des fréquences.
  final int maxWords;

  /// Nombre de mots pris en compte pour les cooccurrences.
  final int networkWords;
}

/// Un mot (ou une famille de formes) et sa fréquence.
class WordStat {
  WordStat(this.key);

  /// Clé de regroupement (racine, ou forme exacte si pas de regroupement).
  final String key;
  int count = 0;

  /// Formes rencontrées et leur nombre.
  final Map<String, int> forms = {};

  /// Phrases (indices dans le verbatim) où le mot apparaît.
  final List<int> sentences = [];

  /// Forme la plus fréquente, utilisée pour l'affichage.
  String get label {
    var best = key;
    var n = -1;
    forms.forEach((f, c) {
      if (c > n || (c == n && f.length < best.length)) {
        best = f;
        n = c;
      }
    });
    return best;
  }

  /// Autres formes regroupées sous ce mot.
  List<String> get otherForms =>
      (forms.keys.where((f) => f != label).toList()..sort());
}

/// Une expression récurrente de plusieurs mots (« prise en charge »).
class Expression {
  Expression(this.key);
  final String key;
  int count = 0;
  final Map<String, int> forms = {};
  final List<int> sentences = [];

  String get label {
    var best = key;
    var n = -1;
    forms.forEach((f, c) {
      if (c > n) {
        best = f;
        n = c;
      }
    });
    return best;
  }

  int get length => key.split(' ').length;
}

/// Phrase retenue comme centrale, avec son score.
class RankedSentence {
  const RankedSentence(this.sentence, this.score, this.rank);
  final Sentence sentence;

  /// Score de centralité normalisé (1 = la plus centrale).
  final double score;
  final int rank;
}

/// Deux mots qui apparaissent ensemble plus souvent que le hasard ne le
/// voudrait.
class Correlation {
  const Correlation({
    required this.a,
    required this.b,
    required this.together,
    required this.pmi,
    required this.jaccard,
    required this.sentences,
  });

  /// Clés des deux mots (voir [WordStat.key]).
  final String a;
  final String b;

  /// Nombre de phrases contenant les deux mots.
  final int together;

  /// Information mutuelle ponctuelle (log2) : 0 = indépendance, 1 = deux
  /// fois plus souvent ensemble que par hasard, 2 = quatre fois…
  final double pmi;

  /// Indice de Jaccard : part des phrases contenant l'un ou l'autre qui
  /// contiennent les deux.
  final double jaccard;
  final List<int> sentences;
}

/// Résultat complet de l'analyse d'un verbatim.
class Analysis {
  Analysis({
    required this.transcript,
    required this.options,
    required this.analyzedSentences,
    required this.tokenCount,
    required this.contentTokenCount,
    required this.words,
    required this.expressions,
    required this.ranked,
    required this.summary,
    required this.correlations,
    required this.networkWords,
  });

  final Transcript transcript;
  final AnalysisOptions options;

  /// Indices des phrases prises en compte (sans l'enquêteur si exclu).
  final List<int> analyzedSentences;

  /// Nombre total de mots analysés.
  final int tokenCount;

  /// Nombre de mots pleins (hors mots-outils).
  final int contentTokenCount;

  /// Mots par fréquence décroissante.
  final List<WordStat> words;
  final List<Expression> expressions;

  /// Phrases clés, de la plus centrale à la moins centrale.
  final List<RankedSentence> ranked;

  /// Résumé extractif : phrases les plus centrales, dans l'ordre du texte.
  final List<Sentence> summary;
  final List<Correlation> correlations;

  /// Mots du réseau de cooccurrences.
  final List<WordStat> networkWords;

  /// L'enquêteur a-t-il été effectivement exclu ?
  bool get interviewerExcluded =>
      options.excludeInterviewer && transcript.hasInterviewer;

  WordStat? word(String key) {
    for (final w in words) {
      if (w.key == key) return w;
    }
    for (final w in networkWords) {
      if (w.key == key) return w;
    }
    return null;
  }

  String labelOf(String key) => word(key)?.label ?? key;

  /// Mots corrélés à [key], du plus fort au plus faible.
  List<Correlation> correlationsOf(String key) {
    final list = correlations.where((c) => c.a == key || c.b == key).toList()
      ..sort((x, y) => y.pmi.compareTo(x.pmi));
    return list;
  }
}

/// Mots de liaison admis à l'intérieur d'une expression (« maison de
/// santé », « prise en charge »), jamais à ses extrémités.
const Set<String> _connectors = {'de', 'du', 'des', 'd', 'en', 'à', 'au', 'aux'};

/// Analyse [text] : fréquences, expressions, phrases clés, résumé
/// extractif et cooccurrences. Calcul pur, sans dépendance à Flutter :
/// peut tourner dans un isolate.
Analysis analyze(String text, [AnalysisOptions options = const AnalysisOptions()]) {
  final transcript =
      parseTranscript(text, interviewerLabels: options.interviewerLabels);
  final excludeInterviewer =
      options.excludeInterviewer && transcript.hasInterviewer;
  final extra = options.extraStopwords.map((w) => w.toLowerCase()).toSet();
  String keyOf(String w) => options.groupForms ? stem(w) : w;

  final analyzed = <int>[];
  final sentenceKeys = <int, Set<String>>{};
  final words = <String, WordStat>{};
  final expressions = <String, Expression>{};
  var tokenCount = 0;
  var contentCount = 0;

  for (final s in transcript.sentences) {
    if (excludeInterviewer && s.isInterviewer) continue;
    analyzed.add(s.index);
    final tokens = tokenize(s.text);
    tokenCount += tokens.length;
    final keys = <String>{};

    // Mots pleins
    for (final t in tokens) {
      if (isStopword(t.surface, extra: extra)) continue;
      contentCount++;
      final k = keyOf(t.surface);
      final ws = words.putIfAbsent(k, () => WordStat(k));
      ws.count++;
      ws.forms[t.surface] = (ws.forms[t.surface] ?? 0) + 1;
      if (keys.add(k)) ws.sentences.add(s.index);
    }
    sentenceKeys[s.index] = keys;

    // Expressions : suites de mots pleins, éventuellement reliés par un mot
    // de liaison, d'au moins deux mots pleins.
    final seenHere = <String>{};
    for (final chunk in _chunks(tokens, extra)) {
      for (final gram in _grams(chunk)) {
        final surface = gram.map((t) => t.surface).join(' ');
        final key = gram
            .map((t) => _connectors.contains(t.surface) ? t.surface : keyOf(t.surface))
            .join(' ');
        final e = expressions.putIfAbsent(key, () => Expression(key));
        e.count++;
        e.forms[surface] = (e.forms[surface] ?? 0) + 1;
        if (seenHere.add(key)) e.sentences.add(s.index);
      }
    }
  }

  // Fréquences
  final wordList = words.values.toList()
    ..sort((a, b) {
      final c = b.count.compareTo(a.count);
      return c != 0 ? c : a.label.compareTo(b.label);
    });

  // Expressions : au moins deux occurrences ; on écarte celles qui ne sont
  // qu'un morceau d'une expression plus longue aussi fréquente.
  final exprList = expressions.values.where((e) => e.count >= 2).toList()
    ..sort((a, b) {
      final c = (b.count * b.length).compareTo(a.count * a.length);
      return c != 0 ? c : b.count.compareTo(a.count);
    });
  final keptExpr = <Expression>[];
  for (final e in exprList) {
    final absorbed = exprList.any((o) =>
        o != e &&
        o.length > e.length &&
        o.count >= e.count &&
        ' ${o.key} '.contains(' ${e.key} '));
    if (!absorbed) keptExpr.add(e);
    if (keptExpr.length >= 40) break;
  }

  // Phrases clés (TextRank)
  final ranked = _textRank(transcript, analyzed, sentenceKeys, options);
  final summary = ranked
      .take(options.summarySentences)
      .map((r) => r.sentence)
      .toList()
    ..sort((a, b) => a.index.compareTo(b.index));

  // Cooccurrences
  final network = wordList
      .where((w) => w.sentences.length >= 3)
      .take(options.networkWords)
      .toList();
  final correlations = _cooccurrences(network, analyzed.length);

  return Analysis(
    transcript: transcript,
    options: options,
    analyzedSentences: analyzed,
    tokenCount: tokenCount,
    contentTokenCount: contentCount,
    words: wordList.take(options.maxWords).toList(),
    expressions: keptExpr,
    ranked: ranked.take(options.keySentences).toList(),
    summary: summary,
    correlations: correlations,
    networkWords: network,
  );
}

/// Découpe une phrase en segments de mots pleins séparés par des mots-outils.
List<List<Token>> _chunks(List<Token> tokens, Set<String> extra) {
  final out = <List<Token>>[];
  var current = <Token>[];
  for (var i = 0; i < tokens.length; i++) {
    final t = tokens[i];
    final content = !isStopword(t.surface, extra: extra);
    if (content) {
      current.add(t);
    } else if (_connectors.contains(t.surface) &&
        current.isNotEmpty &&
        i + 1 < tokens.length &&
        !isStopword(tokens[i + 1].surface, extra: extra)) {
      current.add(t);
    } else {
      if (current.isNotEmpty) out.add(current);
      current = <Token>[];
    }
  }
  if (current.isNotEmpty) out.add(current);
  return out;
}

/// Sous-suites d'un segment qui commencent et finissent par un mot plein
/// et comptent deux ou trois mots pleins.
Iterable<List<Token>> _grams(List<Token> chunk) sync* {
  bool isContent(Token t) => !_connectors.contains(t.surface);
  for (var i = 0; i < chunk.length; i++) {
    if (!isContent(chunk[i])) continue;
    var contents = 1;
    for (var j = i + 1; j < chunk.length && j - i < 5; j++) {
      if (!isContent(chunk[j])) continue;
      contents++;
      if (contents > 3) break;
      yield chunk.sublist(i, j + 1);
    }
  }
}

List<RankedSentence> _textRank(
  Transcript transcript,
  List<int> analyzed,
  Map<int, Set<String>> keys,
  AnalysisOptions options,
) {
  // Phrases candidates : au moins trois mots pleins.
  var candidates = analyzed.where((i) => keys[i]!.length >= 3).toList();
  if (candidates.isEmpty) return const [];
  // Garde-fou de temps de calcul sur les très longs entretiens.
  if (candidates.length > 1500) {
    candidates = (candidates.toList()
          ..sort((a, b) => keys[b]!.length.compareTo(keys[a]!.length)))
        .take(1500)
        .toList()
      ..sort();
  }
  final n = candidates.length;
  final logLen = [for (final i in candidates) math.log(keys[i]!.length)];
  final edges = List.generate(n, (_) => <int, double>{});
  for (var a = 0; a < n; a++) {
    final ka = keys[candidates[a]]!;
    for (var b = a + 1; b < n; b++) {
      final kb = keys[candidates[b]]!;
      var common = 0;
      final small = ka.length < kb.length ? ka : kb;
      final big = identical(small, ka) ? kb : ka;
      for (final k in small) {
        if (big.contains(k)) common++;
      }
      if (common == 0) continue;
      final w = common / (logLen[a] + logLen[b]);
      edges[a][b] = w;
      edges[b][a] = w;
    }
  }
  final outWeight = [
    for (final e in edges) e.values.fold<double>(0, (s, w) => s + w),
  ];
  var score = List<double>.filled(n, 1.0);
  const d = 0.85;
  for (var iter = 0; iter < 40; iter++) {
    final next = List<double>.filled(n, 1 - d);
    for (var a = 0; a < n; a++) {
      if (outWeight[a] == 0) continue;
      final share = score[a] / outWeight[a];
      edges[a].forEach((b, w) => next[b] += d * w * share);
    }
    score = next;
  }

  final order = List<int>.generate(n, (i) => i)
    ..sort((x, y) => score[y].compareTo(score[x]));
  final maxScore = score[order.first];
  final result = <RankedSentence>[];
  final chosenKeys = <Set<String>>[];
  for (final o in order) {
    final idx = candidates[o];
    final k = keys[idx]!;
    // Écarte les quasi-doublons d'une phrase déjà retenue.
    final duplicate = chosenKeys.any((c) {
      final inter = c.intersection(k).length;
      return inter / math.min(c.length, k.length) > 0.8;
    });
    if (duplicate) continue;
    chosenKeys.add(k);
    result.add(RankedSentence(
      transcript.sentences[idx],
      maxScore == 0 ? 0 : score[o] / maxScore,
      result.length + 1,
    ));
    if (result.length >= math.max(options.keySentences, options.summarySentences)) {
      break;
    }
  }
  return result;
}

List<Correlation> _cooccurrences(List<WordStat> network, int sentenceTotal) {
  if (network.length < 2 || sentenceTotal == 0) return const [];
  final sets = [for (final w in network) w.sentences.toSet()];
  final out = <Correlation>[];
  for (var a = 0; a < network.length; a++) {
    for (var b = a + 1; b < network.length; b++) {
      final both = sets[a].intersection(sets[b]);
      if (both.length < 2) continue;
      final pa = sets[a].length / sentenceTotal;
      final pb = sets[b].length / sentenceTotal;
      final pab = both.length / sentenceTotal;
      final pmi = math.log(pab / (pa * pb)) / math.ln2;
      if (pmi <= 0) continue;
      final union = sets[a].length + sets[b].length - both.length;
      out.add(Correlation(
        a: network[a].key,
        b: network[b].key,
        together: both.length,
        pmi: pmi,
        jaccard: both.length / union,
        sentences: both.toList()..sort(),
      ));
    }
  }
  // Classement : force de l'association pondérée par le nombre de phrases
  // communes, pour ne pas faire remonter les rencontres uniques.
  out.sort((x, y) => (y.pmi * math.log(1 + y.together))
      .compareTo(x.pmi * math.log(1 + x.together)));
  return out.take(80).toList();
}
