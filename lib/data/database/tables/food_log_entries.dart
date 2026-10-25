// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

import 'food_items.dart';
import 'meals.dart';

/// The daily log. Every entry stores its own resolved macros (a snapshot taken
/// when it was logged); the catalog references are provenance only.
@TableIndex(name: 'food_log_entries_log_date', columns: {#logDate})
class FoodLogEntries extends Table {
  TextColumn get id => text()();

  /// Day this entry belongs to, as 'yyyy-MM-dd'.
  TextColumn get logDate => text()();
  DateTimeColumn get createdAt => dateTime()();

  /// 'food' | 'meal' | 'adhoc'
  TextColumn get entryType =>
      text().check(entryType.isIn(['food', 'meal', 'adhoc']))();

  TextColumn get name => text()();
  RealColumn get calories => real().check(calories.isBiggerOrEqualValue(0))();
  RealColumn get protein => real().check(protein.isBiggerOrEqualValue(0))();
  RealColumn get carbs => real().check(carbs.isBiggerOrEqualValue(0))();
  RealColumn get fat => real().check(fat.isBiggerOrEqualValue(0))();

  TextColumn get foodItemId => text().nullable().references(
    FoodItems,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get mealId =>
      text().nullable().references(Meals, #id, onDelete: KeyAction.setNull)();

  /// Food entries only.
  RealColumn get servings =>
      real().nullable().check(servings.isBiggerThanValue(0))();

  /// 'breakfast' | 'lunch' | 'dinner' | 'snack'; null shows under "Other".
  TextColumn get mealSlot => text().nullable().check(
    mealSlot.isIn(['breakfast', 'lunch', 'dinner', 'snack']),
  )();

  @override
  Set<Column> get primaryKey => {id};
}
