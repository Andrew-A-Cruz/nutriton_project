// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

/// Saved catalog foods. Macros are stored per 1 serving, where 1 serving is
/// [servingWeightG] grams.
@TableIndex(name: 'food_items_barcode', columns: {#barcode})
class FoodItems extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 2, max: 100)();
  RealColumn get calories => real().check(calories.isBiggerOrEqualValue(0))();
  RealColumn get protein => real().check(protein.isBiggerOrEqualValue(0))();
  RealColumn get carbs => real().check(carbs.isBiggerOrEqualValue(0))();
  RealColumn get fat => real().check(fat.isBiggerOrEqualValue(0))();
  RealColumn get servingWeightG =>
      real().check(servingWeightG.isBiggerThanValue(0))();
  TextColumn get displayUnit => text()
      .check(displayUnit.isIn(['g', 'oz']))
      .withDefault(const Constant('g'))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  /// Optional nutrients: null means not recorded, which is not the same as 0.
  /// Sodium is in milligrams, fiber and sugar in grams.
  RealColumn get fiber =>
      real().nullable().check(fiber.isBiggerOrEqualValue(0))();
  RealColumn get sugar =>
      real().nullable().check(sugar.isBiggerOrEqualValue(0))();
  RealColumn get sodium =>
      real().nullable().check(sodium.isBiggerOrEqualValue(0))();

  /// Optional barcode digits (EAN/UPC), set when a food is created from a
  /// scan or typed in the food form. Null when unknown.
  TextColumn get barcode => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
