# SemantiQ

Application iPhone (et Android) pour les internes et chercheurs en médecine qui analysent les entretiens semi-directifs de leur thèse.

On importe un enregistrement (mémo vocal, dictaphone) ou on colle une retranscription. SemantiQ produit :

- **le texte** : transcription sur l'iPhone (Whisper) ou par API (Mistral, OpenAI), puis relecture, marquage des locuteurs et pseudonymisation ;
- **le résumé** : extractif et calculé sur l'iPhone, ou rédigé par une IA (Mistral, Claude, OpenAI) avec thèmes et verbatims ;
- **les mots les plus fréquents** : hors mots-outils et tics de l'oral, formes regroupées (patient, patiente, patients), en nuage ou en liste, avec les phrases où chaque mot apparaît ;
- **les phrases clés** : classées par centralité (TextRank), et les expressions récurrentes (« médecin traitant », « prise en charge ») ;
- **les corrélations de mots** : un réseau de cooccurrences et le tableau des paires les plus associées, mesurées par l'information mutuelle.

Les exports disponibles sont un rapport Markdown, un tableau des fréquences en CSV et un corpus au format IRaMuTeQ. Le corpus peut regrouper tous les entretiens, avec leurs variables.

## Confidentialité

Par défaut, rien ne quitte le téléphone. Les entretiens sont enregistrés dans l'espace privé de l'app, et les clés API dans le trousseau de l'iPhone.

Tout envoi à un fournisseur d'IA est précédé d'un avertissement. Pour la transcription par API, c'est la voix elle-même qui part, et la voix est une donnée identifiante. Vérifiez que la note d'information et l'avis du comité d'éthique couvrent ce traitement.

Chaque citation proposée par une IA est comparée au verbatim. Celles qui n'y figurent pas mot pour mot sont signalées.

## Écrire les locuteurs

Une ligne commençant par `Libellé :` ouvre un tour de parole.

```
E : Comment avez-vous vécu l'annonce ?
P1 : Très mal, au début…
```

`E`, `Enq`, `Enquêteur`, `Interviewer`, `I` et `Q` désignent l'enquêteur. Sa parole est exclue des statistiques. D'autres libellés peuvent être ajoutés dans les réglages.

## Compilation

L'app est compilée par GitHub Actions (aucun terminal nécessaire) :

- **CI** (à chaque envoi sur `main`) : analyse, tests, APK Android téléchargeable dans les artefacts, compilation iOS de contrôle.
- **TestFlight** (Actions › TestFlight › Run workflow, ou tag `v*`) : compile, signe et envoie l'app sur App Store Connect.

### Secrets requis pour TestFlight

Ils se règlent dans Settings › Secrets and variables › Actions. Ce sont les mêmes que pour CliniFlow :

| Secret | Contenu |
|---|---|
| `APPLE_TEAM_ID` | Identifiant d'équipe Apple Developer |
| `ASC_KEY_ID` | Key ID de la clé API App Store Connect |
| `ASC_ISSUER_ID` | Issuer ID |
| `ASC_KEY_P8` | Contenu du fichier AuthKey_XXXX.p8 |

L'identifiant `fr.semantiq.app` doit être enregistré dans Apple Developer, et l'app créée dans App Store Connect.

## Structure

```
lib/engine/    analyse lexicale (pur Dart, testée) : découpage, racinisation,
               fréquences, TextRank, cooccurrences, exports, vérification des citations
lib/services/  transcription (Whisper local / API), résumé par IA, réglages
lib/data/      enregistrement des entretiens
lib/ui/        écrans
tool/          scripts de compilation
```

© 2026 Franck LE DUFF
