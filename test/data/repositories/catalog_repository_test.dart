import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/catalog_repository.dart';

void main() {
  late AppDatabase db;
  late CatalogRepository catalog;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    catalog = CatalogRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  const chicken = Macros(calories: 165, protein: 31, carbs: 0, fat: 3.6);
  const rice = Macros(calories: 130, protein: 2.7, carbs: 28, fat: 0.3);

  Future<String> makeChicken() => catalog.createFood(
    name: 'Chicken breast',
    perServing: chicken,
    servingWeightG: 100,
  );

  Future<String> makeRice() => catalog.createFood(
    name: 'White rice',
    perServing: rice,
    servingWeightG: 100,
    displayUnit: WeightUnit.oz,
  );

  group('foods', () {
    test('createFood stores macros, serving weight and unit', () async {
      final id = await makeRice();
      final food = await catalog.findFood(id);

      expect(food!.name, 'White rice');
      expect(food.calories, 130);
      expect(food.servingWeightG, 100);
      expect(food.displayUnit, 'oz');
    });

    test('createFood rejects a zero serving weight', () {
      expect(
        () => catalog.createFood(
          name: 'Bad',
          perServing: chicken,
          servingWeightG: 0,
        ),
        throwsArgumentError,
      );
    });

    test('createFood rejects a too-short name', () {
      expect(
        () => catalog.createFood(
          name: ' a ',
          perServing: chicken,
          servingWeightG: 100,
        ),
        throwsArgumentError,
      );
    });

    test('createFood rejects a name longer than the table allows', () async {
      await expectLater(
        catalog.createFood(
          name: 'x' * 101,
          perServing: chicken,
          servingWeightG: 100,
        ),
        throwsArgumentError,
      );
    });

    test('createFood rejects non-finite macros and weights', () async {
      await expectLater(
        catalog.createFood(
          name: 'Infinite',
          perServing: const Macros(calories: double.infinity),
          servingWeightG: 100,
        ),
        throwsArgumentError,
      );
      await expectLater(
        catalog.createFood(
          name: 'Not a number',
          perServing: const Macros(protein: double.nan),
          servingWeightG: 100,
        ),
        throwsArgumentError,
      );
      await expectLater(
        catalog.createFood(
          name: 'Huge serving',
          perServing: chicken,
          servingWeightG: double.infinity,
        ),
        throwsArgumentError,
      );
      expect(await catalog.findFoods(), isEmpty);
    });

    test('createFood rejects negative macros', () {
      expect(
        () => catalog.createFood(
          name: 'Negative',
          perServing: const Macros(calories: -1),
          servingWeightG: 100,
        ),
        throwsArgumentError,
      );
    });

    test('updateFood replaces the values', () async {
      final id = await makeChicken();
      await catalog.updateFood(
        id,
        name: 'Chicken thigh',
        perServing: const Macros(
          calories: 209,
          protein: 26,
          carbs: 0,
          fat: 10.9,
        ),
        servingWeightG: 100,
      );

      final food = await catalog.findFood(id);
      expect(food!.name, 'Chicken thigh');
      expect(food.calories, 209);
    });

    test('archiving hides a food from search but keeps it', () async {
      final id = await makeChicken();
      await makeRice();

      await catalog.setFoodArchived(id, archived: true);

      final visible = await catalog.findFoods();
      expect(visible.map((f) => f.name), ['White rice']);
      expect((await catalog.findFood(id))!.archived, isTrue);
    });

    test('macrosForWeight scales by grams', () async {
      final id = await makeChicken();
      final food = (await catalog.findFood(id))!;

      final macros = CatalogRepository.macrosForWeight(food, 250);
      expect(macros.calories, closeTo(412.5, 1e-9));
    });
  });

  group('meals', () {
    test(
      'createMeal stores items in the given order with their weights',
      () async {
        final chickenId = await makeChicken();
        final riceId = await makeRice();

        final mealId = await catalog.createMeal(
          name: 'Chicken & rice',
          items: [
            MealItemInput(foodItemId: chickenId, weightG: 150),
            MealItemInput(foodItemId: riceId, weightG: 200),
          ],
        );

        final items = await catalog.findMealItems(mealId);
        expect(items.map((i) => i.food.name), ['Chicken breast', 'White rice']);
        expect(items.map((i) => i.link.weightG), [150, 200]);
      },
    );

    test('updateMeal replaces the item list and name', () async {
      final chickenId = await makeChicken();
      final riceId = await makeRice();
      final mealId = await catalog.createMeal(
        name: 'Lunch',
        items: [MealItemInput(foodItemId: chickenId, weightG: 150)],
      );

      await catalog.updateMeal(
        mealId,
        name: 'Big lunch',
        items: [MealItemInput(foodItemId: riceId, weightG: 300)],
      );

      final meal = await catalog.findMeal(mealId);
      final items = await catalog.findMealItems(mealId);
      expect(meal!.name, 'Big lunch');
      expect(items.map((i) => i.food.id), [riceId]);
    });

    test('createMeal rejects a non-positive item weight', () async {
      final chickenId = await makeChicken();
      expect(
        () => catalog.createMeal(
          name: 'Broken',
          items: [MealItemInput(foodItemId: chickenId, weightG: 0)],
        ),
        throwsArgumentError,
      );
      expect(await catalog.findMeals(), isEmpty);
    });
  });
}
