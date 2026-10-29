import 'dart:convert';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

import '../engine/meeting.dart' show markerLine;
import 'api_error.dart';
import 'settings.dart';

/// Étape en cours, pour l'affichage. [fraction] vaut null quand
/// l'avancement n'est pas mesurable.
typedef ProgressCallback = void Function(String stage, double? fraction);

/// Transcrit un fichier audio en texte, sur l'appareil (Whisper) ou par
/// l'API d'un fournisseur.
class TranscriptionService {
  TranscriptionService(this.settings);

  final Settings settings;
  List<Duration> _markers = const [];

  /// Transcrit [sourcePath]. Les [markers] (moments marqués pendant
  /// l'enregistrement) sont insérés dans le texte à leur place quand le
  /// service fournit l'horodatage des passages.
  Future<String> transcribe(
    String sourcePath, {
    required ProgressCallback onProgress,
    List<Duration> markers = const [],
  }) async {
    _markers = [...markers]..sort();
    onProgress('Préparation du fichier', null);
    final work = await _workDir();
    // Copie sous un nom sans espace ni accent : les outils audio
    // n'acceptent pas toujours les noms des mémos vocaux.
    final ext = _extension(sourcePath);
    final input = await File(sourcePath).copy('${work.path}/source$ext');

    try {
      final provider = settings.transcriptionProvider;
      if (provider == null) {
        return await _local(input, onProgress);
      }
      return await _remote(provider, input, work, onProgress);
    } finally {
      try {
        await work.delete(recursive: true);
      } catch (_) {}
    }
  }

  // --- Sur l'appareil -------------------------------------------------------

  Future<String> _local(File input, ProgressCallback onProgress) async {
    final model = switch (settings.localModel) {
      LocalModel.base => WhisperModel.base,
      LocalModel.small => WhisperModel.small,
      LocalModel.medium => WhisperModel.medium,
    };
    final controller = WhisperController();
    await ensureModel(controller, model, onProgress);

    onProgress('Transcription sur l\'iPhone', 0);
    final result = await controller.transcribe(
      model: model,
      audioPath: input.path,
      lang: 'fr',
      withSegments: true,
      // Évite qu'une phrase mal reconnue se répète sur tout l'entretien.
      maxContext: 0,
      suppressNonSpeechTokens: true,
      onProgress: (p) => onProgress('Transcription sur l\'iPhone', p / 100),
    );
    if (result == null) {
      throw const ApiError(
          'La transcription a échoué. Le fichier audio est peut-être '
          'illisible ou la mémoire du téléphone insuffisante : essayez un '
          'modèle plus léger dans les réglages.');
    }
    final segments = result.transcription.segments;
    if (segments == null || segments.isEmpty) {
      return result.transcription.text.trim();
    }
    return paragraphsFromSegments([
      for (final s in segments) (start: s.fromTs, end: s.toTs, text: s.text),
    ], markers: _markers);
  }

  /// Télécharge le modèle Whisper s'il n'est pas déjà sur l'appareil.
  static Future<void> ensureModel(
    WhisperController controller,
    WhisperModel model,
    ProgressCallback onProgress,
  ) async {
    final path = await controller.getPath(model);
    final file = File(path);
    if (file.existsSync() && file.lengthSync() > 1000000) return;

    const stage = 'Téléchargement du modèle de transcription (une seule fois)';
    onProgress(stage, 0);
    final client = HttpClient();
    try {
      final request = await client.getUrl(model.modelUri);
      final response = await request.close();
      if (response.statusCode != 200) {
        throw ApiError('Téléchargement du modèle impossible '
            '(erreur ${response.statusCode}). Vérifiez la connexion.');
      }
      final total = response.contentLength;
      final part = File('$path.part');
      final sink = part.openWrite();
      var received = 0;
      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress(stage, received / total);
      }
      await sink.close();
      await part.rename(path);
    } on SocketException {
      throw const ApiError('Pas de connexion internet pour télécharger le '
          'modèle de transcription. Il ne sera téléchargé qu\'une fois.');
    } finally {
      client.close(force: true);
    }
  }

  // --- Par API ---------------------------------------------------------------

  Future<String> _remote(
    AiProvider provider,
    File input,
    Directory work,
    ProgressCallback onProgress,
  ) async {
    final key = settings.apiKey(provider);
    if (key == null) {
      throw ApiError('Aucune clé API ${provider.label} : ajoutez-la dans les '
          'réglages.');
    }
    onProgress('Compression de l\'audio', null);
    // Morceaux de 10 min pour OpenAI (limite de 25 Mo par envoi), d'une
    // heure pour Mistral, qui garde ainsi les mêmes locuteurs.
    final seconds = provider == AiProvider.openai ? 600 : 3600;
    final chunks = await _compressAndSplit(input, work, seconds);

    final parts = <String>[];
    for (var i = 0; i < chunks.length; i++) {
      final label = chunks.length == 1
          ? 'Transcription par ${provider.label}'
          : 'Transcription par ${provider.label} (${i + 1}/${chunks.length})';
      onProgress(label, i / chunks.length);
      parts.add(switch (provider) {
        AiProvider.mistral =>
          await _mistral(chunks[i], key, Duration(seconds: seconds * i)),
        AiProvider.openai => await _openai(chunks[i], key),
        AiProvider.anthropic => throw const ApiError(
            'Anthropic ne propose pas de transcription audio.'),
      });
    }
    onProgress('Terminé', 1);
    return parts.join('\n\n');
  }

  Future<List<File>> _compressAndSplit(
    File input,
    Directory work,
    int segmentSeconds,
  ) async {
    final pattern = '${work.path}/part_%03d.m4a';
    final session = await FFmpegKit.executeWithArguments([
      '-y', '-i', input.path, '-vn', '-ac', '1', '-ar', '16000',
      '-c:a', 'aac', '-b:a', '32k',
      '-f', 'segment', '-segment_time', '$segmentSeconds',
      '-reset_timestamps', '1', pattern,
    ]);
    final code = await session.getReturnCode();
    if (!ReturnCode.isSuccess(code)) {
      throw const ApiError('Ce fichier audio ne peut pas être lu. Formats '
          'conseillés : m4a, mp3, wav.');
    }
    final files = work
        .listSync()
        .whereType<File>()
        .where((f) => f.path.contains('/part_'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    if (files.isEmpty) {
      throw const ApiError('Le fichier audio semble vide.');
    }
    return files;
  }

  Future<String> _mistral(File chunk, String key, Duration offset) async {
    final model = settings.transcriptionModel(AiProvider.mistral);
    Future<http.Response> send({required bool diarize}) async {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.mistral.ai/v1/audio/transcriptions'),
      )
        ..headers['Authorization'] = 'Bearer $key'
        ..fields['model'] = model
        ..fields['language'] = 'fr';
      if (diarize) {
        req.fields['diarize'] = 'true';
        req.fields['timestamp_granularities'] = 'segment';
      }
      req.files.add(await http.MultipartFile.fromPath('file', chunk.path,
          filename: 'audio.m4a'));
      return http.Response.fromStream(
          await req.send().timeout(const Duration(minutes: 20)));
    }

    var res = await send(diarize: settings.diarize);
    // Séparation des locuteurs refusée (modèle ou paramètre non pris en
    // charge) : on retente sans.
    if (settings.diarize && (res.statusCode == 400 || res.statusCode == 422)) {
      res = await send(diarize: false);
    }
    final json = decodeOrThrow(res, AiProvider.mistral);
    final segments = json['segments'];
    if (segments is List<Object?> &&
        segments.any((s) => s is Map<String, Object?> && s['speaker_id'] != null)) {
      Duration? at(Object? sec) => sec is num
          ? offset + Duration(milliseconds: (sec * 1000).round())
          : null;
      return speakerTurns([
        for (final s in segments)
          if (s is Map<String, Object?>)
            (
              speaker: s['speaker_id']?.toString(),
              text: (s['text'] ?? '').toString(),
              start: at(s['start']),
            ),
      ], markers: [
        for (final m in _markers)
          if (m >= offset && m < offset + const Duration(hours: 1)) m,
      ]);
    }
    return (json['text'] ?? '').toString().trim();
  }

  Future<String> _openai(File chunk, String key) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.openai.com/v1/audio/transcriptions'),
    )
      ..headers['Authorization'] = 'Bearer $key'
      ..fields['model'] = settings.transcriptionModel(AiProvider.openai)
      ..fields['language'] = 'fr'
      ..fields['response_format'] = 'json';
    req.files.add(await http.MultipartFile.fromPath('file', chunk.path,
        filename: 'audio.m4a'));
    final res = await http.Response.fromStream(
        await req.send().timeout(const Duration(minutes: 20)));
    final json = decodeOrThrow(res, AiProvider.openai);
    return (json['text'] ?? '').toString().trim();
  }

  static Future<Directory> _workDir() async {
    final tmp = await getTemporaryDirectory();
    final dir = Directory(
        '${tmp.path}/semantiq_${DateTime.now().microsecondsSinceEpoch}');
    return dir.create(recursive: true);
  }

  static String _extension(String path) {
    final name = path.split('/').last;
    final dot = name.lastIndexOf('.');
    if (dot < 0) return '.m4a';
    final ext = name.substring(dot).toLowerCase();
    return RegExp(r'^\.[a-z0-9]{1,5}$').hasMatch(ext) ? ext : '.m4a';
  }
}

/// Assemble des segments Whisper en paragraphes : un silence de plus de
/// deux secondes ouvre un nouveau paragraphe, ce qui marque souvent un
/// changement de locuteur.
///
/// Chaque moment de [markers] est inséré, sur une ligne « ★ », avant le
/// premier passage qui commence après lui.
String paragraphsFromSegments(
  List<({Duration start, Duration end, String text})> segments, {
  List<Duration> markers = const [],
}) {
  final b = StringBuffer();
  final pending = [...markers]..sort();
  Duration? lastEnd;
  for (final s in segments) {
    final text = s.text.trim();
    if (text.isEmpty || _isNoise(text)) continue;
    var marked = false;
    while (pending.isNotEmpty && pending.first <= s.start) {
      b.write('${b.isEmpty ? '' : '\n\n'}${markerLine(pending.removeAt(0))}');
      marked = true;
    }
    if (marked) {
      b.write('\n\n');
    } else if (lastEnd != null) {
      b.write(s.start - lastEnd > const Duration(seconds: 2) ? '\n\n' : ' ');
    }
    b.write(text);
    lastEnd = s.end;
  }
  for (final m in pending) {
    b.write('\n\n${markerLine(m)}');
  }
  return b.toString().trim();
}

/// Regroupe des segments attribués à des locuteurs en tours de parole
/// « Locuteur 1 : … ».
///
/// Les [markers] sont insérés avant le premier segment qui commence après
/// eux ; le locuteur est ensuite rappelé.
String speakerTurns(
  List<({String? speaker, String text, Duration? start})> segments, {
  List<Duration> markers = const [],
}) {
  final pending = [...markers]..sort();
  final names = <String, String>{};
  String nameOf(String? id) {
    if (id == null) return 'Locuteur ?';
    return names.putIfAbsent(id, () {
      final n = RegExp(r'(\d+)$').firstMatch(id)?.group(1);
      return n != null ? 'Locuteur $n' : id;
    });
  }

  final b = StringBuffer();
  String? current;
  for (final s in segments) {
    final text = s.text.trim();
    if (text.isEmpty) continue;
    final who = nameOf(s.speaker);
    final start = s.start;
    while (start != null && pending.isNotEmpty && pending.first <= start) {
      b.write('${b.isEmpty ? '' : '\n\n'}${markerLine(pending.removeAt(0))}');
      current = null;
    }
    if (who != current) {
      if (b.isNotEmpty) b.write('\n\n');
      b.write('$who : $text');
      current = who;
    } else {
      b.write(' $text');
    }
  }
  for (final m in pending) {
    b.write('\n\n${markerLine(m)}');
  }
  return b.toString();
}

/// Annotations que Whisper produit pour les passages sans parole.
bool _isNoise(String text) =>
    RegExp(r'^[\[(].*[\])]$').hasMatch(text) ||
    text.startsWith('Sous-titr') ||
    text == '...' ||
    text == '…';

/// Décode une réponse JSON ou lève une [ApiError] lisible.
Map<String, Object?> decodeOrThrow(http.Response res, AiProvider provider) {
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw ApiError.fromResponse(res.statusCode, res.body, provider.label);
  }
  final decoded = jsonDecode(utf8.decode(res.bodyBytes));
  if (decoded is! Map<String, Object?>) {
    throw ApiError('Réponse inattendue de ${provider.label}.');
  }
  return decoded;
}
