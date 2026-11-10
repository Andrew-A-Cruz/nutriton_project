// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

import 'food_items.dart';

/// Named portions of a catalog food, such as "cup" = 240 g or "slice" = 28 g.
/// Logging offers them alongside servings and weight. Deleted with the food.
@TableIndex(name: 'food_servings_food_item_id', columns: {#foodItemId})
class FoodServings extends Table {
  TextColumn get id => text()();
  TextColumn get foodItemId =>
      text().references(FoodItems, #id, onDelete: KeyAction.cascade)();

  /// The portion's name, e.g. 'cup' or 'slice'.
  TextColumn get name => text().withLength(min: 1, max: 40)();

  /// Grams in one portion.
  RealColumn get weightG => real().check(weightG.isBiggerThanValue(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
