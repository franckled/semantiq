import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:semantiq/data/interview.dart';
import 'package:semantiq/engine/analysis.dart';
import 'package:semantiq/engine/meeting.dart';
import 'package:semantiq/sample_interview.dart';
import 'package:semantiq/sample_meeting.dart';
import 'package:semantiq/sample_study.dart';
import 'package:semantiq/ui/codebook_screen.dart';
import 'package:semantiq/ui/coding_tab.dart';
import 'package:semantiq/ui/factor_view.dart';
import 'package:semantiq/ui/illustrations.dart';
import 'package:semantiq/ui/minutes_tab.dart';
import 'package:semantiq/ui/network_view.dart';
import 'package:semantiq/ui/results_tabs.dart';
import 'package:semantiq/ui/theme.dart';
import 'package:semantiq/ui/welcome_screen.dart';

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

      testWidgets('Carte factorielle', (tester) async {
        final corpus = analyze(sampleStudy.map((s) => s.text).join('\n'));
        await pumpIn(tester,
            FactorTab(analysis: corpus, onWordTap: (_) {}),
            brightness: b);
        expect(find.text('Carte factorielle'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Texte trop court : un message, pas une carte vide.
        await pumpIn(
            tester,
            FactorTab(analysis: analyze('P1 : Bonjour.'), onWordTap: (_) {}),
            brightness: b);
        expect(find.text('Texte trop court pour une carte'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Codage', (tester) async {
        final store = InterviewStore.memory();
        loadSampleStudy(store);
        final it =
            store.items.firstWhere((i) => i.title.startsWith('Exemple 1'));
        await pumpIn(
          tester,
          CodingTab(analysis: analyze(it.text), interview: it, store: store),
          brightness: b,
        );
        expect(find.text('9 extraits codés · 7 codes'), findsOneWidget);
        expect(find.text("Choc de l'annonce"), findsWidgets);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Livre de codes', (tester) async {
        final store = InterviewStore.memory();
        loadSampleStudy(store);
        await pumpIn(tester, CodebookView(store: store), brightness: b);
        expect(find.text('Saturation des données'), findsOneWidget);
        expect(find.text('+7 nouveaux'), findsOneWidget);
        expect(find.text('aucun nouveau'), findsOneWidget);
        final list = find
            .descendant(
                of: find.byType(CodebookView), matching: find.byType(Scrollable))
            .first;
        await tester.scrollUntilVisible(
            find.text('Rupture ville-hôpital'), 300,
            scrollable: list);
        await tester.pump(const Duration(milliseconds: 800));
        expect(find.text('4 extraits · 3 entretiens'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Présentation', (tester) async {
        await pumpIn(tester, WelcomeView(onDone: (_) {}), brightness: b);
        expect(find.text('Du verbatim aux thèmes'), findsOneWidget);
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
    // Nouvel arbre : la liste repart du haut.
    await tester.pumpWidget(const SizedBox());
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

  testWidgets('Corrélations : du réseau à la carte', (tester) async {
    final corpus = analyze(sampleStudy.map((s) => s.text).join('\n'));
    String? opened;
    await pumpIn(tester,
        CorrelationsTab(analysis: corpus, onWordTap: (k) => opened = k));
    expect(find.text('Réseau des mots'), findsOneWidget);
    await tester.tap(find.text('Carte factorielle'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('Réseau des mots'), findsNothing);
    // On fait défiler sous la carte : sur la carte, le doigt la déplace.
    await tester.dragFrom(const Offset(195, 800), const Offset(0, -400));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Axe horizontal'), findsOneWidget);
    expect(find.text('À gauche'), findsOneWidget);
    expect(find.text('À droite'), findsOneWidget);
    expect(opened, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Coder un extrait', (tester) async {
    final store = InterviewStore.memory();
    loadSampleStudy(store);
    final it = store.items.firstWhere((i) => i.title.startsWith('Exemple 1'));
    await pumpIn(tester,
        CodingTab(analysis: analyze(it.text), interview: it, store: store));
    // Première phrase de la personne interrogée, pas encore codée.
    await tester.tap(find.text('Oui.'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Coder cet extrait'), findsOneWidget);
    final pill = find.descendant(
        of: find.byType(CodeSheet),
        matching: find.text('Rupture ville-hôpital'));
    expect(pill, findsOneWidget);

    // Un code existant, puis un code créé sur place.
    await tester.tap(pill);
    await tester.pump(const Duration(milliseconds: 200));
    expect(store.codesOf(it, 'Oui.').single.label, 'Rupture ville-hôpital');

    await tester.enterText(find.byType(TextField), 'Acquiescement');
    await tester.tap(find.byTooltip('Créer ce code et le poser'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(store.codes, hasLength(10));
    expect(store.codesOf(it, 'Oui.').map((c) => c.label),
        ['Rupture ville-hôpital', 'Acquiescement']);
    expect(it.codings, hasLength(11));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Fiche d\'un code', (tester) async {
    final store = InterviewStore.memory();
    loadSampleStudy(store);
    final code = store.codeByLabel('Information insuffisante')!;
    await pumpIn(tester, CodeDetailSheet(store: store, codeId: code.id));
    expect(find.text('Thème : Relation de soin'), findsOneWidget);
    expect(find.text('P2'), findsNWidgets(2));
    expect(find.text('Exemple 2 – Mme B., 58 ans'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Présentation : jusqu\'à l\'étude d\'exemple', (tester) async {
    bool? sample;
    await pumpIn(tester, WelcomeView(onDone: (s) => sample = s));
    await tester.tap(find.text('Continuer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text("Vos entretiens restent sur l'iPhone"), findsOneWidget);
    await tester.tap(find.text('Continuer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Vos codes, vos citations'), findsOneWidget);
    await tester.tap(find.text("Ouvrir l'étude d'exemple"));
    expect(sample, isTrue);
    expect(tester.takeException(), isNull);
  });

  test('Teintes stables', () {
    expect(Accent.forKey('P1'), Accent.forKey('P1'));
    expect(Accent.all, hasLength(6));
  });
}
