// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'body_weight_dao.dart';

// ignore_for_file: type=lint
mixin _$BodyWeightDaoMixin on DatabaseAccessor<AppDatabase> {
  $BodyWeightsTable get bodyWeights => attachedDatabase.bodyWeights;
  BodyWeightDaoManager get managers => BodyWeightDaoManager(this);
}

class BodyWeightDaoManager {
  final _$BodyWeightDaoMixin _db;
  BodyWeightDaoManager(this._db);
  $$BodyWeightsTableTableManager get bodyWeights =>
      $$BodyWeightsTableTableManager(_db.attachedDatabase, _db.bodyWeights);
}
