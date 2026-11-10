/// Named portions ("1 cup = 240 g"): reading one from a label's serving text,
/// and converting a count of portions to servings. Pure Dart.
library;

/// A portion read from text such as "1 cup (240 g)": its [name] and how many
/// of it the text's grams cover.
typedef ParsedPortion = ({String name, double count});

final _servingText = RegExp(
  r'^\s*(\d+(?:[.,]\d+)?|\d+\s*/\s*\d+)?\s*([A-Za-z][A-Za-z ]{0,38}?)\s*\(',
);

/// The portion named in a serving text like "1 cup (240 g)", "2 slices
/// (56 g)" or "1/2 bar (25g)", or null when there is no name before the
/// grams (e.g. "30 g"). A plural is made singular when the count is not 1.
ParsedPortion? parsePortion(String? text) {
  if (text == null) return null;
  final m = _servingText.firstMatch(text);
  if (m == null) return null;
  var name = m.group(2)!.trim().toLowerCase();
  if (name.isEmpty || name == 'g' || name == 'ml' || name == 'oz') return null;
  final count = _count(m.group(1)) ?? 1;
  if (count <= 0) return null;
  if (count != 1 && name.endsWith('s') && !name.endsWith('ss')) {
    name = name.substring(0, name.length - 1);
  }
  return (name: name, count: count);
}

double? _count(String? raw) {
  if (raw == null) return null;
  final fraction = raw.split('/');
  if (fraction.length == 2) {
    final a = double.tryParse(fraction[0].trim());
    final b = double.tryParse(fraction[1].trim());
    return a == null || b == null || b == 0 ? null : a / b;
  }
  return double.tryParse(raw.replaceAll(',', '.'));
}

/// Servings of a food with [servingWeightG] in [count] portions of
/// [portionWeightG] grams each.
double servingsForPortions({
  required double count,
  required double portionWeightG,
  required double servingWeightG,
}) => count * portionWeightG / servingWeightG;
