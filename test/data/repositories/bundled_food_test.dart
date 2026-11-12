import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/bundled_foods.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/catalog_repository.dart';

void main() {
  late AppDatabase db;
  late CatalogRepository catalog;

  const banana = BundledFood(
    name: 'Bananas, raw',
    per100g: Macros(
      calories: 89,
      protein: 1.1,
      carbs: 22.8,
      fat: 0.3,
      fiber: 2.6,
      sugar: 12.2,
      sodium: 1,
    ),
    portions: [
      (name: 'cup, mashed', weightG: 225),
      (name: 'small', weightG: 101),
    ],
  );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    catalog = CatalogRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'the first use copies the food in, per 100 g, with its portions',
    () async {
      final food = await catalog.adoptBundledFood(banana);

      expect(food.name, 'Bananas, raw');
      expect(food.servingWeightG, 100);
      expect(food.calories, 89);
      expect(food.fiber, 2.6);
      expect(food.sodium, 1);
      expect(food.brand, isNull);
      final portions = await catalog.watchServings(food.id).first;
      expect(
        {for (final p in portions) p.name: p.weightG},
        {'small': 101.0, 'cup, mashed': 225.0},
      );
    },
  );

  test('a second use returns the same food, keeping edits', () async {
    final first = await catalog.adoptBundledFood(banana);
    await catalog.updateFood(
      first.id,
      name: 'bananas, RAW',
      perServing: const Macros(calories: 95),
      servingWeightG: 100,
    );

    final second = await catalog.adoptBundledFood(banana);

    expect(second.id, first.id);
    expect(second.calories, 95);
    expect(await db.select(db.foodItems).get(), hasLength(1));
    expect(await db.select(db.foodServings).get(), hasLength(2));
  });

  test('an archived or branded food of that name is not reused', () async {
    final first = await catalog.adoptBundledFood(banana);
    await catalog.setFoodArchived(first.id, archived: true);
    await catalog.createFood(
      name: 'Bananas, raw',
      perServing: const Macros(calories: 100),
      servingWeightG: 120,
      brand: 'Acme',
    );

    final second = await catalog.adoptBundledFood(banana);

    expect(second.id, isNot(first.id));
    expect(second.brand, isNull);
    expect(await db.select(db.foodItems).get(), hasLength(3));
  });

  test('an over-long name or portion name is trimmed to fit', () async {
    final food = await catalog.adoptBundledFood(
      BundledFood(
        name: 'N' * 150,
        per100g: const Macros(calories: 10),
        portions: [(name: 'p' * 60, weightG: 10)],
      ),
    );
    expect(food.name.length, 100);
    expect((await catalog.watchServings(food.id).first).single.name.length, 40);
  });
}
