import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/bundled_foods.dart';
import '../../core/menus.dart';
import '../../core/nutrition_math.dart';
import '../../core/validation.dart';
import '../database/app_database.dart';
import '../database/daos/meal_dao.dart';

const _uuid = Uuid();

/// The serving weight stored for a food whose weight is unknown
/// (`food_items.weight_unknown`). The column must be positive; the value is
/// never shown.
const unknownServingWeightG = 1.0;

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

  /// [foodId]'s named portions, smallest first.
  Stream<List<FoodServing>> watchServings(String foodId) =>
      _db.foodDao.watchServings(foodId);

  /// Adds a portion called [name] of [weightG] grams to [foodId].
  Future<String> addServing(
    String foodId, {
    required String name,
    required double weightG,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 40) {
      throw ArgumentError.value(name, 'name', 'must be 1 to 40 characters');
    }
    if (!weightG.isFinite || weightG <= 0) {
      throw ArgumentError.value(weightG, 'weightG', 'must be > 0');
    }
    final id = _uuid.v4();
    await _db.foodDao.insertServing(
      FoodServingsCompanion.insert(
        id: id,
        foodItemId: foodId,
        name: trimmed,
        weightG: weightG,
        createdAt: DateTime.now(),
      ),
    );
    return id;
  }

  Future<void> removeServing(String id) => _db.foodDao.deleteServing(id);

  /// The catalog food for a bundled [food], copying it in the first time it
  /// is used: a 100 g serving with the bundled values and portions. A food
  /// with the same name and no brand already in the catalog is used as it
  /// is, with any edits made to it, so picking a bundled food twice never
  /// makes a second copy.
  Future<FoodItem> adoptBundledFood(BundledFood food) =>
      _db.transaction(() async {
        final name = food.name.trim();
        final existing = await _db.foodDao.findActiveUnbrandedByName(name);
        if (existing != null) return existing;
        final id = await createFood(
          name: name.length > maxNameLength
              ? name.substring(0, maxNameLength)
              : name,
          perServing: food.per100g,
          servingWeightG: 100,
        );
        for (final p in food.portions) {
          await addServing(
            id,
            name: p.name.length > 40 ? p.name.substring(0, 40) : p.name,
            weightG: p.weightG,
          );
        }
        return (await _db.foodDao.findById(id))!;
      });

  /// The catalog food for a restaurant menu [item], copying it in the first
  /// time it is used, with the chain as its brand. [version] is the bundled
  /// menus' version the values come from. A food already copied from that
  /// item is returned as it is, with any edits made to it, and un-archived
  /// if it was archived, so picking an item twice never makes a second copy.
  Future<FoodItem> adoptMenuItem(MenuItem item, {required int version}) =>
      _db.transaction(() async {
        final existing = await _db.foodDao.findByMenuItemId(item.id);
        if (existing != null) {
          if (!existing.archived) return existing;
          await _db.foodDao.setArchived(existing.id, archived: false);
          return (await _db.foodDao.findById(existing.id))!;
        }
        final id = await _insertFood(
          name: item.name,
          perServing: item.perItem,
          servingWeightG: item.servingWeightG ?? unknownServingWeightG,
          brand: item.chainName,
          menuItemId: item.id,
          menuVersion: version,
          weightUnknown: item.servingWeightG == null,
        );
        return (await _db.foodDao.findById(id))!;
      });

  /// Brings menu foods the user has not edited up to [menus], when their
  /// values match an older file: the item's name, nutrients and serving
  /// weight are rewritten. Edited foods, foods whose item has left the file
  /// and log entries are left alone. Returns how many foods changed.
  Future<int> refreshMenuFoods(MenuCatalog menus) => _db.transaction(() async {
    final stale = await _db.foodDao.findMenuFoodsBelowVersion(menus.version);
    var updated = 0;
    for (final food in stale) {
      final item = menus.itemById(food.menuItemId!);
      if (item == null) continue;
      await _db.foodDao.updateFood(
        food.id,
        FoodItemsCompanion(
          name: Value(item.name),
          calories: Value(item.perItem.calories),
          protein: Value(item.perItem.protein),
          carbs: Value(item.perItem.carbs),
          fat: Value(item.perItem.fat),
          fiber: Value(item.perItem.fiber),
          sugar: Value(item.perItem.sugar),
          sodium: Value(item.perItem.sodium),
          servingWeightG: Value(item.servingWeightG ?? unknownServingWeightG),
          weightUnknown: Value(item.servingWeightG == null),
          menuVersion: Value(menus.version),
        ),
      );
      updated++;
    }
    return updated;
  });

  Future<String> createFood({
    required String name,
    required Macros perServing,
    required double servingWeightG,
    WeightUnit displayUnit = WeightUnit.g,
    String? barcode,
    String? brand,
  }) => _insertFood(
    name: name,
    perServing: perServing,
    servingWeightG: servingWeightG,
    displayUnit: displayUnit,
    barcode: barcode,
    brand: brand,
  );

  /// The menu columns are set only by [adoptMenuItem]: a food made in the
  /// form, or duplicated from a menu food, is the user's own.
  Future<String> _insertFood({
    required String name,
    required Macros perServing,
    required double servingWeightG,
    WeightUnit displayUnit = WeightUnit.g,
    String? barcode,
    String? brand,
    String? menuItemId,
    int? menuVersion,
    bool weightUnknown = false,
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
        barcode: Value(_cleanBarcode(barcode)),
        brand: Value(_cleanBrand(brand)),
        menuItemId: Value(menuItemId),
        menuVersion: Value(menuVersion),
        weightUnknown: Value(weightUnknown),
      ),
    );
    return id;
  }

  /// Saves the food form. A restaurant menu food becomes the user's own
  /// version: it keeps its link to the menu item but is no longer refreshed
  /// when the bundled menus change. A food with no known weight gains one
  /// when the saved weight differs from its placeholder.
  Future<void> updateFood(
    String id, {
    required String name,
    required Macros perServing,
    required double servingWeightG,
    WeightUnit displayUnit = WeightUnit.g,
    String? barcode,
    String? brand,
  }) async {
    _validateFood(name, perServing, servingWeightG);
    final existing = await _db.foodDao.findById(id);
    await _db.foodDao.updateFood(
      id,
      FoodItemsCompanion(
        weightUnknown: Value(
          existing != null &&
              existing.weightUnknown &&
              servingWeightG == existing.servingWeightG,
        ),
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
        barcode: Value(_cleanBarcode(barcode)),
        brand: Value(_cleanBrand(brand)),
        menuVersion: const Value(null),
      ),
    );
  }

  /// The non-archived catalog food saved with [barcode], or null.
  Future<FoodItem?> findFoodByBarcode(String barcode) =>
      _db.foodDao.findActiveByBarcode(barcode);

  static String? _cleanBarcode(String? barcode) {
    final trimmed = barcode?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  /// Trimmed; empty is no brand. Throws past [maxNameLength] characters.
  static String? _cleanBrand(String? brand) {
    final trimmed = brand?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    if (trimmed.length > maxNameLength) {
      throw ArgumentError.value(
        brand,
        'brand',
        'must be at most $maxNameLength characters',
      );
    }
    return trimmed;
  }

  /// Starred foods are pinned at the top of Add Food.
  Future<void> setFoodFavorite(String id, {required bool favorite}) =>
      _db.foodDao.updateFood(id, FoodItemsCompanion(favorite: Value(favorite)));

  /// Archived foods leave search results but stay in past log entries.
  Future<void> setFoodArchived(String id, {required bool archived}) =>
      _db.foodDao.setArchived(id, archived: archived);

  // ---- Meals ---------------------------------------------------------------

  Stream<List<Meal>> watchMeals() => _db.mealDao.watchActive();

  Future<List<Meal>> findMeals() => _db.mealDao.findActive();

  Future<Meal?> findMeal(String id) => _db.mealDao.findById(id);

  /// Starred meals are pinned at the top of Add Food.
  Future<void> setMealFavorite(String id, {required bool favorite}) =>
      _db.mealDao.updateMeal(id, MealsCompanion(favorite: Value(favorite)));

  Stream<List<MealItemRow>> watchMealItems(String mealId) =>
      _db.mealDao.watchItems(mealId);

  Future<List<MealItemRow>> findMealItems(String mealId) =>
      _db.mealDao.findItems(mealId);

  /// Creates a meal and its items in one transaction. A [cookedWeightG] makes
  /// it a recipe, logged by the portion eaten.
  Future<String> createMeal({
    required String name,
    required List<MealItemInput> items,
    double? cookedWeightG,
  }) async {
    final id = _uuid.v4();
    _validateMeal(name, items);
    _validateCookedWeight(cookedWeightG);
    await _db.transaction(() async {
      await _db.mealDao.insertMeal(
        MealsCompanion.insert(
          id: id,
          name: name.trim(),
          cookedWeightG: Value(cookedWeightG),
        ),
      );
      await _writeItems(id, items);
    });
    return id;
  }

  /// Replaces a meal's name and items in one transaction. The cooked weight
  /// changes only when [cookedWeightG] is given (`Value(null)` turns a recipe
  /// back into an ordinary meal).
  Future<void> updateMeal(
    String id, {
    required String name,
    required List<MealItemInput> items,
    Value<double?> cookedWeightG = const Value.absent(),
  }) async {
    _validateMeal(name, items);
    if (cookedWeightG.present) _validateCookedWeight(cookedWeightG.value);
    await _db.transaction(() async {
      await _db.mealDao.updateMeal(
        id,
        MealsCompanion(name: Value(name.trim()), cookedWeightG: cookedWeightG),
      );
      await _writeItems(id, items);
    });
  }

  static void _validateCookedWeight(double? grams) {
    if (grams != null && (!grams.isFinite || grams <= 0)) {
      throw ArgumentError.value(grams, 'cookedWeightG', 'must be > 0');
    }
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
