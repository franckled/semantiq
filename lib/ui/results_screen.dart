import 'dart:isolate';

import 'package:flutter/material.dart';

import '../data/interview.dart';
import '../engine/analysis.dart';
import '../engine/export.dart';
import '../services/ai_summary.dart';
import '../services/settings.dart';
import 'app_scope.dart';
import 'common.dart';
import 'illustrations.dart';
import 'network_view.dart';
import 'results_tabs.dart';
import 'theme.dart';

/// Lance [analyze] dans un isolat séparé, sans rien capturer de l'interface.
Future<Analysis> _runAnalysis(String text, AnalysisOptions options) =>
    Isolate.run(() => analyze(text, options));

/// Résultats de l'analyse d'un entretien, en cinq onglets.
class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key, required this.interview});

  final Interview interview;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  Analysis? _analysis;
  Object? _error;
  bool _aiRunning = false;
  bool _started = false;

  Interview get _it => widget.interview;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _compute();
    }
  }

  AnalysisOptions _options(Settings s) => AnalysisOptions(
        excludeInterviewer: s.excludeInterviewer,
        groupForms: s.groupForms,
        interviewerLabels: s.interviewerLabels,
        extraStopwords: {...s.globalStopwordSet, ...splitWords(_it.stopwords)},
      );

  Future<void> _compute() async {
    final settings = AppScope.of(context).settings;
    final text = _it.text;
    final options = _options(settings);
    setState(() {
      _analysis = null;
      _error = null;
    });
    try {
      // Calcul hors du fil de l'interface : un entretien d'une heure
      // compte plusieurs centaines de phrases.
      // La fonction lancée dans l'isolat doit être de premier niveau :
      // une fermeture créée ici emporterait l'état de l'écran (contexte,
      // widgets), que Dart refuse d'envoyer à un autre isolat.
      final a = await _runAnalysis(text, options);
      if (mounted) setState(() => _analysis = a);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = _analysis;
    return DefaultTabController(
      length: sections.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_it.title, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              tooltip: 'Options d\'analyse',
              icon: const Icon(Icons.tune_rounded),
              onPressed: a == null ? null : _showOptions,
            ),
            Builder(
              builder: (btnContext) => IconButton(
                tooltip: 'Exporter',
                icon: const Icon(Icons.ios_share_rounded),
                onPressed: a == null ? null : () => _export(btnContext, a),
              ),
            ),
            const SizedBox(width: 4),
          ],
          bottom: const SectionTabBar(),
        ),
        body: Backdrop(
          variant: 2,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: _error != null
                ? EmptyState(
                    key: const ValueKey('error'),
                    title: 'Analyse impossible',
                    message: '$_error',
                    accent: Accent.coral,
                  )
                : a == null
                    ? const _Loading(key: ValueKey('loading'))
                    : TabBarView(
                        key: ValueKey(a),
                        children: [
                          SummaryTab(
                            analysis: a,
                            interview: _it,
                            aiRunning: _aiRunning,
                            onGenerateAi: _generateAi,
                          ),
                          KeySentencesTab(analysis: a, interview: _it),
                          WordsTab(
                            analysis: a,
                            onWordTap: (w) => _openWord(a, w.key),
                          ),
                          NetworkTab(
                            analysis: a,
                            onWordTap: (key) => _openWord(a, key),
                          ),
                          TextTab(analysis: a),
                        ],
                      ),
          ),
        ),
      ),
    );
  }

  void _openWord(Analysis a, String key) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => WordSheet(
        analysis: a,
        wordKey: key,
        onIgnore: (label) {
          Navigator.pop(context);
          _ignoreWord(label);
        },
      ),
    );
  }

  Future<void> _ignoreWord(String label) async {
    final words = splitWords(_it.stopwords)..add(label.toLowerCase());
    final a = _analysis;
    // Ignorer toutes les formes regroupées sous ce mot.
    if (a != null) {
      for (final w in a.words) {
        if (w.label == label) words.addAll(w.forms.keys);
      }
    }
    _it.stopwords = words.join(', ');
    await AppScope.of(context).store.save(_it);
    if (mounted) {
      showSnack(context, '« $label » est ignoré pour cet entretien.');
      await _compute();
    }
  }

  Future<void> _showOptions() async {
    final settings = AppScope.of(context).settings;
    final stop = TextEditingController(text: _it.stopwords);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 16,
            right: 16),
        child: ListenableBuilder(
          listenable: settings,
          builder: (ctx, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Options d\'analyse',
                  style: Theme.of(ctx).textTheme.headlineSmall),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Exclure l\'enquêteur'),
                subtitle: const Text(
                    'Ne compter que la parole des personnes interrogées.'),
                value: settings.excludeInterviewer,
                onChanged: (v) => settings.excludeInterviewer = v,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Regrouper les formes'),
                subtitle: const Text(
                    'patient, patiente, patients… comptés ensemble.'),
                value: settings.groupForms,
                onChanged: (v) => settings.groupForms = v,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: stop,
                maxLines: 3,
                minLines: 1,
                decoration: const InputDecoration(
                  labelText: 'Mots ignorés pour cet entretien',
                  hintText: 'Bastia, Martin, cancer…',
                ),
              ),
              const SizedBox(height: 16),
              GradientButton(
                label: 'Relancer l\'analyse',
                icon: Icons.refresh_rounded,
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    _it.stopwords = stop.text;
    await AppScope.of(context).store.save(_it);
    if (mounted) await _compute();
  }

  Future<void> _export(BuildContext btnContext, Analysis a) async {
    final settings = AppScope.of(context).settings;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        Widget item(String value, IconData icon, String title, String sub,
                Accent accent) =>
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: IconBadge(icon, accent: accent, size: 44),
              title: Text(title, style: Theme.of(ctx).textTheme.titleSmall),
              subtitle: Text(sub),
              onTap: () => Navigator.pop(ctx, value),
            );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('Exporter',
                    style: Theme.of(ctx).textTheme.headlineSmall),
              ),
              item('md', Icons.description_rounded, 'Rapport complet',
                  'Markdown : Word, Pages, Notion…', Accent.violet),
              item('csv', Icons.table_chart_rounded, 'Tableau des fréquences',
                  'CSV pour Excel', Accent.mint),
              item('ira', Icons.hub_rounded, 'Corpus IRaMuTeQ',
                  'Cet entretien seul', Accent.coral),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (choice == null || !btnContext.mounted) return;
    final slug = fileSlug(_it.title);
    switch (choice) {
      case 'md':
        await shareTextFile(btnContext,
            fileName: '$slug.md',
            content: buildReport(
                title: _it.title, text: _it.text, analysis: a, ai: _it.ai));
      case 'csv':
        await shareTextFile(btnContext,
            fileName: '${slug}_frequences.csv',
            content: buildFrequencyCsv(a));
      case 'ira':
        await shareTextFile(btnContext,
            fileName: '${slug}_iramuteq.txt',
            content: buildIramuteq(
              [(id: _it.title, text: _it.text, variables: _it.variables)],
              onlyInterviewees: settings.excludeInterviewer,
              interviewerLabels: settings.interviewerLabels,
            ));
    }
  }

  Future<void> _generateAi() async {
    final settings = AppScope.of(context).settings;
    final provider = settings.summaryProvider;
    if (provider == null || !settings.hasKey(provider)) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Résumé par IA'),
          content: const Text(
              'Choisissez un fournisseur et saisissez votre clé API dans les '
              'réglages (rubrique « Résumé »). Le résumé calculé sur '
              'l\'appareil reste disponible sans clé.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK')),
          ],
        ),
      );
      return;
    }
    if (!await confirmCloudUse(context, settings, provider, audio: false)) {
      return;
    }
    if (!mounted) return;
    setState(() => _aiRunning = true);
    try {
      final r = await AiSummaryService(settings).summarize(_it.text, provider);
      _it.ai = r;
      if (mounted) await AppScope.of(context).store.save(_it);
    } catch (e) {
      if (mounted) await showErrorDialog(context, e);
    } finally {
      if (mounted) setState(() => _aiRunning = false);
    }
  }
}

class _Loading extends StatelessWidget {
  const _Loading({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListeningArt(size: 150),
          const SizedBox(height: 12),
          Text('Analyse en cours…',
              style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
