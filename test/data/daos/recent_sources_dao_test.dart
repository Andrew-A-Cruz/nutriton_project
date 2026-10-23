import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/catalog_repository.dart';

void main() {
  late AppDatabase db;
  late CatalogRepository catalog;
  var seq = 0;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    catalog = CatalogRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  const macros = Macros(calories: 100, protein: 10, carbs: 10, fat: 1);

  Future<FoodItem> food(String name) async {
    final id = await catalog.createFood(
      name: name,
      perServing: macros,
      servingWeightG: 100,
    );
    return (await catalog.findFood(id))!;
  }

  Future<Meal> meal(String name, FoodItem ingredient) async {
    final id = await catalog.createMeal(
      name: name,
      items: [MealItemInput(foodItemId: ingredient.id, weightG: 100)],
    );
    return (await catalog.findMeal(id))!;
  }

  Future<void> logFoodAt(
    FoodItem f,
    DateTime at, {
    String date = '2026-10-20',
    double servings = 1,
  }) => db.logDao.insertEntry(
    FoodLogEntriesCompanion.insert(
      id: 'e${seq++}',
      logDate: date,
      createdAt: at,
      entryType: 'food',
      name: f.name,
      calories: 1,
      protein: 1,
      carbs: 1,
      fat: 1,
      foodItemId: Value(f.id),
      servings: Value(servings),
    ),
  );

  Future<void> logMealAt(Meal m, DateTime at, {String date = '2026-10-20'}) =>
      db.logDao.insertEntry(
        FoodLogEntriesCompanion.insert(
          id: 'e${seq++}',
          logDate: date,
          createdAt: at,
          entryType: 'meal',
          name: m.name,
          calories: 1,
          protein: 1,
          carbs: 1,
          fat: 1,
          mealId: Value(m.id),
        ),
      );

  Future<List<String>> recent({int limit = 8}) async => [
    for (final s in await db.logDao.watchRecentSources(limit: limit).first)
      s.name,
  ];

  Future<List<String>> frequent(String since, {int limit = 8}) async => [
    for (final s
        in await db.logDao
            .watchFrequentSources(sinceDate: since, limit: limit)
            .first)
      s.name,
  ];

  group('watchRecentSources', () {
    test('is empty before anything is logged', () async {
      await food('Apple');
      expect(await recent(), isEmpty);
    });

    test('lists foods and meals once each, newest first', () async {
      final a = await food('Apple');
      final b = await food('Bread');
      final c = await food('Cheese');
      final stew = await meal('Stew', a);
      await logFoodAt(a, DateTime(2026, 10, 1));
      await logFoodAt(b, DateTime(2026, 10, 3));
      await logFoodAt(a, DateTime(2026, 10, 5));
      await logMealAt(stew, DateTime(2026, 10, 4));
      await logFoodAt(c, DateTime(2026, 10, 2));

      expect(await recent(), ['Apple', 'Stew', 'Bread', 'Cheese']);
    });

    test('tells foods from meals', () async {
      final a = await food('Apple');
      final stew = await meal('Stew', a);
      await logFoodAt(a, DateTime(2026, 10, 1));
      await logMealAt(stew, DateTime(2026, 10, 2));

      final sources = await db.logDao.watchRecentSources().first;
      expect(sources[0].meal?.id, stew.id);
      expect(sources[0].food, isNull);
      expect(sources[1].food?.id, a.id);
      expect(sources[1].meal, isNull);
    });

    test('entries logged in the same second keep their order', () async {
      final a = await food('Apple');
      final b = await food('Bread');
      final at = DateTime(2026, 10, 1, 12);
      await logFoodAt(a, at);
      await logFoodAt(b, at);
      expect(await recent(), ['Bread', 'Apple']);
    });

    test('skips archived foods and meals, and one-off entries', () async {
      final a = await food('Apple');
      final gone = await food('Dates');
      final stew = await meal('Stew', a);
      final oldMeal = await meal('Old meal', a);
      await logFoodAt(a, DateTime(2026, 10, 1));
      await logFoodAt(gone, DateTime(2026, 10, 9));
      await logMealAt(stew, DateTime(2026, 10, 2));
      await logMealAt(oldMeal, DateTime(2026, 10, 8));
      await db.logDao.insertEntry(
        FoodLogEntriesCompanion.insert(
          id: 'adhoc',
          logDate: '2026-10-20',
          createdAt: DateTime(2026, 10, 10),
          entryType: 'adhoc',
          name: 'Cake',
          calories: 1,
          protein: 1,
          carbs: 1,
          fat: 1,
        ),
      );
      await catalog.setFoodArchived(gone.id, archived: true);
      await catalog.setMealArchived(oldMeal.id, archived: true);

      expect(await recent(), ['Stew', 'Apple']);
    });

    test('a source disappears when its entries are deleted', () async {
      final a = await food('Apple');
      await logFoodAt(a, DateTime(2026, 10, 1));
      final entries = await db.logDao.findEntriesForDate('2026-10-20');
      await db.logDao.deleteEntry(entries.single.id);
      expect(await recent(), isEmpty);
    });

    test('respects the limit', () async {
      for (final n in ['Aa', 'Bb', 'Cc']) {
        await logFoodAt(await food(n), DateTime(2026, 10, 1));
      }
      expect(await recent(limit: 2), hasLength(2));
    });

    test('re-emits when something new is logged or archived', () async {
      final a = await food('Apple');
      final b = await food('Bread');
      await logFoodAt(a, DateTime(2026, 10, 1));
      final seen = <List<String>>[];
      final sub = db.logDao.watchRecentSources().listen(
        (s) => seen.add([for (final x in s) x.name]),
      );
      await pumpEventQueue();
      await logFoodAt(b, DateTime(2026, 10, 2));
      await pumpEventQueue();
      await catalog.setFoodArchived(a.id, archived: true);
      await pumpEventQueue();
      await sub.cancel();

      expect(seen.first, ['Apple']);
      expect([for (final s in seen) s.join(',')], contains('Bread,Apple'));
      expect(seen.last, ['Bread']);
    });
  });

  group('watchFrequentSources', () {
    test('ranks by how often a source was logged, foods and meals', () async {
      final a = await food('Apple');
      final b = await food('Bread');
      final stew = await meal('Stew', a);
      for (var d = 1; d <= 3; d++) {
        await logFoodAt(b, DateTime(2026, 10, d), date: '2026-10-0$d');
      }
      await logFoodAt(a, DateTime(2026, 10, 4), date: '2026-10-04');
      for (var d = 5; d <= 6; d++) {
        await logMealAt(stew, DateTime(2026, 10, d), date: '2026-10-0$d');
      }

      expect(await frequent('2026-10-01'), ['Bread', 'Stew', 'Apple']);
    });

    test('ties go to the more recently logged source', () async {
      final a = await food('Apple');
      final b = await food('Bread');
      await logFoodAt(a, DateTime(2026, 10, 2), date: '2026-10-02');
      await logFoodAt(b, DateTime(2026, 10, 3), date: '2026-10-03');
      expect(await frequent('2026-10-01'), ['Bread', 'Apple']);
    });

    test('only counts entries on or after the start date', () async {
      final a = await food('Apple');
      final b = await food('Bread');
      // Apple: three old entries and one in the window.
      for (var d = 1; d <= 3; d++) {
        await logFoodAt(a, DateTime(2026, 9, d), date: '2026-09-0$d');
      }
      await logFoodAt(a, DateTime(2026, 10, 1), date: '2026-10-01');
      // Bread: two in the window, the first exactly on the boundary.
      await logFoodAt(b, DateTime(2026, 10, 1), date: '2026-10-01');
      await logFoodAt(b, DateTime(2026, 10, 2), date: '2026-10-02');

      expect(await frequent('2026-10-01'), ['Bread', 'Apple']);
      // One day later the boundary entries drop out.
      expect(await frequent('2026-10-02'), ['Bread']);
    });

    test(
      'leaves out archived sources and sources outside the window',
      () async {
        final a = await food('Apple');
        final b = await food('Bread');
        await logFoodAt(a, DateTime(2026, 9, 1), date: '2026-09-01');
        await logFoodAt(b, DateTime(2026, 10, 2), date: '2026-10-02');
        await catalog.setFoodArchived(b.id, archived: true);

        expect(await frequent('2026-10-01'), isEmpty);
        expect(await recent(), ['Apple']);
      },
    );

    test('respects the limit', () async {
      for (final n in ['Aa', 'Bb', 'Cc']) {
        await logFoodAt(
          await food(n),
          DateTime(2026, 10, 2),
          date: '2026-10-02',
        );
      }
      expect(await frequent('2026-10-01', limit: 2), hasLength(2));
    });
  });

  group('findLastServings', () {
    test('is null for a food that was never logged', () async {
      final a = await food('Apple');
      expect(await db.logDao.findLastServings(a.id), isNull);
    });

    test('returns the servings of the most recent entry', () async {
      final a = await food('Apple');
      await logFoodAt(a, DateTime(2026, 10, 1), servings: 2);
      await logFoodAt(a, DateTime(2026, 10, 5), servings: 1.5);
      await logFoodAt(a, DateTime(2026, 10, 3), servings: 4);
      expect(await db.logDao.findLastServings(a.id), 1.5);
    });

    test('same-second entries: the later insert wins', () async {
      final a = await food('Apple');
      final at = DateTime(2026, 10, 1, 9);
      await logFoodAt(a, at, servings: 2);
      await logFoodAt(a, at, servings: 3);
      expect(await db.logDao.findLastServings(a.id), 3);
    });

    test('ignores other foods', () async {
      final a = await food('Apple');
      final b = await food('Bread');
      await logFoodAt(a, DateTime(2026, 10, 1), servings: 2);
      await logFoodAt(b, DateTime(2026, 10, 9), servings: 7);
      expect(await db.logDao.findLastServings(a.id), 2);
    });
  });
}
