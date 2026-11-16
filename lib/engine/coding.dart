import 'quotes.dart';

/// Un code du livre de codes : l'étiquette que le chercheur pose sur les
/// extraits qui parlent de la même chose.
class Code {
  Code({
    required this.id,
    required this.label,
    this.theme = '',
    this.note = '',
    this.color = 0,
  });

  final String id;
  String label;

  /// Thème auquel le code est rattaché (vide tant qu'il n'est pas classé).
  String theme;

  /// Définition du code : ce qu'il recouvre, ce qu'il exclut.
  String note;

  /// Rang de la teinte dans le spectre de l'app.
  int color;

  Map<String, Object?> toJson() => {
        'id': id,
        'label': label,
        'theme': theme,
        'note': note,
        'color': color,
      };

  factory Code.fromJson(Map<String, Object?> j) => Code(
        id: j['id'].toString(),
        label: (j['label'] ?? '').toString(),
        theme: (j['theme'] ?? '').toString(),
        note: (j['note'] ?? '').toString(),
        color: j['color'] is int ? j['color']! as int : 0,
      );
}

/// Un extrait codé : une phrase du verbatim rattachée à un code.
///
/// L'extrait est retenu par son texte et non par sa position, pour rester
/// valable quand le verbatim est corrigé ailleurs.
class Coding {
  const Coding({required this.codeId, required this.quote, this.speaker});

  final String codeId;
  final String quote;
  final String? speaker;

  Map<String, Object?> toJson() => {
        'code': codeId,
        'quote': quote,
        'speaker': speaker,
      };

  factory Coding.fromJson(Map<String, Object?> j) => Coding(
        codeId: (j['code'] ?? '').toString(),
        quote: (j['quote'] ?? '').toString(),
        speaker: j['speaker'] as String?,
      );
}

/// Ce que le livre de codes a besoin de savoir d'un entretien.
typedef CodedSource = ({
  String id,
  String title,
  String text,
  DateTime date,
  List<Coding> codings,
});

/// Vrai si deux extraits sont le même texte, à la ponctuation, aux accents
/// et à la casse près.
bool sameExcerpt(String a, String b) =>
    normalizeForMatch(a) == normalizeForMatch(b);

/// Un extrait, replacé dans l'entretien d'où il vient.
class CodeExcerpt {
  const CodeExcerpt({
    required this.sourceId,
    required this.sourceTitle,
    required this.quote,
    required this.speaker,
    required this.found,
  });

  final String sourceId;
  final String sourceTitle;
  final String quote;
  final String? speaker;

  /// Faux si le verbatim a été modifié depuis et ne contient plus l'extrait
  /// mot pour mot.
  final bool found;
}

/// L'emploi d'un code dans le corpus.
class CodeUsage {
  const CodeUsage(this.code, this.excerpts);

  final Code code;
  final List<CodeExcerpt> excerpts;

  /// Nombre d'entretiens où le code apparaît.
  int get sources => {for (final e in excerpts) e.sourceId}.length;
}

/// Entretiens par ordre chronologique : celui dans lequel ils ont été menés.
List<CodedSource> _chronological(Iterable<CodedSource> sources) =>
    sources.toList()..sort((a, b) => a.date.compareTo(b.date));

/// Pour chaque code, dans l'ordre du livre de codes, ses extraits dans tout
/// le corpus.
List<CodeUsage> codeUsages(List<Code> codes, Iterable<CodedSource> sources) {
  final ordered = _chronological(sources);
  return [
    for (final c in codes)
      CodeUsage(c, [
        for (final s in ordered)
          for (final k in s.codings)
            if (k.codeId == c.id)
              CodeExcerpt(
                sourceId: s.id,
                sourceTitle: s.title,
                quote: k.quote,
                speaker: k.speaker,
                found: quoteFidelity(k.quote, s.text) >= 1,
              ),
      ]),
  ];
}

/// Thèmes dans l'ordre où ils apparaissent dans le livre de codes ; les
/// codes sans thème viennent en dernier, sous une clé vide.
Map<String, List<CodeUsage>> groupByTheme(List<CodeUsage> usages) {
  final groups = <String, List<CodeUsage>>{};
  for (final u in usages) {
    final theme = u.code.theme.trim();
    if (theme.isNotEmpty) groups.putIfAbsent(theme, () => []).add(u);
  }
  final loose = [for (final u in usages) if (u.code.theme.trim().isEmpty) u];
  if (loose.isNotEmpty) groups[''] = loose;
  return groups;
}

/// Ce qu'un entretien apporte de neuf au livre de codes.
class SaturationPoint {
  const SaturationPoint({
    required this.sourceId,
    required this.title,
    required this.newCodes,
    required this.usedCodes,
    required this.cumulative,
  });

  final String sourceId;
  final String title;

  /// Libellés des codes employés ici pour la première fois.
  final List<String> newCodes;

  /// Nombre de codes différents employés dans cet entretien.
  final int usedCodes;

  /// Nombre de codes du corpus une fois cet entretien codé.
  final int cumulative;
}

/// Courbe de saturation : entretien après entretien, dans l'ordre où ils
/// ont été menés, le nombre de codes nouveaux. Quand les derniers entretiens
/// n'en apportent plus, le chercheur tient un argument de saturation des
/// données. Les entretiens non codés sont laissés de côté.
List<SaturationPoint> saturation(
    List<Code> codes, Iterable<CodedSource> sources) {
  final labels = {for (final c in codes) c.id: c.label};
  final seen = <String>{};
  final points = <SaturationPoint>[];
  for (final s in _chronological(sources)) {
    final used = <String>{
      for (final k in s.codings)
        if (labels.containsKey(k.codeId)) k.codeId,
    };
    if (used.isEmpty) continue;
    final fresh = [for (final id in used) if (!seen.contains(id)) id];
    seen.addAll(used);
    points.add(SaturationPoint(
      sourceId: s.id,
      title: s.title,
      newCodes: [for (final id in fresh) labels[id]!],
      usedCodes: used.length,
      cumulative: seen.length,
    ));
  }
  return points;
}

/// Phrase de lecture de la courbe de saturation, ou null s'il y a trop peu
/// d'entretiens codés pour en dire quelque chose.
String? saturationReading(List<SaturationPoint> points) {
  if (points.length < 2) return null;
  var quiet = 0;
  for (final p in points.reversed) {
    if (p.newCodes.isNotEmpty) break;
    quiet++;
  }
  if (quiet == 0) {
    final n = points.last.newCodes.length;
    return 'Le dernier entretien codé a encore fait apparaître $n '
        '${n > 1 ? 'nouveaux codes' : 'nouveau code'} : la saturation '
        "n'est pas atteinte.";
  }
  return quiet == 1
      ? "Le dernier entretien codé n'a fait apparaître aucun nouveau code : "
          'un premier indice de saturation, à confirmer.'
      : "Les $quiet derniers entretiens codés n'ont fait apparaître aucun "
          'nouveau code : un argument de saturation des données.';
}

/// Livre de codes en Markdown : thèmes, codes, définitions et verbatims,
/// prêt à être repris dans la partie « Résultats » d'une thèse.
String buildCodebookReport({
  required List<Code> codes,
  required Iterable<CodedSource> sources,
  String title = 'Livre de codes',
  DateTime? date,
}) {
  final usages = codeUsages(codes, sources);
  final points = saturation(codes, sources);
  final excerpts = usages.fold<int>(0, (n, u) => n + u.excerpts.length);
  final d = date ?? DateTime.now();
  final b = StringBuffer();
  b.writeln('# $title');
  b.writeln();
  b.writeln('Établi le ${_date(d)} avec SemantiQ.');
  b.writeln();
  b.writeln('- Codes : ${codes.length}');
  b.writeln('- Extraits codés : $excerpts');
  b.writeln('- Entretiens codés : ${points.length}');
  b.writeln();

  if (points.isNotEmpty) {
    b.writeln('## Saturation des données');
    b.writeln();
    b.writeln('Codes apparus pour la première fois dans chaque entretien, '
        'dans l\'ordre où ils ont été menés.');
    b.writeln();
    b.writeln('| Entretien | Codes employés | Nouveaux codes | Cumul |');
    b.writeln('|---|---:|---:|---:|');
    for (final p in points) {
      b.writeln('| ${_cell(p.title)} | ${p.usedCodes} | '
          '${p.newCodes.length} | ${p.cumulative} |');
    }
    b.writeln();
    final reading = saturationReading(points);
    if (reading != null) {
      b.writeln(reading);
      b.writeln();
    }
  }

  groupByTheme(usages).forEach((theme, group) {
    b.writeln('## ${theme.isEmpty ? 'Codes sans thème' : theme}');
    b.writeln();
    for (final u in group) {
      final n = u.excerpts.length;
      b.writeln('### ${u.code.label}');
      b.writeln();
      b.writeln('$n extrait${n > 1 ? 's' : ''} dans ${u.sources} '
          'entretien${u.sources > 1 ? 's' : ''}.');
      b.writeln();
      if (u.code.note.trim().isNotEmpty) {
        b.writeln('Définition : ${u.code.note.trim()}');
        b.writeln();
      }
      for (final e in u.excerpts) {
        final who = e.speaker == null ? '' : '${e.speaker}, ';
        final warn = e.found
            ? ''
            : ' ⚠ extrait introuvable tel quel dans le verbatim actuel';
        b.writeln('> « ${e.quote} » ($who${e.sourceTitle})$warn');
        b.writeln();
      }
    }
  });
  return b.toString();
}

/// Matrice codes × entretiens (CSV, séparateur point-virgule pour Excel
/// français) : le nombre d'extraits de chaque code dans chaque entretien.
String buildCodingMatrixCsv(List<Code> codes, Iterable<CodedSource> sources) {
  final ordered = _chronological(sources)
      .where((s) => s.codings.isNotEmpty)
      .toList();
  final b = StringBuffer('theme;code;total;entretiens');
  for (final s in ordered) {
    b.write(';${_csv(s.title)}');
  }
  b.writeln();
  for (final c in codes) {
    final counts = [
      for (final s in ordered)
        s.codings.where((k) => k.codeId == c.id).length,
    ];
    final total = counts.fold<int>(0, (a, n) => a + n);
    final present = counts.where((n) => n > 0).length;
    b.write('${_csv(c.theme)};${_csv(c.label)};$total;$present');
    for (final n in counts) {
      b.write(';$n');
    }
    b.writeln();
  }
  return b.toString();
}

String _date(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String _cell(String s) => s.replaceAll('|', '/');

String _csv(String s) =>
    s.contains(';') || s.contains('"') ? '"${s.replaceAll('"', '""')}"' : s;
