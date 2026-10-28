import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/settings.dart';
import 'theme.dart';

/// Auteur et structure de rattachement.
abstract final class Credit {
  static const author = 'Dr Franck LE DUFF';
  static const hospital = 'Centre Hospitalier de Bastia';
  static const unit = 'Unité de Recherche Clinique';
  static const oneLine = '$author – $hospital – $unit';
}

/// Mention d'auteur, discrète, en bas de page.
class CreditLine extends StatelessWidget {
  const CreditLine({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tones = Tones.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 28, 4, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 44,
            margin: const EdgeInsets.only(top: 2, right: 12),
            decoration: BoxDecoration(
              color: tones.marker,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Text(
              '${Credit.author}\n${Credit.hospital}\n${Credit.unit}',
              style: t.bodySmall?.copyWith(color: tones.muted, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// Affiche une erreur dans une boîte de dialogue.
Future<void> showErrorDialog(BuildContext context, Object error) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Une erreur est survenue'),
      content: SingleChildScrollView(child: Text(error.toString())),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Avant tout envoi à un service extérieur : rappel des règles de
/// confidentialité. Renvoie true si l'utilisateur confirme.
Future<bool> confirmCloudUse(
  BuildContext context,
  Settings settings,
  AiProvider provider, {
  required bool audio,
}) async {
  if (settings.privacyAccepted(provider)) return true;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Envoi à ${provider.label}'),
      content: SingleChildScrollView(
        child: Text(
          audio
              ? "L'enregistrement va être envoyé à ${provider.label} pour être "
                  'transcrit. ${provider.note}\n\n'
                  "Un enregistrement contient la voix de la personne : c'est "
                  'une donnée identifiante. Vérifiez que la note '
                  "d'information remise aux participants et l'avis de votre "
                  'comité d\'éthique autorisent ce traitement, ou choisissez la '
                  'transcription sur l\'iPhone dans les réglages.'
              : 'Le texte va être envoyé à ${provider.label}. '
                  '${provider.note}\n\n'
                  'Pseudonymisez-le d\'abord (noms, lieux, établissements) '
                  'avec le bouton « Pseudonymiser » de l\'éditeur.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text("J'ai compris, envoyer"),
        ),
      ],
    ),
  );
  if (ok ?? false) settings.acceptPrivacy(provider);
  return ok ?? false;
}

/// Partage un texte sous forme de fichier (AirDrop, Mail, Fichiers…).
Future<void> shareTextFile(
  BuildContext context, {
  required String fileName,
  required String content,
  String? subject,
}) async {
  final box = context.findRenderObject() as RenderBox?;
  final origin =
      box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsString(content, flush: true);
  await SharePlus.instance.share(ShareParams(
    files: [XFile(file.path)],
    subject: subject ?? fileName,
    sharePositionOrigin: origin,
  ));
}

/// Nom de fichier sûr à partir d'un titre.
String fileSlug(String title) {
  final s = title
      .trim()
      .replaceAll(RegExp(r'[^0-9A-Za-zÀ-ÿ _-]'), '')
      .replaceAll(RegExp(r'\s+'), '_');
  return s.isEmpty ? 'entretien' : s;
}

/// En-tête de section dans les listes.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.titleMedium),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!,
                        style: t.bodySmall
                            ?.copyWith(color: Tones.of(context).muted)),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Texte où les occurrences de certains mots sont surlignées.
class HighlightedText extends StatelessWidget {
  const HighlightedText(
    this.text, {
    super.key,
    required this.matches,
    this.style,
  });

  final String text;

  /// Prédicat appliqué à chaque mot (en minuscules).
  final bool Function(String word) matches;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final tones = Tones.of(context);
    final base = style ?? Theme.of(context).textTheme.bodyMedium;
    final spans = <TextSpan>[];
    var last = 0;
    for (final m
        in RegExp(r'[0-9A-Za-zÀ-ÖØ-öø-ÿŒœÆæ-]+').allMatches(text)) {
      if (!matches(m.group(0)!.toLowerCase())) continue;
      if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
      spans.add(TextSpan(
        text: m.group(0),
        style: TextStyle(
          backgroundColor: tones.markerSoft,
          fontWeight: FontWeight.w700,
        ),
      ));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return Text.rich(TextSpan(style: base, children: spans));
  }
}

/// Pastille indiquant le locuteur.
class SpeakerChip extends StatelessWidget {
  const SpeakerChip(this.speaker, {super.key, this.interviewer = false});

  final String speaker;
  final bool interviewer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tones = Tones.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: interviewer ? scheme.surfaceContainerHighest : tones.linkSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        speaker,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: interviewer ? tones.muted : scheme.onSecondaryContainer,
            ),
      ),
    );
  }
}
