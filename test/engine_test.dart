import 'package:flutter_test/flutter_test.dart';
import 'package:semantiq/engine/ai_result.dart';
import 'package:semantiq/engine/analysis.dart';
import 'package:semantiq/engine/export.dart';
import 'package:semantiq/engine/french.dart';
import 'package:semantiq/engine/quotes.dart';
import 'package:semantiq/engine/transcript.dart';
import 'package:semantiq/sample_interview.dart';

void main() {
  group('Racinisation', () {
    test('regroupe pluriel, féminin et conjugaisons', () {
      expect(stem('médecins'), stem('médecin'));
      expect(stem('patiente'), stem('patient'));
      expect(stem('patientes'), stem('patient'));
      expect(stem('hôpitaux'), stem('hôpital'));
      expect(stem('parlait'), stem('parler'));
      expect(stem('parlé'), stem('parler'));
    });

    test('ne touche pas aux mots courts', () {
      expect(stem('vie'), 'vie');
      expect(stem('lien'), 'lien');
    });
  });

  group('Découpage', () {
    test('sépare les élisions et les pronoms', () {
      final words = tokenize("L'hôpital, pouvez-vous m'aider ? Rendez-vous.")
          .map((t) => t.surface)
          .toList();
      expect(words, [
        'l', 'hôpital', 'pouvez', 'vous', 'm', 'aider', 'rendez-vous',
      ]);
    });

    test('mots-outils et tics de langage', () {
      expect(isStopword('euh'), isTrue);
      expect(isStopword('voilà'), isTrue);
      expect(isStopword('médecin'), isFalse);
      expect(isStopword('Corse'.toLowerCase(), extra: {'corse'}), isTrue);
    });
  });

  group('Tours de parole', () {
    test('repère enquêteur et participant', () {
      final t = parseTranscript(sampleInterview);
      expect(t.hasSpeakers, isTrue);
      expect(t.hasInterviewer, isTrue);
      expect(t.speakers, ['E', 'P1']);
      expect(t.turns.where((x) => x.isInterviewer).length, 5);
      expect(t.turns.first.isInterviewer, isTrue);
    });

    test("n'invente pas de locuteur", () {
      final t = parseTranscript(
          "Le souci c'est que : personne ne répond.\nEnsuite on attend.");
      expect(t.hasSpeakers, isFalse);
      expect(t.sentences.length, 2);
    });

    test('texte sans locuteur', () {
      final t = parseTranscript('Première phrase. Deuxième phrase ! Et une '
          'troisième ?');
      expect(t.turns.length, 1);
      expect(t.sentences.length, 3);
    });
  });

  group('Analyse', () {
    final a = analyze(sampleInterview);

    test("exclut l'enquêteur", () {
      expect(a.interviewerExcluded, isTrue);
      final labels = a.words.map((w) => w.label).toSet();
      expect(labels.contains('entretien'), isFalse);
    });

    test('mots fréquents', () {
      final top = a.words.take(8).map((w) => w.label).toList();
      expect(top, contains('médecin'));
      expect(top, contains('hôpital'));
      final medecin = a.words.firstWhere((w) => w.label == 'médecin');
      expect(medecin.forms.keys, containsAll(['médecin', 'médecins']));
    });

    test('expressions récurrentes', () {
      final labels = a.expressions.map((e) => e.label).toList();
      expect(labels, contains('médecin traitant'));
      expect(labels, contains('prise en charge'));
    });

    test('phrases clés et résumé', () {
      expect(a.ranked, isNotEmpty);
      expect(a.ranked.first.score, 1.0);
      expect(a.summary.length, lessThanOrEqualTo(6));
      expect(a.summary.every((s) => !s.isInterviewer), isTrue);
      for (var i = 1; i < a.summary.length; i++) {
        expect(a.summary[i].index, greaterThan(a.summary[i - 1].index));
      }
    });

    test('cooccurrences', () {
      expect(a.correlations, isNotEmpty);
      expect(a.correlations.every((c) => c.pmi > 0 && c.together >= 2),
          isTrue);
      final medecin = a.words.firstWhere((w) => w.label == 'médecin').key;
      final links = a.correlationsOf(medecin).map((c) =>
          a.labelOf(c.a == medecin ? c.b : c.a));
      expect(links, contains('traitant'));
    });

    test('sans regroupement des formes', () {
      final b = analyze(sampleInterview,
          const AnalysisOptions(groupForms: false));
      final labels = b.words.map((w) => w.label).toSet();
      expect(labels, containsAll(['médecin', 'médecins']));
    });

    test('texte vide', () {
      final e = analyze('');
      expect(e.words, isEmpty);
      expect(e.ranked, isEmpty);
      expect(e.correlations, isEmpty);
    });
  });

  group('Citations', () {
    test('citation exacte malgré ponctuation et accents', () {
      expect(
          quoteFidelity("l'attente c'est le plus dur", sampleInterview), 1.0);
      expect(quoteFidelity('LE LIEN entre la ville et l’hôpital',
          sampleInterview), 1.0);
    });

    test('citation inventée', () {
      final f = quoteFidelity(
          "le médecin traitant m'a beaucoup soutenu moralement",
          sampleInterview);
      expect(f, lessThan(1.0));
    });
  });

  group('Exports', () {
    test('rapport Markdown', () {
      final a = analyze(sampleInterview);
      final md = buildReport(title: 'Entretien 1', text: sampleInterview,
          analysis: a);
      expect(md, startsWith('# Entretien 1'));
      expect(md, contains('## Phrases clés'));
      expect(md, contains('| médecin |'));
    });

    test('corpus IRaMuTeQ', () {
      final out = buildIramuteq([
        (id: 'P1', text: sampleInterview, variables: {'Sexe': 'Homme'}),
      ]);
      expect(out, startsWith('**** *entretien_p1 *sexe_homme'));
      expect(out.contains('merci d\'avoir accepté'), isFalse);
      expect(out, contains('médecin traitant'));
    });

    test('CSV des fréquences', () {
      final csv = buildFrequencyCsv(analyze(sampleInterview));
      expect(csv.split('\n').first, 'mot;occurrences;phrases;formes');
    });
  });

  group('Réponse IA', () {
    test('lit un JSON entouré de texte', () {
      const raw = 'Voici :\n```json\n{"resume": "Un résumé.", "themes": '
          '[{"titre": "Attente", "description": "Vécu difficile", '
          '"verbatims": ["L\'attente, c\'est le plus dur."]}], '
          '"phrases_cles": ["Le traitement est lourd."]}\n```';
      final r = AiResult.parse(raw, provider: 'Test', model: 'm');
      expect(r.summary, 'Un résumé.');
      expect(r.themes.single.title, 'Attente');
      expect(r.keyQuotes.single, 'Le traitement est lourd.');
      final back = AiResult.fromJson(r.toJson());
      expect(back.themes.single.quotes.single, contains('attente'));
    });

    test('refuse une réponse sans JSON', () {
      expect(() => AiResult.parse('rien', provider: 'x', model: 'y'),
          throwsFormatException);
    });
  });
}
