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
      // Le barycentre pondéré des mots est à l'origine : propriété de l'AFC.
      expect(
          map.words.fold<double>(0, (s, w) => s + w.contribX), closeTo(1, 1e-9));
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
}
