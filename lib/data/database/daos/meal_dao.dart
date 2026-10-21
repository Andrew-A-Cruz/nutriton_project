import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/food_items.dart';
import '../tables/meal_food_items.dart';
import '../tables/meals.dart';

part 'meal_dao.g.dart';

/// One line of a meal template: the link row plus the food it points at.
class MealItemRow {
  const MealItemRow({required this.link, required this.food});

  final MealFoodItem link;
  final FoodItem food;
}

@DriftAccessor(tables: [Meals, MealFoodItems, FoodItems])
class MealDao extends DatabaseAccessor<AppDatabase> with _$MealDaoMixin {
  MealDao(super.attachedDatabase);

  Future<void> insertMeal(MealsCompanion meal) => into(meals).insert(meal);

  Future<Meal?> findById(String id) =>
      (select(meals)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> updateMeal(String id, MealsCompanion changes) =>
      (update(meals)..where((t) => t.id.equals(id))).write(changes);

  Future<int> setArchived(String id, {required bool archived}) =>
      (update(meals)..where((t) => t.id.equals(id))).write(
        MealsCompanion(archived: Value(archived)),
      );

  /// Hard delete; the template's items cascade.
  Future<int> deleteMeal(String id) =>
      (delete(meals)..where((t) => t.id.equals(id))).go();

  Stream<List<Meal>> watchActive() => _activeMealsQuery().watch();

  Future<List<Meal>> findActive() => _activeMealsQuery().get();

  SimpleSelectStatement<$MealsTable, Meal> _activeMealsQuery() {
    return select(meals)
      ..where((t) => t.archived.equals(false))
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
  }

  Future<void> insertItems(List<MealFoodItemsCompanion> items) =>
      batch((b) => b.insertAll(mealFoodItems, items));

  Future<int> deleteItems(String mealId) =>
      (delete(mealFoodItems)..where((t) => t.mealId.equals(mealId))).go();

  Future<List<MealItemRow>> findItems(String mealId) =>
      _itemsQuery(mealId).get();

  Stream<List<MealItemRow>> watchItems(String mealId) =>
      _itemsQuery(mealId).watch();

  Selectable<MealItemRow> _itemsQuery(String mealId) {
    final query =
        select(mealFoodItems).join([
            innerJoin(
              foodItems,
              foodItems.id.equalsExp(mealFoodItems.foodItemId),
            ),
          ])
          ..where(mealFoodItems.mealId.equals(mealId))
          ..orderBy([OrderingTerm.asc(mealFoodItems.sortOrder)]);

    return query.map(
      (row) => MealItemRow(
        link: row.readTable(mealFoodItems),
        food: row.readTable(foodItems),
      ),
    );
  }
}
