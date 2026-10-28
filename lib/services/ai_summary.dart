import 'dart:convert';

import 'package:http/http.dart' as http;

import '../engine/ai_result.dart';
import 'api_error.dart';
import 'settings.dart';
import 'transcription.dart' show decodeOrThrow;

/// Consignes données au modèle. Elles insistent sur la fidélité des
/// citations : l'app vérifie ensuite chacune d'elles dans le verbatim.
const String summaryInstructions = '''
Tu assistes un interne en médecine qui analyse les entretiens semi-directifs de sa thèse (recherche qualitative).

Tu reçois le verbatim d'un entretien. Les lignes peuvent commencer par un libellé de locuteur (« E : » ou « Enquêteur : » pour l'enquêteur, « P1 : », « Locuteur 2 : »… pour les personnes interrogées).

Réponds UNIQUEMENT par un objet JSON valide, sans texte autour, de la forme :
{
  "resume": "résumé de 150 à 250 mots",
  "themes": [
    {"titre": "thème court", "description": "une ou deux phrases", "verbatims": ["citation exacte", "..."]}
  ],
  "phrases_cles": ["citation exacte", "..."]
}

Règles :
- Le résumé décrit le vécu, les représentations et les points de vue de la personne interrogée, dans un style neutre et factuel, sans interpréter au-delà du texte.
- 3 à 7 thèmes, chacun illustré par 1 à 3 verbatims.
- 5 à 8 phrases clés : les phrases les plus significatives de la personne interrogée.
- Toute citation (verbatims et phrases clés) est recopiée MOT POUR MOT depuis le texte, sans correction, sans reformulation, sans coupure au milieu d'un mot. Ne cite jamais l'enquêteur.
- N'invente rien. N'ajoute aucun nom, lieu ou détail absent du texte.
- Écris en français.''';

/// Résumé et thèmes produits par un modèle de langage.
class AiSummaryService {
  AiSummaryService(this.settings);

  final Settings settings;

  Future<AiResult> summarize(String text, AiProvider provider) async {
    final key = settings.apiKey(provider);
    if (key == null) {
      throw ApiError('Aucune clé API ${provider.label} : ajoutez-la dans les '
          'réglages.');
    }
    final model = settings.chatModel(provider);
    final user = 'Verbatim de l\'entretien :\n\n$text';

    final raw = switch (provider) {
      AiProvider.anthropic => await _anthropic(key, model, user),
      AiProvider.openai => await _openAiCompatible(
          'https://api.openai.com/v1/chat/completions', key, model, user,
          provider),
      AiProvider.mistral => await _openAiCompatible(
          'https://api.mistral.ai/v1/chat/completions', key, model, user,
          provider),
    };
    try {
      return AiResult.parse(raw, provider: provider.label, model: model);
    } on FormatException {
      throw ApiError('La réponse de ${provider.label} n\'a pas pu être lue. '
          'Réessayez, ou choisissez un autre modèle dans les réglages.');
    }
  }

  Future<String> _anthropic(String key, String model, String user) async {
    final res = await http
        .post(
          Uri.parse('https://api.anthropic.com/v1/messages'),
          headers: {
            'x-api-key': key,
            'anthropic-version': '2023-06-01',
            'content-type': 'application/json',
          },
          body: jsonEncode({
            'model': model,
            'max_tokens': 4096,
            'system': summaryInstructions,
            'messages': [
              {'role': 'user', 'content': user},
            ],
          }),
        )
        .timeout(const Duration(minutes: 5));
    final json = decodeOrThrow(res, AiProvider.anthropic);
    final content = json['content'];
    if (content is List<Object?>) {
      return content
          .whereType<Map<String, Object?>>()
          .where((c) => c['type'] == 'text')
          .map((c) => c['text'].toString())
          .join();
    }
    throw const ApiError('Réponse inattendue d\'Anthropic.');
  }

  Future<String> _openAiCompatible(
    String url,
    String key,
    String model,
    String user,
    AiProvider provider,
  ) async {
    final res = await http
        .post(
          Uri.parse(url),
          headers: {
            'Authorization': 'Bearer $key',
            'content-type': 'application/json',
          },
          body: jsonEncode({
            'model': model,
            'response_format': {'type': 'json_object'},
            'messages': [
              {'role': 'system', 'content': summaryInstructions},
              {'role': 'user', 'content': user},
            ],
          }),
        )
        .timeout(const Duration(minutes: 5));
    final json = decodeOrThrow(res, provider);
    final choices = json['choices'];
    if (choices is List<Object?> && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map<String, Object?>) {
        final message = first['message'];
        if (message is Map<String, Object?>) {
          return (message['content'] ?? '').toString();
        }
      }
    }
    throw ApiError('Réponse inattendue de ${provider.label}.');
  }
}
