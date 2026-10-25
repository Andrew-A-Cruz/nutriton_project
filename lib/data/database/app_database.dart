import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'app_database.steps.dart';
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
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: stepByStep(
      // v1 -> v2: scheduling.
      from1To2: (m, schema) async {
        await m.createTable(schema.scheduledMeals);
        await m.createTable(schema.scheduledMealOutcomes);
        await m.create(schema.scheduledMealsStartDate);
      },
      // v2 -> v3: meal sections; existing rows stay null (shown as Other).
      from2To3: (m, schema) async {
        await m.addColumn(
          schema.foodLogEntries,
          schema.foodLogEntries.mealSlot,
        );
      },
      // v3 -> v4: fiber, sugar and sodium; existing rows stay null (not
      // recorded).
      from3To4: (m, schema) async {
        await m.addColumn(schema.foodItems, schema.foodItems.fiber);
        await m.addColumn(schema.foodItems, schema.foodItems.sugar);
        await m.addColumn(schema.foodItems, schema.foodItems.sodium);
        await m.addColumn(schema.foodLogEntries, schema.foodLogEntries.fiber);
        await m.addColumn(schema.foodLogEntries, schema.foodLogEntries.sugar);
        await m.addColumn(schema.foodLogEntries, schema.foodLogEntries.sodium);
        await m.addColumn(
          schema.foodLogEntryItems,
          schema.foodLogEntryItems.fiber,
        );
        await m.addColumn(
          schema.foodLogEntryItems,
          schema.foodLogEntryItems.sugar,
        );
        await m.addColumn(
          schema.foodLogEntryItems,
          schema.foodLogEntryItems.sodium,
        );
      },
    ),
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
