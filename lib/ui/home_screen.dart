import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/interview.dart';
import '../engine/export.dart';
import '../sample_interview.dart';
import '../sample_meeting.dart';
import 'app_scope.dart';
import 'common.dart';
import 'editor_screen.dart';
import 'illustrations.dart';
import 'motion.dart';
import 'record_screen.dart';
import 'settings_screen.dart';
import 'theme.dart';
import 'transcribe_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context).store;
    return Scaffold(
      body: Backdrop(
        child: SafeArea(
          bottom: false,
          child: ListenableBuilder(
            listenable: store,
            builder: (context, _) {
              final items = store.items;
              return CustomScrollView(
                physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    sliver: SliverList.list(
                      children: [
                        _TopBar(onExport: () => _exportCorpus(context)),
                        const SizedBox(height: 22),
                        _Hero(items: items),
                        const SizedBox(height: 24),
                        FadeSlideIn(
                          delay: const Duration(milliseconds: 60),
                          child: _RecordTile(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                  builder: (_) => const RecordScreen()),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _ActionTiles(
                          onAudio: () => _importAudio(context),
                          onPaste: () => _pasteText(context),
                        ),
                        if (items.isEmpty) ...[
                          const SizedBox(height: 14),
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 260),
                            child: _SampleTile(
                              title: 'Essayer avec un entretien',
                              subtitle: 'Un entretien fictif, prêt à analyser',
                              accent: Accent.mint,
                              onTap: () => _openSample(context),
                            ),
                          ),
                          const SizedBox(height: 10),
                          FadeSlideIn(
                            delay: const Duration(milliseconds: 320),
                            child: _SampleTile(
                              title: 'Essayer avec une réunion',
                              subtitle: 'Décisions, actions, compte rendu',
                              accent: Accent.sky,
                              onTap: () => _openSampleMeeting(context),
                            ),
                          ),
                        ],
                        if (items.isNotEmpty)
                          SectionTitle(
                            'Mes entretiens',
                            subtitle: 'Balayez vers la gauche pour supprimer',
                            trailing: _CountPill(items.length),
                          ),
                      ],
                    ),
                  ),
                  if (items.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList.builder(
                        itemCount: items.length,
                        itemBuilder: (context, i) => FadeSlideIn.indexed(
                          i,
                          key: ValueKey(items[i].id),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _InterviewCard(interview: items[i]),
                          ),
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                        20, 0, 20, 24 + MediaQuery.paddingOf(context).bottom),
                    sliver: const SliverToBoxAdapter(child: CreditLine()),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _pasteText(BuildContext context) async {
    final store = AppScope.of(context).store;
    final it = store.create(
        title: store.nextTitle(), text: '', source: 'Texte collé');
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
          builder: (_) => EditorScreen(interview: it, pasteOnOpen: true)),
    );
    // Entretien laissé vide : on ne le garde pas.
    if (it.text.trim().isEmpty && context.mounted) {
      await AppScope.of(context).store.delete(it);
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
    final kind = await _askKind(context);
    if (kind == null || !context.mounted) return;
    if (provider != null &&
        !await confirmCloudUse(context, scope.settings, provider, audio: true)) {
      return;
    }
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            TranscribeScreen(audioPath: path, fileName: name, kind: kind),
      ),
    );
  }

  Future<InterviewKind?> _askKind(BuildContext context) {
    return showModalBottomSheet<InterviewKind>(
      context: context,
      builder: (ctx) {
        Widget option(InterviewKind k, IconData icon, String sub, Accent a) =>
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: IconBadge(icon, accent: a, size: 44),
              title: Text(k.label, style: Theme.of(ctx).textTheme.titleSmall),
              subtitle: Text(sub),
              onTap: () => Navigator.pop(ctx, k),
            );
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text('Cet enregistrement est…',
                    style: Theme.of(ctx).textTheme.headlineSmall),
              ),
              option(InterviewKind.interview, Icons.record_voice_over_rounded,
                  'Recherche qualitative : thèmes, verbatims', Accent.violet),
              option(InterviewKind.meeting, Icons.groups_rounded,
                  'Compte rendu : décisions, actions', Accent.rose),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openSampleMeeting(BuildContext context) async {
    final store = AppScope.of(context).store;
    final it = store.create(
      title: 'Exemple – réunion de lancement d\'étude',
      text: sampleMeeting,
      kind: InterviewKind.meeting,
      source: 'Exemple fourni avec l\'app',
      duration: const Duration(minutes: 14, seconds: 32),
      markers: const [Duration(minutes: 8, seconds: 12)],
    );
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => EditorScreen(interview: it)),
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

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onExport});

  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Wordmark(size: 32)),
        RoundIconButton(
          tooltip: 'Exporter le corpus pour IRaMuTeQ',
          icon: Icons.ios_share_rounded,
          onPressed: onExport,
        ),
        const SizedBox(width: 10),
        RoundIconButton(
          tooltip: 'Réglages',
          icon: Icons.tune_rounded,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.items});

  final List<Interview> items;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tones = Tones.of(context);
    final words = items.fold<int>(0, (s, i) => s + i.wordCount);
    final meetings = items.where((i) => i.isMeeting).length;
    final interviews = items.length - meetings;
    return FadeSlideIn(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Vos entretiens,', style: t.headlineMedium),
                ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (r) => const LinearGradient(
                    colors: Palette.brand,
                  ).createShader(r),
                  child: Text('mot à mot.',
                      style: t.headlineMedium
                          ?.copyWith(fontStyle: FontStyle.italic)),
                ),
                const SizedBox(height: 10),
                Text(
                  items.isEmpty
                      ? 'Entretiens et réunions : transcription, résumé, mots '
                          'clés et liens entre les idées.'
                      : [
                          if (interviews > 0)
                            '$interviews entretien${interviews > 1 ? 's' : ''}',
                          if (meetings > 0)
                            '$meetings réunion${meetings > 1 ? 's' : ''}',
                          '${_thousands(words)} mots',
                        ].join(' · '),
                  style: t.bodyMedium?.copyWith(color: tones.muted),
                ),
              ],
            ),
          ),
          const HeroArt(size: Size(150, 128)),
        ],
      ),
    );
  }

  static String _thousands(int n) {
    final s = n.toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
      b.write(s[i]);
    }
    return b.toString();
  }
}

class _ActionTiles extends StatelessWidget {
  const _ActionTiles({required this.onAudio, required this.onPaste});

  final VoidCallback onAudio;
  final VoidCallback onPaste;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FadeSlideIn(
            delay: const Duration(milliseconds: 120),
            child: _ActionTile(
              title: 'Importer\nun audio',
              subtitle: 'Mémo vocal, dictaphone',
              colors: const [Palette.coral, Color(0xFFFF9466)],
              art: TileArtKind.audio,
              onTap: onAudio,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FadeSlideIn(
            delay: const Duration(milliseconds: 190),
            child: _ActionTile(
              title: 'Coller\nun texte',
              subtitle: 'Retranscription',
              colors: const [Palette.violet, Color(0xFF9B7BFF)],
              art: TileArtKind.paste,
              onTap: onPaste,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.art,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final List<Color> colors;
  final TileArtKind art;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 172,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: colors.first.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TileArt(art, size: 54),
                const Spacer(),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_rounded,
                      color: Colors.white, size: 20),
                ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                fontFamily: displayFamily,
                fontSize: 22,
                height: 1.05,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontFamily: fontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 18, 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Palette.rose, Palette.coral],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Palette.rose.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mic_rounded,
                  color: Colors.white, size: 32),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enregistrer une réunion',
                    style: TextStyle(
                      fontFamily: displayFamily,
                      fontSize: 22,
                      height: 1.1,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Compte rendu, décisions et actions',
                    style: TextStyle(
                      fontFamily: fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class _SampleTile extends StatelessWidget {
  const _SampleTile({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Accent accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final fg = accent.onSoft(context);
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: accent.soft(context),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                gradient: accent.gradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const TileArt(TileArtKind.sample),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.titleSmall?.copyWith(color: fg)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: t.bodySmall?.copyWith(color: fg)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_rounded, color: fg),
          ],
        ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill(this.n);

  final int n;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Accent.violet.soft(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$n',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Accent.violet.onSoft(context),
            ),
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
    final accent = Accent.forKey(interview.id);
    final d = interview.updatedAt;
    final date = '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';

    return Dismissible(
      key: ValueKey('dismiss-${interview.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) =>
          confirmDeleteInterview(context, interview, deleteNow: false),
      onDismissed: (_) {
        final title = interview.title;
        AppScope.of(context).store.delete(interview);
        showSnack(context, '« $title » supprimé.');
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: tones.danger,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Supprimer',
                style: TextStyle(
                    fontFamily: fontFamily,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
            SizedBox(width: 8),
            Icon(Icons.delete_outline_rounded, color: Colors.white),
          ],
        ),
      ),
      child: Pressable(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
              builder: (_) => EditorScreen(interview: interview)),
        ),
        onLongPress: () => _actions(context),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
          decoration: BoxDecoration(
            color: tones.raised,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: tones.rule),
          ),
          child: Row(
            children: [
              InterviewAvatar(accent: accent),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(interview.title,
                        style: t.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (interview.isMeeting)
                          const _MiniChip('Réunion', Accent.rose,
                              icon: Icons.groups_rounded),
                        if (interview.text.trim().isEmpty &&
                            interview.audioFile != null)
                          const _MiniChip('À transcrire', Accent.coral,
                              icon: Icons.graphic_eq_rounded)
                        else
                          _MiniChip('${interview.wordCount} mots', accent),
                        Text(date,
                            style: t.bodySmall?.copyWith(color: tones.muted)),
                        if (interview.ai != null || interview.minutes != null)
                          const _MiniChip('IA', Accent.violet,
                              icon: Icons.auto_awesome_rounded),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Options',
                icon: Icon(Icons.more_horiz_rounded, color: tones.muted),
                onPressed: () => _actions(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _actions(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                child: Text(interview.title,
                    style: Theme.of(ctx).textTheme.headlineSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
              _SheetAction(
                icon: Icons.edit_rounded,
                label: 'Renommer',
                accent: Accent.sky,
                onTap: () => Navigator.pop(ctx, 'rename'),
              ),
              _SheetAction(
                icon: Icons.delete_outline_rounded,
                label: 'Supprimer l\'entretien',
                accent: Accent.coral,
                danger: true,
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted) return;
    switch (choice) {
      case 'rename':
        await renameInterview(context, interview);
      case 'delete':
        final title = interview.title;
        if (await confirmDeleteInterview(context, interview) &&
            context.mounted) {
          showSnack(context, '« $title » supprimé.');
        }
    }
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final Accent accent;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final tones = Tones.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: tones.raised,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              IconBadge(icon, accent: accent),
              const SizedBox(width: 14),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: danger ? tones.danger : null,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip(this.label, this.accent, {this.icon});

  final String label;
  final Accent accent;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = accent.onSoft(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: accent.soft(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 3),
          ],
          Text(label,
              style: TextStyle(
                  fontFamily: fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: fg)),
        ],
      ),
    );
  }
}
