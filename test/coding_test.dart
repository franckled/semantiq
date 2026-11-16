import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:semantiq/data/interview.dart';
import 'package:semantiq/engine/coding.dart';
import 'package:semantiq/engine/transcript.dart';
import 'package:semantiq/sample_study.dart';

void main() {
  InterviewStore study() {
    final store = InterviewStore.memory();
    loadSampleStudy(store);
    return store;
  }

  Interview byTitle(InterviewStore store, String start) =>
      store.items.firstWhere((i) => i.title.startsWith(start));

  group("Étude d'exemple", () {
    test('chaque extrait codé est une phrase dite par la personne', () {
      final labels = sampleCodes.map((c) => c.label).toSet();
      for (final s in sampleStudy) {
        final said = parseTranscript(s.text)
            .sentences
            .where((x) => !x.isInterviewer)
            .map((x) => x.text)
            .toSet();
        for (final c in s.codings) {
          expect(said, contains(c.quote), reason: s.title);
          expect(labels, contains(c.code));
        }
      }
    });

    test('se charge dans un corpus vide', () {
      final empty = InterviewStore.memory();
      expect(hasSampleStudy(empty), isFalse);
      final store = study();
      expect(hasSampleStudy(store), isTrue);
      expect(store.items, hasLength(3));
      expect(store.codes, hasLength(9));
      expect(store.codingCount, 25);
      expect({for (final i in store.items) i.id}, hasLength(3));
    });

    test('ne duplique pas les codes existants', () {
      final store = study();
      loadSampleStudy(store);
      expect(store.codes, hasLength(9));
    });
  });

  group('Livre de codes', () {
    test('rassemble les extraits de tout le corpus', () {
      final store = study();
      final usages = codeUsages(store.codes, store.codedSources);
      expect(usages, hasLength(9));
      final rupture =
          usages.firstWhere((u) => u.code.label == 'Rupture ville-hôpital');
      expect(rupture.excerpts, hasLength(4));
      expect(rupture.sources, 3);
      expect(rupture.excerpts.first.sourceTitle, startsWith('Exemple 1'));
      expect(rupture.excerpts.first.speaker, 'P1');
      expect(usages.expand((u) => u.excerpts).every((e) => e.found), isTrue);
    });

    test('range les codes par thème', () {
      final store = study();
      final groups =
          groupByTheme(codeUsages(store.codes, store.codedSources));
      expect(groups.keys, [
        'Vécu de la maladie',
        'Relation de soin',
        'Organisation du parcours',
      ]);
      expect(groups.values.map((g) => g.length), [3, 3, 3]);

      store.addCode('Code libre');
      final again =
          groupByTheme(codeUsages(store.codes, store.codedSources));
      expect(again.keys.last, '');
      expect(again['']!.single.code.label, 'Code libre');
    });

    test('suit la saturation dans l\'ordre des entretiens', () {
      final store = study();
      final points = saturation(store.codes, store.codedSources);
      expect(points.map((p) => p.title.substring(0, 9)),
          ['Exemple 1', 'Exemple 2', 'Exemple 3']);
      expect(points.map((p) => p.newCodes.length), [7, 2, 0]);
      expect(points.map((p) => p.cumulative), [7, 9, 9]);
      expect(points[1].newCodes,
          containsAll(['Renoncement aux soins', 'Information insuffisante']));
      expect(saturationReading(points), contains('premier indice'));
      expect(saturationReading(points.take(2).toList()),
          contains('2 nouveaux codes'));
      expect(saturationReading(points.take(1).toList()), isNull);
    });

    test('ignore les entretiens non codés et les réunions', () {
      final store = study();
      store.create(title: 'Entretien 4', text: 'P4 : Rien à signaler.');
      store.create(
          title: 'Réunion', text: 'L1 : Bonjour.', kind: InterviewKind.meeting);
      expect(saturation(store.codes, store.codedSources), hasLength(3));
      expect(store.codedSources, hasLength(4));
    });

    test('pose et retire un code sur un extrait', () async {
      final store = study();
      final it = byTitle(store, 'Exemple 3');
      const quote = 'Il faut tout réexpliquer à chaque consultation.';
      final code = store.addCode('Répétition');
      expect(store.codes, hasLength(10));
      expect(store.addCode('  répétition '), same(code));

      await store.toggleCoding(it, code, quote, 'P3');
      expect(store.codesOf(it, quote).single, same(code));
      // Même extrait à la ponctuation et à la casse près.
      expect(store.codesOf(it, 'il faut tout réexpliquer à chaque consultation'),
          hasLength(1));
      expect(saturation(store.codes, store.codedSources).last.newCodes,
          ['Répétition']);

      await store.toggleCoding(it, code, quote, 'P3');
      expect(store.codesOf(it, quote), isEmpty);
    });

    test('supprime un code avec ses extraits', () async {
      final store = study();
      final code = store.codeByLabel('Rupture ville-hôpital')!;
      await store.deleteCode(code);
      expect(store.codes, hasLength(8));
      expect(store.codingCount, 21);
      expect(store.codeById(code.id), isNull);
    });

    test('signale un extrait que le texte corrigé ne contient plus', () {
      final store = study();
      final it = byTitle(store, 'Exemple 2');
      it.text = it.text.replaceAll('sidérée', 'abasourdie');
      final choc = codeUsages(store.codes, store.codedSources)
          .firstWhere((u) => u.code.label == "Choc de l'annonce");
      expect(choc.excerpts.map((e) => e.found), [true, false]);
    });

    test('exporte le livre de codes', () {
      final store = study();
      final md = buildCodebookReport(
        codes: store.codes,
        sources: store.codedSources,
        date: DateTime(2026, 11, 16),
      );
      expect(md, contains('Établi le 16/11/2026'));
      expect(md, contains('- Codes : 9'));
      expect(md, contains('- Extraits codés : 25'));
      expect(md, contains('## Saturation des données'));
      expect(md, contains('| Exemple 2 – Mme B., 58 ans | 7 | 2 | 9 |'));
      expect(md, contains('## Relation de soin'));
      expect(md, contains('### Information insuffisante'));
      expect(md, contains('2 extraits dans 1 entretien.'));
      expect(md,
          contains("> « J'étais sidérée. » (P2, Exemple 2 – Mme B., 58 ans)"));
      expect(md, isNot(contains('⚠')));
    });

    test('exporte la matrice codes × entretiens', () {
      final store = study();
      final lines =
          buildCodingMatrixCsv(store.codes, store.codedSources).trim().split('\n');
      expect(lines, hasLength(10));
      expect(
          lines.first,
          'theme;code;total;entretiens;Exemple 1 – M. A., 64 ans;'
          'Exemple 2 – Mme B., 58 ans;Exemple 3 – M. C., 71 ans');
      expect(lines,
          contains('Organisation du parcours;Rupture ville-hôpital;4;3;2;1;1'));
      expect(lines,
          contains('Organisation du parcours;Renoncement aux soins;2;1;0;2;0'));
    });

    test('se conserve dans le fichier de l\'entretien', () {
      final store = study();
      final it = byTitle(store, 'Exemple 1');
      final copy = Interview.fromJson(
          jsonDecode(jsonEncode(it.toJson())) as Map<String, Object?>);
      expect(copy.codings, hasLength(9));
      expect(copy.codings.first.quote, it.codings.first.quote);
      expect(copy.codings.first.speaker, 'P1');
      expect(copy.variables, {'sexe': 'homme', 'age': '64'});

      final code = store.codes.first;
      final back = Code.fromJson(
          jsonDecode(jsonEncode(code.toJson())) as Map<String, Object?>);
      expect(back.label, code.label);
      expect(back.theme, 'Vécu de la maladie');
    });
  });
}
