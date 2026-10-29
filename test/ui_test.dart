import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:semantiq/data/interview.dart';
import 'package:semantiq/engine/analysis.dart';
import 'package:semantiq/engine/meeting.dart';
import 'package:semantiq/sample_interview.dart';
import 'package:semantiq/sample_meeting.dart';
import 'package:semantiq/ui/illustrations.dart';
import 'package:semantiq/ui/minutes_tab.dart';
import 'package:semantiq/ui/network_view.dart';
import 'package:semantiq/ui/results_tabs.dart';
import 'package:semantiq/ui/theme.dart';

/// Vérifie que les écrans de résultats et les illustrations se construisent
/// et se dessinent sans erreur de mise en page, en clair comme en sombre.
void main() {
  final analysis = analyze(sampleInterview);
  final interview = Interview(
    id: 'test',
    title: 'Entretien test',
    text: sampleInterview,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<void> pumpIn(WidgetTester tester, Widget child,
      {Brightness brightness = Brightness.light}) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(brightness),
      home: DefaultTabController(
        length: sections.length,
        child: Scaffold(
          appBar: AppBar(bottom: const SectionTabBar()),
          body: child,
        ),
      ),
    ));
    // Les illustrations tournent en boucle : on avance le temps sans
    // attendre une fin d'animation.
    await tester.pump(const Duration(milliseconds: 1500));
  }

  for (final b in Brightness.values) {
    group('Thème ${b.name}', () {
      testWidgets('Résumé', (tester) async {
        await pumpIn(
          tester,
          SummaryTab(
            analysis: analysis,
            interview: interview,
            aiRunning: false,
            onGenerateAi: () {},
          ),
          brightness: b,
        );
        expect(find.text('Résumé extractif'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Phrases clés', (tester) async {
        await pumpIn(
            tester, KeySentencesTab(analysis: analysis, interview: interview),
            brightness: b);
        expect(find.text('Phrases les plus centrales'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Mots', (tester) async {
        await pumpIn(tester, WordsTab(analysis: analysis, onWordTap: (_) {}),
            brightness: b);
        expect(find.text('médecin'), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Corrélations', (tester) async {
        await pumpIn(tester, NetworkTab(analysis: analysis, onWordTap: (_) {}),
            brightness: b);
        expect(find.text('Réseau des mots'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Texte', (tester) async {
        await pumpIn(tester, TextTab(analysis: analysis), brightness: b);
        expect(find.text('P1'), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Illustrations', (tester) async {
        await pumpIn(
          tester,
          const Backdrop(
            child: Column(
              children: [
                HeroArt(),
                ListeningArt(size: 160, progress: 0.4),
                ListeningArt(size: 120),
                Row(
                  children: [
                    TileArt(TileArtKind.audio),
                    TileArt(TileArtKind.paste),
                    TileArt(TileArtKind.sample),
                    TileArt(TileArtKind.empty),
                  ],
                ),
                InterviewAvatar(accent: Accent.coral),
              ],
            ),
          ),
          brightness: b,
        );
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets('Compte rendu de réunion (local puis IA)', (tester) async {
    final meeting = Interview(
      id: 'reunion',
      title: 'Réunion test',
      text: sampleMeeting,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      kind: InterviewKind.meeting,
      duration: const Duration(minutes: 14),
      markers: const [Duration(minutes: 8, seconds: 12)],
    );
    final a = analyze(sampleMeeting, const AnalysisOptions(excludeInterviewer: false));
    final cues = findMeetingCues(sampleMeeting);
    Widget tab() => MinutesTab(
          analysis: a,
          interview: meeting,
          cues: cues,
          running: false,
          onGenerate: () {},
        );
    await pumpIn(tester, tab());
    expect(find.text('Compte rendu par IA'), findsOneWidget);
    // Liste construite à la demande : on fait défiler jusqu'aux rubriques.
    final list = find
        .descendant(of: find.byType(MinutesTab), matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(find.text('Moments marqués'), 300,
        scrollable: list);
    expect(find.text('Moments marqués'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Repérage sur l\'iPhone'), 300,
        scrollable: list);
    expect(find.text('Repérage sur l\'iPhone'), findsOneWidget);
    expect(tester.takeException(), isNull);

    meeting.minutes = MeetingMinutes(
      provider: 'Test',
      model: 'm',
      date: DateTime(2026),
      summary: 'Lancement de l\'étude.',
      participants: const ['Locuteur 1', 'Locuteur 2'],
      topics: const ['Recrutement', 'Formation'],
      decisions: const ['Sept cabinets retenus'],
      actions: const [
        ActionItem(task: 'Préparer le support', owner: 'Locuteur 1', due: 'vendredi'),
      ],
      openQuestions: const ['Budget de la licence'],
      nextSteps: const ['Réunion dans quinze jours'],
    );
    await pumpIn(tester, tab());
    await tester.scrollUntilVisible(find.text('Préparer le support'), 300,
        scrollable: list);
    expect(find.text('Préparer le support'), findsOneWidget);
    expect(find.text('vendredi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Fiche d\'un mot', (tester) async {
    final key = analysis.words.first.key;
    await pumpIn(
      tester,
      WordSheet(analysis: analysis, wordKey: key, onIgnore: (_) {}),
    );
    expect(find.text('Dans le texte'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('Teintes stables', () {
    expect(Accent.forKey('P1'), Accent.forKey('P1'));
    expect(Accent.all, hasLength(6));
  });
}
