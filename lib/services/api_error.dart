import 'dart:convert';

/// Erreur présentée telle quelle à l'utilisateur.
class ApiError implements Exception {
  const ApiError(this.message);

  final String message;

  /// Traduit une réponse HTTP en erreur compréhensible.
  factory ApiError.fromResponse(int status, String body, String provider) {
    final detail = _detail(body);
    final suffix = detail == null ? '' : '\n\nDétail : $detail';
    return switch (status) {
      401 || 403 => ApiError('$provider refuse la clé API. Vérifiez-la dans '
          'les réglages.$suffix'),
      402 => ApiError('Crédit épuisé chez $provider.$suffix'),
      404 => ApiError('Modèle introuvable chez $provider : vérifiez le nom du '
          'modèle dans les réglages.$suffix'),
      413 => ApiError('Fichier trop volumineux pour $provider.$suffix'),
      429 => ApiError('$provider limite le nombre de requêtes ou le quota est '
          'atteint. Réessayez dans quelques minutes.$suffix'),
      >= 500 => ApiError('$provider est momentanément indisponible '
          '(erreur $status). Réessayez plus tard.$suffix'),
      _ => ApiError('Erreur $status renvoyée par $provider.$suffix'),
    };
  }

  static String? _detail(String body) {
    try {
      final j = jsonDecode(body);
      if (j is Map<String, Object?>) {
        final e = j['error'];
        if (e is Map<String, Object?> && e['message'] != null) {
          return e['message'].toString();
        }
        for (final k in ['message', 'detail', 'error']) {
          if (j[k] != null) return j[k].toString();
        }
      }
    } catch (_) {}
    final t = body.trim();
    if (t.isEmpty) return null;
    return t.length > 300 ? '${t.substring(0, 300)}…' : t;
  }

  @override
  String toString() => message;
}
