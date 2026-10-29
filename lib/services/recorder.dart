import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import 'api_error.dart';

enum RecorderPhase { idle, recording, paused, stopped }

/// Enregistrement d'une réunion dans un fichier m4a du dossier de l'app :
/// durée, niveau sonore en direct et moments marqués.
class MeetingRecorder extends ChangeNotifier {
  MeetingRecorder({required this.directory});

  /// Dossier des enregistrements de l'app.
  final Directory directory;

  final AudioRecorder _rec = AudioRecorder();
  final Stopwatch _clock = Stopwatch();
  StreamSubscription<Amplitude>? _ampSub;
  StreamSubscription<RecordState>? _stateSub;
  Timer? _tick;

  RecorderPhase phase = RecorderPhase.idle;

  /// Nom du fichier en cours (dans [directory]).
  String? fileName;

  /// Niveaux récents, de 0 à 1, du plus ancien au plus récent.
  final List<double> levels = [];
  static const int maxLevels = 80;

  /// Instants marqués.
  final List<Duration> markers = [];

  /// Enregistrement mis en pause par le système (appel entrant…).
  bool interrupted = false;

  Duration get elapsed => _clock.elapsed;

  String? get path => fileName == null ? null : '${directory.path}/$fileName';

  Future<void> start() async {
    if (!await _rec.hasPermission()) {
      throw const ApiError(
          'SemantiQ n\'a pas accès au micro. Autorisez-le dans Réglages › '
          'SemantiQ › Micro, puis réessayez.');
    }
    final name = 'reunion_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await directory.create(recursive: true);
    await _rec.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 44100,
        numChannels: 1,
        autoGain: false,
        // Un appel entrant met l'enregistrement en pause ; il reprend seul
        // ensuite.
        audioInterruption: AudioInterruptionMode.pauseResume,
        iosConfig: IosRecordConfig(
          categoryOptions: [
            IosAudioCategoryOption.defaultToSpeaker,
            IosAudioCategoryOption.allowBluetooth,
            IosAudioCategoryOption.mixWithOthers,
          ],
        ),
      ),
      path: '${directory.path}/$name',
    );
    fileName = name;
    _clock
      ..reset()
      ..start();
    phase = RecorderPhase.recording;
    _ampSub = _rec
        .onAmplitudeChanged(const Duration(milliseconds: 110))
        .listen(_onAmplitude);
    _stateSub = _rec.onStateChanged().listen(_onState);
    _tick = Timer.periodic(
        const Duration(milliseconds: 250), (_) => notifyListeners());
    notifyListeners();
  }

  void _onAmplitude(Amplitude a) {
    if (phase != RecorderPhase.recording) return;
    // Décibels (≈ -60 silence, 0 saturation) ramenés à 0..1.
    final v = ((a.current + 55) / 55).clamp(0.02, 1.0).toDouble();
    levels.add(v);
    if (levels.length > maxLevels) levels.removeAt(0);
  }

  void _onState(RecordState s) {
    // Pause ou reprise décidées par le système (interruption audio).
    if (s == RecordState.pause && phase == RecorderPhase.recording) {
      _clock.stop();
      phase = RecorderPhase.paused;
      interrupted = true;
      notifyListeners();
    } else if (s == RecordState.record && phase == RecorderPhase.paused) {
      _clock.start();
      phase = RecorderPhase.recording;
      interrupted = false;
      notifyListeners();
    }
  }

  Future<void> pause() async {
    if (phase != RecorderPhase.recording) return;
    await _rec.pause();
    _clock.stop();
    phase = RecorderPhase.paused;
    notifyListeners();
  }

  Future<void> resume() async {
    if (phase != RecorderPhase.paused) return;
    await _rec.resume();
    _clock.start();
    phase = RecorderPhase.recording;
    interrupted = false;
    notifyListeners();
  }

  /// Marque l'instant présent comme important.
  void mark() {
    if (phase == RecorderPhase.idle || phase == RecorderPhase.stopped) return;
    markers.add(elapsed);
    notifyListeners();
  }

  /// Termine l'enregistrement et renvoie le chemin du fichier.
  Future<String?> stop() async {
    if (phase == RecorderPhase.idle || phase == RecorderPhase.stopped) {
      return path;
    }
    final p = await _rec.stop();
    _clock.stop();
    phase = RecorderPhase.stopped;
    _stopStreams();
    notifyListeners();
    return p ?? path;
  }

  /// Abandonne l'enregistrement et efface le fichier.
  Future<void> discard() async {
    if (phase == RecorderPhase.recording || phase == RecorderPhase.paused) {
      await _rec.cancel();
    }
    final p = path;
    if (p != null) {
      final f = File(p);
      if (f.existsSync()) await f.delete();
    }
    _clock.stop();
    phase = RecorderPhase.stopped;
    fileName = null;
    _stopStreams();
    notifyListeners();
  }

  void _stopStreams() {
    _tick?.cancel();
    _ampSub?.cancel();
    _stateSub?.cancel();
    _tick = null;
    _ampSub = null;
    _stateSub = null;
  }

  @override
  void dispose() {
    _stopStreams();
    _rec.dispose();
    super.dispose();
  }
}
