import 'package:drift/drift.dart';

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
      ),
      daysLogged: daysLogged,
    );
  }

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
        ),
      ),
  ];
}

const _averagesSql = '''
SELECT
  AVG(day_cal)  AS avg_cal,
  AVG(day_pro)  AS avg_pro,
  AVG(day_carb) AS avg_carb,
  AVG(day_fat)  AS avg_fat,
  COUNT(*)      AS days_logged
FROM (
  SELECT log_date,
         SUM(calories) AS day_cal,
         SUM(protein)  AS day_pro,
         SUM(carbs)    AS day_carb,
         SUM(fat)      AS day_fat
  FROM food_log_entries
  WHERE log_date BETWEEN ? AND ?
  GROUP BY log_date
)
''';

const _dailyTotalsSql = '''
SELECT log_date,
       SUM(calories) AS cal,
       SUM(protein)  AS pro,
       SUM(carbs)    AS carb,
       SUM(fat)      AS fat
FROM food_log_entries
WHERE log_date BETWEEN ? AND ?
GROUP BY log_date
ORDER BY log_date
''';
