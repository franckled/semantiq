import 'package:flutter/material.dart';

import '../data/interview.dart';
import '../engine/analysis.dart';
import '../engine/meeting.dart';
import 'common.dart';
import 'illustrations.dart';
import 'motion.dart';
import 'results_tabs.dart';
import 'theme.dart';

/// Compte rendu d'une réunion : rédigé par une IA si demandé, et toujours un
/// repérage local des décisions, actions, questions et moments marqués.
class MinutesTab extends StatelessWidget {
  const MinutesTab({
    super.key,
    required this.analysis,
    required this.interview,
    required this.cues,
    required this.running,
    required this.onGenerate,
  });

  final Analysis analysis;
  final Interview interview;
  final MeetingCues cues;
  final bool running;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final m = interview.minutes;
    var n = 0;
    Widget step(Widget w) => FadeSlideIn.indexed(n++, child: w);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      children: [
        step(_MeetingStats(interview: interview, analysis: analysis, cues: cues)),
        const SizedBox(height: 18),
        if (m == null)
          step(AiInviteCard(
            title: 'Compte rendu par IA',
            text: 'Un modèle de langage rédige la synthèse, la liste des '
                'décisions, les actions avec leur responsable et leur '
                'échéance, et les points restés en suspens.',
            running: running,
            onGenerate: onGenerate,
          ))
        else ...[
          step(_MinutesCard(minutes: m, running: running, onRegenerate: onGenerate)),
          if (m.decisions.isNotEmpty) ...[
            const SectionTitle('Décisions', accent: Accent.mint),
            for (final d in m.decisions)
              step(_Bullet(text: d, icon: Icons.check_circle_rounded,
                  accent: Accent.mint)),
          ],
          if (m.actions.isNotEmpty) ...[
            const SectionTitle('Actions', accent: Accent.sun),
            for (final a in m.actions) step(_ActionCard(action: a)),
          ],
          if (m.openQuestions.isNotEmpty) ...[
            const SectionTitle('Points en suspens', accent: Accent.coral),
            for (final q in m.openQuestions)
              step(_Bullet(text: q, icon: Icons.help_rounded,
                  accent: Accent.coral)),
          ],
          if (m.nextSteps.isNotEmpty) ...[
            const SectionTitle('Prochaines étapes', accent: Accent.sky),
            for (final q in m.nextSteps)
              step(_Bullet(text: q, icon: Icons.arrow_circle_right_rounded,
                  accent: Accent.sky)),
          ],
        ],
        if (cues.moments.isNotEmpty) ...[
          const SectionTitle('Moments marqués',
              subtitle: 'Repérés pendant l\'enregistrement',
              accent: Accent.sun),
          for (final mm in cues.moments) step(_MomentCard(moment: mm)),
        ],
        if (m == null) _LocalCues(cues: cues),
      ],
    );
  }
}

class _MeetingStats extends StatelessWidget {
  const _MeetingStats({
    required this.interview,
    required this.analysis,
    required this.cues,
  });

  final Interview interview;
  final Analysis analysis;
  final MeetingCues cues;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget tile(String value, String label, IconData icon, Accent accent) =>
        Expanded(
          child: TintCard(
            accent: accent,
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 19, color: accent.onSoft(context)),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(value,
                      style: t.headlineSmall
                          ?.copyWith(color: accent.onSoft(context))),
                ),
                Text(label,
                    style: t.bodySmall?.copyWith(
                      color: accent.onSoft(context),
                      fontWeight: FontWeight.w700,
                    )),
              ],
            ),
          ),
        );
    final d = interview.duration;
    final m = interview.minutes;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          tile(d == null ? '—' : formatClock(d), 'durée', Icons.timer_rounded,
              Accent.rose),
          const SizedBox(width: 8),
          tile('${analysis.transcript.speakers.length}', 'voix',
              Icons.groups_rounded, Accent.violet),
          const SizedBox(width: 8),
          tile('${m?.decisions.length ?? cues.decisions.length}', 'décisions',
              Icons.check_circle_rounded, Accent.mint),
          const SizedBox(width: 8),
          tile('${m?.actions.length ?? cues.actions.length}', 'actions',
              Icons.task_alt_rounded, Accent.sun),
        ],
      ),
    );
  }
}

class _MinutesCard extends StatelessWidget {
  const _MinutesCard({
    required this.minutes,
    required this.running,
    required this.onRegenerate,
  });

  final MeetingMinutes minutes;
  final bool running;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tones = Tones.of(context);
    final m = minutes;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 8, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const IconBadge(Icons.event_note_rounded,
                    accent: Accent.rose, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Synthèse', style: t.titleMedium),
                      Text('${m.provider} · ${m.model} · à relire',
                          style: t.bodySmall?.copyWith(color: tones.muted)),
                    ],
                  ),
                ),
                running
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      )
                    : IconButton(
                        tooltip: 'Régénérer',
                        onPressed: onRegenerate,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: SelectableText(m.summary, style: t.bodyLarge),
            ),
            if (m.participants.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final p in m.participants) SpeakerChip(p),
                ],
              ),
            ],
            if (m.topics.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Sujets abordés', style: t.titleSmall),
              const SizedBox(height: 6),
              for (var i = 0; i < m.topics.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, right: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        margin: const EdgeInsets.only(right: 10, top: 1),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Accent.at(i).soft(context),
                          shape: BoxShape.circle,
                        ),
                        child: Text('${i + 1}',
                            style: t.labelSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: Accent.at(i).onSoft(context),
                            )),
                      ),
                      Expanded(child: Text(m.topics[i], style: t.bodyMedium)),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text, required this.icon, required this.accent});

  final String text;
  final IconData icon;
  final Accent accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: accent.soft(context),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: accent.onSoft(context)),
            const SizedBox(width: 10),
            Expanded(
              child: SelectableText(
                text,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: accent.onSoft(context),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.action});

  final ActionItem action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tones = Tones.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tones.raised,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tones.rule),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(right: 12, top: 1),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Palette.sun, width: 2.5),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(action.task,
                      style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                  if (action.owner.isNotEmpty || action.due.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (action.owner.isNotEmpty) SpeakerChip(action.owner),
                        if (action.due.isNotEmpty)
                          _DueChip(action.due),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DueChip extends StatelessWidget {
  const _DueChip(this.due);

  final String due;

  @override
  Widget build(BuildContext context) {
    final fg = Accent.sun.onSoft(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Accent.sun.soft(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_rounded, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(due,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(fontWeight: FontWeight.w800, color: fg)),
        ],
      ),
    );
  }
}

class _MomentCard extends StatelessWidget {
  const _MomentCard({required this.moment});

  final MarkedMoment moment;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final fg = Accent.sun.onSoft(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TintCard(
        accent: Accent.sun,
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.star_rounded, color: fg),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(moment.label,
                      style: t.titleSmall?.copyWith(color: fg)),
                  if (moment.excerpt.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    SelectableText(moment.excerpt,
                        style: t.bodyMedium?.copyWith(color: fg)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Repérage local, présenté par catégorie.
class _LocalCues extends StatelessWidget {
  const _LocalCues({required this.cues});

  final MeetingCues cues;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tones = Tones.of(context);
    if (cues.decisions.isEmpty &&
        cues.actions.isEmpty &&
        cues.questions.isEmpty) {
      return const EmptyState(
        title: 'Rien de repéré pour l\'instant',
        message: 'Aucune tournure de décision ou d\'action reconnue. Le '
            'compte rendu par IA lira l\'ensemble de la réunion.',
        accent: Accent.rose,
      );
    }
    Widget group(String title, List<Cue> items, Accent accent, IconData icon) {
      if (items.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(title, accent: accent),
          for (var i = 0; i < items.length; i++)
            FadeSlideIn.indexed(
              i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: tones.raised,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: tones.rule),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2, right: 10),
                        child: Icon(icon, size: 20, color: accent.color),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SentenceLine(sentence: items[i].sentence),
                            if (items[i].due.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: _DueChip(items[i].due),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 26, 4, 0),
          child: Row(
            children: [
              const IconBadge(Icons.manage_search_rounded,
                  accent: Accent.violet, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Repérage sur l\'iPhone', style: t.titleMedium),
                    Text('D\'après les tournures de phrase, à relire',
                        style: t.bodySmall?.copyWith(color: tones.muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
        group('Décisions', cues.decisions, Accent.mint,
            Icons.check_circle_rounded),
        group('Actions', cues.actions, Accent.sun, Icons.task_alt_rounded),
        group('Questions et points en suspens', cues.questions, Accent.coral,
            Icons.help_rounded),
      ],
    );
  }
}
