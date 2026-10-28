import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../engine/ai_result.dart';

/// Un entretien : son verbatim et ce qui s'y rattache.
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
  }) : variables = variables ?? {};

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
      );
}

/// Entretiens enregistrés dans l'espace privé de l'app, un fichier JSON
/// par entretien. Rien ne quitte le téléphone.
class InterviewStore extends ChangeNotifier {
  InterviewStore._(this._dir, this._items);

  final Directory _dir;
  final List<Interview> _items;

  List<Interview> get items =>
      List.unmodifiable(_items..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)));

  static Future<InterviewStore> open() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/entretiens');
    await dir.create(recursive: true);
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
    return InterviewStore._(dir, items);
  }

  Interview create({required String title, required String text, String source = ''}) {
    final now = DateTime.now();
    final it = Interview(
      id: now.microsecondsSinceEpoch.toRadixString(36),
      title: title,
      text: text,
      createdAt: now,
      updatedAt: now,
      source: source,
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
  }

  /// Titre par défaut du prochain entretien.
  String nextTitle() => 'Entretien ${_items.length + 1}';
}
