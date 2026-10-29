import 'dart:convert';

import 'package:http/http.dart' as http;

import '../engine/ai_result.dart';
import '../engine/meeting.dart';
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

/// Consignes pour le compte rendu d'une réunion de travail.
const String minutesInstructions = '''
Tu rédiges le compte rendu d'une réunion de travail à partir de sa transcription automatique. Les lignes peuvent commencer par un libellé de locuteur (« Locuteur 1 : », « Marie : »…). Les lignes qui commencent par « ★ » signalent un moment que l'organisateur a jugé important.

Réponds UNIQUEMENT par un objet JSON valide, sans texte autour, de la forme :
{
  "resume": "synthèse de 120 à 220 mots",
  "participants": ["libellé ou nom tel qu'il apparaît"],
  "sujets": ["sujet abordé, dans l'ordre de la réunion"],
  "decisions": ["décision prise, formulée clairement"],
  "actions": [{"tache": "ce qui doit être fait", "responsable": "qui, si c'est dit, sinon chaîne vide", "echeance": "quand, si c'est dit, sinon chaîne vide"}],
  "points_en_suspens": ["question restée ouverte ou point à trancher"],
  "prochaines_etapes": ["prochaine réunion, jalon à venir…"]
}

Règles :
- Ne retiens comme décision que ce qui a été effectivement décidé ou validé, pas ce qui a seulement été évoqué.
- Une action a un verbe à l'infinitif (« Préparer le support de formation »). N'invente ni responsable ni échéance : laisse la chaîne vide s'ils ne sont pas dits.
- Accorde une attention particulière aux passages qui suivent une ligne « ★ ».
- La transcription peut contenir des erreurs de reconnaissance : corrige les mots manifestement mal transcrits, sans rien ajouter qui n'ait été dit.
- Style neutre et factuel, en français. Listes vides si rien ne correspond.''';

/// Résumé et thèmes produits par un modèle de langage.
class AiSummaryService {
  AiSummaryService(this.settings);

  final Settings settings;

  Future<AiResult> summarize(String text, AiProvider provider) async {
    final model = settings.chatModel(provider);
    final raw = await _complete(provider, summaryInstructions,
        'Verbatim de l\'entretien :\n\n$text');
    try {
      return AiResult.parse(raw, provider: provider.label, model: model);
    } on FormatException {
      throw ApiError('La réponse de ${provider.label} n\'a pas pu être lue. '
          'Réessayez, ou choisissez un autre modèle dans les réglages.');
    }
  }

  /// Compte rendu d'une réunion.
  Future<MeetingMinutes> minutes(String text, AiProvider provider) async {
    final model = settings.chatModel(provider);
    final raw = await _complete(provider, minutesInstructions,
        'Transcription de la réunion :\n\n$text');
    try {
      return MeetingMinutes.parse(raw, provider: provider.label, model: model);
    } on FormatException {
      throw ApiError('La réponse de ${provider.label} n\'a pas pu être lue. '
          'Réessayez, ou choisissez un autre modèle dans les réglages.');
    }
  }

  Future<String> _complete(
    AiProvider provider,
    String system,
    String user,
  ) async {
    final key = settings.apiKey(provider);
    if (key == null) {
      throw ApiError('Aucune clé API ${provider.label} : ajoutez-la dans les '
          'réglages.');
    }
    final model = settings.chatModel(provider);
    return switch (provider) {
      AiProvider.anthropic => await _anthropic(key, model, system, user),
      AiProvider.openai => await _openAiCompatible(
          'https://api.openai.com/v1/chat/completions',
          key, model, system, user, provider),
      AiProvider.mistral => await _openAiCompatible(
          'https://api.mistral.ai/v1/chat/completions',
          key, model, system, user, provider),
    };
  }

  Future<String> _anthropic(
      String key, String model, String system, String user) async {
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
            'system': system,
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
    String system,
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
              {'role': 'system', 'content': system},
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
