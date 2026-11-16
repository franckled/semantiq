// Captures des écrans principaux, avec les vraies polices, pour relire la
// mise en page sans téléphone :
//
//   flutter test tool/screens_test.dart
//
// Les images sont écrites dans build/screens/. La CI les dépose dans la
// branche ci-screens.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:semantiq/data/interview.dart';
import 'package:semantiq/engine/analysis.dart';
import 'package:semantiq/sample_study.dart';
import 'package:semantiq/services/settings.dart';
import 'package:semantiq/ui/app_scope.dart';
import 'package:semantiq/ui/codebook_screen.dart';
import 'package:semantiq/ui/coding_tab.dart';
import 'package:semantiq/ui/home_screen.dart';
import 'package:semantiq/ui/illustrations.dart';
import 'package:semantiq/ui/results_tabs.dart';
import 'package:semantiq/ui/theme.dart';
import 'package:semantiq/ui/welcome_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _root = GlobalKey();

Future<void> _loadFonts() async {
  Future<void> family(String name, List<String> files) async {
    final loader = FontLoader(name);
    for (final f in files) {
      final bytes = File(f).readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  await family('Atkinson', [
    for (final w in [400, 500, 700, 800])
      'assets/fonts/AtkinsonHyperlegibleNext-$w.ttf',
  ]);
  await family('DMSerif', [
    'assets/fonts/DMSerifDisplay-Regular.ttf',
    'assets/fonts/DMSerifDisplay-Italic.ttf',
  ]);
  final icons = File('${Platform.environment['FLUTTER_ROOT']}/bin/cache/'
      'artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) await family('MaterialIcons', [icons.path]);
}

void main() {
  testWidgets('Captures d\'écran', (tester) async {
    // iPhone 15 : 390 × 844 points, encoche et barre d'accueil.
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(780, 1688);
    tester.view.padding = const FakeViewPadding(top: 94, bottom: 68);
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final settings = (await tester.runAsync(Settings.load))!;
    await tester.runAsync(_loadFonts);

    Future<void> settle() async {
      for (var i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> show(
      String name,
      Widget home,
      InterviewStore store, {
      Brightness brightness = Brightness.light,
    }) async {
      await tester.pumpWidget(RepaintBoundary(
        key: _root,
        child: AppScope(
          settings: settings,
          store: store,
          child: MaterialApp(
            key: ValueKey(name),
            debugShowCheckedModeBanner: false,
            theme: buildTheme(brightness),
            locale: const Locale('fr', 'FR'),
            supportedLocales: const [Locale('fr', 'FR')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: home,
          ),
        ),
      ));
      await settle();
    }

    Future<void> shoot(String name) async {
      final boundary =
          _root.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        File('build/screens/$name.png')
          ..createSync(recursive: true)
          ..writeAsBytesSync(data!.buffer.asUint8List());
      });
    }

    InterviewStore study() {
      final store = InterviewStore.memory();
      loadSampleStudy(store);
      return store;
    }

    Widget coding(InterviewStore store) {
      final it = store.items.firstWhere((i) => i.title.startsWith('Exemple 1'));
      return DefaultTabController(
        length: sections.length,
        initialIndex: 1,
        child: Scaffold(
          appBar: AppBar(
            title: Text(it.title, overflow: TextOverflow.ellipsis),
            bottom: const SectionTabBar(),
          ),
          body: Backdrop(
            variant: 2,
            child: CodingTab(
                analysis: analyze(it.text), interview: it, store: store),
          ),
        ),
      );
    }

    debugDisableShadows = false;
    try {
      final empty = InterviewStore.memory();
      await show('presentation', const WelcomeScreen(), empty);
      await shoot('01_presentation');
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('Continuer'));
        await settle();
      }
      await shoot('02_presentation_fin');

      await show('accueil_vide', const HomeScreen(), empty);
      await shoot('03_accueil_vide');

      final store = study();
      await show('accueil', const HomeScreen(), store);
      await shoot('04_accueil');
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -420));
      await settle();
      await shoot('05_accueil_bas');

      await show('livre', CodebookScreen(store: store), store);
      await shoot('06_livre_de_codes');
      await tester.scrollUntilVisible(
        find.text('Renoncement aux soins'),
        200,
        scrollable: find
            .descendant(
                of: find.byType(CodebookView),
                matching: find.byType(Scrollable))
            .first,
      );
      await settle();
      await shoot('07_livre_de_codes_bas');
      await tester.tap(find.text('Rupture ville-hôpital'));
      await settle();
      await shoot('08_fiche_code');

      await show('codage', coding(store), store);
      await shoot('09_codage');
      await tester.tap(find.text('Oui.'));
      await settle();
      await shoot('10_coder_un_extrait');

      final dark = study();
      await show('accueil_sombre', const HomeScreen(), dark,
          brightness: Brightness.dark);
      await shoot('11_accueil_sombre');
      await show('livre_sombre', CodebookScreen(store: dark), dark,
          brightness: Brightness.dark);
      await shoot('12_livre_de_codes_sombre');
      await show('codage_sombre', coding(dark), dark,
          brightness: Brightness.dark);
      await shoot('13_codage_sombre');

      await tester.pumpWidget(const SizedBox());
    } finally {
      debugDisableShadows = true;
    }
  });
}
