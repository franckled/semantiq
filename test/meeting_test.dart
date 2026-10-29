import 'package:flutter_test/flutter_test.dart';
import 'package:semantiq/engine/analysis.dart';
import 'package:semantiq/engine/meeting.dart';
import 'package:semantiq/engine/transcript.dart';
import 'package:semantiq/sample_meeting.dart';
import 'package:semantiq/services/transcription.dart';

void main() {
  group('Repérage local', () {
    final cues = findMeetingCues(sampleMeeting);

    test('décisions', () {
      final texts = cues.decisions.map((c) => c.sentence.text).join(' | ');
      expect(texts, contains('On valide donc les sept cabinets'));
      expect(texts, contains('on part sur une visio'));
    });

    test('actions, responsable et échéance', () {
      final support = cues.actions.firstWhere(
          (c) => c.sentence.text.contains('support de présentation'));
      expect(support.sentence.speaker, 'Locuteur 1');
      expect(support.due, contains('vendredi'));
      final cpp =
          cues.actions.firstWhere((c) => c.sentence.text.contains('CPP'));
      expect(cpp.due, contains('lundi prochain'));
      expect(cues.actions.any((c) => c.sentence.text.contains('tableau de suivi')),
          isTrue);
    });

    test('points en suspens', () {
      final texts = cues.questions.map((c) => c.sentence.text).join(' | ');
      expect(texts, contains('à voir avec la direction'));
      expect(texts, contains('visio ou une réunion sur place'));
    });

    test('moments marqués', () {
      expect(cues.moments, hasLength(1));
      expect(cues.moments.single.label, contains('08:12'));
      expect(cues.moments.single.excerpt, contains('comité de protection'));
    });
  });

  test('les marqueurs restent hors de l\'analyse', () {
    final t = parseTranscript(sampleMeeting);
    expect(t.sentences.any((s) => s.text.contains('Moment marqué')), isFalse);
    final a = analyze(sampleMeeting, const AnalysisOptions(excludeInterviewer: false));
    expect(a.words.any((w) => w.label == 'marqué'), isFalse);
    // Le locuteur reste le même de part et d'autre du marqueur.
    expect(t.speakers, ['Locuteur 1', 'Locuteur 2', 'Locuteur 3']);
  });

  test('horloge', () {
    expect(formatClock(const Duration(minutes: 8, seconds: 12)), '08:12');
    expect(formatClock(const Duration(hours: 1, minutes: 2, seconds: 5)),
        '1:02:05');
    expect(markerLine(const Duration(seconds: 75)), '★ Moment marqué (01:15)');
  });

  test('compte rendu IA : lecture et retour JSON', () {
    const raw = '```json\n{"resume": "Lancement de l\'étude.", '
        '"participants": ["Locuteur 1"], "sujets": ["Recrutement"], '
        '"decisions": ["Sept cabinets retenus"], '
        '"actions": [{"tache": "Préparer le support", "responsable": '
        '"Locuteur 1", "echeance": "vendredi"}], '
        '"points_en_suspens": ["Budget de la licence"], '
        '"prochaines_etapes": ["Réunion dans 15 jours"]}\n```';
    final m = MeetingMinutes.parse(raw, provider: 'Test', model: 'x');
    expect(m.actions.single.owner, 'Locuteur 1');
    final back = MeetingMinutes.fromJson(m.toJson());
    expect(back.decisions.single, 'Sept cabinets retenus');
    expect(back.actions.single.due, 'vendredi');
  });

  test('export du compte rendu', () {
    final md = buildMinutesReport(
      title: 'Réunion de lancement',
      date: DateTime(2026, 10, 29),
      duration: const Duration(minutes: 42),
      cues: findMeetingCues(sampleMeeting),
    );
    expect(md, startsWith('# Réunion de lancement'));
    expect(md, contains('durée 42:00'));
    expect(md, contains('## Décisions'));
    expect(md, contains('## Moments marqués'));
  });

  group('Marqueurs dans la transcription', () {
    test('paragraphes Whisper', () {
      final text = paragraphsFromSegments([
        (start: Duration.zero, end: const Duration(seconds: 3), text: ' Bonjour.'),
        (start: const Duration(seconds: 3), end: const Duration(seconds: 6), text: ' On commence.'),
        (start: const Duration(seconds: 10), end: const Duration(seconds: 12), text: ' Point suivant.'),
      ], markers: const [Duration(seconds: 4)]);
      expect(text, 'Bonjour. On commence.\n\n★ Moment marqué (00:04)\n\nPoint suivant.');
    });

    test('tours de parole Mistral', () {
      final text = speakerTurns([
        (speaker: 'speaker_1', text: 'Bonjour.', start: Duration.zero),
        (speaker: 'speaker_1', text: 'On valide.', start: const Duration(seconds: 5)),
        (speaker: 'speaker_2', text: 'Oui.', start: const Duration(seconds: 9)),
      ], markers: const [Duration(seconds: 4)]);
      expect(text,
          'Locuteur 1 : Bonjour.\n\n★ Moment marqué (00:04)\n\nLocuteur 1 : On valide.\n\nLocuteur 2 : Oui.');
      final t = parseTranscript(text);
      expect(t.turns.map((x) => x.speaker), ['Locuteur 1', 'Locuteur 1', 'Locuteur 2']);
    });
  });
}
