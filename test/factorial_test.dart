import 'package:flutter_test/flutter_test.dart';
import 'package:semantiq/engine/analysis.dart';
import 'package:semantiq/engine/factorial.dart';
import 'package:semantiq/sample_interview.dart';
import 'package:semantiq/sample_study.dart';

void main() {
  group('Valeurs propres', () {
    test('matrice symétrique 3 × 3', () {
      final e = symmetricEigen([
        [2, 1, 0],
        [1, 2, 0],
        [0, 0, 5],
      ]);
      expect(e.values.toList()..sort(), [
        closeTo(1, 1e-9),
        closeTo(3, 1e-9),
        closeTo(5, 1e-9),
      ]);
      // Chaque colonne est un vecteur propre de norme 1.
      for (var k = 0; k < 3; k++) {
        var norm = 0.0;
        for (var i = 0; i < 3; i++) {
          norm += e.vectors[i][k] * e.vectors[i][k];
        }
        expect(norm, closeTo(1, 1e-9));
      }
    });
  });

  group('Analyse des correspondances', () {
    // Tableau d'école (Greenacre) : catégories de personnel × consommation
    // de tabac. Résultats publiés : inertie 0,0852 ; axes 87,8 % et 11,8 %.
    const smoking = [
      [4.0, 2.0, 3.0, 2.0],
      [4.0, 3.0, 7.0, 4.0],
      [25.0, 10.0, 12.0, 4.0],
      [18.0, 24.0, 33.0, 13.0],
      [10.0, 6.0, 7.0, 2.0],
    ];

    test('retrouve les résultats publiés', () {
      final ca = correspondence(smoking)!;
      expect(ca.inertia, closeTo(0.08519, 1e-5));
      expect(ca.share(0), closeTo(0.8776, 1e-4));
      expect(ca.share(1), closeTo(0.1176, 1e-4));
      expect([for (final r in ca.rows) r[0]], [
        closeTo(0.0658, 1e-4),
        closeTo(-0.2590, 1e-4),
        closeTo(0.3806, 1e-4),
        closeTo(-0.2330, 1e-4),
        closeTo(0.2011, 1e-4),
      ]);
      expect([for (final c in ca.columns) c[0]], [
        closeTo(0.3933, 1e-4),
        closeTo(-0.0995, 1e-4),
        closeTo(-0.1963, 1e-4),
        closeTo(-0.2938, 1e-4),
      ]);
    });

    test('garde tout l\'éboulis des valeurs propres', () {
      final ca = correspondence(smoking)!;
      // Quatre colonnes : trois axes au plus.
      expect(ca.spectrum, hasLength(3));
      expect(ca.spectrum[0], closeTo(0.07476, 1e-5));
      expect(ca.spectrum[1], closeTo(0.01002, 1e-5));
      expect(ca.spectrum[2], closeTo(0.00041, 1e-5));
      expect(ca.spectrum.reduce((a, b) => a + b), closeTo(ca.inertia, 1e-12));
      expect(ca.spectrum.take(2), ca.eigenvalues);
      // La courbe se casse dès le deuxième axe : un seul axe à retenir.
      expect(elbowAxes(ca.spectrum), 1);
    });

    test('critère du coude', () {
      expect(elbowAxes([5, 4, 3, 1, 0.9, 0.8]), 3);
      expect(elbowAxes([10, 9, 2, 1.5, 1]), 2);
      expect(elbowAxes([8, 1, 0.9, 0.8]), 1);
      // Deux valeurs ou moins : pas de coude.
      expect(elbowAxes([3, 1]), isNull);
      expect(elbowAxes([]), isNull);
    });

    test('contributions et qualités cohérentes', () {
      final ca = correspondence(smoking)!;
      for (var k = 0; k < 2; k++) {
        final sum =
            ca.contributions.fold<double>(0, (total, row) => total + row[k]);
        expect(sum, closeTo(1, 1e-9));
      }
      expect(ca.contributions[2][0], closeTo(0.512, 1e-3));
      for (final q in ca.quality) {
        expect(q, inInclusiveRange(0, 1));
      }
      // Deux axes sur trois portent presque toute l'inertie de ce tableau.
      expect(ca.quality[2], greaterThan(0.99));
    });

    test('refuse un tableau trop petit ou sans structure', () {
      expect(correspondence([
        [1.0, 2.0, 3.0],
        [3.0, 2.0, 1.0],
      ]), isNull);
      // Lignes proportionnelles : aucun écart à l'indépendance.
      expect(correspondence([
        [1.0, 2.0, 3.0],
        [2.0, 4.0, 6.0],
        [3.0, 6.0, 9.0],
      ]), isNull);
      expect(correspondence([
        [1.0, 0.0, 3.0],
        [0.0, 0.0, 0.0],
        [3.0, 0.0, 9.0],
      ]), isNull);
    });
  });

  group('Carte factorielle', () {
    final corpus = analyze(sampleStudy.map((s) => s.text).join('\n'));

    test('découpe le texte analysé en segments, sans rien perdre', () {
      final segments = textSegments(corpus, 20);
      expect(segments.length, greaterThan(4));
      expect(segments.expand((s) => s).toList(), corpus.analyzedSentences);
      expect(textSegments(analyze(''), 20), isEmpty);
    });

    test('projette les mots fréquents sur deux axes', () {
      final map = FactorMap.of(corpus)!;
      expect(map.words.length, inInclusiveRange(4, 40));
      expect(map.segments, greaterThanOrEqualTo(4));
      expect(map.shareX, greaterThan(0));
      expect(map.shareX, greaterThanOrEqualTo(map.shareY));
      expect(map.shareX + map.shareY, lessThanOrEqualTo(1.0000001));
      for (final w in map.words) {
        expect(w.count, greaterThanOrEqualTo(3));
        expect(w.x.isFinite && w.y.isFinite, isTrue);
        expect(corpus.word(w.key), isNotNull);
      }
      // Les contributions des mots à un axe se partagent toute son inertie.
      expect(
          map.words.fold<double>(0, (s, w) => s + w.contribX), closeTo(1, 1e-9));
      // L'éboulis décroît, commence par les deux axes de la carte et
      // totalise toute l'inertie.
      expect(map.spectrum.length, greaterThanOrEqualTo(3));
      expect(map.spectrum[0], closeTo(map.shareX, 1e-12));
      expect(map.spectrum[1], closeTo(map.shareY, 1e-12));
      for (var k = 1; k < map.spectrum.length; k++) {
        expect(map.spectrum[k], lessThanOrEqualTo(map.spectrum[k - 1]));
      }
      expect(map.spectrum.reduce((a, b) => a + b), closeTo(1, 1e-9));
      expect(map.elbow, inInclusiveRange(1, map.spectrum.length - 2));
      // Même objet au second appel : calculée une seule fois.
      expect(FactorMap.of(corpus), same(map));
    });

    test('nomme les mots qui s\'opposent sur chaque axe', () {
      final map = FactorMap.of(corpus)!;
      for (var axis = 0; axis < 2; axis++) {
        final low = map.pole(axis, positive: false);
        final high = map.pole(axis, positive: true);
        expect(low.length + high.length, greaterThan(0));
        expect(low.length, lessThanOrEqualTo(6));
        for (final w in low) {
          expect(axis == 0 ? w.x : w.y, lessThan(0));
        }
        for (final w in high) {
          expect(axis == 0 ? w.x : w.y, greaterThan(0));
        }
        expect({...low, ...high}.length, low.length + high.length);
      }
      // Le signe de l'axe est fixé : le mot qui y pèse le plus est positif.
      expect(map.pole(0, positive: true), isNotEmpty);
    });

    test('renonce quand le texte est trop court', () {
      expect(FactorMap.of(analyze('P1 : Bonjour, ça va bien.')), isNull);
      expect(FactorMap.of(analyze('')), isNull);
      // Un entretien bref ne doit jamais faire échouer le calcul.
      expect(() => FactorMap.of(analyze(sampleInterview)), returnsNormally);
    });
  });

  group('Carte du corpus', () {
    final texts = <CorpusText>[
      for (final s in sampleStudy) (id: s.title, title: s.title, text: s.text),
    ];

    test('place les mots et les trois entretiens', () {
      final corpus = buildCorpusMap(texts, const AnalysisOptions())!;
      expect(corpus.documents.map((d) => d.title),
          sampleStudy.map((s) => s.title));
      expect(corpus.map.words.length, inInclusiveRange(4, 40));
      // Trois entretiens : deux axes portent toute l'inertie.
      expect(corpus.map.shareX + corpus.map.shareY, closeTo(1, 1e-6));
      expect(corpus.map.spectrum, hasLength(2));
      expect(corpus.map.elbow, isNull);
      for (final w in corpus.map.words) {
        final counts = corpus.counts[w.key]!;
        expect(counts, hasLength(3));
        expect(counts.reduce((a, b) => a + b), w.count);
        expect(w.count, greaterThanOrEqualTo(3));
      }
      // Chaque axe a des entretiens des deux côtés : c'est une opposition.
      for (var axis = 0; axis < 2; axis++) {
        final low = corpus.side(axis, positive: false);
        final high = corpus.side(axis, positive: true);
        expect(low, isNotEmpty);
        expect(high, isNotEmpty);
        expect(low.length + high.length, 3);
      }
    });

    test('un mot propre à un entretien tombe de son côté', () {
      // « kiné » n'est dit que dans le deuxième entretien.
      final corpus =
          buildCorpusMap(texts, const AnalysisOptions(), minCount: 1,
              maxWords: 120)!;
      final second = corpus.documents[1];
      final own = corpus.map.words.where((w) {
        final c = corpus.counts[w.key]!;
        return c[0] == 0 && c[1] > 0 && c[2] == 0;
      }).toList();
      expect(own, isNotEmpty);
      for (final w in own) {
        // Même direction depuis l'origine que l'entretien lui-même.
        expect(w.x * second.x + w.y * second.y, greaterThan(0));
      }
    });

    test('renonce à moins de trois entretiens', () {
      expect(buildCorpusMap(texts.take(2).toList(), const AnalysisOptions()),
          isNull);
      expect(buildCorpusMap(const [], const AnalysisOptions()), isNull);
      expect(
          buildCorpusMap([
            ...texts.take(2),
            (id: 'vide', title: 'Vide', text: ''),
          ], const AnalysisOptions()),
          isNull);
    });
  });
}
