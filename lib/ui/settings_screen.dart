import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/settings.dart';
import 'app_scope.dart';
import 'common.dart';
import 'theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
      body: ListenableBuilder(
        listenable: s,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
          children: [
            const SectionTitle('Transcription des enregistrements'),
            _Choice<AiProvider?>(
              value: s.transcriptionProvider,
              options: [
                (null, 'Sur l\'iPhone', 'Rien ne quitte le téléphone. Plus lent.'),
                for (final p in AiProvider.values.where((p) => p.canTranscribe))
                  (p, p.label, p.note),
              ],
              onChanged: (v) => s.transcriptionProvider = v,
            ),
            if (s.transcriptionProvider == null) ...[
              const SizedBox(height: 8),
              Text('Modèle Whisper',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              _Choice<LocalModel>(
                value: s.localModel,
                options: [
                  for (final m in LocalModel.values)
                    (m, '${m.id} – ${m.label}',
                        'Téléchargé une fois : ${m.sizeMb} Mo'),
                ],
                onChanged: (v) => s.localModel = v,
              ),
            ] else ...[
              if (s.transcriptionProvider == AiProvider.mistral)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Séparer les locuteurs'),
                  subtitle: const Text(
                      'Le texte arrive découpé en « Locuteur 1 : », '
                      '« Locuteur 2 : »… à renommer ensuite.'),
                  value: s.diarize,
                  onChanged: (v) => s.diarize = v,
                ),
              _ModelField(
                fieldKey: 'stt-${s.transcriptionProvider!.name}',
                label: 'Modèle de transcription',
                value: s.transcriptionModel(s.transcriptionProvider!),
                onChanged: (v) =>
                    s.setTranscriptionModel(s.transcriptionProvider!, v),
              ),
            ],
            const SectionTitle('Résumé et thèmes'),
            _Choice<AiProvider?>(
              value: s.summaryProvider,
              options: [
                (null, 'Sur l\'iPhone uniquement',
                    'Résumé extractif : les phrases les plus centrales.'),
                for (final p in AiProvider.values) (p, p.label, p.note),
              ],
              onChanged: (v) => s.summaryProvider = v,
            ),
            if (s.summaryProvider != null)
              _ModelField(
                fieldKey: 'chat-${s.summaryProvider!.name}',
                label: 'Modèle de langage',
                value: s.chatModel(s.summaryProvider!),
                onChanged: (v) => s.setChatModel(s.summaryProvider!, v),
              ),
            const SectionTitle(
              'Clés API',
              subtitle: 'Rangées dans le trousseau sécurisé de l\'iPhone',
            ),
            for (final p in AiProvider.values) _KeyTile(provider: p),
            const SectionTitle('Analyse'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Exclure l\'enquêteur des statistiques'),
              value: s.excludeInterviewer,
              onChanged: (v) => s.excludeInterviewer = v,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Regrouper les formes d\'un même mot'),
              value: s.groupForms,
              onChanged: (v) => s.groupForms = v,
            ),
            const SizedBox(height: 8),
            _TextSetting(
              label: 'Autres libellés de l\'enquêteur',
              hint: 'Thésard, Interne, Marie…',
              helper: 'Déjà reconnus : E, Enq, Enquêteur, Enquêtrice, '
                  'Interviewer, I, Q, Chercheur…',
              value: s.extraInterviewerLabels,
              onChanged: (v) => s.extraInterviewerLabels = v,
            ),
            const SizedBox(height: 12),
            _TextSetting(
              label: 'Mots ignorés dans tous les entretiens',
              hint: 'docteur, madame…',
              value: s.globalStopwords,
              onChanged: (v) => s.globalStopwords = v,
            ),
            const SectionTitle('Méthode'),
            Text(
              'Fréquences : mots pleins, hors mots-outils et tics de '
              'l\'oral (euh, voilà, bon…). Phrases clés : algorithme '
              'TextRank, qui classe les phrases selon le vocabulaire qu\'elles '
              'partagent avec le reste de l\'entretien. Cooccurrences : mots '
              'réunis dans une même phrase, mesurés par l\'information '
              'mutuelle (log2 du rapport observé / attendu). Ces outils '
              'aident à explorer le matériau ; ils ne remplacent pas le '
              'codage thématique du chercheur.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Tones.of(context).muted),
            ),
            const CreditLine(),
          ],
        ),
      ),
    );
  }
}

class _Choice<T> extends StatelessWidget {
  const _Choice({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final List<(T, String, String)> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final tones = Tones.of(context);
    final t = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (v, title, subtitle) in options)
            ListTile(
              onTap: () => onChanged(v),
              leading: Icon(
                v == value
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: v == value ? tones.link : tones.muted,
              ),
              title: Text(title),
              subtitle: Text(subtitle,
                  style: t.bodySmall?.copyWith(color: tones.muted)),
            ),
        ],
      ),
    );
  }
}

class _ModelField extends StatelessWidget {
  const _ModelField({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String fieldKey;
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TextFormField(
        key: ValueKey(fieldKey),
        initialValue: value,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: label,
          helperText: 'Laissez vide pour revenir au modèle par défaut.',
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _TextSetting extends StatefulWidget {
  const _TextSetting({
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.helper,
  });

  final String label;
  final String value;
  final String? hint;
  final String? helper;
  final ValueChanged<String> onChanged;

  @override
  State<_TextSetting> createState() => _TextSettingState();
}

class _TextSettingState extends State<_TextSetting> {
  late final _c = TextEditingController(text: widget.value);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      minLines: 1,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        helperText: widget.helper,
        helperMaxLines: 3,
      ),
      onChanged: widget.onChanged,
    );
  }
}

class _KeyTile extends StatelessWidget {
  const _KeyTile({required this.provider});

  final AiProvider provider;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context).settings;
    final has = s.hasKey(provider);
    final tones = Tones.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          title: Text(provider.label),
          subtitle: Text(has ? 'Clé enregistrée' : 'Aucune clé',
              style: TextStyle(color: has ? tones.link : tones.muted)),
          trailing: const Icon(Icons.key_outlined),
          onTap: () => _edit(context, s),
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, Settings s) async {
    final c = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Clé ${provider.label}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: c,
              autofocus: true,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: s.hasKey(provider)
                    ? 'Nouvelle clé (remplace l\'actuelle)'
                    : 'Clé API',
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => launchUrl(Uri.parse(provider.keyUrl),
                    mode: LaunchMode.externalApplication),
                child: const Text('Obtenir une clé'),
              ),
            ),
          ],
        ),
        actions: [
          if (s.hasKey(provider))
            TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              child: const Text('Supprimer'),
            ),
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text),
              child: const Text('Enregistrer')),
        ],
      ),
    );
    if (result == null) return;
    await s.setApiKey(provider, result);
  }
}
