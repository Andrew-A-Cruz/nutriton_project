// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fast_dao.dart';

// ignore_for_file: type=lint
mixin _$FastDaoMixin on DatabaseAccessor<AppDatabase> {
  $FastsTable get fasts => attachedDatabase.fasts;
  FastDaoManager get managers => FastDaoManager(this);
}

class FastDaoManager {
  final _$FastDaoMixin _db;
  FastDaoManager(this._db);
  $$FastsTableTableManager get fasts =>
      $$FastsTableTableManager(_db.attachedDatabase, _db.fasts);
}
