import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../engine/ai_result.dart';
import '../engine/meeting.dart';

/// Nature de l'enregistrement : entretien de recherche ou réunion de
/// travail. Elle change l'analyse proposée (compte rendu pour une réunion).
enum InterviewKind {
  interview('Entretien'),
  meeting('Réunion');

  const InterviewKind(this.label);
  final String label;
}

/// Un entretien (ou une réunion) : son verbatim et ce qui s'y rattache.
class Interview {
  Interview({
    required this.id,
    required this.title,
    required this.text,
    required this.createdAt,
    required this.updatedAt,
    this.source = '',
    this.ai,
    this.stopwords = '',
    Map<String, String>? variables,
    this.kind = InterviewKind.interview,
    this.audioFile,
    this.duration,
    List<Duration>? markers,
    this.minutes,
  })  : variables = variables ?? {},
        markers = markers ?? [];

  final String id;
  String title;
  String text;
  final DateTime createdAt;
  DateTime updatedAt;

  /// Origine : « Texte collé » ou nom du fichier audio.
  String source;

  /// Dernier résumé produit par une IA, s'il y en a un.
  AiResult? ai;

  /// Mots à ignorer pour cet entretien (prénoms, lieux…).
  String stopwords;

  /// Variables de l'entretien pour l'export IRaMuTeQ (sexe, âge, métier…).
  final Map<String, String> variables;

  InterviewKind kind;

  /// Nom du fichier audio enregistré dans l'app (dossier des
  /// enregistrements), s'il y en a un.
  String? audioFile;

  /// Durée de l'enregistrement.
  Duration? duration;

  /// Instants marqués pendant l'enregistrement.
  final List<Duration> markers;

  /// Compte rendu de réunion rédigé par une IA.
  MeetingMinutes? minutes;

  bool get isMeeting => kind == InterviewKind.meeting;

  int get wordCount =>
      RegExp(r'[0-9A-Za-zÀ-ÿ]+').allMatches(text).length;

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'source': source,
        'ai': ai?.toJson(),
        'stopwords': stopwords,
        'variables': variables,
        'kind': kind.name,
        'audioFile': audioFile,
        'durationMs': duration?.inMilliseconds,
        'markersMs': [for (final m in markers) m.inMilliseconds],
        'minutes': minutes?.toJson(),
      };

  factory Interview.fromJson(Map<String, Object?> j) => Interview(
        id: j['id'].toString(),
        title: (j['title'] ?? '').toString(),
        text: (j['text'] ?? '').toString(),
        createdAt: DateTime.tryParse('${j['createdAt']}') ?? DateTime.now(),
        updatedAt: DateTime.tryParse('${j['updatedAt']}') ?? DateTime.now(),
        source: (j['source'] ?? '').toString(),
        ai: j['ai'] is Map<String, Object?>
            ? AiResult.fromJson(j['ai']! as Map<String, Object?>)
            : null,
        stopwords: (j['stopwords'] ?? '').toString(),
        variables: {
          if (j['variables'] is Map<String, Object?>)
            for (final e in (j['variables']! as Map<String, Object?>).entries)
              e.key: '${e.value}',
        },
        kind: InterviewKind.values.firstWhere(
          (k) => k.name == j['kind'],
          orElse: () => InterviewKind.interview,
        ),
        audioFile: j['audioFile'] as String?,
        duration: j['durationMs'] is int
            ? Duration(milliseconds: j['durationMs']! as int)
            : null,
        markers: [
          for (final m in (j['markersMs'] as List<Object?>? ?? const []))
            if (m is int) Duration(milliseconds: m),
        ],
        minutes: j['minutes'] is Map<String, Object?>
            ? MeetingMinutes.fromJson(j['minutes']! as Map<String, Object?>)
            : null,
      );
}

/// Entretiens enregistrés dans l'espace privé de l'app, un fichier JSON
/// par entretien. Rien ne quitte le téléphone.
class InterviewStore extends ChangeNotifier {
  InterviewStore._(this._dir, this.recordingsDir, this._items);

  final Directory _dir;

  /// Dossier des enregistrements faits dans l'app.
  final Directory recordingsDir;

  /// Chemin complet du fichier audio d'un entretien, s'il existe encore.
  String? audioPathOf(Interview it) {
    final f = it.audioFile;
    if (f == null) return null;
    final path = '${recordingsDir.path}/$f';
    return File(path).existsSync() ? path : null;
  }
  final List<Interview> _items;

  List<Interview> get items =>
      List.unmodifiable(_items..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)));

  static Future<InterviewStore> open() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/entretiens');
    await dir.create(recursive: true);
    final rec = Directory('${docs.path}/enregistrements');
    await rec.create(recursive: true);
    final items = <Interview>[];
    for (final f in dir.listSync().whereType<File>()) {
      if (!f.path.endsWith('.json')) continue;
      try {
        final j = jsonDecode(await f.readAsString());
        if (j is Map<String, Object?>) items.add(Interview.fromJson(j));
      } catch (_) {
        // Fichier illisible : ignoré plutôt que de bloquer l'app.
      }
    }
    return InterviewStore._(dir, rec, items);
  }

  Interview create({
    required String title,
    required String text,
    String source = '',
    InterviewKind kind = InterviewKind.interview,
    String? audioFile,
    Duration? duration,
    List<Duration>? markers,
  }) {
    final now = DateTime.now();
    final it = Interview(
      id: now.microsecondsSinceEpoch.toRadixString(36),
      title: title,
      text: text,
      createdAt: now,
      updatedAt: now,
      source: source,
      kind: kind,
      audioFile: audioFile,
      duration: duration,
      markers: markers,
    );
    _items.add(it);
    save(it);
    return it;
  }

  Future<void> save(Interview it) async {
    it.updatedAt = DateTime.now();
    notifyListeners();
    await File('${_dir.path}/${it.id}.json')
        .writeAsString(jsonEncode(it.toJson()), flush: true);
  }

  Future<void> delete(Interview it) async {
    _items.remove(it);
    notifyListeners();
    final f = File('${_dir.path}/${it.id}.json');
    if (f.existsSync()) await f.delete();
    final audio = audioPathOf(it);
    if (audio != null) await File(audio).delete();
  }

  /// Titre par défaut du prochain entretien.
  String nextTitle([InterviewKind kind = InterviewKind.interview]) =>
      '${kind.label} ${_items.where((i) => i.kind == kind).length + 1}';
}
