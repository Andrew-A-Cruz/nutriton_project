// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'water_dao.dart';

// ignore_for_file: type=lint
mixin _$WaterDaoMixin on DatabaseAccessor<AppDatabase> {
  $WaterLogTable get waterLog => attachedDatabase.waterLog;
  WaterDaoManager get managers => WaterDaoManager(this);
}

class WaterDaoManager {
  final _$WaterDaoMixin _db;
  WaterDaoManager(this._db);
  $$WaterLogTableTableManager get waterLog =>
      $$WaterLogTableTableManager(_db.attachedDatabase, _db.waterLog);
}
