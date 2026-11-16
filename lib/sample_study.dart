import 'data/interview.dart';
import 'engine/coding.dart';
import 'sample_interview.dart';

/// Étude fictive fournie avec l'app : trois entretiens sur le vécu du
/// parcours de soins, déjà codés, pour découvrir le codage thématique, le
/// livre de codes et la courbe de saturation. Sert aussi aux tests.

const _interview2 = '''
E : Bonjour, merci de me recevoir. Pouvez-vous me raconter comment votre maladie a été découverte ?
P2 : C'est mon médecin traitant qui a insisté pour faire des examens. Moi je repoussais, je n'avais pas le temps.
P2 : Quand il m'a annoncé le résultat, je n'ai rien entendu de ce qu'il disait après. J'étais sidérée.
E : Qu'est-ce qui s'est passé ensuite ?
P2 : Ensuite il a fallu aller à l'hôpital. Depuis le village, c'est une heure et demie de route, et l'hiver la route est mauvaise.
P2 : J'ai annulé deux rendez-vous à cause de ça. Je me disais que ça pouvait attendre.
E : Vous avez renoncé à certains soins ?
P2 : Oui, la kinésithérapie par exemple. Il n'y a pas de kiné au village, j'ai laissé tomber.
E : Comment se passaient les consultations à l'hôpital ?
P2 : Le spécialiste était pressé. Il parlait avec des mots que je ne comprenais pas, et je n'osais pas poser de questions.
P2 : Personne ne m'a expliqué les effets du traitement. Je les ai découverts toute seule, à la maison.
E : Et votre médecin traitant dans tout ça ?
P2 : Lui, je lui fais confiance, il prend le temps. Mais il ne recevait pas les comptes rendus de l'hôpital, il me demandait à moi ce que le spécialiste avait dit.
E : Qui vous a aidée pendant cette période ?
P2 : Ma fille. Elle a pris des jours de congé pour m'emmener, sans elle je n'y serais pas allée.
''';

const _interview3 = '''
E : Bonjour, merci d'avoir accepté. Comment s'est passé le début de votre prise en charge ?
P3 : Le début, c'était long. Trois semaines entre la prise de sang et le rendez-vous, trois semaines sans dormir.
P3 : On tourne en rond, on se pose mille questions et personne ne répond.
E : Vous étiez accompagné ?
P3 : Mon fils vit sur le continent, mais il m'appelait tous les soirs. Et ma voisine m'a conduit à Bastia à chaque fois.
E : Comment décririez-vous la relation avec les soignants ?
P3 : À l'hôpital, je n'ai jamais vu deux fois le même médecin. Il faut tout réexpliquer à chaque consultation.
P3 : Mon médecin traitant, c'est différent. Il connaît mon histoire, je n'ai pas besoin de tout redire.
E : Les informations circulaient bien entre eux ?
P3 : Non. C'est moi qui apportais les résultats d'un cabinet à l'autre, dans une pochette.
E : Et les trajets ?
P3 : À mon âge, la route de nuit pour un rendez-vous à huit heures, c'est une épreuve. J'ai demandé des horaires plus tard, on m'a dit que ce n'était pas possible.
''';

const _choc = "Choc de l'annonce";
const _attente = 'Attente et incertitude';
const _proches = 'Soutien des proches';
const _confiance = 'Confiance envers le médecin traitant';
const _numero = "Dépersonnalisation à l'hôpital";
const _information = 'Information insuffisante';
const _rupture = 'Rupture ville-hôpital';
const _distance = 'Éloignement géographique';
const _renoncement = 'Renoncement aux soins';

const _vecu = 'Vécu de la maladie';
const _relation = 'Relation de soin';
const _parcours = 'Organisation du parcours';

/// Livre de codes de l'étude d'exemple.
const List<({String label, String theme, String note})> sampleCodes = [
  (
    label: _choc,
    theme: _vecu,
    note: "Réaction immédiate à l'annonce du diagnostic.",
  ),
  (
    label: _attente,
    theme: _vecu,
    note: 'Délais avant un rendez-vous ou un résultat, et ce qu\'ils font '
        'vivre.',
  ),
  (
    label: _proches,
    theme: _vecu,
    note: "Aide concrète ou morale apportée par l'entourage.",
  ),
  (
    label: _confiance,
    theme: _relation,
    note: 'Relation ancienne, disponibilité, connaissance de la personne.',
  ),
  (
    label: _numero,
    theme: _relation,
    note: 'Sentiment d\'anonymat, interlocuteurs qui changent.',
  ),
  (
    label: _information,
    theme: _relation,
    note: 'Explications absentes ou incomprises ; questions non posées.',
  ),
  (
    label: _rupture,
    theme: _parcours,
    note: 'Informations qui ne circulent pas entre la ville et l\'hôpital.',
  ),
  (
    label: _distance,
    theme: _parcours,
    note: 'Temps et fatigue des trajets vers les lieux de soins.',
  ),
  (
    label: _renoncement,
    theme: _parcours,
    note: 'Soins repoussés ou abandonnés, quelle qu\'en soit la raison.',
  ),
];

typedef SampleStudyInterview = ({
  String title,
  String text,
  String speaker,
  int daysAgo,
  Map<String, String> variables,
  List<({String code, String quote})> codings,
});

/// Les trois entretiens de l'étude d'exemple, du plus ancien au plus récent.
const List<SampleStudyInterview> sampleStudy = [
  (
    title: 'Exemple 1 – M. A., 64 ans',
    text: sampleInterview,
    speaker: 'P1',
    daysAgo: 21,
    variables: {'sexe': 'homme', 'age': '64'},
    codings: [
      (code: _choc, quote: 'Alors le diagnostic, ça a été un choc, euh, vraiment.'),
      (code: _attente, quote: "L'attente, c'est le plus dur."),
      (code: _attente, quote: 'On ne sait pas, on imagine le pire.'),
      (
        code: _confiance,
        quote: "Le médecin traitant, c'est quelqu'un qui me connaît depuis "
            'vingt ans, donc la confiance était là.',
      ),
      (
        code: _numero,
        quote: 'Mais on se sent un peu un numéro, les médecins changent tout '
            'le temps.',
      ),
      (
        code: _rupture,
        quote: "Ce qui m'a manqué c'est le lien entre l'hôpital et mon "
            'médecin traitant.',
      ),
      (
        code: _rupture,
        quote: "Le lien entre la ville et l'hôpital, c'est vraiment ça qui "
            'manque en Corse.',
      ),
      (
        code: _distance,
        quote: 'Faire deux heures de route pour une consultation de dix '
            "minutes, avec la fatigue du traitement, c'est épuisant.",
      ),
      (
        code: _proches,
        quote: "Ma femme m'accompagne à chaque consultation, elle conduit "
            "parce que la fatigue m'empêche de faire la route.",
      ),
    ],
  ),
  (
    title: 'Exemple 2 – Mme B., 58 ans',
    text: _interview2,
    speaker: 'P2',
    daysAgo: 12,
    variables: {'sexe': 'femme', 'age': '58'},
    codings: [
      (code: _choc, quote: "J'étais sidérée."),
      (
        code: _distance,
        quote: "Depuis le village, c'est une heure et demie de route, et "
            "l'hiver la route est mauvaise.",
      ),
      (code: _renoncement, quote: "J'ai annulé deux rendez-vous à cause de ça."),
      (
        code: _renoncement,
        quote: "Il n'y a pas de kiné au village, j'ai laissé tomber.",
      ),
      (
        code: _information,
        quote: 'Il parlait avec des mots que je ne comprenais pas, et je '
            "n'osais pas poser de questions.",
      ),
      (
        code: _information,
        quote: "Personne ne m'a expliqué les effets du traitement.",
      ),
      (code: _confiance, quote: 'Lui, je lui fais confiance, il prend le temps.'),
      (
        code: _rupture,
        quote: "Mais il ne recevait pas les comptes rendus de l'hôpital, il "
            'me demandait à moi ce que le spécialiste avait dit.',
      ),
      (
        code: _proches,
        quote: "Elle a pris des jours de congé pour m'emmener, sans elle je "
            "n'y serais pas allée.",
      ),
    ],
  ),
  (
    title: 'Exemple 3 – M. C., 71 ans',
    text: _interview3,
    speaker: 'P3',
    daysAgo: 4,
    variables: {'sexe': 'homme', 'age': '71'},
    codings: [
      (
        code: _attente,
        quote: 'Trois semaines entre la prise de sang et le rendez-vous, '
            'trois semaines sans dormir.',
      ),
      (
        code: _attente,
        quote: 'On tourne en rond, on se pose mille questions et personne ne '
            'répond.',
      ),
      (
        code: _proches,
        quote: "Et ma voisine m'a conduit à Bastia à chaque fois.",
      ),
      (
        code: _numero,
        quote: "À l'hôpital, je n'ai jamais vu deux fois le même médecin.",
      ),
      (
        code: _confiance,
        quote: "Il connaît mon histoire, je n'ai pas besoin de tout redire.",
      ),
      (
        code: _rupture,
        quote: "C'est moi qui apportais les résultats d'un cabinet à l'autre, "
            'dans une pochette.',
      ),
      (
        code: _distance,
        quote: 'À mon âge, la route de nuit pour un rendez-vous à huit '
            "heures, c'est une épreuve.",
      ),
    ],
  ),
];

/// Ajoute l'étude d'exemple au corpus : les codes qui manquent au livre de
/// codes, puis les trois entretiens avec leurs extraits codés.
void loadSampleStudy(InterviewStore store) {
  final codes = {
    for (final c in sampleCodes)
      c.label: store.addCode(c.label, theme: c.theme, note: c.note),
  };
  final now = DateTime.now();
  for (final s in sampleStudy) {
    store.create(
      title: s.title,
      text: s.text,
      source: "Exemple fourni avec l'app",
      createdAt: now.subtract(Duration(days: s.daysAgo)),
      variables: s.variables,
      codings: [
        for (final c in s.codings)
          Coding(codeId: codes[c.code]!.id, quote: c.quote, speaker: s.speaker),
      ],
    );
  }
}

/// Vrai si l'étude d'exemple est déjà dans le corpus.
bool hasSampleStudy(InterviewStore store) =>
    store.items.any((i) => i.title == sampleStudy.first.title);
