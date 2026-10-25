import 'package:drift/drift.dart';

import '../../../core/metrics.dart';
import '../../../core/nutrition_math.dart';
import '../../../core/summary_math.dart';
import '../app_database.dart';
import '../tables/food_log_entries.dart';

part 'summary_dao.g.dart';

/// Averages over the days in a range that have at least one entry. Days with
/// nothing logged are skipped, so they do not drag the averages down.
class RangeAverages {
  const RangeAverages({required this.averages, required this.daysLogged});

  /// Null when no day in the range has any entries.
  final Macros? averages;
  final int daysLogged;
}

@DriftAccessor(tables: [FoodLogEntries])
class SummaryDao extends DatabaseAccessor<AppDatabase> with _$SummaryDaoMixin {
  SummaryDao(super.attachedDatabase);

  /// [start] and [end] are inclusive 'yyyy-MM-dd' keys.
  Future<RangeAverages> averagesForRange(String start, String end) async {
    final row = await customSelect(
      _averagesSql,
      variables: [Variable.withString(start), Variable.withString(end)],
      readsFrom: {foodLogEntries},
    ).getSingle();

    final daysLogged = row.read<int>('days_logged');
    if (daysLogged == 0) {
      return const RangeAverages(averages: null, daysLogged: 0);
    }
    return RangeAverages(
      averages: Macros(
        calories: row.read<double>('avg_cal'),
        protein: row.read<double>('avg_pro'),
        carbs: row.read<double>('avg_carb'),
        fat: row.read<double>('avg_fat'),
        fiber: row.read<double?>('avg_fiber'),
        sugar: row.read<double?>('avg_sugar'),
        sodium: row.read<double?>('avg_sodium'),
      ),
      daysLogged: daysLogged,
    );
  }

  /// Every day up to [endKey] (inclusive, 'yyyy-MM-dd') that has at least
  /// one entry, newest first, re-emitting whenever the log changes. Input for
  /// the streak.
  Stream<List<String>> watchLoggedDatesUpTo(String endKey) => customSelect(
    'SELECT DISTINCT log_date FROM food_log_entries '
    'WHERE log_date <= ? ORDER BY log_date DESC',
    variables: [Variable.withString(endKey)],
    readsFrom: {foodLogEntries},
  ).watch().map((rows) => [for (final r in rows) r.read<String>('log_date')]);

  /// One row per day that has entries, oldest first.
  Future<List<DayTotal>> dailyTotalsForRange(String start, String end) async {
    final rows = await _dailyTotalsQuery(start, end).get();
    return _toDayTotals(rows);
  }

  /// As [dailyTotalsForRange], re-emitting whenever the log changes.
  Stream<List<DayTotal>> watchDailyTotalsForRange(String start, String end) =>
      _dailyTotalsQuery(start, end).watch().map(_toDayTotals);

  Selectable<QueryRow> _dailyTotalsQuery(String start, String end) =>
      customSelect(
        _dailyTotalsSql,
        variables: [Variable.withString(start), Variable.withString(end)],
        readsFrom: {foodLogEntries},
      );

  static List<DayTotal> _toDayTotals(List<QueryRow> rows) => [
    for (final row in rows)
      DayTotal(
        logDate: row.read<String>('log_date'),
        totals: Macros(
          calories: row.read<double>('cal'),
          protein: row.read<double>('pro'),
          carbs: row.read<double>('carb'),
          fat: row.read<double>('fat'),
          fiber: row.read<double?>('fiber'),
          sugar: row.read<double?>('sugar'),
          sodium: row.read<double?>('sodium'),
        ),
        coverage: {
          Metric.fiber: Coverage(
            recorded: row.read<int>('fiber_entries'),
            total: row.read<int>('entries'),
          ),
          Metric.sugar: Coverage(
            recorded: row.read<int>('sugar_entries'),
            total: row.read<int>('entries'),
          ),
          Metric.sodium: Coverage(
            recorded: row.read<int>('sodium_entries'),
            total: row.read<int>('entries'),
          ),
        },
      ),
  ];
}

// The optional nutrients (fiber, sugar, sodium) sum to NULL for a day where no
// entry recorded them, and the average is NULL only when no day did. A day with
// some recorded entries counts the others as 0.
const _averagesSql = '''
SELECT
  AVG(day_cal)  AS avg_cal,
  AVG(day_pro)  AS avg_pro,
  AVG(day_carb) AS avg_carb,
  AVG(day_fat)  AS avg_fat,
  CASE WHEN COUNT(day_fiber) = 0 THEN NULL
       ELSE SUM(COALESCE(day_fiber, 0)) * 1.0 / COUNT(*) END AS avg_fiber,
  CASE WHEN COUNT(day_sugar) = 0 THEN NULL
       ELSE SUM(COALESCE(day_sugar, 0)) * 1.0 / COUNT(*) END AS avg_sugar,
  CASE WHEN COUNT(day_sodium) = 0 THEN NULL
       ELSE SUM(COALESCE(day_sodium, 0)) * 1.0 / COUNT(*) END AS avg_sodium,
  COUNT(*)      AS days_logged
FROM (
  SELECT log_date,
         SUM(calories) AS day_cal,
         SUM(protein)  AS day_pro,
         SUM(carbs)    AS day_carb,
         SUM(fat)      AS day_fat,
         SUM(fiber)    AS day_fiber,
         SUM(sugar)    AS day_sugar,
         SUM(sodium)   AS day_sodium
  FROM food_log_entries
  WHERE log_date BETWEEN ? AND ?
  GROUP BY log_date
)
''';

// COUNT(column) counts the entries that recorded a value, for the coverage
// hint ("sodium recorded for 3 of 5 entries").
const _dailyTotalsSql = '''
SELECT log_date,
       SUM(calories) AS cal,
       SUM(protein)  AS pro,
       SUM(carbs)    AS carb,
       SUM(fat)      AS fat,
       SUM(fiber)    AS fiber,
       SUM(sugar)    AS sugar,
       SUM(sodium)   AS sodium,
       COUNT(*)      AS entries,
       COUNT(fiber)  AS fiber_entries,
       COUNT(sugar)  AS sugar_entries,
       COUNT(sodium) AS sodium_entries
FROM food_log_entries
WHERE log_date BETWEEN ? AND ?
GROUP BY log_date
ORDER BY log_date
''';
