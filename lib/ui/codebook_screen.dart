import 'package:flutter/material.dart';

import '../data/interview.dart';
import '../engine/coding.dart';
import 'common.dart';
import 'illustrations.dart';
import 'motion.dart';
import 'theme.dart';

/// Livre de codes du corpus : les codes de tous les entretiens, rangés par
/// thème, avec leurs verbatims et la courbe de saturation.
class CodebookScreen extends StatelessWidget {
  const CodebookScreen({super.key, required this.store});

  final InterviewStore store;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Livre de codes'),
        actions: [
          Builder(
            builder: (btnContext) => IconButton(
              tooltip: 'Exporter',
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: () => _export(btnContext),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Backdrop(
        variant: 2,
        child: SafeArea(
          top: false,
          bottom: false,
          child: CodebookView(store: store),
        ),
      ),
    );
  }

  Future<void> _export(BuildContext btnContext) async {
    if (store.codes.isEmpty) {
      showSnack(btnContext, 'Le livre de codes est vide.');
      return;
    }
    final choice = await showModalBottomSheet<String>(
      context: btnContext,
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
              item('md', Icons.menu_book_rounded, 'Livre de codes',
                  'Thèmes, codes, définitions et verbatims', Accent.violet),
              item('csv', Icons.grid_on_rounded, 'Matrice codes × entretiens',
                  'CSV pour Excel', Accent.mint),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (choice == null || !btnContext.mounted) return;
    switch (choice) {
      case 'md':
        await shareTextFile(btnContext,
            fileName: 'livre_de_codes.md',
            content: buildCodebookReport(
                codes: store.codes, sources: store.codedSources),
            subject: 'Livre de codes');
      case 'csv':
        await shareTextFile(btnContext,
            fileName: 'matrice_codes_entretiens.csv',
            content: buildCodingMatrixCsv(store.codes, store.codedSources),
            subject: 'Matrice codes × entretiens');
    }
  }
}

/// Contenu du livre de codes, sans la barre de titre.
class CodebookView extends StatelessWidget {
  const CodebookView({super.key, required this.store});

  final InterviewStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final bottom = 40 + MediaQuery.paddingOf(context).bottom;
        final codes = store.codes;
        if (codes.isEmpty) {
          return ListView(
            padding: EdgeInsets.fromLTRB(16, 4, 16, bottom),
            children: const [
              EmptyState(
                title: 'Votre livre de codes est vide',
                message: 'Ouvrez un entretien, touchez « Analyser », puis '
                    'l\'onglet « Codage » : chaque phrase peut recevoir un '
                    'code. Les codes de tous vos entretiens se rassemblent '
                    'ici, avec leurs verbatims.',
                accent: Accent.violet,
              ),
            ],
          );
        }
        final sources = store.codedSources;
        final usages = codeUsages(codes, sources);
        final points = saturation(codes, sources);
        final groups = groupByTheme(usages);
        final excerpts =
            usages.fold<int>(0, (n, u) => n + u.excerpts.length);
        final most = usages.fold<int>(
            1, (n, u) => u.excerpts.length > n ? u.excerpts.length : n);
        var order = 0;
        Widget step(Widget w) => FadeSlideIn.indexed(order++, child: w);

        return ListView(
          padding: EdgeInsets.fromLTRB(16, 4, 16, bottom),
          children: [
            const SizedBox(height: 12),
            step(_Totals(
              codes: codes.length,
              excerpts: excerpts,
              interviews: points.length,
            )),
            if (points.isNotEmpty) ...[
              const SectionTitle(
                'Saturation des données',
                subtitle: 'Codes nouveaux à chaque entretien, dans l\'ordre '
                    'où ils ont été menés',
                accent: Accent.mint,
              ),
              step(_SaturationCard(points: points)),
            ],
            for (final g in groups.entries) ...[
              SectionTitle(
                g.key.isEmpty ? 'Codes sans thème' : g.key,
                subtitle: g.key.isEmpty
                    ? 'Touchez un code pour le rattacher à un thème'
                    : '${g.value.length} code${g.value.length > 1 ? 's' : ''}',
                accent: g.key.isEmpty ? null : Accent.forKey(g.key),
              ),
              for (final u in g.value)
                step(Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CodeCard(
                    usage: u,
                    most: most,
                    onTap: () => showCodeDetail(context, store, u.code),
                  ),
                )),
            ],
          ],
        );
      },
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({
    required this.codes,
    required this.excerpts,
    required this.interviews,
  });

  final int codes;
  final int excerpts;
  final int interviews;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget fact(int value, String label, Accent accent) => Expanded(
          child: TintCard(
            accent: accent,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedCount(
                  value,
                  style: TextStyle(
                    fontFamily: displayFamily,
                    fontSize: 30,
                    height: 1,
                    color: accent.onSoft(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 2,
                  style: t.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: accent.onSoft(context),
                  ),
                ),
              ],
            ),
          ),
        );
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          fact(codes, codes > 1 ? 'codes' : 'code', Accent.violet),
          const SizedBox(width: 10),
          fact(excerpts, excerpts > 1 ? 'extraits codés' : 'extrait codé',
              Accent.coral),
          const SizedBox(width: 10),
          fact(interviews,
              interviews > 1 ? 'entretiens codés' : 'entretien codé',
              Accent.mint),
        ],
      ),
    );
  }
}

class _SaturationCard extends StatelessWidget {
  const _SaturationCard({required this.points});

  final List<SaturationPoint> points;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tones = Tones.of(context);
    final total = points.last.cumulative;
    final reading = saturationReading(points);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final p in points)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(p.title,
                              style: t.titleSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 8),
                        _NewBadge(count: p.newCodes.length),
                      ],
                    ),
                    const SizedBox(height: 8),
                    GrowBar(
                      value: total == 0 ? 0 : p.cumulative / total,
                      color: Palette.mint,
                      background: tones.rule,
                      height: 10,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${p.cumulative} code${p.cumulative > 1 ? 's' : ''} '
                      'au total après cet entretien',
                      style: t.bodySmall?.copyWith(color: tones.muted),
                    ),
                  ],
                ),
              ),
            if (reading != null)
              Text(reading, style: t.bodyMedium)
            else
              Text(
                'Codez au moins deux entretiens pour suivre la saturation.',
                style: t.bodyMedium?.copyWith(color: tones.muted),
              ),
          ],
        ),
      ),
    );
  }
}

class _NewBadge extends StatelessWidget {
  const _NewBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final accent = count == 0 ? Accent.mint : Accent.sun;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: accent.soft(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count == 0
            ? 'aucun nouveau'
            : '+$count nouveau${count > 1 ? 'x' : ''}',
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: accent.onSoft(context),
        ),
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({
    required this.usage,
    required this.most,
    required this.onTap,
  });

  final CodeUsage usage;
  final int most;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tones = Tones.of(context);
    final accent = Accent.at(usage.code.color);
    final n = usage.excerpts.length;
    final m = usage.sources;
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
        decoration: BoxDecoration(
          color: tones.raised,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: tones.rule),
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration:
                  BoxDecoration(color: accent.color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(usage.code.label, style: t.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    n == 0
                        ? 'Aucun extrait'
                        : '$n extrait${n > 1 ? 's' : ''} · $m '
                            'entretien${m > 1 ? 's' : ''}',
                    style: t.bodySmall?.copyWith(color: tones.muted),
                  ),
                  const SizedBox(height: 8),
                  GrowBar(
                    value: n / most,
                    color: accent.color,
                    background: accent.soft(context),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: tones.muted),
          ],
        ),
      ),
    );
  }
}

/// Ouvre la fiche d'un code : définition et verbatims dans tout le corpus.
Future<void> showCodeDetail(
    BuildContext context, InterviewStore store, Code code) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => CodeDetailSheet(store: store, codeId: code.id),
  );
}

class CodeDetailSheet extends StatelessWidget {
  const CodeDetailSheet({super.key, required this.store, required this.codeId});

  final InterviewStore store;
  final String codeId;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tones = Tones.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final code = store.codeById(codeId);
        if (code == null) return const SizedBox(height: 24);
        final accent = Accent.at(code.color);
        final usage = codeUsages([code], store.codedSources).first;
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.86,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                            color: accent.color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(code.label, style: t.headlineSmall),
                      ),
                      IconButton(
                        tooltip: 'Modifier le code',
                        icon: const Icon(Icons.edit_rounded),
                        onPressed: () => editCode(context, store, code),
                      ),
                      IconButton(
                        tooltip: 'Supprimer le code',
                        icon: Icon(Icons.delete_outline_rounded,
                            color: tones.danger),
                        onPressed: () => _delete(context, code),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    children: [
                      Text(
                        code.theme.trim().isEmpty
                            ? 'Sans thème'
                            : 'Thème : ${code.theme.trim()}',
                        style: t.labelLarge?.copyWith(color: tones.muted),
                      ),
                      if (code.note.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(code.note.trim(), style: t.bodyMedium),
                      ],
                      const SizedBox(height: 14),
                      if (usage.excerpts.isEmpty)
                        Text(
                          'Aucun extrait ne porte encore ce code.',
                          style: t.bodyMedium?.copyWith(color: tones.muted),
                        ),
                      for (final e in usage.excerpts)
                        _ExcerptTile(excerpt: e, accent: accent),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _delete(BuildContext context, Code code) async {
    final n = store.codedSources
        .expand((s) => s.codings)
        .where((k) => k.codeId == code.id)
        .length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final tones = Tones.of(ctx);
        return AlertDialog(
          icon:
              Icon(Icons.delete_outline_rounded, color: tones.danger, size: 34),
          title: const Text('Supprimer ce code ?'),
          content: Text(n == 0
              ? '« ${code.label} » sera retiré du livre de codes.'
              : '« ${code.label} » sera retiré du livre de codes, ainsi que '
                  'de $n extrait${n > 1 ? 's' : ''}. Les verbatims, eux, ne '
                  'changent pas.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: tones.danger,
                foregroundColor: Colors.white,
                minimumSize: const Size(48, 46),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );
    if (!(ok ?? false) || !context.mounted) return;
    Navigator.pop(context);
    await store.deleteCode(code);
  }
}

class _ExcerptTile extends StatelessWidget {
  const _ExcerptTile({required this.excerpt, required this.accent});

  final CodeExcerpt excerpt;
  final Accent accent;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tones = Tones.of(context);
    final speaker = excerpt.speaker;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.soft(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            '« ${excerpt.quote} »',
            style: t.bodyMedium?.copyWith(
              fontStyle: FontStyle.italic,
              color: accent.onSoft(context),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (speaker != null) ...[
                SpeakerChip(speaker),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  excerpt.sourceTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: accent.onSoft(context),
                  ),
                ),
              ),
            ],
          ),
          if (!excerpt.found)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 15, color: tones.danger),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Introuvable tel quel dans le verbatim actuel : à '
                      'vérifier avant de le citer',
                      style: t.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: tones.danger,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Modifie le nom, le thème et la définition d'un code.
Future<void> editCode(
    BuildContext context, InterviewStore store, Code code) async {
  final name = TextEditingController(text: code.label);
  final theme = TextEditingController(text: code.theme);
  final note = TextEditingController(text: code.note);
  final themes = {
    for (final c in store.codes)
      if (c.theme.trim().isNotEmpty) c.theme.trim(),
  };
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Modifier le code'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nom du code'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: theme,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Thème',
                helperText: themes.isEmpty
                    ? 'Regroupe plusieurs codes proches'
                    : 'Déjà utilisés : ${themes.join(', ')}',
                helperMaxLines: 3,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: note,
              textCapitalization: TextCapitalization.sentences,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Définition',
                hintText: 'Ce que le code recouvre, ce qu\'il exclut',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Enregistrer'),
        ),
      ],
    ),
  );
  if (!(ok ?? false)) return;
  if (name.text.trim().isNotEmpty) code.label = name.text.trim();
  code.theme = theme.text.trim();
  code.note = note.text.trim();
  await store.saveCodebook();
}
