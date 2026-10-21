import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/food_items.dart';

part 'food_dao.g.dart';

@DriftAccessor(tables: [FoodItems])
class FoodDao extends DatabaseAccessor<AppDatabase> with _$FoodDaoMixin {
  FoodDao(super.attachedDatabase);

  Future<void> insertFood(FoodItemsCompanion food) =>
      into(foodItems).insert(food);

  Future<FoodItem?> findById(String id) =>
      (select(foodItems)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> updateFood(String id, FoodItemsCompanion changes) =>
      (update(foodItems)..where((t) => t.id.equals(id))).write(changes);

  Future<int> setArchived(String id, {required bool archived}) =>
      (update(foodItems)..where((t) => t.id.equals(id))).write(
        FoodItemsCompanion(archived: Value(archived)),
      );

  /// Hard delete. Fails with a foreign-key error if a meal still uses the food.
  Future<int> deleteFood(String id) =>
      (delete(foodItems)..where((t) => t.id.equals(id))).go();

  /// Non-archived foods whose name contains [search] (case-insensitive for
  /// ASCII). An empty search returns everything active.
  Stream<List<FoodItem>> watchActive({String search = ''}) =>
      _activeQuery(search).watch();

  Future<List<FoodItem>> findActive({String search = ''}) =>
      _activeQuery(search).get();

  SimpleSelectStatement<$FoodItemsTable, FoodItem> _activeQuery(String search) {
    return select(foodItems)
      ..where((t) {
        final notArchived = t.archived.equals(false);
        if (search.trim().isEmpty) return notArchived;
        return notArchived & t.name.contains(search.trim());
      })
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
  }
}
