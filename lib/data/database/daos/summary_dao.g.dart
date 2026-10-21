// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'summary_dao.dart';

// ignore_for_file: type=lint
mixin _$SummaryDaoMixin on DatabaseAccessor<AppDatabase> {
  $FoodItemsTable get foodItems => attachedDatabase.foodItems;
  $MealsTable get meals => attachedDatabase.meals;
  $FoodLogEntriesTable get foodLogEntries => attachedDatabase.foodLogEntries;
  SummaryDaoManager get managers => SummaryDaoManager(this);
}

class SummaryDaoManager {
  final _$SummaryDaoMixin _db;
  SummaryDaoManager(this._db);
  $$FoodItemsTableTableManager get foodItems =>
      $$FoodItemsTableTableManager(_db.attachedDatabase, _db.foodItems);
  $$MealsTableTableManager get meals =>
      $$MealsTableTableManager(_db.attachedDatabase, _db.meals);
  $$FoodLogEntriesTableTableManager get foodLogEntries =>
      $$FoodLogEntriesTableTableManager(
        _db.attachedDatabase,
        _db.foodLogEntries,
      );
}
