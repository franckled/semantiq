import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/interview.dart';
import '../engine/export.dart';
import '../sample_interview.dart';
import 'app_scope.dart';
import 'common.dart';
import 'editor_screen.dart';
import 'settings_screen.dart';
import 'theme.dart';
import 'transcribe_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final store = scope.store;
    final t = Theme.of(context).textTheme;
    final tones = Tones.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const _Wordmark(),
        actions: [
          IconButton(
            tooltip: 'Exporter le corpus pour IRaMuTeQ',
            icon: const Icon(Icons.ios_share),
            onPressed: () => _exportCorpus(context),
          ),
          IconButton(
            tooltip: 'Réglages',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _newInterview(context),
        icon: const Icon(Icons.add),
        label: const Text('Nouvel entretien'),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final items = store.items;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              if (items.isEmpty) ...[
                const SizedBox(height: 24),
                Text('Vos entretiens, mot à mot.', style: t.headlineSmall),
                const SizedBox(height: 12),
                Text(
                  'Importez un enregistrement ou collez une retranscription : '
                  'SemantiQ en tire le texte, un résumé, les mots les plus '
                  'fréquents, les phrases clés et les mots qui vont ensemble.',
                  style: t.bodyLarge?.copyWith(color: tones.muted),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => _openSample(context),
                  icon: const Icon(Icons.auto_stories_outlined),
                  label: const Text('Ouvrir un entretien d\'exemple'),
                ),
              ] else ...[
                SectionTitle('Entretiens',
                    subtitle: '${items.length} enregistré'
                        '${items.length > 1 ? 's' : ''} sur cet appareil'),
                for (final it in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _InterviewCard(interview: it),
                  ),
              ],
              const CreditLine(),
            ],
          );
        },
      ),
    );
  }

  Future<void> _newInterview(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.graphic_eq),
              title: const Text('Importer un enregistrement'),
              subtitle: const Text('Mémo vocal, dictaphone : m4a, mp3, wav…'),
              onTap: () => Navigator.pop(ctx, 'audio'),
            ),
            ListTile(
              leading: const Icon(Icons.content_paste),
              title: const Text('Coller une retranscription'),
              subtitle: const Text('Texte déjà transcrit'),
              onTap: () => Navigator.pop(ctx, 'text'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!context.mounted || choice == null) return;
    if (choice == 'text') {
      final store = AppScope.of(context).store;
      final it = store.create(title: store.nextTitle(), text: '',
          source: 'Texte collé');
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => EditorScreen(interview: it, pasteOnOpen: true)),
      );
    } else {
      await _importAudio(context);
    }
  }

  Future<void> _importAudio(BuildContext context) async {
    final scope = AppScope.of(context);
    final provider = scope.settings.transcriptionProvider;
    final PlatformFile? file;
    try {
      file = await FilePicker.pickFile(type: FileType.audio);
    } catch (e) {
      if (context.mounted) await showErrorDialog(context, e);
      return;
    }
    if (file == null || !context.mounted) return;
    final path = file.path;
    final name = file.name;
    if (path == null) {
      await showErrorDialog(context,
          "Ce fichier n'est pas accessible. Enregistrez-le d'abord dans "
          "l'app Fichiers, puis réessayez.");
      return;
    }
    if (provider != null &&
        !await confirmCloudUse(context, scope.settings, provider, audio: true)) {
      return;
    }
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => TranscribeScreen(audioPath: path, fileName: name),
      ),
    );
  }

  Future<void> _openSample(BuildContext context) async {
    final store = AppScope.of(context).store;
    final it = store.create(
        title: 'Exemple – vécu du parcours de soins',
        text: sampleInterview,
        source: 'Exemple fourni avec l\'app');
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => EditorScreen(interview: it)),
    );
  }

  Future<void> _exportCorpus(BuildContext context) async {
    final scope = AppScope.of(context);
    final items = scope.store.items.where((i) => i.text.trim().isNotEmpty);
    if (items.isEmpty) {
      showSnack(context, 'Aucun entretien à exporter.');
      return;
    }
    final corpus = buildIramuteq(
      [
        for (final it in items)
          (id: it.title, text: it.text, variables: it.variables),
      ],
      onlyInterviewees: scope.settings.excludeInterviewer,
      interviewerLabels: scope.settings.interviewerLabels,
    );
    await shareTextFile(context,
        fileName: 'corpus_iramuteq.txt',
        content: corpus,
        subject: 'Corpus IRaMuTeQ');
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    final tones = Tones.of(context);
    final style = Theme.of(context).appBarTheme.titleTextStyle;
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          const TextSpan(text: 'Semanti'),
          TextSpan(
            text: 'Q',
            style: TextStyle(
              backgroundColor: tones.markerSoft,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _InterviewCard extends StatelessWidget {
  const _InterviewCard({required this.interview});

  final Interview interview;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tones = Tones.of(context);
    final d = interview.updatedAt;
    final date = '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
              builder: (_) => EditorScreen(interview: interview)),
        ),
        onLongPress: () => _confirmDelete(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(interview.title, style: t.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${interview.wordCount} mots · $date'
                      '${interview.source.isEmpty ? '' : ' · ${interview.source}'}',
                      style: t.bodySmall?.copyWith(color: tones.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (interview.ai != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(Icons.auto_awesome, size: 18, color: tones.link),
                ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cet entretien ?'),
        content: Text('« ${interview.title} » sera définitivement supprimé de '
            'cet appareil.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer')),
        ],
      ),
    );
    if ((ok ?? false) && context.mounted) {
      await AppScope.of(context).store.delete(interview);
    }
  }
}
