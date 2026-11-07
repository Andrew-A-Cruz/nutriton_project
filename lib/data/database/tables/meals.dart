// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

/// Named meal templates in the catalog. Items live in `meal_food_items`.
class Meals extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 2, max: 100)();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  /// Starred meals are pinned at the top of Add Food.
  BoolColumn get favorite => boolean().withDefault(const Constant(false))();

  /// Set for a recipe: the weight of the whole batch once cooked. A portion
  /// of the recipe then logs portion / cooked weight of the items' totals.
  /// Null for an ordinary meal.
  RealColumn get cookedWeightG =>
      real().nullable().check(cookedWeightG.isBiggerThanValue(0))();

  @override
  Set<Column> get primaryKey => {id};
}
