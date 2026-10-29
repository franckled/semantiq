import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../services/transcription.dart';
import 'app_scope.dart';
import 'common.dart';
import 'editor_screen.dart';
import 'illustrations.dart';
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
    return PopScope(
      canPop: _error != null,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Transcription'),
          automaticallyImplyLeading: _error != null,
        ),
        body: Backdrop(
          variant: 2,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                child: _error == null
                    ? Column(
                        key: const ValueKey('run'),
                        children: [
                          const Spacer(),
                          ListeningArt(size: 240, progress: _fraction),
                          const SizedBox(height: 8),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: Text(
                              _fraction == null
                                  ? ' '
                                  : '${(_fraction! * 100).round()} %',
                              key: ValueKey(_fraction == null
                                  ? -1
                                  : (_fraction! * 100).round()),
                              style: t.headlineMedium,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(_stage,
                              style: t.titleMedium,
                              textAlign: TextAlign.center),
                          const SizedBox(height: 6),
                          Text(widget.fileName,
                              style: t.bodySmall?.copyWith(color: tones.muted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const Spacer(),
                          TintCard(
                            accent: Accent.sky,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.light_mode_rounded,
                                    color: Accent.sky.onSoft(context)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Gardez l\'app ouverte : l\'écran reste '
                                    'allumé pendant la transcription. Sur '
                                    'l\'iPhone, comptez quelques minutes pour '
                                    'dix minutes d\'enregistrement.',
                                    style: t.bodyMedium?.copyWith(
                                        color: Accent.sky.onSoft(context)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        key: const ValueKey('error'),
                        children: [
                          const Spacer(),
                          EmptyState(
                            title: 'La transcription n\'a pas abouti',
                            message: _error.toString(),
                            accent: Accent.coral,
                          ),
                          const Spacer(),
                          SizedBox(
                            width: double.infinity,
                            child: GradientButton(
                              label: 'Retour',
                              icon: Icons.arrow_back_rounded,
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
