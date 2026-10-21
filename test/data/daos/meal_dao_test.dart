import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/data/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.foodDao.insertFood(
      FoodItemsCompanion.insert(
        id: 'chicken',
        name: 'Chicken breast',
        calories: 165,
        protein: 31,
        carbs: 0,
        fat: 3.6,
        servingWeightG: 100,
      ),
    );
    await db.foodDao.insertFood(
      FoodItemsCompanion.insert(
        id: 'rice',
        name: 'White rice',
        calories: 130,
        protein: 2.7,
        carbs: 28,
        fat: 0.3,
        servingWeightG: 100,
      ),
    );
    await db.mealDao.insertMeal(
      MealsCompanion.insert(id: 'lunch', name: 'Chicken & rice'),
    );
  });

  tearDown(() async {
    await db.close();
  });

  MealFoodItemsCompanion item(String id, String foodId, double g, int order) =>
      MealFoodItemsCompanion.insert(
        id: id,
        mealId: 'lunch',
        foodItemId: foodId,
        weightG: g,
        sortOrder: Value(order),
      );

  test(
    'insertItems stores items joined to their food, in sort order',
    () async {
      await db.mealDao.insertItems([
        item('i2', 'rice', 200, 1),
        item('i1', 'chicken', 150, 0),
      ]);

      final rows = await db.mealDao.findItems('lunch');
      expect(rows.map((r) => r.food.name), ['Chicken breast', 'White rice']);
      expect(rows.map((r) => r.link.weightG), [150, 200]);
    },
  );

  test('deleteItems clears the template so it can be rewritten', () async {
    await db.mealDao.insertItems([item('i1', 'chicken', 150, 0)]);

    await db.mealDao.deleteItems('lunch');
    expect(await db.mealDao.findItems('lunch'), isEmpty);

    await db.mealDao.insertItems([item('i2', 'rice', 100, 0)]);
    expect((await db.mealDao.findItems('lunch')).single.food.id, 'rice');
  });

  test('deleting a meal cascades to its items', () async {
    await db.mealDao.insertItems([item('i1', 'chicken', 150, 0)]);

    await db.mealDao.deleteMeal('lunch');

    expect(await db.mealDao.findById('lunch'), isNull);
    expect(await db.mealDao.findItems('lunch'), isEmpty);
  });

  test('a food used in a meal cannot be hard-deleted', () async {
    await db.mealDao.insertItems([item('i1', 'chicken', 150, 0)]);

    await expectLater(
      db.foodDao.deleteFood('chicken'),
      throwsA(isA<SqliteException>()),
    );
  });

  test('archived meals are hidden from the active list', () async {
    await db.mealDao.setArchived('lunch', archived: true);

    expect(await db.mealDao.findActive(), isEmpty);
    expect((await db.mealDao.findById('lunch'))!.archived, isTrue);
  });
}
