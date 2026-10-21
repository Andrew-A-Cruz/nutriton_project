import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'daos/food_dao.dart';
import 'daos/log_dao.dart';
import 'daos/meal_dao.dart';
import 'daos/scheduled_meal_dao.dart';
import 'daos/summary_dao.dart';
import 'tables/food_items.dart';
import 'tables/food_log_entries.dart';
import 'tables/food_log_entry_items.dart';
import 'tables/meal_food_items.dart';
import 'tables/meals.dart';
import 'tables/scheduled_meals.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    FoodItems,
    Meals,
    MealFoodItems,
    FoodLogEntries,
    FoodLogEntryItems,
    ScheduledMeals,
    ScheduledMealOutcomes,
  ],
  daos: [FoodDao, MealDao, LogDao, SummaryDao, ScheduledMealDao],
)
class AppDatabase extends _$AppDatabase {
  /// Pass a [QueryExecutor] (e.g. `NativeDatabase.memory()`) in tests. The
  /// default opens the on-disk `food_log` database.
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      // v1 -> v2: scheduling.
      if (from < 2) {
        await m.createTable(scheduledMeals);
        await m.createTable(scheduledMealOutcomes);
        await m.createIndex(scheduledMealsStartDate);
      }
    },
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
