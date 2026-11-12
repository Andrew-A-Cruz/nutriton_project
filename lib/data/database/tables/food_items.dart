// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

/// Saved catalog foods. Macros are stored per 1 serving, where 1 serving is
/// [servingWeightG] grams.
@TableIndex(name: 'food_items_barcode', columns: {#barcode})
@TableIndex(name: 'food_items_menu_item_id', columns: {#menuItemId})
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

  /// Optional brand, e.g. from an Open Food Facts lookup. Shown beside the
  /// name and matched by search.
  TextColumn get brand => text().nullable().withLength(max: 100)();

  /// Starred foods are pinned at the top of Add Food.
  BoolColumn get favorite => boolean().withDefault(const Constant(false))();

  /// `"<chain id>/<item id>"` of the bundled restaurant menu item this food
  /// was copied from. Null for every other food.
  TextColumn get menuItemId => text().nullable()();

  /// The bundled menus' version this food's values match, so a newer file
  /// can refresh it. Null when it is not a menu food, or once the user has
  /// edited it: an edited food is never refreshed.
  IntColumn get menuVersion => integer().nullable()();

  /// True for a restaurant item whose chain publishes no weight for it. The
  /// food is then counted in items only: [servingWeightG] is a placeholder
  /// of 1 that is never shown, and logging by weight is not offered.
  BoolColumn get weightUnknown =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}
