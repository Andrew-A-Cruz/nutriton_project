import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

class FoodItems extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 2, max: 100)();
  RealColumn get calories => real().check(calories.isBiggerOrEqualValue(0))();
  RealColumn get protein => real().check(protein.isBiggerOrEqualValue(0))();
  RealColumn get carbs => real().check(carbs.isBiggerOrEqualValue(0))();
  RealColumn get fat => real().check(fat.isBiggerOrEqualValue(0))();
  RealColumn get servingWeight =>
      real().check(servingWeight.isBiggerOrEqualValue(0))();
  TextColumn get weightUnit => text().check(weightUnit.isIn(['g', 'oz']))();

  @override
  Set<Column> get primaryKey => {id};
}

class Meals extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 2, max: 100)();

  @override
  Set<Column> get primaryKey => {id};
}

class MealFoodItems extends Table {
  TextColumn get id => text()();
  TextColumn get mealId =>
      text().references(Meals, #id, onDelete: KeyAction.cascade)();
  TextColumn get foodItemId =>
      text().references(FoodItems, #id, onDelete: KeyAction.restrict)();

  RealColumn get servingWeight =>
      real().check(servingWeight.isBiggerOrEqualValue(0))();
  TextColumn get weightUnit => text().check(weightUnit.isIn(['g', 'oz']))();

  @override
  Set<Column> get primaryKey => {id};
}

class FoodLogEntries extends Table {
  TextColumn get id => text()();
  DateTimeColumn get logDate => dateTime()();

  // Catalog food item entry
  TextColumn get foodItemId => text().nullable().references(
    FoodItems,
    #id,
    onDelete: KeyAction.restrict,
  )();
  RealColumn get servings =>
      real().nullable().check(servings.isBiggerOrEqualValue(0))();

  // Catalog meal entry
  TextColumn get mealId =>
      text().nullable().references(Meals, #id, onDelete: KeyAction.restrict)();

  // Adhoc entry
  TextColumn get adhocName => text().nullable()();
  RealColumn get adhocCalories =>
      real().nullable().check(adhocCalories.isBiggerOrEqualValue(0))();
  RealColumn get adhocProtein =>
      real().nullable().check(adhocProtein.isBiggerOrEqualValue(0))();
  RealColumn get adhocCarbs =>
      real().nullable().check(adhocCarbs.isBiggerOrEqualValue(0))();
  RealColumn get adhocFat =>
      real().nullable().check(adhocFat.isBiggerOrEqualValue(0))();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [FoodItems, Meals, MealFoodItems, FoodLogEntries])
class AppDatabase extends _$AppDatabase {
  // After generating code, this class needs to define a `schemaVersion` getter
  // and a constructor telling drift where the database should be stored.
  // These are described in the getting started guide: https://drift.simonbinder.eu/setup/
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'my_database',
      native: const DriftNativeOptions(
        // By default, `driftDatabase` from `package:drift_flutter` stores the
        // database files in `getApplicationDocumentsDirectory()`.
        databaseDirectory: getApplicationSupportDirectory,
      ),
      // If you need web support, see https://drift.simonbinder.eu/platforms/web/
    );
  }
}
