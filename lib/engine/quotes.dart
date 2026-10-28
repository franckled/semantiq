import 'french.dart';

/// Ramène un texte à une suite de mots comparables : minuscules, sans
/// accents, sans ponctuation, espaces simples.
String normalizeForMatch(String s) => stripAccents(s.toLowerCase())
    .replaceAll('’', "'")
    .replaceAll(RegExp(r"[^a-z0-9' ]+"), ' ')
    .replaceAll("'", ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Vérifie qu'une citation proposée par une IA figure bien dans le verbatim.
///
/// Renvoie 1 si la citation est présente mot pour mot (ponctuation et
/// accents mis à part), sinon la plus grande part de ses mots retrouvée
/// d'un seul tenant dans le texte (entre 0 et 1). Une thèse ne peut citer
/// qu'un verbatim réellement prononcé : l'interface signale toute citation
/// sous 1.
double quoteFidelity(String quote, String transcript) {
  final q = normalizeForMatch(quote);
  if (q.isEmpty) return 0;
  final t = ' ${normalizeForMatch(transcript)} ';
  if (t.contains(' $q ')) return 1;

  // Plus longue suite de mots de la citation présente dans le texte.
  final words = q.split(' ');
  var best = 0;
  for (var i = 0; i < words.length && words.length - i > best; i++) {
    for (var j = words.length; j - i > best; j--) {
      if (t.contains(' ${words.sublist(i, j).join(' ')} ')) {
        best = j - i;
        break;
      }
    }
  }
  return best / words.length;
}
