import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/nutrition_math.dart';
import '../../core/validation.dart';
import '../database/app_database.dart';
import '../database/daos/meal_dao.dart';

const _uuid = Uuid();

/// A food (by catalog id) and how many grams of it a meal contains.
class MealItemInput {
  const MealItemInput({required this.foodItemId, required this.weightG});

  final String foodItemId;
  final double weightG;
}

/// Catalog foods and meal templates.
class CatalogRepository {
  CatalogRepository(this._db);

  final AppDatabase _db;

  // ---- Foods ---------------------------------------------------------------

  Stream<List<FoodItem>> watchFoods({String search = ''}) =>
      _db.foodDao.watchActive(search: search);

  Future<List<FoodItem>> findFoods({String search = ''}) =>
      _db.foodDao.findActive(search: search);

  Future<FoodItem?> findFood(String id) => _db.foodDao.findById(id);

  Future<String> createFood({
    required String name,
    required Macros perServing,
    required double servingWeightG,
    WeightUnit displayUnit = WeightUnit.g,
  }) async {
    final id = _uuid.v4();
    _validateFood(name, perServing, servingWeightG);
    await _db.foodDao.insertFood(
      FoodItemsCompanion.insert(
        id: id,
        name: name.trim(),
        calories: perServing.calories,
        protein: perServing.protein,
        carbs: perServing.carbs,
        fat: perServing.fat,
        fiber: Value(perServing.fiber),
        sugar: Value(perServing.sugar),
        sodium: Value(perServing.sodium),
        servingWeightG: servingWeightG,
        displayUnit: Value(displayUnit.name),
      ),
    );
    return id;
  }

  Future<void> updateFood(
    String id, {
    required String name,
    required Macros perServing,
    required double servingWeightG,
    WeightUnit displayUnit = WeightUnit.g,
  }) async {
    _validateFood(name, perServing, servingWeightG);
    await _db.foodDao.updateFood(
      id,
      FoodItemsCompanion(
        name: Value(name.trim()),
        calories: Value(perServing.calories),
        protein: Value(perServing.protein),
        carbs: Value(perServing.carbs),
        fat: Value(perServing.fat),
        fiber: Value(perServing.fiber),
        sugar: Value(perServing.sugar),
        sodium: Value(perServing.sodium),
        servingWeightG: Value(servingWeightG),
        displayUnit: Value(displayUnit.name),
      ),
    );
  }

  /// Archived foods leave search results but stay in past log entries.
  Future<void> setFoodArchived(String id, {required bool archived}) =>
      _db.foodDao.setArchived(id, archived: archived);

  // ---- Meals ---------------------------------------------------------------

  Stream<List<Meal>> watchMeals() => _db.mealDao.watchActive();

  Future<List<Meal>> findMeals() => _db.mealDao.findActive();

  Future<Meal?> findMeal(String id) => _db.mealDao.findById(id);

  Stream<List<MealItemRow>> watchMealItems(String mealId) =>
      _db.mealDao.watchItems(mealId);

  Future<List<MealItemRow>> findMealItems(String mealId) =>
      _db.mealDao.findItems(mealId);

  /// Creates a meal and its items in one transaction.
  Future<String> createMeal({
    required String name,
    required List<MealItemInput> items,
  }) async {
    final id = _uuid.v4();
    _validateMeal(name, items);
    await _db.transaction(() async {
      await _db.mealDao.insertMeal(
        MealsCompanion.insert(id: id, name: name.trim()),
      );
      await _writeItems(id, items);
    });
    return id;
  }

  /// Replaces a meal's name and items in one transaction.
  Future<void> updateMeal(
    String id, {
    required String name,
    required List<MealItemInput> items,
  }) async {
    _validateMeal(name, items);
    await _db.transaction(() async {
      await _db.mealDao.updateMeal(
        id,
        MealsCompanion(name: Value(name.trim())),
      );
      await _writeItems(id, items);
    });
  }

  Future<void> setMealArchived(String id, {required bool archived}) =>
      _db.mealDao.setArchived(id, archived: archived);

  /// Writes the items of a meal template, replacing whatever was there.
  /// Must run inside a transaction.
  Future<void> _writeItems(String mealId, List<MealItemInput> items) async {
    await _db.mealDao.deleteItems(mealId);
    await _db.mealDao.insertItems([
      for (var i = 0; i < items.length; i++)
        MealFoodItemsCompanion.insert(
          id: _uuid.v4(),
          mealId: mealId,
          foodItemId: items[i].foodItemId,
          weightG: items[i].weightG,
          sortOrder: Value(i),
        ),
    ]);
  }

  /// Macros for [weightG] grams of [food].
  static Macros macrosForWeight(FoodItem food, double weightG) => scaleByWeight(
    Macros(
      calories: food.calories,
      protein: food.protein,
      carbs: food.carbs,
      fat: food.fat,
      fiber: food.fiber,
      sugar: food.sugar,
      sodium: food.sodium,
    ),
    servingWeightG: food.servingWeightG,
    weightG: weightG,
  );

  // ---- Validation ----------------------------------------------------------

  static void _validateName(String name) {
    final length = name.trim().length;
    if (length < 2 || length > maxNameLength) {
      throw ArgumentError.value(
        name,
        'name',
        'must be 2 to $maxNameLength characters',
      );
    }
  }

  /// Throws unless every macro is finite and >= 0. The optional nutrients may
  /// be null (not recorded).
  static void validateMacros(Macros macros) {
    for (final v in [
      macros.calories,
      macros.protein,
      macros.carbs,
      macros.fat,
      ?macros.fiber,
      ?macros.sugar,
      ?macros.sodium,
    ]) {
      if (!v.isFinite || v < 0) {
        throw ArgumentError('macro values must be finite and >= 0');
      }
    }
  }

  static void _validateFood(
    String name,
    Macros perServing,
    double servingWeightG,
  ) {
    _validateName(name);
    validateMacros(perServing);
    if (!servingWeightG.isFinite || servingWeightG <= 0) {
      throw ArgumentError.value(
        servingWeightG,
        'servingWeightG',
        'must be > 0',
      );
    }
  }

  static void _validateMeal(String name, List<MealItemInput> items) {
    _validateName(name);
    for (final item in items) {
      if (!item.weightG.isFinite || item.weightG <= 0) {
        throw ArgumentError.value(item.weightG, 'weightG', 'must be > 0');
      }
    }
  }
}
