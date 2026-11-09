import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/metrics.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/core/top_foods.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/catalog_repository.dart';
import 'package:nutriton_project/data/repositories/log_repository.dart';

Macros kcal(double c, {double protein = 0}) =>
    Macros(calories: c, protein: protein, carbs: 0, fat: 0);

SourceTotal source(String name, int count, double c, {double protein = 0}) =>
    SourceTotal(
      key: name,
      name: name,
      kind: SourceKind.oneOff,
      count: count,
      totals: kcal(c, protein: protein),
    );

void main() {
  group('ranking', () {
    final all = [
      source('Rice', 6, 1200),
      source('Pizza', 2, 1800),
      source('Coffee', 9, 0),
      source('Eggs', 6, 900, protein: 75),
    ];

    test('by amount leaves out sources with none', () {
      expect(
        [for (final s in topByAmount(all, Metric.calories)) s.name],
        ['Pizza', 'Rice', 'Eggs'],
      );
      expect(
        [for (final s in topByAmount(all, Metric.protein)) s.name],
        ['Eggs'],
      );
    });

    test('by count breaks ties on the amount', () {
      expect(
        [for (final s in topByCount(all, Metric.calories)) s.name],
        ['Coffee', 'Rice', 'Eggs', 'Pizza'],
      );
    });

    test('share of the total', () {
      expect(shareOf(all[1], all, Metric.calories), 46); // 1800 / 3900
      expect(shareOf(all[0], [source('x', 1, 0)], Metric.calories), 0);
    });
  });

  test('the query groups by food, by meal and by one-off name', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final catalog = CatalogRepository(db);
    final log = LogRepository(db);
    final rice = (await catalog.findFood(
      await catalog.createFood(
        name: 'Rice',
        perServing: kcal(200),
        servingWeightG: 100,
      ),
    ))!;
    await log.logFood(logDate: '2026-11-01', food: rice, servings: 1);
    await log.logFood(logDate: '2026-11-02', food: rice, servings: 2);
    await log.logAdhoc(logDate: '2026-11-02', name: 'Latte', macros: kcal(150));
    await log.logAdhoc(
      logDate: '2026-11-03',
      name: 'latte ',
      macros: kcal(150),
    );
    // Outside the range.
    await log.logFood(logDate: '2026-10-01', food: rice, servings: 5);

    final totals = await db.summaryDao
        .watchSourceTotals('2026-11-01', '2026-11-07')
        .first;
    final byName = {for (final s in totals) s.name.trim().toLowerCase(): s};
    expect(byName.keys, unorderedEquals(['rice', 'latte']));
    expect(byName['rice']!.kind, SourceKind.food);
    expect(byName['rice']!.count, 2);
    expect(byName['rice']!.totals.calories, 600);
    expect(byName['latte']!.kind, SourceKind.oneOff);
    expect(byName['latte']!.count, 2);
  });
}
