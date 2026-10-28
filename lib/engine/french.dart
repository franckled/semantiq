/// Outils linguistiques pour le français oral retranscrit : découpage en
/// mots, mots-outils, tics de langage et racinisation légère.
library;

/// Mots-outils du français écrit et oral, ignorés dans les statistiques.
/// Les formes sont en minuscules, accents compris.
const List<String> _stopwordList = [
  // Articles, prépositions, conjonctions
  'a', 'à', 'au', 'aux', 'avec', 'ce', 'ces', 'cet', 'cette', 'dans', 'de',
  'des', 'du', 'en', 'entre', 'et', 'la', 'le', 'les', 'leur', 'leurs', 'mais',
  'ou', 'où', 'par', 'pour', 'sans', 'sous', 'sur', 'un', 'une', 'vers', 'chez',
  'contre', 'depuis', 'pendant', 'avant', 'après', 'selon', 'comme', 'si',
  'ni', 'car', 'or', 'donc', 'puis', 'lorsque', 'quand', 'que', 'qui', 'quoi',
  'dont', 'lequel', 'laquelle', 'lesquels', 'lesquelles', 'auquel', 'duquel',
  // Pronoms
  'je', 'j', 'tu', 'il', 'elle', 'on', 'nous', 'vous', 'ils', 'elles', 'me',
  'm', 'te', 't', 'se', 's', 'lui', 'eux', 'moi', 'toi', 'soi', 'y', 'l', 'd',
  'qu', 'c', 'n', 'ça', 'ca', 'cela', 'ceci', 'celui', 'celle', 'ceux',
  'celles', 'mon', 'ma', 'mes', 'ton', 'ta', 'tes', 'son', 'sa', 'ses', 'notre',
  'nos', 'votre', 'vos', 'même', 'mêmes', 'autre', 'autres', 'tout', 'tous',
  'toute', 'toutes', 'chaque', 'quelque', 'quelques', 'quelqu', 'aucun',
  'aucune', 'rien', 'personne', 'chacun', 'plusieurs',
  // Adverbes et négations très fréquents
  'ne', 'pas', 'plus', 'moins', 'très', 'trop', 'peu', 'bien', 'aussi',
  'encore', 'déjà', 'toujours', 'jamais', 'souvent', 'ici', 'là', 'alors',
  'ainsi', 'assez', 'beaucoup', 'tant', 'tellement', 'vraiment', 'peut',
  'non', 'oui', 'si', 'tout', 'juste', 'surtout', 'presque', 'parfois',
  'ensuite', 'enfin', 'maintenant', 'après', 'avant', 'là-dessus', 'dessus',
  'dessous', 'dedans', 'dehors', 'comment', 'pourquoi', 'combien', 'autant',
  // Être, avoir, faire, aller, dire, pouvoir, vouloir, savoir (formes courantes)
  'être', 'suis', 'es', 'est', 'sommes', 'êtes', 'sont', 'étais', 'était',
  'étions', 'étiez', 'étaient', 'été', 'serai', 'sera', 'serait', 'seraient',
  'serons', 'seront', 'sois', 'soit', 'soient', 'fut',
  'avoir', 'ai', 'as', 'avons', 'avez', 'ont', 'avais', 'avait', 'avions',
  'aviez', 'avaient', 'eu', 'aurai', 'aura', 'aurait', 'auraient', 'aie',
  'ait', 'aient',
  'faire', 'fais', 'fait', 'faisait', 'faites', 'font', 'ferait', 'fera',
  'aller', 'vais', 'va', 'vas', 'allons', 'allez', 'vont', 'allait', 'allé',
  'dire', 'dis', 'dit', 'disait', 'dites', 'disent',
  'pouvoir', 'peux', 'pouvait', 'pourrait', 'pu', 'vouloir', 'veux', 'veut',
  'voulait', 'voudrais', 'savoir', 'sais', 'sait', 'savait', 'su',
  'falloir', 'faut', 'fallait', 'faudrait',
  'avoir', 'chose', 'choses', 'fois', 'gens', 'trucs', 'truc',
  // Tics et marqueurs de l'oral
  'euh', 'heu', 'hum', 'hmm', 'mm', 'mmh', 'ah', 'oh', 'eh', 'bah', 'ben',
  'bon', 'bref', 'voilà', 'voila', 'hein', 'quoi', 'genre', 'ouais', 'ouai',
  'okay', 'ok', 'd\'accord', 'accord', 'effectivement', 'disons', 'enfin',
  'style', 'machin', 'là', 'tiens', 'dac', 'peut-être', 'est-à-dire',
  'là-bas', 'celui-ci', 'celle-ci', 'ceux-ci', 'quelqu\'un', 'quelqu',
];

/// Ensemble des mots-outils (les doublons de la liste sont sans effet).
final Set<String> frenchStopwords = _stopwordList.toSet();

/// Caractères pris comme lettres dans un mot (lettres latines accentuées,
/// chiffres, trait d'union interne).
final RegExp _wordPattern = RegExp(
  r'[0-9A-Za-zÀ-ÖØ-öø-ÿŒœÆæ]+(?:-[0-9A-Za-zÀ-ÖØ-öø-ÿŒœÆæ]+)*',
);

/// Un mot repéré dans le texte, avec sa position.
class Token {
  const Token(this.surface, this.start, this.end);

  /// Forme telle qu'écrite, en minuscules.
  final String surface;
  final int start;
  final int end;
}

/// Découpe [text] en mots. Les élisions (l', j', qu'…) sont séparées du mot
/// qui suit : « l'hôpital » donne « l » et « hôpital ».
///
/// Les formes interrogatives ou impératives à pronom (« pouvez-vous »,
/// « est-ce », « dites-moi ») sont séparées en mots ; les mots composés
/// (« rendez-vous », « vis-à-vis ») restent entiers.
List<Token> tokenize(String text) {
  final out = <Token>[];
  for (final m in _wordPattern.allMatches(text)) {
    final word = m.group(0)!.toLowerCase();
    final parts = word.split('-');
    if (parts.length > 1 &&
        _cliticSuffixes.contains(parts.last) &&
        !_compounds.contains(word)) {
      var pos = m.start;
      for (final p in parts) {
        out.add(Token(p, pos, pos + p.length));
        pos += p.length + 1;
      }
    } else {
      out.add(Token(word, m.start, m.end));
    }
  }
  return out;
}

const Set<String> _cliticSuffixes = {
  'je', 'tu', 'il', 'elle', 'on', 'nous', 'vous', 'ils', 'elles', 'ce', 'ci',
  'là', 'le', 'la', 'les', 'moi', 'toi', 'lui', 'leur', 'y', 'en', 't',
};

const Set<String> _compounds = {'rendez-vous', 'vis-à-vis', 'face-à-face'};

/// Vrai si [word] est un mot-outil, un nombre ou un mot trop court pour
/// porter du sens dans une analyse lexicale.
bool isStopword(String word, {Set<String> extra = const {}}) {
  if (word.length < 3) return true;
  if (frenchStopwords.contains(word) || extra.contains(word)) return true;
  if (RegExp(r'^[0-9]+$').hasMatch(word)) return true;
  return false;
}

const Map<String, String> _accents = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ã': 'a',
  'ç': 'c',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'î': 'i', 'ï': 'i', 'í': 'i',
  'ô': 'o', 'ö': 'o', 'ó': 'o',
  'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u',
  'ÿ': 'y', 'œ': 'oe', 'æ': 'ae',
};

/// Retire les accents (« hôpital » → « hopital »).
String stripAccents(String s) {
  final b = StringBuffer();
  for (final ch in s.split('')) {
    b.write(_accents[ch] ?? ch);
  }
  return b.toString();
}

/// Racinisation légère du français : regroupe pluriel, féminin et les
/// terminaisons verbales les plus fréquentes, sans tronquer les mots au
/// point de les rendre méconnaissables. Volontairement prudente : elle
/// préfère laisser deux formes séparées que fusionner deux sens.
///
///   médecins, médecin → medecin
///   patiente, patientes, patient → patient
///   hôpitaux, hôpital → hopital
///   parler, parlé, parlait, parlaient → parl
String stem(String word) {
  var w = stripAccents(word.toLowerCase());
  if (w.length <= 3) return w;

  // Pluriels en -aux (hôpitaux, généraux) → -al
  if (w.length > 5 && w.endsWith('aux')) {
    return '${w.substring(0, w.length - 3)}al';
  }
  // Pluriel
  if (w.length > 3 && (w.endsWith('s') || w.endsWith('x')) &&
      !w.endsWith('ss')) {
    w = w.substring(0, w.length - 1);
  }
  // Terminaisons verbales (de la plus longue à la plus courte)
  for (final suffix in const ['aient', 'ait', 'ais', 'ant', 'er', 'ez', 'ee']) {
    if (w.endsWith(suffix) && w.length - suffix.length >= 4) {
      return w.substring(0, w.length - suffix.length);
    }
  }
  // Féminin et participe passé
  if (w.endsWith('e') && w.length > 4) {
    w = w.substring(0, w.length - 1);
  }
  return w;
}
