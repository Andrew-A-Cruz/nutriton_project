/// Foods bundled with the app (the starter generic foods from USDA
/// FoodData Central; later, restaurant menus): reading the bundled file and
/// searching it. Pure Dart.
library;

import 'nutrition_math.dart';
import 'search.dart';

/// A named portion of a bundled food, e.g. "cup" = 158 g.
typedef BundledPortion = ({String name, double weightG});

/// One bundled food. It is not in the catalog until the user picks it.
class BundledFood {
  const BundledFood({
    required this.name,
    required this.per100g,
    this.portions = const [],
  });

  final String name;

  /// Values for 100 g. Fiber, sugar and sodium are null when not recorded.
  final Macros per100g;
  final List<BundledPortion> portions;
}

/// Reads the bundled file: one food per line, tab separated, as
/// `name, kcal, protein, carbs, fat, fiber, sugar, sodium mg, portions`, with
/// values per 100 g and portions as `name=grams` pairs joined by `;`. Lines
/// starting with `#` are comments. A line that is malformed, has a negative
/// value or has no energy figure is skipped, as is a malformed portion.
List<BundledFood> parseBundledFoods(String source) {
  final foods = <BundledFood>[];
  for (final line in source.split('\n')) {
    if (line.isEmpty || line.startsWith('#')) continue;
    final cells = line.split('\t');
    if (cells.length < 8) continue;
    final name = cells[0].trim();
    double? required(int i) => _nonNegative(cells[i]);
    final calories = required(1);
    final protein = required(2);
    final carbs = required(3);
    final fat = required(4);
    if (name.isEmpty ||
        calories == null ||
        protein == null ||
        carbs == null ||
        fat == null) {
      continue;
    }
    // Empty means not recorded; anything else must be a valid number.
    final optional = [
      for (var i = 5; i < 8; i++)
        cells[i].trim().isEmpty ? null : _nonNegative(cells[i]) ?? -1,
    ];
    if (optional.contains(-1)) continue;
    foods.add(
      BundledFood(
        name: name,
        per100g: Macros(
          calories: calories,
          protein: protein,
          carbs: carbs,
          fat: fat,
          fiber: optional[0],
          sugar: optional[1],
          sodium: optional[2],
        ),
        portions: cells.length > 8 ? _portions(cells[8]) : const [],
      ),
    );
  }
  return foods;
}

double? _nonNegative(String text) {
  final v = double.tryParse(text.trim());
  return v == null || !v.isFinite || v < 0 ? null : v;
}

List<BundledPortion> _portions(String cell) => [
  for (final part in cell.split(';'))
    if (part.split('=') case [final name, final grams])
      if (double.tryParse(grams.trim()) case final g?
          when g > 0 && g.isFinite && name.trim().isNotEmpty)
        (name: name.trim(), weightG: g),
];

/// The foods in [all] whose name has every word of [query] (see
/// [searchWords]), best first, at most [limit]. A name that starts with the
/// first word comes before one that has it later, and shorter names (the
/// plainer foods) come first within each. [exclude] holds lower-case names to
/// leave out, such as foods already in the catalog. An empty query matches
/// nothing.
List<BundledFood> searchBundledFoods(
  List<BundledFood> all,
  String query, {
  int limit = 25,
  Set<String> exclude = const {},
}) {
  final words = searchWords(query);
  if (words.isEmpty) return const [];
  final matches = <({BundledFood food, int rank})>[];
  for (final food in all) {
    final name = food.name.toLowerCase();
    if (exclude.contains(name) || !words.every(name.contains)) continue;
    matches.add((food: food, rank: name.startsWith(words.first) ? 0 : 1));
  }
  matches.sort((a, b) {
    final byRank = a.rank.compareTo(b.rank);
    if (byRank != 0) return byRank;
    final byLength = a.food.name.length.compareTo(b.food.name.length);
    return byLength != 0 ? byLength : a.food.name.compareTo(b.food.name);
  });
  return [for (final m in matches.take(limit)) m.food];
}
