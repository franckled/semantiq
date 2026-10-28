import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../engine/transcript.dart';

/// Fournisseurs d'IA accessibles par clé API.
enum AiProvider {
  mistral(
    label: 'Mistral AI',
    note: 'Entreprise française, serveurs dans l\'Union européenne.',
    chatModel: 'mistral-medium-latest',
    transcriptionModel: 'voxtral-mini-transcribe-3',
    keyUrl: 'https://console.mistral.ai/api-keys',
  ),
  anthropic(
    label: 'Anthropic (Claude)',
    note: 'Résumé et analyse uniquement (pas de transcription audio).',
    chatModel: 'claude-sonnet-5-5',
    transcriptionModel: null,
    keyUrl: 'https://console.anthropic.com/settings/keys',
  ),
  openai(
    label: 'OpenAI',
    note: 'Serveurs principalement hors Union européenne.',
    chatModel: 'gpt-5-mini',
    transcriptionModel: 'gpt-4o-transcribe',
    keyUrl: 'https://platform.openai.com/api-keys',
  );

  const AiProvider({
    required this.label,
    required this.note,
    required this.chatModel,
    required this.transcriptionModel,
    required this.keyUrl,
  });

  final String label;
  final String note;
  final String chatModel;
  final String? transcriptionModel;
  final String keyUrl;

  bool get canTranscribe => transcriptionModel != null;
}

/// Modèles Whisper proposés pour la transcription sur l'iPhone.
enum LocalModel {
  base('base', 'Rapide', 142),
  small('small', 'Équilibré (conseillé)', 466),
  medium('medium', 'Le plus précis, lent', 1500);

  const LocalModel(this.id, this.label, this.sizeMb);
  final String id;
  final String label;
  final int sizeMb;
}

/// Réglages de l'app. Les clés API sont rangées dans le trousseau
/// sécurisé du téléphone (Keychain sur iPhone), jamais en clair.
class Settings extends ChangeNotifier {
  Settings._(this._prefs);

  final SharedPreferences _prefs;
  static const _secure = FlutterSecureStorage();
  final Map<AiProvider, String> _keys = {};

  static Future<Settings> load() async {
    final s = Settings._(await SharedPreferences.getInstance());
    for (final p in AiProvider.values) {
      try {
        final k = await _secure.read(key: 'key_${p.name}');
        if (k != null && k.isNotEmpty) s._keys[p] = k;
      } catch (_) {
        // Trousseau indisponible : l'app reste utilisable en mode local.
      }
    }
    return s;
  }

  // Transcription
  /// null = transcription sur l'appareil.
  AiProvider? get transcriptionProvider =>
      _provider(_prefs.getString('transcription_provider'));
  set transcriptionProvider(AiProvider? p) =>
      _setString('transcription_provider', p?.name);

  LocalModel get localModel => LocalModel.values.firstWhere(
        (m) => m.name == _prefs.getString('local_model'),
        orElse: () => LocalModel.small,
      );
  set localModel(LocalModel m) => _setString('local_model', m.name);

  /// Demander à l'API de séparer les locuteurs (Mistral).
  bool get diarize => _prefs.getBool('diarize') ?? true;
  set diarize(bool v) => _setBool('diarize', v);

  // Résumé
  /// null = résumé extractif calculé sur l'appareil.
  AiProvider? get summaryProvider =>
      _provider(_prefs.getString('summary_provider'));
  set summaryProvider(AiProvider? p) => _setString('summary_provider', p?.name);

  String chatModel(AiProvider p) =>
      _prefs.getString('chat_model_${p.name}') ?? p.chatModel;
  void setChatModel(AiProvider p, String model) =>
      _setString('chat_model_${p.name}', model.trim().isEmpty ? null : model.trim());

  String transcriptionModel(AiProvider p) =>
      _prefs.getString('stt_model_${p.name}') ?? p.transcriptionModel ?? '';
  void setTranscriptionModel(AiProvider p, String model) => _setString(
      'stt_model_${p.name}', model.trim().isEmpty ? null : model.trim());

  // Clés
  String? apiKey(AiProvider p) => _keys[p];
  bool hasKey(AiProvider p) => (_keys[p] ?? '').isNotEmpty;

  Future<void> setApiKey(AiProvider p, String? key) async {
    final k = key?.trim() ?? '';
    if (k.isEmpty) {
      _keys.remove(p);
      await _secure.delete(key: 'key_${p.name}');
    } else {
      _keys[p] = k;
      await _secure.write(key: 'key_${p.name}', value: k);
    }
    notifyListeners();
  }

  // Analyse
  bool get excludeInterviewer => _prefs.getBool('exclude_interviewer') ?? true;
  set excludeInterviewer(bool v) => _setBool('exclude_interviewer', v);

  bool get groupForms => _prefs.getBool('group_forms') ?? true;
  set groupForms(bool v) => _setBool('group_forms', v);

  /// Libellés supplémentaires désignant l'enquêteur (séparés par des
  /// virgules), en plus des libellés par défaut.
  String get extraInterviewerLabels =>
      _prefs.getString('interviewer_labels') ?? '';
  set extraInterviewerLabels(String v) => _setString('interviewer_labels', v);

  Set<String> get interviewerLabels => {
        ...defaultInterviewerLabels,
        ...extraInterviewerLabels
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty),
      };

  /// Mots ignorés dans toutes les analyses (séparés par des virgules).
  String get globalStopwords => _prefs.getString('stopwords') ?? '';
  set globalStopwords(String v) => _setString('stopwords', v);

  Set<String> get globalStopwordSet => splitWords(globalStopwords);

  /// Avertissement de confidentialité déjà accepté pour ce fournisseur.
  bool privacyAccepted(AiProvider p) =>
      _prefs.getBool('privacy_${p.name}') ?? false;
  void acceptPrivacy(AiProvider p) => _setBool('privacy_${p.name}', true);

  AiProvider? _provider(String? name) {
    for (final p in AiProvider.values) {
      if (p.name == name) return p;
    }
    return null;
  }

  void _setString(String key, String? v) {
    if (v == null) {
      _prefs.remove(key);
    } else {
      _prefs.setString(key, v);
    }
    notifyListeners();
  }

  void _setBool(String key, bool v) {
    _prefs.setBool(key, v);
    notifyListeners();
  }
}

/// Découpe une liste saisie (« Bastia, Ajaccio, Dr Martin ») en mots
/// minuscules.
Set<String> splitWords(String s) => s
    .split(RegExp(r'[,;\n]'))
    .expand((w) => w.trim().toLowerCase().split(RegExp(r'\s+')))
    .where((w) => w.isNotEmpty)
    .toSet();
