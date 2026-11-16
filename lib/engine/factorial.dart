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
    required this.inertia,
    required this.eigenvalues,
    required this.rows,
    required this.columns,
    required this.contributions,
    required this.quality,
  });

  /// Inertie totale du tableau (khi-deux divisé par l'effectif).
  final double inertia;

  /// Inertie portée par chaque axe gardé, du premier au dernier.
  final List<double> eigenvalues;

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

  return Correspondence(
    inertia: inertia,
    eigenvalues: values,
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
  );
}
