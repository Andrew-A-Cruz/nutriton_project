// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

/// Water drunk, one total per day. Always milliliters; the water unit
/// preference only changes how it is shown. A day with none has no row.
@DataClassName('WaterDay')
class WaterLog extends Table {
  /// 'yyyy-MM-dd'. One row per day, so it is the key.
  TextColumn get logDate => text()();
  RealColumn get amountMl => real().check(amountMl.isBiggerThanValue(0))();

  @override
  Set<Column> get primaryKey => {logDate};
}
