import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../data/interview.dart';
import '../engine/meeting.dart';
import '../services/recorder.dart';
import 'app_scope.dart';
import 'common.dart';
import 'editor_screen.dart';
import 'illustrations.dart';
import 'motion.dart';
import 'theme.dart';
import 'transcribe_screen.dart';

/// Enregistrement d'une réunion en direct : minuteur, onde sonore, pause et
/// moments marqués. À l'arrêt, la réunion est créée avec son fichier audio,
/// puis transcrite.
class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  MeetingRecorder? _rec;
  final _title = TextEditingController();
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_rec == null) {
      final store = AppScope.of(context).store;
      _rec = MeetingRecorder(directory: store.recordingsDir);
      _title.text = store.nextTitle(InterviewKind.meeting);
    }
  }

  @override
  void dispose() {
    final r = _rec;
    // Écran quitté sans arrêt explicite (cas rare) : on garde le fichier.
    if (r != null &&
        (r.phase == RecorderPhase.recording || r.phase == RecorderPhase.paused)) {
      r.stop();
    }
    r?.dispose();
    _title.dispose();
    _wakelock(false);
    super.dispose();
  }

  bool get _live =>
      _rec!.phase == RecorderPhase.recording ||
      _rec!.phase == RecorderPhase.paused;

  /// Sur Android, l'écran reste allumé : le système peut couper le micro
  /// d'une app en arrière-plan. Sur iPhone, l'enregistrement continue écran
  /// verrouillé.
  Future<void> _wakelock(bool on) async {
    if (!Platform.isAndroid) return;
    try {
      await WakelockPlus.toggle(enable: on);
    } catch (_) {}
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      await _rec!.start();
      HapticFeedback.heavyImpact();
      await _wakelock(true);
    } catch (e) {
      if (mounted) await showErrorDialog(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    setState(() => _busy = true);
    final r = _rec!;
    final duration = r.elapsed;
    await r.stop();
    HapticFeedback.heavyImpact();
    await _wakelock(false);
    if (!mounted) return;
    final scope = AppScope.of(context);
    final title = _title.text.trim().isEmpty
        ? scope.store.nextTitle(InterviewKind.meeting)
        : _title.text.trim();
    final it = scope.store.create(
      title: title,
      text: '',
      kind: InterviewKind.meeting,
      source: 'Enregistré dans l\'app',
      audioFile: r.fileName,
      duration: duration,
      markers: [...r.markers],
    );
    setState(() => _busy = false);
    final now = await _askTranscribe(duration);
    if (!mounted) return;
    final path = scope.store.audioPathOf(it);
    if (now && path != null) {
      final provider = scope.settings.transcriptionProvider;
      if (provider != null &&
          !await confirmCloudUse(context, scope.settings, provider,
              audio: true)) {
        if (mounted) _openEditor(it);
        return;
      }
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => TranscribeScreen(
            audioPath: path,
            fileName: title,
            target: it,
            kind: InterviewKind.meeting,
          ),
        ),
      );
    } else {
      _openEditor(it);
    }
  }

  void _openEditor(Interview it) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(builder: (_) => EditorScreen(interview: it)),
    );
  }

  Future<bool> _askTranscribe(Duration d) async {
    final r = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) {
        final t = Theme.of(ctx).textTheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: IconBadge(Icons.check_rounded,
                      accent: Accent.mint, size: 64),
                ),
                const SizedBox(height: 14),
                Text('Réunion enregistrée',
                    textAlign: TextAlign.center, style: t.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  '${formatClock(d)} · ${_rec!.markers.length} moment'
                  '${_rec!.markers.length > 1 ? 's' : ''} marqué'
                  '${_rec!.markers.length > 1 ? 's' : ''}',
                  textAlign: TextAlign.center,
                  style: t.bodyMedium
                      ?.copyWith(color: Tones.of(ctx).muted),
                ),
                const SizedBox(height: 20),
                GradientButton(
                  label: 'Transcrire maintenant',
                  icon: Icons.subtitles_rounded,
                  onPressed: () => Navigator.pop(ctx, true),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Plus tard'),
                ),
              ],
            ),
          ),
        );
      },
    );
    return r ?? false;
  }

  /// Retour pendant l'enregistrement : arrêter, abandonner ou continuer.
  Future<void> _onBack() async {
    if (!_live) {
      Navigator.pop(context);
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enregistrement en cours'),
        content: const Text('Que voulez-vous faire de cet enregistrement ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: Text('Effacer',
                style: TextStyle(color: Tones.of(ctx).danger)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'continue'),
            child: const Text('Continuer'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'stop'),
            child: const Text('Terminer'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'stop':
        await _stop();
      case 'discard':
        await _rec!.discard();
        await _wakelock(false);
        if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rec = _rec!;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Réunion'),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: _busy ? null : _onBack,
          ),
        ),
        body: Backdrop(
          variant: 0,
          child: SafeArea(
            top: false,
            child: ListenableBuilder(
              listenable: rec,
              builder: (context, _) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: rec.phase == RecorderPhase.idle
                    ? _Ready(
                        key: const ValueKey('ready'),
                        title: _title,
                        busy: _busy,
                        onStart: _start,
                      )
                    : _Live(
                        key: const ValueKey('live'),
                        rec: rec,
                        busy: _busy,
                        onStop: _stop,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Ready extends StatelessWidget {
  const _Ready({
    super.key,
    required this.title,
    required this.busy,
    required this.onStart,
  });

  final TextEditingController title;
  final bool busy;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tones = Tones.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        FadeSlideIn(
          child: TextField(
            controller: title,
            textCapitalization: TextCapitalization.sentences,
            style: t.titleMedium,
            decoration: const InputDecoration(
              labelText: 'Titre de la réunion',
              prefixIcon: Icon(Icons.edit_rounded),
            ),
          ),
        ),
        const SizedBox(height: 40),
        Center(
          child: _RecordButton(
            busy: busy,
            onTap: onStart,
          ),
        ),
        const SizedBox(height: 18),
        Text('Appuyez pour démarrer',
            textAlign: TextAlign.center, style: t.titleMedium),
        const SizedBox(height: 6),
        Text(
          'Posez l\'iPhone au centre de la table, micro vers les participants.',
          textAlign: TextAlign.center,
          style: t.bodyMedium?.copyWith(color: tones.muted),
        ),
        const SizedBox(height: 36),
        FadeSlideIn(
          delay: const Duration(milliseconds: 200),
          child: TintCard(
            accent: Accent.sun,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.campaign_rounded, color: Accent.sun.onSoft(context)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Prévenez les participants que la réunion est enregistrée '
                    'et recueillez leur accord. Le fichier reste sur cet '
                    'iPhone.',
                    style: t.bodyMedium
                        ?.copyWith(color: Accent.sun.onSoft(context)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        FadeSlideIn(
          delay: const Duration(milliseconds: 280),
          child: TintCard(
            accent: Accent.sky,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.star_rounded, color: Accent.sky.onSoft(context)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Pendant la réunion, touchez « Marquer » à chaque moment '
                    'important : il sera repéré dans le texte et mis en avant '
                    'dans le compte rendu.',
                    style: t.bodyMedium
                        ?.copyWith(color: Accent.sky.onSoft(context)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Gros bouton rond d'enregistrement, entouré d'ondes qui respirent.
class _RecordButton extends StatelessWidget {
  const _RecordButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 210,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: LoopingArt(
              period: const Duration(milliseconds: 2600),
              painter: (t, _) => _RingsPainter(t, Palette.coral),
            ),
          ),
          Pressable(
            onTap: busy ? null : onTap,
            borderRadius: BorderRadius.circular(60),
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Palette.coral, Palette.rose],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Palette.coral.withValues(alpha: 0.45),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: busy
                  ? const Padding(
                      padding: EdgeInsets.all(42),
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 3),
                    )
                  : const Icon(Icons.mic_rounded, color: Colors.white, size: 54),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter(this.t, this.color);

  final double t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    for (var i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1;
      canvas.drawCircle(
        c,
        r * (0.58 + 0.42 * p),
        Paint()..color = color.withValues(alpha: 0.22 * (1 - p)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingsPainter old) => old.t != t;
}

class _Live extends StatelessWidget {
  const _Live({
    super.key,
    required this.rec,
    required this.busy,
    required this.onStop,
  });

  final MeetingRecorder rec;
  final bool busy;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tones = Tones.of(context);
    final recording = rec.phase == RecorderPhase.recording;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        children: [
          _StatusPill(recording: recording, interrupted: rec.interrupted),
          const SizedBox(height: 18),
          Text(
            formatClock(rec.elapsed),
            style: t.displaySmall?.copyWith(
              fontSize: 64,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 120,
            width: double.infinity,
            child: CustomPaint(
              painter: _LevelsPainter(
                levels: rec.levels,
                active: recording,
                idle: tones.rule,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: rec.markers.isEmpty
                ? Center(
                    child: Text(
                      'Touchez « Marquer » pour repérer un moment important.',
                      textAlign: TextAlign.center,
                      style: t.bodyMedium?.copyWith(color: tones.muted),
                    ),
                  )
                : SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final m in rec.markers)
                          FadeSlideIn(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: Accent.sun.soft(context),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star_rounded,
                                      size: 16,
                                      color: Accent.sun.onSoft(context)),
                                  const SizedBox(width: 4),
                                  Text(formatClock(m),
                                      style: t.labelLarge?.copyWith(
                                          color: Accent.sun.onSoft(context))),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _RoundAction(
                icon: recording ? Icons.pause_rounded : Icons.play_arrow_rounded,
                label: recording ? 'Pause' : 'Reprendre',
                accent: Accent.violet,
                onTap: busy
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        recording ? rec.pause() : rec.resume();
                      },
              ),
              _StopButton(busy: busy, onTap: onStop),
              _RoundAction(
                icon: Icons.star_rounded,
                label: 'Marquer',
                accent: Accent.sun,
                onTap: busy
                    ? null
                    : () {
                        HapticFeedback.mediumImpact();
                        rec.mark();
                      },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            Platform.isIOS
                ? 'Vous pouvez verrouiller l\'écran : l\'enregistrement continue.'
                : 'Gardez l\'app ouverte pendant l\'enregistrement.',
            textAlign: TextAlign.center,
            style: t.bodySmall?.copyWith(color: tones.muted),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.recording, required this.interrupted});

  final bool recording;
  final bool interrupted;

  @override
  Widget build(BuildContext context) {
    final accent = recording ? Accent.coral : Accent.violet;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: accent.soft(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 12,
            child: recording
                ? LoopingArt(
                    period: const Duration(milliseconds: 1400),
                    painter: (t, _) => _DotPainter(t),
                  )
                : Icon(Icons.pause_rounded,
                    size: 12, color: accent.onSoft(context)),
          ),
          const SizedBox(width: 8),
          Text(
            recording
                ? 'Enregistrement'
                : interrupted
                    ? 'En pause (interruption)'
                    : 'En pause',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: accent.onSoft(context),
                ),
          ),
        ],
      ),
    );
  }
}

class _DotPainter extends CustomPainter {
  _DotPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final a = 0.45 + 0.55 * (0.5 + 0.5 * math.cos(t * 2 * math.pi));
    canvas.drawCircle(size.center(Offset.zero), size.width / 2,
        Paint()..color = Palette.coral.withValues(alpha: a));
  }

  @override
  bool shouldRepaint(covariant _DotPainter old) => old.t != t;
}

/// Onde du niveau sonore, qui défile de droite à gauche.
class _LevelsPainter extends CustomPainter {
  _LevelsPainter({
    required this.levels,
    required this.active,
    required this.idle,
  }) : _snapshot = List.of(levels);

  final List<double> levels;
  final List<double> _snapshot;
  final bool active;
  final Color idle;

  @override
  void paint(Canvas canvas, Size size) {
    const n = MeetingRecorder.maxLevels;
    final gap = size.width / (n * 2 - 1);
    final cy = size.height / 2;
    final shader = const LinearGradient(
      colors: [Palette.violet, Palette.rose, Palette.coral],
    ).createShader(Offset.zero & size);
    for (var i = 0; i < n; i++) {
      final idx = _snapshot.length - n + i;
      final v = idx >= 0 ? _snapshot[idx] : 0.03;
      final h = math.max(4.0, size.height * v);
      final x = i * 2 * gap;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, cy - h / 2, gap, h),
          Radius.circular(gap / 2),
        ),
        active ? (Paint()..shader = shader) : (Paint()..color = idle),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LevelsPainter old) => true;
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Accent accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Pressable(
          onTap: onTap,
          borderRadius: BorderRadius.circular(32),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: accent.soft(context),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30, color: accent.onSoft(context)),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: accent.onSoft(context),
                )),
      ],
    );
  }
}

class _StopButton extends StatelessWidget {
  const _StopButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Pressable(
          onTap: busy ? null : onTap,
          borderRadius: BorderRadius.circular(44),
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Palette.coral, Palette.rose],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Palette.coral.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: busy
                ? const Padding(
                    padding: EdgeInsets.all(30),
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 3),
                  )
                : Center(
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text('Terminer',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Accent.coral.onSoft(context),
                )),
      ],
    );
  }
}
