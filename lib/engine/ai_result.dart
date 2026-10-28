import 'dart:convert';

/// Thème dégagé par l'IA, avec les verbatims qui l'illustrent.
class AiTheme {
  const AiTheme({
    required this.title,
    required this.description,
    required this.quotes,
  });

  final String title;
  final String description;
  final List<String> quotes;

  Map<String, Object?> toJson() =>
      {'titre': title, 'description': description, 'verbatims': quotes};

  factory AiTheme.fromJson(Map<String, Object?> j) => AiTheme(
        title: _str(j['titre'] ?? j['title']),
        description: _str(j['description']),
        quotes: _strList(j['verbatims'] ?? j['quotes']),
      );
}

/// Résumé et analyse produits par un modèle de langage.
class AiResult {
  const AiResult({
    required this.provider,
    required this.model,
    required this.date,
    required this.summary,
    required this.themes,
    required this.keyQuotes,
  });

  final String provider;
  final String model;
  final DateTime date;
  final String summary;
  final List<AiTheme> themes;

  /// Phrases clés citées telles quelles depuis le verbatim.
  final List<String> keyQuotes;

  Map<String, Object?> toJson() => {
        'provider': provider,
        'model': model,
        'date': date.toIso8601String(),
        'resume': summary,
        'themes': [for (final t in themes) t.toJson()],
        'phrases_cles': keyQuotes,
      };

  factory AiResult.fromJson(Map<String, Object?> j) => AiResult(
        provider: _str(j['provider']),
        model: _str(j['model']),
        date: DateTime.tryParse(_str(j['date'])) ?? DateTime.now(),
        summary: _str(j['resume']),
        themes: [
          for (final t in (j['themes'] as List<Object?>? ?? const []))
            if (t is Map<String, Object?>) AiTheme.fromJson(t),
        ],
        keyQuotes: _strList(j['phrases_cles']),
      );

  /// Lit la réponse d'un modèle, qui doit contenir un objet JSON
  /// (éventuellement entouré de texte ou d'un bloc de code).
  factory AiResult.parse(
    String raw, {
    required String provider,
    required String model,
  }) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw const FormatException('La réponse ne contient pas de JSON.');
    }
    final decoded = jsonDecode(raw.substring(start, end + 1));
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Réponse JSON inattendue.');
    }
    return AiResult.fromJson({
      ...decoded,
      'provider': provider,
      'model': model,
      'date': DateTime.now().toIso8601String(),
    });
  }
}

String _str(Object? o) => o == null ? '' : o.toString().trim();

List<String> _strList(Object? o) => [
      for (final e in (o is List<Object?> ? o : const <Object?>[]))
        if (_str(e).isNotEmpty) _str(e),
    ];
