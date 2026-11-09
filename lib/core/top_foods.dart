/// Top foods for a Summary range: which foods, meals and one-offs gave the
/// most of a metric, and which were logged most often. Pure Dart.
library;

import 'metrics.dart';
import 'nutrition_math.dart';

/// What a group of entries was logged from.
enum SourceKind { food, meal, oneOff }

/// One food, meal or one-off name with its entries' totals in a range.
class SourceTotal {
  const SourceTotal({
    required this.key,
    required this.name,
    required this.kind,
    required this.count,
    required this.totals,
  });

  /// Stable identity: the food or meal id, or the one-off's lowercased name.
  final String key;

  /// The name on its latest entry.
  final String name;
  final SourceKind kind;

  /// Entries in the range.
  final int count;
  final Macros totals;
}

/// How many rows each list shows.
const topFoodsShown = 5;

/// The sources with the most [metric], largest first, leaving out those with
/// none. Ties go to the more often logged, then by name.
List<SourceTotal> topByAmount(Iterable<SourceTotal> sources, Metric metric) =>
    [
      for (final s in sources)
        if (metric.amountIn(s.totals) > 0) s,
    ]..sort((a, b) {
      final byAmount = metric
          .amountIn(b.totals)
          .compareTo(metric.amountIn(a.totals));
      if (byAmount != 0) return byAmount;
      final byCount = b.count.compareTo(a.count);
      return byCount != 0 ? byCount : a.name.compareTo(b.name);
    });

/// The sources logged most often, most first. Ties go to the larger
/// [metric] total, then by name.
List<SourceTotal> topByCount(Iterable<SourceTotal> sources, Metric metric) =>
    [...sources]..sort((a, b) {
      final byCount = b.count.compareTo(a.count);
      if (byCount != 0) return byCount;
      final byAmount = metric
          .amountIn(b.totals)
          .compareTo(metric.amountIn(a.totals));
      return byAmount != 0 ? byAmount : a.name.compareTo(b.name);
    });

/// [source]'s whole-percent share of [metric] across [all].
int shareOf(SourceTotal source, Iterable<SourceTotal> all, Metric metric) {
  final total = all.fold<double>(
    0,
    (sum, s) => sum + metric.amountIn(s.totals),
  );
  if (total <= 0) return 0;
  return (metric.amountIn(source.totals) / total * 100).round();
}
