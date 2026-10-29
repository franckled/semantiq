import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/interview.dart';
import '../services/settings.dart';
import 'app_scope.dart';
import 'illustrations.dart';
import 'motion.dart';
import 'theme.dart';

/// Auteur de l'application.
abstract final class Credit {
  static const author = 'Franck LE DUFF';
  static const copyright = '© ${AppInfo.year} $author';
}

/// Version et date de compilation, fournies au moment de la compilation
/// (--dart-define=APP_VERSION=… --dart-define=BUILD_DATE=…).
abstract final class AppInfo {
  static const version =
      String.fromEnvironment('APP_VERSION', defaultValue: 'développement');

  /// Date de compilation, au format JJ/MM/AAAA.
  static const buildDate = String.fromEnvironment('BUILD_DATE');

  static const year = String.fromEnvironment('BUILD_YEAR', defaultValue: '2026');
}

/// Mention d'auteur, discrète, en bas de page.
class CreditLine extends StatelessWidget {
  const CreditLine({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tones = Tones.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 32, 4, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 18,
            margin: const EdgeInsets.only(top: 1, right: 12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: Palette.brand,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Text(
              Credit.copyright,
              style: t.bodySmall?.copyWith(color: tones.muted, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Le nom de l'app, le Q en dégradé.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 30});

  final double size;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    final style = TextStyle(
      fontFamily: displayFamily,
      fontSize: size,
      height: 1,
      color: color,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text('Semanti', style: style),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (r) => const LinearGradient(
            colors: Palette.brand,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(r),
          child: Text('Q', style: style.copyWith(fontStyle: FontStyle.italic)),
        ),
      ],
    );
  }
}

/// Bouton principal, en dégradé de la marque.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.colors = Palette.brand,
    this.height = 56,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final List<Color> colors;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Pressable(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.45,
        duration: const Duration(milliseconds: 200),
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: colors.first.withValues(alpha: 0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: fontFamily,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bouton rond, discret, pour les barres d'en-tête.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final tones = Tones.of(context);
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: tones.raised,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: tones.rule),
          ),
          child: Icon(icon, size: 22),
        ),
      ),
    );
  }
}

/// Affiche une erreur dans une boîte de dialogue.
Future<void> showErrorDialog(BuildContext context, Object error) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(Icons.error_outline_rounded,
          color: Tones.of(ctx).danger, size: 34),
      title: const Text('Un souci est survenu'),
      content: SingleChildScrollView(child: Text(error.toString())),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

void showSnack(BuildContext context, String message, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), action: action));
}

/// Demande confirmation puis supprime l'entretien. Renvoie true s'il a été
/// supprimé.
///
/// Avec [deleteNow] à false, seule la confirmation est demandée (le
/// balayage d'une carte supprime lui-même une fois l'animation finie).
Future<bool> confirmDeleteInterview(
  BuildContext context,
  Interview interview, {
  bool deleteNow = true,
}) async {
  HapticFeedback.mediumImpact();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final tones = Tones.of(ctx);
      return AlertDialog(
        icon: Icon(Icons.delete_outline_rounded, color: tones.danger, size: 34),
        title: const Text('Supprimer cet entretien ?'),
        content: Text('« ${interview.title} » sera définitivement effacé de '
            'cet appareil, avec son analyse.'),
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
  if (!(ok ?? false) || !context.mounted) return false;
  if (deleteNow) await AppScope.of(context).store.delete(interview);
  return true;
}

/// Demande un titre et renomme l'entretien.
Future<void> renameInterview(BuildContext context, Interview interview) async {
  final c = TextEditingController(text: interview.title);
  final title = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Renommer'),
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
  if (title == null || title.trim().isEmpty || !context.mounted) return;
  interview.title = title.trim();
  await AppScope.of(context).store.save(interview);
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
      icon: const IconBadge(Icons.shield_outlined, accent: Accent.violet, size: 52),
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

/// En-tête de section, avec une pastille de couleur facultative.
class SectionTitle extends StatelessWidget {
  const SectionTitle(
    this.title, {
    super.key,
    this.subtitle,
    this.trailing,
    this.accent,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Accent? accent;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 26, 4, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (accent != null)
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: accent!.color,
                shape: BoxShape.circle,
              ),
            ),
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

/// Carte à fond légèrement teinté d'une couleur du spectre.
class TintCard extends StatelessWidget {
  const TintCard({
    super.key,
    required this.accent,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Accent accent;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: accent.soft(context),
        borderRadius: BorderRadius.circular(22),
      ),
      child: child,
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
    this.highlight,
  });

  final String text;

  /// Prédicat appliqué à chaque mot (en minuscules).
  final bool Function(String word) matches;
  final TextStyle? style;
  final Color? highlight;

  @override
  Widget build(BuildContext context) {
    final tones = Tones.of(context);
    final base = style ?? Theme.of(context).textTheme.bodyMedium;
    final spans = <TextSpan>[];
    var last = 0;
    for (final m in RegExp(r'[0-9A-Za-zÀ-ÖØ-öø-ÿŒœÆæ-]+').allMatches(text)) {
      if (!matches(m.group(0)!.toLowerCase())) continue;
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      spans.add(TextSpan(
        text: m.group(0),
        style: TextStyle(
          backgroundColor: highlight ?? tones.markerSoft,
          fontWeight: FontWeight.w800,
        ),
      ));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return Text.rich(TextSpan(style: base, children: spans));
  }
}

/// Pastille indiquant le locuteur, dans la teinte propre à chacun.
class SpeakerChip extends StatelessWidget {
  const SpeakerChip(this.speaker, {super.key, this.interviewer = false});

  final String speaker;
  final bool interviewer;

  @override
  Widget build(BuildContext context) {
    final tones = Tones.of(context);
    final scheme = Theme.of(context).colorScheme;
    final accent = Accent.forKey(speaker);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: interviewer ? scheme.surfaceContainerHighest : accent.soft(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            interviewer ? Icons.mic_none_rounded : Icons.person_rounded,
            size: 14,
            color: interviewer ? tones.muted : accent.onSoft(context),
          ),
          const SizedBox(width: 4),
          Text(
            speaker,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: interviewer ? tones.muted : accent.onSoft(context),
                ),
          ),
        ],
      ),
    );
  }
}

/// État vide illustré.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.accent = Accent.sky,
    this.kind = TileArtKind.empty,
  });

  final String title;
  final String message;
  final Accent accent;
  final TileArtKind kind;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: accent.gradient,
              borderRadius: BorderRadius.circular(30),
            ),
            child: TileArt(kind),
          ),
          const SizedBox(height: 18),
          Text(title, style: t.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            message,
            style: t.bodyMedium?.copyWith(color: Tones.of(context).muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
