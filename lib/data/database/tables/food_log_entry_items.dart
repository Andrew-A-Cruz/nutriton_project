// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

import 'food_items.dart';
import 'food_log_entries.dart';

/// Breakdown of a logged meal as it was actually eaten (after adding, removing
/// or re-weighing items). Snapshot values, independent of the template.
class FoodLogEntryItems extends Table {
  TextColumn get id => text()();
  TextColumn get entryId =>
      text().references(FoodLogEntries, #id, onDelete: KeyAction.cascade)();
  TextColumn get foodItemId => text().nullable().references(
    FoodItems,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get name => text()();
  RealColumn get weightG => real().check(weightG.isBiggerThanValue(0))();
  RealColumn get calories => real().check(calories.isBiggerOrEqualValue(0))();
  RealColumn get protein => real().check(protein.isBiggerOrEqualValue(0))();
  RealColumn get carbs => real().check(carbs.isBiggerOrEqualValue(0))();
  RealColumn get fat => real().check(fat.isBiggerOrEqualValue(0))();

  /// Optional nutrients: null means not recorded, which is not the same as 0.
  /// Sodium is in milligrams, fiber and sugar in grams.
  RealColumn get fiber =>
      real().nullable().check(fiber.isBiggerOrEqualValue(0))();
  RealColumn get sugar =>
      real().nullable().check(sugar.isBiggerOrEqualValue(0))();
  RealColumn get sodium =>
      real().nullable().check(sodium.isBiggerOrEqualValue(0))();

  @override
  Set<Column> get primaryKey => {id};
}
