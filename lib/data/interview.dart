import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../engine/ai_result.dart';
import '../engine/coding.dart';
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
    List<Coding>? codings,
  })  : variables = variables ?? {},
        markers = markers ?? [],
        codings = codings ?? [];

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

  /// Extraits codés par le chercheur (codage thématique).
  final List<Coding> codings;

  /// L'entretien tel que le livre de codes le lit.
  CodedSource get coded => (
        id: id,
        title: title,
        text: text,
        date: createdAt,
        codings: codings,
      );

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
        'codings': [for (final c in codings) c.toJson()],
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
        codings: [
          for (final c in (j['codings'] as List<Object?>? ?? const []))
            if (c is Map<String, Object?>) Coding.fromJson(c),
        ],
      );
}

/// Entretiens et livre de codes enregistrés dans l'espace privé de l'app :
/// un fichier JSON par entretien, un autre pour le livre de codes. Rien ne
/// quitte le téléphone.
class InterviewStore extends ChangeNotifier {
  InterviewStore._(
      this._dir, this.recordingsDir, this._items, this._codebookFile, this._codes);

  /// Corpus gardé en mémoire seulement, sans rien écrire (tests, aperçus).
  InterviewStore.memory()
      : _dir = null,
        _codebookFile = null,
        recordingsDir = Directory.systemTemp,
        _items = [],
        _codes = [];

  final Directory? _dir;
  final File? _codebookFile;

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
  final List<Code> _codes;

  /// Écritures sur disque, l'une après l'autre : deux enregistrements
  /// rapprochés du même fichier ne peuvent pas se croiser.
  Future<void> _queue = Future<void>.value();

  Future<void> _enqueue(Future<void> Function() job) {
    final next = _queue.then((_) => job());
    _queue = next.catchError((Object _) {});
    return next;
  }

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
    final codebook = File('${docs.path}/livre_de_codes.json');
    final codes = <Code>[];
    if (codebook.existsSync()) {
      try {
        final j = jsonDecode(await codebook.readAsString());
        if (j is List<Object?>) {
          for (final c in j) {
            if (c is Map<String, Object?>) codes.add(Code.fromJson(c));
          }
        }
      } catch (_) {
        // Livre de codes illisible : on repart d'un livre vide.
      }
    }
    return InterviewStore._(dir, rec, items, codebook, codes);
  }

  Interview create({
    required String title,
    required String text,
    String source = '',
    InterviewKind kind = InterviewKind.interview,
    String? audioFile,
    Duration? duration,
    List<Duration>? markers,
    DateTime? createdAt,
    Map<String, String>? variables,
    List<Coding>? codings,
  }) {
    final now = DateTime.now();
    var id = now.microsecondsSinceEpoch.toRadixString(36);
    while (_items.any((i) => i.id == id)) {
      id = '${id}x';
    }
    final it = Interview(
      id: id,
      title: title,
      text: text,
      createdAt: createdAt ?? now,
      updatedAt: now,
      source: source,
      kind: kind,
      audioFile: audioFile,
      duration: duration,
      markers: markers,
      variables: variables == null ? null : {...variables},
      codings: codings == null ? null : [...codings],
    );
    _items.add(it);
    save(it);
    return it;
  }

  Future<void> save(Interview it) async {
    it.updatedAt = DateTime.now();
    notifyListeners();
    final dir = _dir;
    if (dir == null) return;
    await _enqueue(() async {
      // Entretien supprimé entre-temps : ne pas recréer son fichier.
      if (!_items.contains(it)) return;
      await File('${dir.path}/${it.id}.json')
          .writeAsString(jsonEncode(it.toJson()), flush: true);
    });
  }

  Future<void> delete(Interview it) async {
    _items.remove(it);
    notifyListeners();
    final dir = _dir;
    if (dir == null) return;
    await _enqueue(() async {
      final f = File('${dir.path}/${it.id}.json');
      if (f.existsSync()) await f.delete();
      final audio = audioPathOf(it);
      if (audio != null) await File(audio).delete();
    });
  }

  /// Titre par défaut du prochain entretien.
  String nextTitle([InterviewKind kind = InterviewKind.interview]) =>
      '${kind.label} ${_items.where((i) => i.kind == kind).length + 1}';

  // --- Livre de codes -------------------------------------------------------

  /// Les codes, dans l'ordre où ils ont été créés.
  List<Code> get codes => List.unmodifiable(_codes);

  /// Entretiens de recherche, tels que le livre de codes les lit.
  List<CodedSource> get codedSources =>
      [for (final i in _items) if (!i.isMeeting) i.coded];

  Code? codeById(String id) {
    for (final c in _codes) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Code portant ce libellé (à la casse et aux accents près), s'il existe.
  Code? codeByLabel(String label) {
    for (final c in _codes) {
      if (sameExcerpt(c.label, label)) return c;
    }
    return null;
  }

  /// Crée un code, ou renvoie celui qui porte déjà ce libellé.
  Code addCode(String label, {String theme = '', String note = ''}) {
    final clean = label.trim();
    final existing = codeByLabel(clean);
    if (existing != null) return existing;
    var id = 'c${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}';
    while (_codes.any((c) => c.id == id)) {
      id = '${id}x';
    }
    final code = Code(
      id: id,
      label: clean,
      theme: theme.trim(),
      note: note.trim(),
      color: _codes.length,
    );
    _codes.add(code);
    saveCodebook();
    return code;
  }

  /// À appeler après avoir modifié un code (libellé, thème, définition).
  Future<void> saveCodebook() async {
    notifyListeners();
    final f = _codebookFile;
    if (f == null) return;
    await _enqueue(() => f.writeAsString(
        jsonEncode([for (final c in _codes) c.toJson()]),
        flush: true));
  }

  /// Supprime un code et tous les extraits qui lui étaient rattachés.
  Future<void> deleteCode(Code code) async {
    _codes.remove(code);
    for (final it in _items) {
      final before = it.codings.length;
      it.codings.removeWhere((k) => k.codeId == code.id);
      if (it.codings.length != before) await save(it);
    }
    await saveCodebook();
  }

  /// Codes posés sur cet extrait de l'entretien.
  List<Code> codesOf(Interview it, String quote) => [
        for (final k in it.codings)
          if (sameExcerpt(k.quote, quote)) ?codeById(k.codeId),
      ];

  /// Pose le code sur l'extrait, ou le retire s'il y était déjà.
  Future<void> toggleCoding(
      Interview it, Code code, String quote, String? speaker) async {
    final before = it.codings.length;
    it.codings.removeWhere(
        (k) => k.codeId == code.id && sameExcerpt(k.quote, quote));
    if (it.codings.length == before) {
      it.codings.add(Coding(codeId: code.id, quote: quote, speaker: speaker));
    }
    await save(it);
  }

  /// Nombre total d'extraits codés dans le corpus.
  int get codingCount =>
      _items.fold<int>(0, (n, i) => n + i.codings.length);
}
