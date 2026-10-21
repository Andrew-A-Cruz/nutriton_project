import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'daos/food_dao.dart';
import 'daos/log_dao.dart';
import 'daos/meal_dao.dart';
import 'daos/summary_dao.dart';
import 'tables/food_items.dart';
import 'tables/food_log_entries.dart';
import 'tables/food_log_entry_items.dart';
import 'tables/meal_food_items.dart';
import 'tables/meals.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [FoodItems, Meals, MealFoodItems, FoodLogEntries, FoodLogEntryItems],
  daos: [FoodDao, MealDao, LogDao, SummaryDao],
)
class AppDatabase extends _$AppDatabase {
  /// Pass a [QueryExecutor] (e.g. `NativeDatabase.memory()`) in tests. The
  /// default opens the on-disk `food_log` database.
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    beforeOpen: (details) async {
      // SQLite does not enforce foreign keys unless asked to.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  static QueryExecutor _openConnection() {
    return driftDatabase(
      name: 'food_log',
      native: const DriftNativeOptions(
        // Stores the file in getApplicationSupportDirectory().
        databaseDirectory: getApplicationSupportDirectory,
      ),
    );
  }
}
