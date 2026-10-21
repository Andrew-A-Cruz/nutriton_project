// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scheduled_meal_dao.dart';

// ignore_for_file: type=lint
mixin _$ScheduledMealDaoMixin on DatabaseAccessor<AppDatabase> {
  $MealsTable get meals => attachedDatabase.meals;
  $ScheduledMealsTable get scheduledMeals => attachedDatabase.scheduledMeals;
  $FoodItemsTable get foodItems => attachedDatabase.foodItems;
  $FoodLogEntriesTable get foodLogEntries => attachedDatabase.foodLogEntries;
  $ScheduledMealOutcomesTable get scheduledMealOutcomes =>
      attachedDatabase.scheduledMealOutcomes;
  ScheduledMealDaoManager get managers => ScheduledMealDaoManager(this);
}

class ScheduledMealDaoManager {
  final _$ScheduledMealDaoMixin _db;
  ScheduledMealDaoManager(this._db);
  $$MealsTableTableManager get meals =>
      $$MealsTableTableManager(_db.attachedDatabase, _db.meals);
  $$ScheduledMealsTableTableManager get scheduledMeals =>
      $$ScheduledMealsTableTableManager(
        _db.attachedDatabase,
        _db.scheduledMeals,
      );
  $$FoodItemsTableTableManager get foodItems =>
      $$FoodItemsTableTableManager(_db.attachedDatabase, _db.foodItems);
  $$FoodLogEntriesTableTableManager get foodLogEntries =>
      $$FoodLogEntriesTableTableManager(
        _db.attachedDatabase,
        _db.foodLogEntries,
      );
  $$ScheduledMealOutcomesTableTableManager get scheduledMealOutcomes =>
      $$ScheduledMealOutcomesTableTableManager(
        _db.attachedDatabase,
        _db.scheduledMealOutcomes,
      );
}
