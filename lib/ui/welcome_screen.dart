import 'package:flutter/material.dart';

import '../sample_study.dart';
import 'app_scope.dart';
import 'codebook_screen.dart';
import 'common.dart';
import 'home_screen.dart';
import 'illustrations.dart';
import 'theme.dart';

/// Présentation de l'app, au premier lancement.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Backdrop(
        child: SafeArea(
          child: WelcomeView(onDone: (sample) => _finish(context, sample)),
        ),
      ),
    );
  }

  void _finish(BuildContext context, bool sample) {
    final scope = AppScope.of(context);
    scope.settings.welcomed = true;
    final navigator = Navigator.of(context);
    navigator.pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
    );
    if (sample) {
      // L'étude d'exemple s'ouvre sur son livre de codes ; l'accueil, avec
      // les trois entretiens, attend derrière.
      if (!hasSampleStudy(scope.store)) loadSampleStudy(scope.store);
      navigator.push(
        MaterialPageRoute<void>(
            builder: (_) => CodebookScreen(store: scope.store)),
      );
    }
  }
}

typedef _Page = ({String title, String text, IconData? icon, Accent accent});

const List<_Page> _pages = [
  (
    title: 'Du verbatim aux thèmes',
    text: "SemantiQ accompagne l'analyse qualitative des entretiens de "
        'thèse : transcription, codage thématique, livre de codes et '
        'suivi de la saturation.',
    icon: null,
    accent: Accent.violet,
  ),
  (
    title: "Vos entretiens restent sur l'iPhone",
    text: 'Aucun compte à créer. Par défaut, rien n\'est envoyé : la '
        "transcription et les analyses se font sur l'appareil. L'aide "
        "d'une IA est facultative et toujours précédée d'un avertissement.",
    icon: Icons.lock_rounded,
    accent: Accent.mint,
  ),
  (
    title: 'Vos codes, vos citations',
    text: "L'app ne code pas à votre place. Elle range vos extraits par "
        'code et par thème, vérifie que chaque citation figure mot pour '
        'mot dans le verbatim, et exporte le tout pour la rédaction.',
    icon: Icons.sell_rounded,
    accent: Accent.coral,
  ),
];

/// Les trois pages de présentation. [onDone] reçoit true si la personne
/// veut découvrir l'app avec l'étude d'exemple.
class WelcomeView extends StatefulWidget {
  const WelcomeView({super.key, required this.onDone});

  final void Function(bool sample) onDone;

  @override
  State<WelcomeView> createState() => _WelcomeViewState();
}

class _WelcomeViewState extends State<WelcomeView> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _last => _page == _pages.length - 1;

  @override
  Widget build(BuildContext context) {
    final tones = Tones.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
          child: Row(
            children: [
              const Expanded(child: Wordmark(size: 28)),
              TextButton(
                onPressed: () => widget.onDone(false),
                child: const Text('Passer'),
              ),
            ],
          ),
        ),
        Expanded(
          child: PageView(
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            children: [for (final p in _pages) _PageBody(page: p)],
          ),
        ),
        Semantics(
          label: 'Page ${_page + 1} sur ${_pages.length}',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < _pages.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _page ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _page ? Palette.violet : tones.rule,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GradientButton(
                label: _last ? "Ouvrir l'étude d'exemple" : 'Continuer',
                icon: _last ? Icons.menu_book_rounded : null,
                onPressed: _last
                    ? () => widget.onDone(true)
                    : () => _controller.nextPage(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutCubic,
                        ),
              ),
              const SizedBox(height: 4),
              // Même hauteur sur les trois pages : rien ne saute.
              Visibility(
                visible: _last,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: TextButton(
                  onPressed: () => widget.onDone(false),
                  child: const Text('Commencer avec mes entretiens'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PageBody extends StatelessWidget {
  const _PageBody({required this.page});

  final _Page page;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tones = Tones.of(context);
    final icon = page.icon;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon == null)
              const HeroArt(size: Size(220, 188))
            else
              Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  gradient: page.accent.gradient,
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Icon(icon, size: 60, color: Colors.white),
              ),
            const SizedBox(height: 32),
            Text(page.title,
                style: t.headlineMedium, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(
              page.text,
              style: t.bodyLarge?.copyWith(color: tones.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
