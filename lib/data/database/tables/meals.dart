// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

/// Named meal templates in the catalog. Items live in `meal_food_items`.
class Meals extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 2, max: 100)();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
