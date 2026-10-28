import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/interview.dart';
import 'services/settings.dart';
import 'ui/app_scope.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await Settings.load();
  final store = await InterviewStore.open();
  runApp(SemantiqApp(settings: settings, store: store));
}

class SemantiqApp extends StatelessWidget {
  const SemantiqApp({super.key, required this.settings, required this.store});

  final Settings settings;
  final InterviewStore store;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      settings: settings,
      store: store,
      child: MaterialApp(
        title: 'SemantiQ',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        locale: const Locale('fr', 'FR'),
        supportedLocales: const [Locale('fr', 'FR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const HomeScreen(),
      ),
    );
  }
}
