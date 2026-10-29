import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../data/interview.dart';
import '../engine/meeting.dart' show formatClock;
import '../engine/transcript.dart';
import 'app_scope.dart';
import 'common.dart';
import 'illustrations.dart';
import 'motion.dart';
import 'results_screen.dart';
import 'theme.dart';
import 'transcribe_screen.dart';

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

  /// Entretien supprimé depuis cet écran : ne plus rien enregistrer.
  bool _deleted = false;

  Interview get _it => widget.interview;

  @override
  void initState() {
    super.initState();
    _savedText = widget.interview.text;
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
    // Le texte en mémoire suit la frappe ; seule l'écriture sur disque est
    // différée.
    _it.text = _text.text;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 700), _saveNow);
  }

  String? _savedText;

  void _saveNow() {
    if (_deleted || _savedText == _text.text) return;
    _it.text = _text.text;
    _savedText = _text.text;
    _store.save(_it);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tones = Tones.of(context);
    final empty = _text.text.trim().isEmpty;
    final accent = Accent.forKey(_it.id);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 4,
        title: GestureDetector(
          onTap: _rename,
          child: Row(
            children: [
              InterviewAvatar(accent: accent, size: 34),
              const SizedBox(width: 10),
              Flexible(
                child: Text(_it.title, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Pseudonymiser',
            icon: const Icon(Icons.visibility_off_rounded),
            onPressed: _pseudonymize,
          ),
          IconButton(
            tooltip: 'Plus',
            icon: const Icon(Icons.more_horiz_rounded),
            onPressed: _menu,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Backdrop(
        variant: 1,
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: appCurve,
                child: _showTips
                    ? _Tips(onClose: () => setState(() => _showTips = false))
                    : const SizedBox(width: double.infinity),
              ),
              if (empty && _audioPath != null)
                FadeSlideIn(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: _TranscribeCard(
                      duration: _it.duration,
                      markers: _it.markers.length,
                      onTap: _transcribe,
                    ),
                  ),
                ),
              if (empty && widget.pasteOnOpen)
                FadeSlideIn(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: GradientButton(
                      label: 'Coller la retranscription',
                      icon: Icons.content_paste_rounded,
                      colors: const [Palette.violet, Color(0xFF9B7BFF)],
                      onPressed: _paste,
                    ),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: tones.raised,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: tones.rule),
                    ),
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
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.all(18),
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
              ),
              _BottomBar(
                labels: _it.isMeeting
                    ? const ['L1', 'L2', 'L3']
                    : const ['E', 'P1', 'P2'],
                onSpeaker: _insertSpeaker,
                onAnalyze: empty ? null : _analyze,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? get _audioPath => _store.audioPathOf(_it);

  Future<void> _transcribe() async {
    final path = _audioPath;
    if (path == null) return;
    final settings = AppScope.of(context).settings;
    final provider = settings.transcriptionProvider;
    if (provider != null &&
        !await confirmCloudUse(context, settings, provider, audio: true)) {
      return;
    }
    if (!mounted) return;
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) => TranscribeScreen(
          audioPath: path,
          fileName: _it.title,
          target: _it,
          kind: _it.kind,
        ),
      ),
    );
  }

  Future<void> _shareAudio() async {
    final path = _audioPath;
    if (path == null) return;
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(ShareParams(
      files: [XFile(path, mimeType: 'audio/mp4')],
      fileNameOverrides: ['${fileSlug(_it.title)}.m4a'],
      sharePositionOrigin:
          box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    ));
  }

  Future<void> _menu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) {
        Widget item(String value, IconData icon, String label, Accent accent,
                {bool danger = false}) =>
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: IconBadge(icon, accent: accent),
              title: Text(
                label,
                style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                      color: danger ? Tones.of(ctx).danger : null,
                    ),
              ),
              onTap: () => Navigator.pop(ctx, value),
            );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              item('rename', Icons.edit_rounded, 'Renommer', Accent.sky),
              item('speakers', Icons.groups_rounded, 'Renommer les locuteurs',
                  Accent.mint),
              item('variables', Icons.label_rounded, 'Variables (IRaMuTeQ)',
                  Accent.sun),
              item('share', Icons.ios_share_rounded, 'Partager le texte',
                  Accent.violet),
              if (_audioPath != null) ...[
                item('audio', Icons.audio_file_rounded,
                    'Partager l\'enregistrement', Accent.rose),
                if (_text.text.trim().isNotEmpty)
                  item('retranscribe', Icons.subtitles_rounded,
                      'Transcrire à nouveau', Accent.coral),
              ],
              item('delete', Icons.delete_outline_rounded,
                  'Supprimer l\'entretien', Accent.coral,
                  danger: true),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (!mounted) return;
    switch (choice) {
      case 'rename':
        await _rename();
      case 'speakers':
        await _renameSpeakers();
      case 'variables':
        await _editVariables();
      case 'share':
        await shareTextFile(context,
            fileName: '${fileSlug(_it.title)}.txt', content: _text.text);
      case 'audio':
        await _shareAudio();
      case 'retranscribe':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Transcrire à nouveau ?'),
            content: const Text('Le texte actuel, et vos corrections, seront '
                'remplacés par une nouvelle transcription.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Annuler')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Remplacer')),
            ],
          ),
        );
        if ((ok ?? false) && mounted) await _transcribe();
      case 'delete':
        _saveTimer?.cancel();
        final title = _it.title;
        if (await confirmDeleteInterview(context, _it) && mounted) {
          _deleted = true;
          final messenger = ScaffoldMessenger.of(context);
          Navigator.pop(context);
          messenger.showSnackBar(
              SnackBar(content: Text('« $title » supprimé.')));
        }
    }
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
    await renameInterview(context, _it);
    if (mounted) setState(() {});
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
    final t = Theme.of(context).textTheme;
    final fg = Accent.sun.onSoft(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: TintCard(
        accent: Accent.sun,
        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 10),
              child: Icon(Icons.tips_and_updates_rounded, color: fg),
            ),
            Expanded(
              child: Text(
                'Relisez la transcription avant de l\'analyser : corrigez les '
                'mots mal reconnus, marquez les locuteurs avec les boutons E '
                'et P1, et pseudonymisez les noms propres.',
                style: t.bodyMedium?.copyWith(color: fg),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onClose,
              icon: Icon(Icons.close_rounded, color: fg),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.labels,
    required this.onSpeaker,
    required this.onAnalyze,
  });

  /// Libellés proposés : le premier est l'enquêteur pour un entretien.
  final List<String> labels;

  final void Function(String label) onSpeaker;
  final VoidCallback? onAnalyze;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tones = Tones.of(context);
    Widget speaker(String label, Color bg, Color fg) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Pressable(
            onTap: () => onSpeaker(label),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 56,
              constraints: const BoxConstraints(minWidth: 50),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '$label :',
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: fg,
                ),
              ),
            ),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          for (final l in labels)
            l == 'E'
                ? speaker(l, scheme.surfaceContainerHighest, tones.muted)
                : speaker(l, Accent.forKey(l).soft(context),
                    Accent.forKey(l).onSoft(context)),
          Expanded(
            child: GradientButton(
              label: 'Analyser',
              icon: Icons.auto_graph_rounded,
              onPressed: onAnalyze,
            ),
          ),
        ],
      ),
    );
  }
}

class _TranscribeCard extends StatelessWidget {
  const _TranscribeCard({
    required this.duration,
    required this.markers,
    required this.onTap,
  });

  final Duration? duration;
  final int markers;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final fg = Accent.coral.onSoft(context);
    final d = duration;
    return TintCard(
      accent: Accent.coral,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const IconBadge(Icons.graphic_eq_rounded, accent: Accent.coral),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Enregistrement prêt',
                        style: t.titleMedium?.copyWith(color: fg)),
                    Text(
                      [
                        if (d != null) formatClock(d),
                        if (markers > 0)
                          '$markers moment${markers > 1 ? 's' : ''} marqué'
                              '${markers > 1 ? 's' : ''}',
                      ].join(' · '),
                      style: t.bodySmall?.copyWith(color: fg),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GradientButton(
            label: 'Transcrire l\'enregistrement',
            icon: Icons.subtitles_rounded,
            colors: const [Palette.coral, Palette.rose],
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}
