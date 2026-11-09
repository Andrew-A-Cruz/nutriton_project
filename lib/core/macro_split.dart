/// The share of calories from protein, carbs and fat. Pure Dart.
library;

import 'metrics.dart';
import 'nutrition_math.dart';

/// Calories per gram (Atwater factors).
const double kcalPerGramProtein = 4;
const double kcalPerGramCarbs = 4;
const double kcalPerGramFat = 9;

/// Whole percentages of calories from each macro. They always add up to 100.
typedef MacroSplit = ({int protein, int carbs, int fat});

/// The split of [macros] by the calories each macro supplies, or null when
/// there are no protein, carbs or fat (e.g. only a calories-only quick add).
/// It uses the grams, not the logged calories, so alcohol and rounding on
/// labels do not skew it.
MacroSplit? macroSplit(Macros macros) {
  final kcal = [
    macros.protein * kcalPerGramProtein,
    macros.carbs * kcalPerGramCarbs,
    macros.fat * kcalPerGramFat,
  ];
  final total = kcal.fold<double>(0, (a, b) => a + b);
  if (total <= 0) return null;
  final shares = roundToHundred([for (final k in kcal) k / total * 100]);
  return (protein: shares[0], carbs: shares[1], fat: shares[2]);
}

/// Rounds [percents] (which add up to 100) to whole numbers that still add up
/// to 100: round down, then give the leftover points to the largest
/// remainders (ties to the earlier item).
List<int> roundToHundred(List<double> percents) {
  final floors = [for (final p in percents) p.floor()];
  var left = 100 - floors.fold<int>(0, (a, b) => a + b);
  final order = List.generate(percents.length, (i) => i)
    ..sort((a, b) {
      final byRemainder = (percents[b] - floors[b]).compareTo(
        percents[a] - floors[a],
      );
      // Ties go to the earlier item, so the result never varies.
      return byRemainder != 0 ? byRemainder : a.compareTo(b);
    });
  for (final i in order) {
    if (left <= 0) break;
    floors[i]++;
    left--;
  }
  return floors;
}

/// "Protein 30%, carbs 45%, fat 25% of calories", for VoiceOver and as the
/// chart's caption.
String macroSplitText(MacroSplit split) =>
    'Protein ${split.protein}%, carbs ${split.carbs}%, fat ${split.fat}% '
    'of calories';

/// Calories per gram of [metric]: protein, carbs or fat.
double kcalPerGram(Metric metric) => switch (metric) {
  Metric.protein => kcalPerGramProtein,
  Metric.carbs => kcalPerGramCarbs,
  Metric.fat => kcalPerGramFat,
  _ => throw ArgumentError.value(metric, 'metric', 'not a macro'),
};

/// The three macros a [MacroSplit] covers, in its order.
const macroMetrics = [Metric.protein, Metric.carbs, Metric.fat];

/// [split]'s percentage for [metric].
int percentOf(MacroSplit split, Metric metric) => switch (metric) {
  Metric.protein => split.protein,
  Metric.carbs => split.carbs,
  Metric.fat => split.fat,
  _ => throw ArgumentError.value(metric, 'metric', 'not a macro'),
};

/// Gram goals for protein, carbs and fat from a [calories] goal and the
/// percentages in [split], to one decimal place. 30% of 2000 kcal as
/// protein is 150 g.
Map<Metric, double> macroGoalsFromPercents(double calories, MacroSplit split) =>
    {
      for (final m in macroMetrics)
        m: roundTo(calories * percentOf(split, m) / 100 / kcalPerGram(m), 1),
    };

/// A split whose parts are 0 to 100 and add up to exactly 100, or null.
MacroSplit? validMacroSplit(int protein, int carbs, int fat) {
  final parts = [protein, carbs, fat];
  if (parts.any((p) => p < 0 || p > 100)) return null;
  if (protein + carbs + fat != 100) return null;
  return (protein: protein, carbs: carbs, fat: fat);
}
