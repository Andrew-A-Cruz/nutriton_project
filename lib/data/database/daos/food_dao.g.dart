// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'food_dao.dart';

// ignore_for_file: type=lint
mixin _$FoodDaoMixin on DatabaseAccessor<AppDatabase> {
  $FoodItemsTable get foodItems => attachedDatabase.foodItems;
  FoodDaoManager get managers => FoodDaoManager(this);
}

class FoodDaoManager {
  final _$FoodDaoMixin _db;
  FoodDaoManager(this._db);
  $$FoodItemsTableTableManager get foodItems =>
      $$FoodItemsTableTableManager(_db.attachedDatabase, _db.foodItems);
}
