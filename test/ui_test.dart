import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:semantiq/data/interview.dart';
import 'package:semantiq/engine/analysis.dart';
import 'package:semantiq/sample_interview.dart';
import 'package:semantiq/ui/illustrations.dart';
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
