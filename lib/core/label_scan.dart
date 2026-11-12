/// Reads a nutrition label from on-device text recognition: rebuilds the
/// table's rows from where each piece of text sits, then picks out energy,
/// macros, fiber, sugar, sodium and the serving size. Pure Dart, tested
/// against saved recognizer output (`test/fixtures/labels/`).
library;

import 'dart:math' as math;

import 'nutrition_math.dart';

/// One line of recognized text and where it is in the photo, in pixels from
/// the top left. ([x1], [y1]) is the middle of its left edge and ([x2], [y2])
/// of its right edge, so a tilted photo shows in the slope between them.
class OcrLine {
  const OcrLine({
    required this.text,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.height,
  });

  final String text;
  final double x1;
  final double y1;
  final double x2;
  final double y2;
  final double height;

  /// A line from the platform channel, or null when it is malformed.
  static OcrLine? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final text = raw['text'];
    final nums = [
      for (final k in const ['x1', 'y1', 'x2', 'y2', 'height']) raw[k],
    ];
    if (text is! String || nums.any((n) => n is! num || !n.isFinite)) {
      return null;
    }
    final v = [for (final n in nums) (n as num).toDouble()];
    return OcrLine(
      text: text,
      x1: v[0],
      y1: v[1],
      x2: v[2],
      y2: v[3],
      height: v[4],
    );
  }
}

/// The table rows of [lines], top to bottom, each with its pieces left to
/// right. A recognizer returns a label's names and values as separate pieces,
/// so pieces at the same height are joined. A tilted photo is levelled first,
/// using the slope of the longer pieces.
List<List<String>> rowsFromLines(List<OcrLine> lines) {
  final usable = [
    for (final l in lines)
      if (l.text.trim().isNotEmpty && l.height > 0) l,
  ];
  if (usable.isEmpty) return const [];

  // Tilt: the median slope of the pieces, longest first, so one short piece
  // with a noisy box does not decide it.
  final byLength = [...usable]
    ..sort((a, b) => (b.x2 - b.x1).compareTo(a.x2 - a.x1));
  final slopes = [
    for (final l in byLength.take(math.max(3, usable.length ~/ 2)))
      if (l.x2 - l.x1 > l.height) (l.y2 - l.y1) / (l.x2 - l.x1),
  ]..sort();
  final slope = slopes.isEmpty ? 0.0 : slopes[slopes.length ~/ 2];

  double level(OcrLine l) => (l.y1 + l.y2) / 2 - slope * (l.x1 + l.x2) / 2;

  final sorted = [...usable]..sort((a, b) => level(a).compareTo(level(b)));
  final rows = <List<OcrLine>>[];
  var rowY = 0.0;
  var rowHeight = 0.0;
  for (final l in sorted) {
    final y = level(l);
    if (rows.isNotEmpty &&
        (y - rowY).abs() < 0.6 * math.min(l.height, rowHeight)) {
      rows.last.add(l);
      // The row follows its pieces, so a slight curve does not split it.
      rowY = (rowY * (rows.last.length - 1) + y) / rows.last.length;
      rowHeight = math.min(rowHeight, l.height);
    } else {
      rows.add([l]);
      rowY = y;
      rowHeight = l.height;
    }
  }
  return [
    for (final row in rows)
      [
        for (final l in row..sort((a, b) => a.x1.compareTo(b.x1)))
          l.text.trim(),
      ],
  ];
}

/// What a label states for one basis (a serving, or 100 g). Null = not found.
class LabelNutrients {
  const LabelNutrients({
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.fiber,
    this.sugar,
    this.sodiumMg,
  });

  final double? calories;
  final double? protein;
  final double? carbs;
  final double? fat;
  final double? fiber;
  final double? sugar;
  final double? sodiumMg;

  /// How many of the four main values (energy, protein, carbs, fat) were read.
  int get mainFound =>
      [calories, protein, carbs, fat].where((v) => v != null).length;

  bool get isEmpty =>
      mainFound == 0 && fiber == null && sugar == null && sodiumMg == null;

  @override
  String toString() =>
      'LabelNutrients(calories: $calories, protein: $protein, carbs: $carbs, '
      'fat: $fat, fiber: $fiber, sugar: $sugar, sodiumMg: $sodiumMg)';
}

/// Everything read from one label.
class LabelScan {
  const LabelScan({this.perServing, this.servingWeightG, this.per100});

  /// The "per serving" column, or null when the label has none.
  final LabelNutrients? perServing;

  /// Grams (or ml) in one serving, when the label says.
  final double? servingWeightG;

  /// The "per 100 g" column, or null when the label has none.
  final LabelNutrients? per100;

  bool get isEmpty =>
      (perServing?.isEmpty ?? true) && (per100?.isEmpty ?? true);
}

/// What to put in the food form after a scan.
class LabelFill {
  const LabelFill({
    required this.nutrients,
    required this.servingWeightG,
    required this.per100,
  });

  /// Values for one serving of [servingWeightG]. Null fields were not found
  /// and are left for the user.
  final LabelNutrients nutrients;

  /// Null when the label gave per-serving values with no serving weight.
  final double? servingWeightG;

  /// Whether the values are the label's "per 100 g" column.
  final bool per100;

  /// Names of the main values the label did not give, for the notice.
  List<String> get missing => [
    if (nutrients.calories == null) 'calories',
    if (nutrients.protein == null) 'protein',
    if (nutrients.carbs == null) 'carbs',
    if (nutrients.fat == null) 'fat',
    if (servingWeightG == null) 'serving weight',
  ];
}

/// The values to fill the form with, or null when the label gave none. A
/// serving with a known weight is preferred; otherwise per 100 g; otherwise a
/// serving whose weight the user must enter.
LabelFill? labelFill(LabelScan scan) {
  final serving = scan.perServing;
  final per100 = scan.per100;
  final hasServing = serving != null && !serving.isEmpty;
  final has100 = per100 != null && !per100.isEmpty;
  if (hasServing &&
      (scan.servingWeightG != null || !has100) &&
      (!has100 || serving.mainFound >= per100.mainFound)) {
    return LabelFill(
      nutrients: serving,
      servingWeightG: scan.servingWeightG,
      per100: false,
    );
  }
  if (has100) {
    return LabelFill(nutrients: per100, servingWeightG: 100, per100: true);
  }
  return null;
}

/// Kilojoules in one kilocalorie.
const kjPerKcal = 4.184;

/// Grams of salt (NaCl) per gram of sodium.
const _saltPerSodium = 2.5;

enum _Nutrient { energy, fat, carbs, sugar, fiber, protein, sodium, salt }

/// Rows about a part of a nutrient the app does not track. Checked first, so
/// "Saturated Fat" is not read as fat.
const _ignored = [
  'saturat',
  'trans',
  'added',
  'polyun',
  'monoun',
  'cholest',
  'from fat',
  'gesättigt',
  'gesattigt',
  'saturé',
  'satures',
  'saturi',
  'saturad',
  'polyol',
  'starch',
  'stärke',
];

/// Words that name each nutrient on English, German, French, Spanish and
/// Italian labels. Sugar comes before carbs, so "of which sugars" under
/// "Carbohydrate" is sugar.
const _names = <_Nutrient, List<String>>{
  _Nutrient.energy: [
    'calories',
    'energy',
    'energie',
    'énergie',
    'energia',
    'energía',
    'brennwert',
    'valor energ',
    'kcal',
    'kj',
  ],
  _Nutrient.sugar: ['sugar', 'zucker', 'sucre', 'zuccheri', 'azúcar', 'azucar'],
  _Nutrient.carbs: [
    'carbohydrate',
    'carbs',
    'kohlenhydrat',
    'glucide',
    'carboidrati',
    'hidratos',
  ],
  _Nutrient.fiber: ['fiber', 'fibre', 'ballaststoff', 'fibra'],
  _Nutrient.protein: [
    'protein',
    'eiweiß',
    'eiweiss',
    'protéine',
    'proteín',
    'proteina',
  ],
  _Nutrient.sodium: ['sodium', 'natrium', 'sodio'],
  _Nutrient.salt: ['salt', 'salz'],
  _Nutrient.fat: [
    'fat',
    'fett',
    'matières grasses',
    'matieres grasses',
    'lipide',
    'grassi',
    'grasas',
  ],
};

final _quantity = RegExp(
  r'(\d+(?:\.\d+)?)\s*(kcal|kj|cal\b|mcg|µg|mg|g\b|ml\b|%)?',
);

/// "per 100 g", "pro 100 ml", "per 30 g serving", and so on.
final _perAmount = RegExp(
  r'\b(?:per|pro|pour|por|je)\s*(\d+(?:\.\d+)?)\s*(g|ml)\b',
);

final _perServingWord = RegExp(
  r'\b(?:per|pro|pour|por|je)\s+(?:serving|portion|porción|porzione)',
);

/// Lower case, with decimal commas as points and a letter O before a unit
/// read as zero ("Og" for "0g").
String _normalize(String text) => text
    .toLowerCase()
    .replaceAllMapped(RegExp(r'(\d),(\d)'), (m) => '${m[1]}.${m[2]}')
    .replaceAllMapped(
      RegExp(r'(^|[^a-z0-9])o\s?(g|mg)\b'),
      (m) => '${m[1]}0${m[2]}',
    );

/// Reads a label from its [rows] (see [rowsFromLines]). Every row is taken on
/// its own: its name decides the nutrient, and its amounts fill the label's
/// columns in order. Percentages (% Daily Value) are ignored.
LabelScan parseNutritionLabel(List<List<String>> rows) {
  final texts = [for (final row in rows) _normalize(row.join(' '))];

  // The columns, left to right: 100 for "per 100 g", otherwise the grams of
  // a serving, or null for a serving of unknown size.
  final columns = <double?>[];
  for (final text in texts) {
    final found = <({int at, double? grams})>[
      for (final m in _perAmount.allMatches(text))
        (at: m.start, grams: double.parse(m[1]!)),
      for (final m in _perServingWord.allMatches(text))
        (at: m.start, grams: null),
    ]..sort((a, b) => a.at.compareTo(b.at));
    if (found.isEmpty || found.every((c) => c.grams == null)) continue;
    columns.addAll([for (final c in found) c.grams]);
    break;
  }

  double? servingG;
  for (final text in texts) {
    if (!text.contains('serving size') &&
        !text.contains('serv. size') &&
        !text.contains('portion size')) {
      continue;
    }
    // "2/3 cup (55g)": the weight is the last amount in g or ml.
    for (final m in _quantity.allMatches(text)) {
      final unit = m[2]?.trim();
      if (unit == 'g' || unit == 'ml') servingG = double.parse(m[1]!);
    }
    if (servingG != null) break;
  }

  final values = <_Nutrient, List<double>>{};
  for (final text in texts) {
    if (_ignored.any(text.contains)) continue;
    // A heading or a column title, not a row of the table.
    if (text.contains('serving') && !RegExp(r'\d').hasMatch(text)) continue;
    final nutrient = _nutrientOf(text);
    if (nutrient == null || values.containsKey(nutrient)) continue;
    final amounts = nutrient == _Nutrient.energy
        ? _energyAmounts(text)
        : _amounts(text, milligrams: nutrient == _Nutrient.sodium);
    if (amounts.isNotEmpty) values[nutrient] = amounts;
  }

  LabelNutrients column(int i) {
    double? at(_Nutrient n) {
      final list = values[n];
      return list == null || i >= list.length ? null : list[i];
    }

    final salt = at(_Nutrient.salt);
    final sodium =
        at(_Nutrient.sodium) ??
        (salt == null ? null : salt / _saltPerSodium * 1000);
    return LabelNutrients(
      calories: switch (at(_Nutrient.energy)) {
        final double v => roundTo(v, 0),
        null => null,
      },
      protein: at(_Nutrient.protein),
      carbs: at(_Nutrient.carbs),
      fat: at(_Nutrient.fat),
      fiber: at(_Nutrient.fiber),
      sugar: at(_Nutrient.sugar),
      sodiumMg: sodium == null ? null : roundTo(sodium, 0),
    );
  }

  if (columns.isEmpty) {
    // No column titles: a US label, whose one column is a serving.
    return LabelScan(perServing: column(0), servingWeightG: servingG);
  }
  final at100 = columns.indexOf(100);
  final atServing = columns.indexWhere((c) => c != 100);
  return LabelScan(
    per100: at100 < 0 ? null : column(at100),
    perServing: atServing < 0 ? null : column(atServing),
    servingWeightG: atServing < 0 ? servingG : columns[atServing] ?? servingG,
  );
}

_Nutrient? _nutrientOf(String text) {
  for (final entry in _names.entries) {
    for (final word in entry.value) {
      final at = text.indexOf(word);
      if (at < 0) continue;
      // At the start of a word, so "unsalted" is not salt.
      if (at == 0 || !RegExp(r'[a-zà-ÿ]').hasMatch(text[at - 1])) {
        return entry.key;
      }
    }
  }
  return null;
}

/// The amounts in grams on a row, in order (milligrams when [milligrams]).
/// Percentages and micrograms are skipped.
List<double> _amounts(String text, {required bool milligrams}) => [
  for (final m in _quantity.allMatches(text))
    if (m[2]?.trim() case final unit?)
      if (unit == 'g')
        double.parse(m[1]!) * (milligrams ? 1000 : 1)
      else if (unit == 'mg')
        double.parse(m[1]!) / (milligrams ? 1 : 1000),
];

/// The energy on a row in kcal, one per column. A column given in both units
/// uses its kcal; one given only in kJ is converted. "Calories 230" on a US
/// label has no unit at all.
List<double> _energyAmounts(String text) {
  final kcal = <double>[];
  final kj = <double>[];
  final bare = <double>[];
  for (final m in _quantity.allMatches(text)) {
    final value = double.parse(m[1]!);
    switch (m[2]?.trim()) {
      case 'kcal' || 'cal':
        kcal.add(value);
      case 'kj':
        kj.add(value);
      case null:
        bare.add(value);
    }
  }
  if (kcal.isNotEmpty) return kcal;
  if (kj.isNotEmpty) return [for (final v in kj) v / kjPerKcal];
  return bare;
}
