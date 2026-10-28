import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/interview.dart';
import '../engine/transcript.dart';
import 'app_scope.dart';
import 'common.dart';
import 'results_screen.dart';
import 'theme.dart';

/// Relecture et préparation du verbatim : locuteurs, pseudonymisation,
/// puis lancement de l'analyse.
class EditorScreen extends StatefulWidget {
  const EditorScreen({
    super.key,
    required this.interview,
    this.pasteOnOpen = false,
    this.justTranscribed = false,
  });

  final Interview interview;

  /// Nouvel entretien vide : proposer de coller le presse-papiers.
  final bool pasteOnOpen;

  /// Arrivée depuis une transcription : afficher les conseils de relecture.
  final bool justTranscribed;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final TextEditingController _text =
      TextEditingController(text: widget.interview.text);
  final _focus = FocusNode();
  Timer? _saveTimer;
  late bool _showTips = widget.justTranscribed;
  late InterviewStore _store;

  Interview get _it => widget.interview;

  @override
  void initState() {
    super.initState();
    _text.addListener(_scheduleSave);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _store = AppScope.of(context).store;
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _saveNow();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 700), _saveNow);
  }

  void _saveNow() {
    if (_it.text == _text.text) return;
    _it.text = _text.text;
    _store.save(_it);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tones = Tones.of(context);
    final empty = _text.text.trim().isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _rename,
          child: Text(_it.title, overflow: TextOverflow.ellipsis),
        ),
        actions: [
          IconButton(
            tooltip: 'Pseudonymiser',
            icon: const Icon(Icons.visibility_off_outlined),
            onPressed: _pseudonymize,
          ),
          PopupMenuButton<String>(
            onSelected: (v) => switch (v) {
              'rename' => _rename(),
              'speakers' => _renameSpeakers(),
              'variables' => _editVariables(),
              'share' => shareTextFile(context,
                  fileName: '${fileSlug(_it.title)}.txt',
                  content: _text.text),
              _ => null,
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Renommer')),
              PopupMenuItem(
                  value: 'speakers', child: Text('Renommer les locuteurs')),
              PopupMenuItem(
                  value: 'variables',
                  child: Text('Variables (IRaMuTeQ)')),
              PopupMenuItem(value: 'share', child: Text('Partager le texte')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_showTips)
              _Tips(onClose: () => setState(() => _showTips = false)),
            if (empty && widget.pasteOnOpen)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: OutlinedButton.icon(
                  onPressed: _paste,
                  icon: const Icon(Icons.content_paste),
                  label: const Text('Coller la retranscription'),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: _text,
                  focusNode: _focus,
                  maxLines: null,
                  expands: true,
                  keyboardType: TextInputType.multiline,
                  textAlignVertical: TextAlignVertical.top,
                  style: t.bodyLarge,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'E : Pouvez-vous me parler de…\n'
                        'P1 : Alors, au début…\n\n'
                        'Indiquez les locuteurs en début de ligne '
                        '(E pour l\'enquêteur) : leurs propos seront '
                        'distingués dans l\'analyse.',
                    hintMaxLines: 8,
                    hintStyle: t.bodyLarge?.copyWith(color: tones.muted),
                  ),
                ),
              ),
            ),
            _BottomBar(
              onSpeaker: _insertSpeaker,
              onAnalyze: empty ? null : _analyze,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.trim().isEmpty) {
      if (mounted) showSnack(context, 'Le presse-papiers est vide.');
      return;
    }
    setState(() => _text.text = text);
  }

  /// Ajoute (ou remplace) un libellé de locuteur au début de la ligne où
  /// se trouve le curseur.
  void _insertSpeaker(String label) {
    final value = _text.value;
    final text = value.text;
    final cursor = value.selection.isValid
        ? value.selection.baseOffset.clamp(0, text.length)
        : text.length;
    final lineStart = cursor == 0 ? 0 : text.lastIndexOf('\n', cursor - 1) + 1;
    var lineEnd = text.indexOf('\n', lineStart);
    if (lineEnd < 0) lineEnd = text.length;
    final line = text.substring(lineStart, lineEnd);
    final existing =
        RegExp(r'^\s*[^:\n]{1,24}?\s*:\s*').firstMatch(line)?.group(0);
    final removed = existing != null &&
            RegExp(r'^[A-Za-zÀ-ÿ0-9 .]{1,24}$')
                .hasMatch(existing.replaceAll(':', '').trim())
        ? existing.length
        : 0;
    final insert = '$label : ';
    final newText = text.replaceRange(lineStart, lineStart + removed, insert);
    final newCursor = (cursor - removed).clamp(lineStart, newText.length) +
        insert.length;
    _text.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
          offset: newCursor.clamp(0, newText.length)),
    );
    _focus.requestFocus();
    setState(() {});
  }

  Future<void> _rename() async {
    final c = TextEditingController(text: _it.title);
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Titre de l\'entretien'),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text),
              child: const Text('OK')),
        ],
      ),
    );
    if (title == null || title.trim().isEmpty || !mounted) return;
    setState(() => _it.title = title.trim());
    await AppScope.of(context).store.save(_it);
  }

  Future<void> _renameSpeakers() async {
    final settings = AppScope.of(context).settings;
    final speakers = parseTranscript(_text.text,
            interviewerLabels: settings.interviewerLabels)
        .speakers;
    if (speakers.isEmpty) {
      showSnack(context,
          'Aucun locuteur repéré. Ajoutez « E : » ou « P1 : » en début de ligne.');
      return;
    }
    final controllers = {for (final s in speakers) s: TextEditingController(text: s)};
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renommer les locuteurs'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Par exemple « E » pour l\'enquêteur et « P1 » pour '
                  'la personne interrogée.'),
              const SizedBox(height: 12),
              for (final s in speakers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: controllers[s],
                    decoration: InputDecoration(labelText: s),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Renommer')),
        ],
      ),
    );
    if (!(ok ?? false)) return;
    var text = _text.text;
    controllers.forEach((old, c) {
      final name = c.text.trim();
      if (name.isEmpty || name == old) return;
      text = text.replaceAllMapped(
        RegExp('^(\\s*[\\[(]?)${RegExp.escape(old)}([\\])]?\\s*[:：])',
            multiLine: true),
        (m) => '${m.group(1)}$name${m.group(2)}',
      );
    });
    setState(() => _text.text = text);
  }

  Future<void> _pseudonymize() async {
    final find = TextEditingController();
    final replace = TextEditingController(text: '[X]');
    var count = 0;
    RegExp pattern(String w) => RegExp(
        '(?<![0-9A-Za-zÀ-ÿ])${RegExp.escape(w.trim())}(?![0-9A-Za-zÀ-ÿ])',
        caseSensitive: false);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Pseudonymiser'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Remplacez noms de personnes, lieux et '
                    'établissements avant toute analyse ou tout envoi à une '
                    'IA.'),
                const SizedBox(height: 12),
                TextField(
                  controller: find,
                  autofocus: true,
                  decoration: const InputDecoration(
                      labelText: 'Mot ou nom à remplacer'),
                  onChanged: (v) => setLocal(() => count = v.trim().isEmpty
                      ? 0
                      : pattern(v).allMatches(_text.text).length),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: replace,
                  decoration: const InputDecoration(labelText: 'Remplacer par'),
                ),
                const SizedBox(height: 8),
                Text('$count occurrence${count > 1 ? 's' : ''}'),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Fermer')),
            FilledButton(
                onPressed: count == 0 ? null : () => Navigator.pop(ctx, true),
                child: const Text('Remplacer')),
          ],
        ),
      ),
    );
    if (!(ok ?? false) || find.text.trim().isEmpty) return;
    setState(() {
      _text.text =
          _text.text.replaceAll(pattern(find.text), replace.text.trim());
    });
    if (mounted) {
      showSnack(context, '$count occurrence${count > 1 ? 's' : ''} '
          'remplacée${count > 1 ? 's' : ''}.');
    }
  }

  Future<void> _editVariables() async {
    final c = TextEditingController(
      text: _it.variables.entries.map((e) => '${e.key} = ${e.value}').join('\n'),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Variables de l\'entretien'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Une variable par ligne, utilisée dans l\'export '
                'IRaMuTeQ pour comparer les entretiens.'),
            const SizedBox(height: 12),
            TextField(
              controller: c,
              maxLines: 6,
              decoration: const InputDecoration(
                  hintText: 'sexe = femme\nage = 40-50\nprofession = IDE'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enregistrer')),
        ],
      ),
    );
    if (!(ok ?? false) || !mounted) return;
    _it.variables
      ..clear()
      ..addAll({
        for (final line in c.text.split('\n'))
          if (line.contains('='))
            line.split('=').first.trim(): line.split('=').skip(1).join('=').trim(),
      });
    await AppScope.of(context).store.save(_it);
  }

  Future<void> _analyze() async {
    _saveTimer?.cancel();
    _saveNow();
    FocusScope.of(context).unfocus();
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => ResultsScreen(interview: _it)),
    );
    if (mounted) setState(() => _text.text = _it.text);
  }
}

class _Tips extends StatelessWidget {
  const _Tips({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final tones = Tones.of(context);
    final t = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      decoration: BoxDecoration(
        color: tones.markerSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              'Relisez la transcription avant de l\'analyser : corrigez les '
              'mots mal reconnus, marquez les locuteurs avec les boutons E et '
              'P1, et pseudonymisez les noms propres.',
              style: t.bodyMedium?.copyWith(color: tones.onMarker),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onClose,
            icon: Icon(Icons.close, color: tones.onMarker),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.onSpeaker, required this.onAnalyze});

  final void Function(String label) onSpeaker;
  final VoidCallback? onAnalyze;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Row(
        children: [
          for (final l in const ['E', 'P1', 'P2'])
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                onPressed: () => onSpeaker(l),
                child: Text('$l :'),
              ),
            ),
          const SizedBox(width: 4),
          Expanded(
            child: FilledButton.icon(
              onPressed: onAnalyze,
              icon: const Icon(Icons.insights),
              label: const Text('Analyser'),
            ),
          ),
        ],
      ),
    );
  }
}
