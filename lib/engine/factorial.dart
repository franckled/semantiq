import 'dart:math' as math;

import 'analysis.dart';

/// Valeurs et vecteurs propres d'une matrice symétrique, par la méthode de
/// Jacobi (rotations successives). Les vecteurs sont les colonnes de
/// `vectors`. Suffisant et sûr pour les petites matrices de l'app
/// (quelques dizaines de lignes).
({List<double> values, List<List<double>> vectors}) symmetricEigen(
    List<List<double>> matrix) {
  final n = matrix.length;
  final a = [for (final row in matrix) List<double>.of(row)];
  final v = [
    for (var i = 0; i < n; i++)
      [for (var j = 0; j < n; j++) i == j ? 1.0 : 0.0],
  ];
  for (var sweep = 0; sweep < 60; sweep++) {
    var off = 0.0;
    for (var p = 0; p < n; p++) {
      for (var q = p + 1; q < n; q++) {
        off += a[p][q] * a[p][q];
      }
    }
    if (off < 1e-22) break;
    for (var p = 0; p < n; p++) {
      for (var q = p + 1; q < n; q++) {
        final apq = a[p][q];
        if (apq.abs() < 1e-300) continue;
        final theta = (a[q][q] - a[p][p]) / (2 * apq);
        final t = (theta >= 0 ? 1.0 : -1.0) /
            (theta.abs() + math.sqrt(theta * theta + 1));
        final c = 1 / math.sqrt(t * t + 1);
        final s = t * c;
        for (var k = 0; k < n; k++) {
          final akp = a[k][p];
          final akq = a[k][q];
          a[k][p] = c * akp - s * akq;
          a[k][q] = s * akp + c * akq;
        }
        for (var k = 0; k < n; k++) {
          final apk = a[p][k];
          final aqk = a[q][k];
          a[p][k] = c * apk - s * aqk;
          a[q][k] = s * apk + c * aqk;
        }
        for (var k = 0; k < n; k++) {
          final vkp = v[k][p];
          final vkq = v[k][q];
          v[k][p] = c * vkp - s * vkq;
          v[k][q] = s * vkp + c * vkq;
        }
      }
    }
  }
  return (values: [for (var i = 0; i < n; i++) a[i][i]], vectors: v);
}

/// Résultat d'une analyse factorielle des correspondances.
class Correspondence {
  const Correspondence({
    required this.total,
    required this.smallExpected,
    required this.inertia,
    required this.eigenvalues,
    required this.spectrum,
    required this.rows,
    required this.columns,
    required this.contributions,
    required this.quality,
  });

  /// Effectif total du tableau.
  final double total;

  /// Part des cases dont l'effectif attendu sous l'indépendance est
  /// inférieur à 5 (règle de Cochran : au-delà de 20 %, la loi du
  /// khi-deux n'est qu'une approximation grossière).
  final double smallExpected;

  /// Inertie totale du tableau (khi-deux divisé par l'effectif).
  final double inertia;

  /// Inertie portée par chaque axe gardé, du premier au dernier.
  final List<double> eigenvalues;

  /// Inertie de tous les axes du tableau, du plus fort au plus faible :
  /// l'éboulis des valeurs propres.
  final List<double> spectrum;

  /// Coordonnées principales des lignes : `rows[i][k]` sur l'axe k.
  final List<List<double>> rows;

  /// Coordonnées principales des colonnes.
  final List<List<double>> columns;

  /// Part de chaque ligne dans l'inertie de chaque axe (somme 1 par axe).
  final List<List<double>> contributions;

  /// Qualité de représentation de chaque ligne sur les axes gardés
  /// (cosinus carré, de 0 à 1).
  final List<double> quality;

  /// Part de l'inertie totale portée par l'axe [k].
  double share(int k) => inertia <= 0 ? 0 : eigenvalues[k] / inertia;

  /// Statistique du khi-deux d'indépendance du tableau.
  double get chi2 => total * inertia;

  /// Degrés de liberté : (lignes − 1) × (colonnes − 1).
  int get degrees => (rows.length - 1) * (columns.length - 1);

  /// Probabilité d'observer un écart à l'indépendance au moins aussi grand
  /// si les lignes et les colonnes étaient indépendantes.
  double get pValue => chiSquarePValue(chi2, degrees);
}

/// Probabilité qu'une variable du khi-deux à [degrees] degrés de liberté
/// dépasse [statistic].
double chiSquarePValue(double statistic, int degrees) {
  if (degrees <= 0) return 1;
  if (statistic <= 0) return 1;
  return upperGamma(degrees / 2, statistic / 2);
}

/// Fonction gamma incomplète supérieure régularisée Q(a, x), par la série
/// (x < a + 1) ou la fraction continue de Lentz (au-delà).
double upperGamma(double a, double x) {
  if (x <= 0) return 1;
  final logPrefix = -x + a * math.log(x) - _logGamma(a);
  if (x < a + 1) {
    var term = 1 / a;
    var sum = term;
    var ap = a;
    for (var n = 0; n < 1000; n++) {
      ap += 1;
      term *= x / ap;
      sum += term;
      if (term.abs() < sum.abs() * 1e-15) break;
    }
    return (1 - sum * math.exp(logPrefix)).clamp(0.0, 1.0);
  }
  const tiny = 1e-300;
  var b = x + 1 - a;
  var c = 1 / tiny;
  var d = 1 / b;
  var h = d;
  for (var i = 1; i < 1000; i++) {
    final an = -i * (i - a);
    b += 2;
    d = an * d + b;
    if (d.abs() < tiny) d = tiny;
    c = b + an / c;
    if (c.abs() < tiny) c = tiny;
    d = 1 / d;
    final delta = d * c;
    h *= delta;
    if ((delta - 1).abs() < 1e-15) break;
  }
  return (math.exp(logPrefix) * h).clamp(0.0, 1.0);
}

/// Logarithme de la fonction gamma (approximation de Lanczos).
double _logGamma(double x) {
  const g = 7.0;
  const coef = [
    0.99999999999980993,
    676.5203681218851,
    -1259.1392167224028,
    771.32342877765313,
    -176.61502916214059,
    12.507343278686905,
    -0.13857109526572012,
    9.9843695780195716e-6,
    1.5056327351493116e-7,
  ];
  if (x < 0.5) {
    return math.log(math.pi / math.sin(math.pi * x)) - _logGamma(1 - x);
  }
  final z = x - 1;
  var sum = coef[0];
  for (var i = 1; i < coef.length; i++) {
    sum += coef[i] / (z + i);
  }
  final t = z + g + 0.5;
  return 0.5 * math.log(2 * math.pi) +
      (z + 0.5) * math.log(t) -
      t +
      math.log(sum);
}

/// Analyse factorielle des correspondances du tableau de contingence
/// [table] (lignes × colonnes, effectifs positifs ou nuls, aucune ligne ni
/// colonne vide). Renvoie null si le tableau ne porte pas [axes] axes.
///
/// Méthode classique : décomposition des écarts à l'indépendance, pondérés
/// par les marges. Le signe de chaque axe, arbitraire, est fixé pour que la
/// ligne qui y pèse le plus soit du côté positif.
Correspondence? correspondence(List<List<double>> table, {int axes = 2}) {
  final rowCount = table.length;
  if (rowCount < 3) return null;
  final colCount = table.first.length;
  if (colCount < 3) return null;

  var total = 0.0;
  final r = List<double>.filled(rowCount, 0);
  final c = List<double>.filled(colCount, 0);
  for (var i = 0; i < rowCount; i++) {
    for (var j = 0; j < colCount; j++) {
      final x = table[i][j];
      total += x;
      r[i] += x;
      c[j] += x;
    }
  }
  if (total <= 0 || r.any((x) => x <= 0) || c.any((x) => x <= 0)) return null;
  for (var i = 0; i < rowCount; i++) {
    r[i] /= total;
  }
  for (var j = 0; j < colCount; j++) {
    c[j] /= total;
  }

  // Écarts à l'indépendance, standardisés.
  final s = [
    for (var i = 0; i < rowCount; i++)
      [
        for (var j = 0; j < colCount; j++)
          (table[i][j] / total - r[i] * c[j]) / math.sqrt(r[i] * c[j]),
      ],
  ];
  final gram = [
    for (var i = 0; i < rowCount; i++)
      [
        for (var j = 0; j < rowCount; j++)
          _dot(s[i], s[j]),
      ],
  ];
  final eigen = symmetricEigen(gram);
  final order = [for (var i = 0; i < rowCount; i++) i]
    ..sort((x, y) => eigen.values[y].compareTo(eigen.values[x]));
  final inertia = eigen.values.fold<double>(0, (sum, x) => sum + math.max(x, 0.0));
  if (order.length < axes || eigen.values[order[axes - 1]] < 1e-10) return null;

  final values = <double>[];
  final rows = [for (var i = 0; i < rowCount; i++) <double>[]];
  final columns = [for (var j = 0; j < colCount; j++) <double>[]];
  final contributions = [for (var i = 0; i < rowCount; i++) <double>[]];
  for (var k = 0; k < axes; k++) {
    final axis = order[k];
    final lambda = eigen.values[axis];
    final u = [for (var i = 0; i < rowCount; i++) eigen.vectors[i][axis]];
    var heaviest = 0;
    for (var i = 1; i < rowCount; i++) {
      if (u[i].abs() > u[heaviest].abs()) heaviest = i;
    }
    if (u[heaviest] < 0) {
      for (var i = 0; i < rowCount; i++) {
        u[i] = -u[i];
      }
    }
    final sigma = math.sqrt(lambda);
    values.add(lambda);
    for (var i = 0; i < rowCount; i++) {
      rows[i].add(u[i] * sigma / math.sqrt(r[i]));
      contributions[i].add(u[i] * u[i]);
    }
    for (var j = 0; j < colCount; j++) {
      var sum = 0.0;
      for (var i = 0; i < rowCount; i++) {
        sum += s[i][j] * u[i];
      }
      columns[j].add(sum / math.sqrt(c[j]));
    }
  }

  // Distance du khi-deux de chaque ligne au profil moyen, et part de cette
  // distance que les axes gardés restituent.
  final quality = List<double>.filled(rowCount, 0);
  for (var i = 0; i < rowCount; i++) {
    final distance = gram[i][i] / r[i];
    if (distance <= 0) continue;
    var shown = 0.0;
    for (final x in rows[i]) {
      shown += x * x;
    }
    quality[i] = math.min(1.0, shown / distance);
  }

  var small = 0;
  for (var i = 0; i < rowCount; i++) {
    for (var j = 0; j < colCount; j++) {
      if (r[i] * c[j] * total < 5) small++;
    }
  }
  final first = eigen.values[order.first];
  return Correspondence(
    total: total,
    smallExpected: small / (rowCount * colCount),
    inertia: inertia,
    eigenvalues: values,
    spectrum: [
      for (final k in order)
        if (eigen.values[k] > first * 1e-9) eigen.values[k],
    ],
    rows: rows,
    columns: columns,
    contributions: contributions,
    quality: quality,
  );
}

double _dot(List<double> a, List<double> b) {
  var sum = 0.0;
  for (var k = 0; k < a.length; k++) {
    sum += a[k] * b[k];
  }
  return sum;
}

/// Critère du coude sur un éboulis de valeurs propres décroissantes :
/// nombre d'axes à retenir, c'est-à-dire ceux qui précèdent la cassure la
/// plus nette de la courbe (plus forte différence seconde). Null s'il y a
/// moins de trois valeurs : une courbe à deux points n'a pas de coude.
///
/// C'est un repère visuel mis en chiffre, pas un test statistique.
int? elbowAxes(List<double> values) {
  if (values.length < 3) return null;
  var best = 0;
  var sharpest = double.negativeInfinity;
  for (var k = 0; k + 2 < values.length; k++) {
    final bend = values[k] - 2 * values[k + 1] + values[k + 2];
    if (bend > sharpest) {
      sharpest = bend;
      best = k;
    }
  }
  return best + 1;
}

/// Un mot placé sur la carte factorielle.
class FactorWord {
  const FactorWord({
    required this.key,
    required this.label,
    required this.count,
    required this.x,
    required this.y,
    required this.contribX,
    required this.contribY,
    required this.quality,
  });

  final String key;
  final String label;
  final int count;

  /// Coordonnées sur le premier et le deuxième axe.
  final double x;
  final double y;

  /// Part du mot dans l'inertie de chaque axe (0 à 1).
  final double contribX;
  final double contribY;

  /// Qualité de représentation dans le plan (0 à 1) : proche de 0, la
  /// position du mot sur la carte dit peu de chose.
  final double quality;
}

/// Carte factorielle d'un verbatim : les mots projetés sur les deux
/// premiers axes d'une analyse des correspondances du tableau
/// mots × segments de texte. Deux mots proches sont employés dans les
/// mêmes passages ; deux mots aux extrémités d'un axe s'excluent.
class FactorMap {
  const FactorMap({
    required this.words,
    required this.segments,
    required this.segmentSize,
    required this.shareX,
    required this.shareY,
    required this.inertia,
    this.spectrum = const [],
    this.chi2 = 0,
    this.degrees = 0,
    this.pValue = 1,
    this.smallExpected = 0,
  });

  final List<FactorWord> words;

  /// Nombre de segments de texte du tableau.
  final int segments;

  /// Taille visée d'un segment, en mots.
  final int segmentSize;

  /// Part de l'inertie portée par chaque axe (0 à 1).
  final double shareX;
  final double shareY;
  final double inertia;

  /// Éboulis : part de l'inertie portée par chaque axe du tableau, du
  /// premier au dernier (les deux premiers sont ceux de la carte).
  final List<double> spectrum;

  /// Test du khi-deux d'indépendance du tableau : statistique, degrés de
  /// liberté, valeur p, et part des effectifs attendus inférieurs à 5.
  final double chi2;
  final int degrees;
  final double pValue;
  final double smallExpected;

  /// Seuil de cos² sous lequel un mot est dit mal représenté.
  static const faintBelow = 0.3;

  /// Mots mal représentés dans le plan, du moins au mieux représenté.
  List<FactorWord> get poorlyShown =>
      [for (final w in words) if (w.quality < faintBelow) w]
        ..sort((a, b) => a.quality.compareTo(b.quality));

  /// Nombre d'axes que le critère du coude invite à retenir, ou null si
  /// le tableau en porte trop peu pour chercher un coude.
  int? get elbow => elbowAxes(spectrum);

  /// Mots qui pèsent le plus sur un côté de l'axe [axis] (0 ou 1) : ceux
  /// dont la contribution dépasse la moyenne, du plus au moins contributif.
  List<FactorWord> pole(int axis, {required bool positive, int max = 6}) {
    double coord(FactorWord w) => axis == 0 ? w.x : w.y;
    double contrib(FactorWord w) => axis == 0 ? w.contribX : w.contribY;
    final mean = 1 / words.length;
    final side = [
      for (final w in words)
        if ((coord(w) > 0) == positive && coord(w) != 0 && contrib(w) > mean) w,
    ]..sort((a, b) => contrib(b).compareTo(contrib(a)));
    return side.take(max).toList();
  }

  static final _cache = Expando<_Cached>();

  /// Carte de l'analyse [a], calculée une fois ; null si le texte est trop
  /// court pour porter deux axes.
  static FactorMap? of(Analysis a) =>
      (_cache[a] ??= _Cached(buildFactorMap(a))).map;
}

class _Cached {
  const _Cached(this.map);
  final FactorMap? map;
}

final _wordPattern = RegExp(r'\S+');

/// Découpe les phrases analysées en segments de texte d'environ [size]
/// mots (les « unités de contexte » de la statistique textuelle). Un reste
/// trop court est rattaché au segment précédent.
List<List<int>> textSegments(Analysis a, int size) {
  final segments = <List<int>>[];
  var current = <int>[];
  var length = 0;
  for (final i in a.analyzedSentences) {
    current.add(i);
    length += _wordPattern.allMatches(a.transcript.sentences[i].text).length;
    if (length >= size) {
      segments.add(current);
      current = <int>[];
      length = 0;
    }
  }
  if (current.isNotEmpty) {
    if (segments.isNotEmpty && length < size / 2) {
      segments.last.addAll(current);
    } else {
      segments.add(current);
    }
  }
  return segments;
}

/// Construit la carte factorielle de [a] à partir des [maxWords] mots les
/// plus fréquents présents dans au moins deux segments.
FactorMap? buildFactorMap(Analysis a, {int maxWords = 40}) {
  // Des segments assez courts pour en avoir une quinzaine dans un entretien
  // bref, sans dépasser les 40 mots d'usage pour un long.
  final size = math.min(40, math.max(15, a.tokenCount ~/ 15));
  final segments = textSegments(a, size);
  if (segments.length < 4) return null;
  final segmentOf = <int, int>{
    for (var j = 0; j < segments.length; j++)
      for (final i in segments[j]) i: j,
  };

  final chosen = <WordStat>[];
  final counts = <List<double>>[];
  for (final w in a.words) {
    if (w.count < 3) break;
    final row = List<double>.filled(segments.length, 0);
    for (final i in w.sentences) {
      final j = segmentOf[i];
      if (j != null) row[j] += 1;
    }
    if (row.where((x) => x > 0).length < 2) continue;
    chosen.add(w);
    counts.add(row);
    if (chosen.length >= maxWords) break;
  }
  if (chosen.length < 4) return null;

  // Les segments où aucun des mots retenus n'apparaît sortent du tableau.
  final kept = [
    for (var j = 0; j < segments.length; j++)
      if (counts.any((row) => row[j] > 0)) j,
  ];
  if (kept.length < 4) return null;
  final table = [
    for (final row in counts) [for (final j in kept) row[j]],
  ];

  final ca = correspondence(table);
  if (ca == null) return null;
  return FactorMap(
    words: [
      for (var i = 0; i < chosen.length; i++)
        FactorWord(
          key: chosen[i].key,
          label: chosen[i].label,
          count: chosen[i].count,
          x: ca.rows[i][0],
          y: ca.rows[i][1],
          contribX: ca.contributions[i][0],
          contribY: ca.contributions[i][1],
          quality: ca.quality[i],
        ),
    ],
    segments: kept.length,
    segmentSize: size,
    shareX: ca.share(0),
    shareY: ca.share(1),
    inertia: ca.inertia,
    spectrum: [for (final v in ca.spectrum) v / ca.inertia],
    chi2: ca.chi2,
    degrees: ca.degrees,
    pValue: ca.pValue,
    smallExpected: ca.smallExpected,
  );
}

/// Un entretien placé sur la carte du corpus.
class FactorDocument {
  const FactorDocument({
    required this.id,
    required this.title,
    required this.x,
    required this.y,
  });

  final String id;
  final String title;
  final double x;
  final double y;
}

/// Texte d'un entretien, tel que la carte du corpus le lit.
typedef CorpusText = ({String id, String title, String text});

/// Carte factorielle du corpus : analyse des correspondances du tableau
/// mots × entretiens. Un mot est attiré par les entretiens qui l'emploient
/// plus que les autres ; deux entretiens proches parlent avec les mêmes
/// mots, deux entretiens opposés sur un axe n'ont pas le même vocabulaire.
class CorpusMap {
  const CorpusMap({
    required this.map,
    required this.documents,
    required this.counts,
  });

  /// Les mots, leurs coordonnées et la part d'inertie des axes.
  final FactorMap map;

  /// Les entretiens du tableau, du plus ancien au plus récent tels qu'ils
  /// ont été fournis.
  final List<FactorDocument> documents;

  /// Pour chaque mot (par sa clé), ses occurrences dans chaque entretien,
  /// dans l'ordre de [documents].
  final Map<String, List<int>> counts;

  /// Entretiens situés d'un côté de l'axe [axis] (0 ou 1), du plus éloigné
  /// de l'origine au plus proche.
  List<FactorDocument> side(int axis, {required bool positive}) {
    double coord(FactorDocument d) => axis == 0 ? d.x : d.y;
    return [
      for (final d in documents)
        if (coord(d) != 0 && (coord(d) > 0) == positive) d,
    ]..sort((a, b) => coord(b).abs().compareTo(coord(a).abs()));
  }
}

/// Construit la carte du corpus à partir des [maxWords] mots les plus
/// fréquents (au moins [minCount] occurrences en tout). Il faut au moins
/// trois entretiens pour porter deux axes ; sinon, null. Calcul pur : peut
/// tourner dans un isolate.
CorpusMap? buildCorpusMap(
  List<CorpusText> texts,
  AnalysisOptions options, {
  int maxWords = 40,
  int minCount = 3,
}) {
  if (texts.length < 3) return null;
  final wide = AnalysisOptions(
    excludeInterviewer: options.excludeInterviewer,
    groupForms: options.groupForms,
    extraStopwords: options.extraStopwords,
    interviewerLabels: options.interviewerLabels,
    summarySentences: 0,
    keySentences: 0,
    maxWords: 100000,
    networkWords: 0,
  );

  // Fréquence de chaque mot dans chaque entretien.
  final merged = <String, WordStat>{};
  final perText = <Map<String, int>>[];
  for (final text in texts) {
    final counts = <String, int>{};
    for (final w in analyze(text.text, wide).words) {
      counts[w.key] = w.count;
      final m = merged.putIfAbsent(w.key, () => WordStat(w.key));
      m.count += w.count;
      w.forms.forEach((form, n) => m.forms[form] = (m.forms[form] ?? 0) + n);
    }
    perText.add(counts);
  }

  // Les entretiens sans aucun mot plein ne peuvent pas être placés.
  final kept = [
    for (var j = 0; j < texts.length; j++)
      if (perText[j].isNotEmpty) j,
  ];
  if (kept.length < 3) return null;

  final chosen = merged.values.where((w) => w.count >= minCount).toList()
    ..sort((a, b) {
      final c = b.count.compareTo(a.count);
      return c != 0 ? c : a.label.compareTo(b.label);
    });
  if (chosen.length > maxWords) chosen.removeRange(maxWords, chosen.length);
  if (chosen.length < 4) return null;

  final table = [
    for (final w in chosen)
      [for (final j in kept) (perText[j][w.key] ?? 0).toDouble()],
  ];
  // Un entretien qui n'emploie aucun des mots retenus viderait une colonne.
  for (var c = 0; c < kept.length; c++) {
    if (table.every((row) => row[c] == 0)) return null;
  }
  final ca = correspondence(table);
  if (ca == null) return null;

  return CorpusMap(
    map: FactorMap(
      words: [
        for (var i = 0; i < chosen.length; i++)
          FactorWord(
            key: chosen[i].key,
            label: chosen[i].label,
            count: chosen[i].count,
            x: ca.rows[i][0],
            y: ca.rows[i][1],
            contribX: ca.contributions[i][0],
            contribY: ca.contributions[i][1],
            quality: ca.quality[i],
          ),
      ],
      segments: kept.length,
      segmentSize: 0,
      shareX: ca.share(0),
      shareY: ca.share(1),
      inertia: ca.inertia,
      spectrum: [for (final v in ca.spectrum) v / ca.inertia],
      chi2: ca.chi2,
      degrees: ca.degrees,
      pValue: ca.pValue,
      smallExpected: ca.smallExpected,
    ),
    documents: [
      for (var c = 0; c < kept.length; c++)
        FactorDocument(
          id: texts[kept[c]].id,
          title: texts[kept[c]].title,
          x: ca.columns[c][0],
          y: ca.columns[c][1],
        ),
    ],
    counts: {
      for (final w in chosen)
        w.key: [for (final j in kept) perText[j][w.key] ?? 0],
    },
  );
}
