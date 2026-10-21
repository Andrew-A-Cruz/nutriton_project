// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

import 'food_items.dart';
import 'meals.dart';

/// Junction table: the foods in a meal template and how many grams of each.
class MealFoodItems extends Table {
  TextColumn get id => text()();
  TextColumn get mealId =>
      text().references(Meals, #id, onDelete: KeyAction.cascade)();
  TextColumn get foodItemId =>
      text().references(FoodItems, #id, onDelete: KeyAction.restrict)();
  RealColumn get weightG => real().check(weightG.isBiggerThanValue(0))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
