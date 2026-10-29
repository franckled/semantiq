import 'dart:convert';

import 'french.dart';
import 'transcript.dart';

/// Préfixe des lignes insérées à l'emplacement d'un moment marqué pendant
/// l'enregistrement. Ces lignes sont ignorées par l'analyse lexicale.
const String markerPrefix = '★';

/// Ligne de marqueur pour un instant de l'enregistrement.
String markerLine(Duration at) => '$markerPrefix Moment marqué (${formatClock(at)})';

/// « 1:02:05 » ou « 12:34 ».
String formatClock(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}

/// Une tâche décidée en réunion.
class ActionItem {
  const ActionItem({required this.task, this.owner = '', this.due = ''});

  final String task;

  /// Responsable (vide si non dit).
  final String owner;

  /// Échéance telle que formulée (« d'ici vendredi »), vide si non dite.
  final String due;

  Map<String, Object?> toJson() =>
      {'tache': task, 'responsable': owner, 'echeance': due};

  factory ActionItem.fromJson(Map<String, Object?> j) => ActionItem(
        task: _str(j['tache'] ?? j['task']),
        owner: _str(j['responsable'] ?? j['owner']),
        due: _str(j['echeance'] ?? j['due']),
      );
}

/// Compte rendu rédigé par un modèle de langage.
class MeetingMinutes {
  const MeetingMinutes({
    required this.provider,
    required this.model,
    required this.date,
    required this.summary,
    required this.participants,
    required this.topics,
    required this.decisions,
    required this.actions,
    required this.openQuestions,
    required this.nextSteps,
  });

  final String provider;
  final String model;
  final DateTime date;
  final String summary;
  final List<String> participants;

  /// Sujets abordés, dans l'ordre de la réunion.
  final List<String> topics;
  final List<String> decisions;
  final List<ActionItem> actions;
  final List<String> openQuestions;
  final List<String> nextSteps;

  Map<String, Object?> toJson() => {
        'provider': provider,
        'model': model,
        'date': date.toIso8601String(),
        'resume': summary,
        'participants': participants,
        'sujets': topics,
        'decisions': decisions,
        'actions': [for (final a in actions) a.toJson()],
        'points_en_suspens': openQuestions,
        'prochaines_etapes': nextSteps,
      };

  factory MeetingMinutes.fromJson(Map<String, Object?> j) => MeetingMinutes(
        provider: _str(j['provider']),
        model: _str(j['model']),
        date: DateTime.tryParse(_str(j['date'])) ?? DateTime.now(),
        summary: _str(j['resume']),
        participants: _strList(j['participants']),
        topics: _strList(j['sujets']),
        decisions: _strList(j['decisions']),
        actions: [
          for (final a in (j['actions'] as List<Object?>? ?? const []))
            if (a is Map<String, Object?>) ActionItem.fromJson(a),
        ],
        openQuestions: _strList(j['points_en_suspens']),
        nextSteps: _strList(j['prochaines_etapes']),
      );

  /// Lit la réponse d'un modèle, qui doit contenir un objet JSON.
  factory MeetingMinutes.parse(
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
    return MeetingMinutes.fromJson({
      ...decoded,
      'provider': provider,
      'model': model,
      'date': DateTime.now().toIso8601String(),
    });
  }
}

/// Phrase repérée par l'analyse locale, avec son locuteur.
class Cue {
  const Cue(this.sentence, {this.due = ''});

  final Sentence sentence;

  /// Échéance repérée dans la phrase, le cas échéant.
  final String due;
}

/// Moment marqué pendant l'enregistrement et ce qui a été dit juste après.
class MarkedMoment {
  const MarkedMoment(this.label, this.excerpt);

  final String label;
  final String excerpt;
}

/// Repérage local, sans IA, des décisions, actions et questions d'une
/// réunion, d'après les tournures de langage les plus courantes. C'est un
/// premier tri, à relire : il ne remplace pas un compte rendu rédigé.
class MeetingCues {
  const MeetingCues({
    required this.decisions,
    required this.actions,
    required this.questions,
    required this.moments,
  });

  final List<Cue> decisions;
  final List<Cue> actions;
  final List<Cue> questions;
  final List<MarkedMoment> moments;

  bool get isEmpty =>
      decisions.isEmpty && actions.isEmpty && questions.isEmpty && moments.isEmpty;
}

const List<String> _decisionCues = [
  'on a décidé', 'nous avons décidé', 'il est décidé', 'il a été décidé',
  'on décide', 'décision', 'on valide', 'on a validé', 'c\'est validé',
  'validé', 'c\'est acté', 'on acte', 'acté', 'on retient', 'on part sur',
  'on garde', 'on choisit', 'on a choisi', 'on se met d\'accord',
  'tout le monde est d\'accord', 'on est d\'accord', 'adopté', 'on maintient',
  'on abandonne', 'on arrête',
];

const List<String> _actionCues = [
  'je m\'en occupe', 'je m\'occupe', 'je me charge', 'je t\'envoie',
  'je vous envoie', 'je te renvoie', 'je vous renvoie', 'je ferai',
  'je prépare', 'je rédige', 'je contacte', 'j\'appelle', 'je relance',
  's\'en occupe', 'se charge', 'tu pourrais', 'vous pourriez',
  'il faut que', 'il faudrait que', 'il faudra', 'à faire',
  'on doit', 'on devra', 'il reste à', 'action', 'à envoyer', 'à préparer',
  'à prévoir', 'prévoir de', 'penser à',
];

/// Tournures trop courantes à l'oral pour signaler seules une action :
/// retenues seulement si la phrase donne aussi une échéance.
const List<String> _weakActionCues = [
  'je vais', 'je fais', 'tu peux', 'vous pouvez', 'on va', 'tu vas',
];

const List<String> _openCues = [
  'à voir', 'on verra', 'reste à définir', 'reste à voir', 'en suspens',
  'on en reparle', 'à revoir', 'pas tranché', 'à trancher', 'on ne sait pas',
  'question ouverte', 'à creuser', 'à clarifier', 'pas encore décidé',
  'à rediscuter',
];

final RegExp _dueRe = RegExp(
  r"\b(?:d'ici|avant|pour|d'ici à|au plus tard|dès)\s+(?:le\s+|la\s+|lundi|mardi|mercredi|jeudi|vendredi|samedi|dimanche|demain|ce soir|la semaine prochaine|la fin|fin|mi-|début|[0-9]{1,2})[^,.;!?]{0,25}"
  r"|\b(?:lundi|mardi|mercredi|jeudi|vendredi)\s+(?:prochain|matin|soir)\b"
  r"|\b(?:la semaine prochaine|le mois prochain|demain|cette semaine|ce mois-ci)\b",
  caseSensitive: false,
);

bool _hasCue(String normalized, List<String> cues) {
  for (final c in cues) {
    final n = ' ${_norm(c)} ';
    if (normalized.contains(n)) return true;
  }
  return false;
}

String _norm(String s) => stripAccents(s.toLowerCase())
    .replaceAll('’', "'")
    .replaceAll(RegExp(r"[^a-z0-9' -]+"), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Repère décisions, actions et questions dans le verbatim d'une réunion.
MeetingCues findMeetingCues(String raw) {
  final t = parseTranscript(raw, interviewerLabels: const {});
  final decisions = <Cue>[];
  final actions = <Cue>[];
  final questions = <Cue>[];
  for (final s in t.sentences) {
    final n = ' ${_norm(s.text)} ';
    final words = n.trim().split(' ').length;
    if (words < 4) continue;
    if (_hasCue(n, _decisionCues)) {
      decisions.add(Cue(s));
    } else if (_hasCue(n, _actionCues) ||
        (_hasCue(n, _weakActionCues) && _dueRe.hasMatch(s.text))) {
      final due = _dueRe.firstMatch(s.text)?.group(0)?.trim() ?? '';
      actions.add(Cue(s, due: due));
    } else if (_hasCue(n, _openCues) ||
        (s.text.trim().endsWith('?') && words >= 6)) {
      questions.add(Cue(s));
    }
  }
  return MeetingCues(
    decisions: decisions.take(20).toList(),
    actions: actions.take(30).toList(),
    questions: questions.take(20).toList(),
    moments: findMarkedMoments(raw),
  );
}

/// Moments marqués (lignes « ★ ») et les phrases qui les suivent.
List<MarkedMoment> findMarkedMoments(String raw) {
  final lines = raw.split('\n');
  final out = <MarkedMoment>[];
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if (!line.startsWith(markerPrefix)) continue;
    final label = line.substring(markerPrefix.length).trim();
    final after = StringBuffer();
    for (var j = i + 1; j < lines.length && after.length < 280; j++) {
      final l = lines[j].trim();
      if (l.isEmpty) continue;
      if (l.startsWith(markerPrefix)) break;
      if (after.isNotEmpty) after.write(' ');
      after.write(l);
    }
    var excerpt = after.toString();
    if (excerpt.length > 280) excerpt = '${excerpt.substring(0, 277)}…';
    out.add(MarkedMoment(label, excerpt));
  }
  return out;
}

/// Compte rendu en Markdown.
String buildMinutesReport({
  required String title,
  required DateTime date,
  Duration? duration,
  MeetingMinutes? minutes,
  required MeetingCues cues,
}) {
  final b = StringBuffer();
  b.writeln('# $title');
  b.writeln();
  final d = '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
  b.writeln('Réunion du $d'
      '${duration == null ? '' : ' · durée ${formatClock(duration)}'}');
  b.writeln();
  final m = minutes;
  if (m != null) {
    if (m.participants.isNotEmpty) {
      b.writeln('**Participants :** ${m.participants.join(', ')}');
      b.writeln();
    }
    b.writeln('## Résumé');
    b.writeln();
    b.writeln(m.summary);
    b.writeln();
    void list(String heading, List<String> items) {
      if (items.isEmpty) return;
      b.writeln('## $heading');
      b.writeln();
      for (final i in items) {
        b.writeln('- $i');
      }
      b.writeln();
    }

    list('Sujets abordés', m.topics);
    list('Décisions', m.decisions);
    if (m.actions.isNotEmpty) {
      b.writeln('## Actions');
      b.writeln();
      b.writeln('| Action | Responsable | Échéance |');
      b.writeln('|---|---|---|');
      for (final a in m.actions) {
        b.writeln('| ${_cell(a.task)} | ${_cell(a.owner)} | ${_cell(a.due)} |');
      }
      b.writeln();
    }
    list('Points en suspens', m.openQuestions);
    list('Prochaines étapes', m.nextSteps);
    b.writeln('_Compte rendu rédigé par ${m.provider} (${m.model}), à relire._');
    b.writeln();
  } else {
    b.writeln('_Repérage automatique sur l\'appareil, à relire et compléter._');
    b.writeln();
    void cueList(String heading, List<Cue> items) {
      if (items.isEmpty) return;
      b.writeln('## $heading');
      b.writeln();
      for (final c in items) {
        final who = c.sentence.speaker == null ? '' : '${c.sentence.speaker} : ';
        final due = c.due.isEmpty ? '' : ' (échéance : ${c.due})';
        b.writeln('- $who${c.sentence.text}$due');
      }
      b.writeln();
    }

    cueList('Décisions', cues.decisions);
    cueList('Actions', cues.actions);
    cueList('Questions et points en suspens', cues.questions);
  }
  if (cues.moments.isNotEmpty) {
    b.writeln('## Moments marqués');
    b.writeln();
    for (final mm in cues.moments) {
      b.writeln('- **${mm.label}** — ${mm.excerpt}');
    }
    b.writeln();
  }
  return b.toString();
}

String _cell(String s) => s.isEmpty ? '—' : s.replaceAll('|', '/');

String _str(Object? o) => o == null ? '' : o.toString().trim();

List<String> _strList(Object? o) => [
      for (final e in (o is List<Object?> ? o : const <Object?>[]))
        if (_str(e).isNotEmpty) _str(e),
    ];
