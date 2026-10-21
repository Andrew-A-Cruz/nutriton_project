// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'log_dao.dart';

// ignore_for_file: type=lint
mixin _$LogDaoMixin on DatabaseAccessor<AppDatabase> {
  $FoodItemsTable get foodItems => attachedDatabase.foodItems;
  $MealsTable get meals => attachedDatabase.meals;
  $FoodLogEntriesTable get foodLogEntries => attachedDatabase.foodLogEntries;
  $FoodLogEntryItemsTable get foodLogEntryItems =>
      attachedDatabase.foodLogEntryItems;
  LogDaoManager get managers => LogDaoManager(this);
}

class LogDaoManager {
  final _$LogDaoMixin _db;
  LogDaoManager(this._db);
  $$FoodItemsTableTableManager get foodItems =>
      $$FoodItemsTableTableManager(_db.attachedDatabase, _db.foodItems);
  $$MealsTableTableManager get meals =>
      $$MealsTableTableManager(_db.attachedDatabase, _db.meals);
  $$FoodLogEntriesTableTableManager get foodLogEntries =>
      $$FoodLogEntriesTableTableManager(
        _db.attachedDatabase,
        _db.foodLogEntries,
      );
  $$FoodLogEntryItemsTableTableManager get foodLogEntryItems =>
      $$FoodLogEntryItemsTableTableManager(
        _db.attachedDatabase,
        _db.foodLogEntryItems,
      );
}
