import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../services/transcription.dart';
import 'app_scope.dart';
import 'editor_screen.dart';
import 'theme.dart';

/// Transcription d'un fichier audio, avec suivi de l'avancement. À la fin,
/// l'entretien est créé et ouvert dans l'éditeur.
class TranscribeScreen extends StatefulWidget {
  const TranscribeScreen({
    super.key,
    required this.audioPath,
    required this.fileName,
  });

  final String audioPath;
  final String fileName;

  @override
  State<TranscribeScreen> createState() => _TranscribeScreenState();
}

class _TranscribeScreenState extends State<TranscribeScreen> {
  String _stage = 'Préparation';
  double? _fraction;
  Object? _error;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _run();
    }
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
  }

  Future<void> _run() async {
    final scope = AppScope.of(context);
    // L'écran reste allumé : iOS suspend les apps en arrière-plan, ce qui
    // interromprait une longue transcription.
    try {
      await WakelockPlus.enable();
    } catch (_) {}
    try {
      final text = await TranscriptionService(scope.settings).transcribe(
        widget.audioPath,
        onProgress: (stage, fraction) {
          if (mounted) {
            setState(() {
              _stage = stage;
              _fraction = fraction;
            });
          }
        },
      );
      if (!mounted) return;
      final provider = scope.settings.transcriptionProvider;
      final it = scope.store.create(
        title: scope.store.nextTitle(),
        text: text,
        source: '${widget.fileName} · '
            '${provider == null ? 'transcrit sur l\'appareil' : 'transcrit par ${provider.label}'}',
      );
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => EditorScreen(interview: it, justTranscribed: true),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      try {
        await WakelockPlus.disable();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tones = Tones.of(context);
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: _error != null,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Transcription'),
          automaticallyImplyLeading: _error != null,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.fileName,
                    style: t.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 32),
                if (_error == null) ...[
                  Text(_stage, style: t.bodyLarge),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _fraction,
                      minHeight: 10,
                      color: tones.marker,
                      backgroundColor: tones.markerSoft,
                    ),
                  ),
                  if (_fraction != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('${(_fraction! * 100).round()} %',
                          style: t.bodySmall?.copyWith(color: tones.muted)),
                    ),
                  const SizedBox(height: 32),
                  Text(
                    'Gardez l\'app ouverte : l\'écran reste allumé pendant la '
                    'transcription. Sur l\'appareil, comptez quelques minutes '
                    'pour dix minutes d\'enregistrement selon le modèle choisi.',
                    style: t.bodyMedium?.copyWith(color: tones.muted),
                  ),
                ] else ...[
                  Icon(Icons.error_outline, color: scheme.error, size: 40),
                  const SizedBox(height: 12),
                  Text(_error.toString(), style: t.bodyLarge),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Retour'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
