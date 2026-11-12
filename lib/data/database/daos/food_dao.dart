import 'package:drift/drift.dart';

import '../../../core/search.dart';
import '../app_database.dart';
import '../tables/food_items.dart';
import '../tables/food_servings.dart';

part 'food_dao.g.dart';

@DriftAccessor(tables: [FoodItems, FoodServings])
class FoodDao extends DatabaseAccessor<AppDatabase> with _$FoodDaoMixin {
  FoodDao(super.attachedDatabase);

  /// [foodId]'s portions, smallest first. Re-emits on change.
  Stream<List<FoodServing>> watchServings(String foodId) =>
      (select(foodServings)
            ..where((s) => s.foodItemId.equals(foodId))
            ..orderBy([(s) => OrderingTerm.asc(s.weightG)]))
          .watch();

  Future<void> insertServing(FoodServingsCompanion serving) =>
      into(foodServings).insert(serving);

  Future<int> deleteServing(String id) =>
      (delete(foodServings)..where((s) => s.id.equals(id))).go();

  Future<void> insertFood(FoodItemsCompanion food) =>
      into(foodItems).insert(food);

  Future<FoodItem?> findById(String id) =>
      (select(foodItems)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// The non-archived food saved with [barcode], or null. If several share it,
  /// the first by name wins.
  Future<FoodItem?> findActiveByBarcode(String barcode) =>
      (select(foodItems)
            ..where((t) => t.barcode.equals(barcode) & t.archived.equals(false))
            ..orderBy([(t) => OrderingTerm.asc(t.name)])
            ..limit(1))
          .getSingleOrNull();

  /// The non-archived food with no brand called [name] (ignoring ASCII
  /// case), or null.
  Future<FoodItem?> findActiveUnbrandedByName(String name) =>
      (select(foodItems)
            ..where(
              (t) =>
                  t.name.lower().equals(name.toLowerCase()) &
                  t.brand.isNull() &
                  t.archived.equals(false),
            )
            ..limit(1))
          .getSingleOrNull();

  Future<int> updateFood(String id, FoodItemsCompanion changes) =>
      (update(foodItems)..where((t) => t.id.equals(id))).write(changes);

  Future<int> setArchived(String id, {required bool archived}) =>
      (update(foodItems)..where((t) => t.id.equals(id))).write(
        FoodItemsCompanion(archived: Value(archived)),
      );

  /// Hard delete. Fails with a foreign-key error if a meal still uses the food.
  Future<int> deleteFood(String id) =>
      (delete(foodItems)..where((t) => t.id.equals(id))).go();

  /// Non-archived foods matching [search]: every word of it must appear in the
  /// name or the brand, in any order (case-insensitive for ASCII; see
  /// [searchWords]). An empty search returns everything active, by name. A
  /// search puts the most recently logged foods first, then the rest by name.
  Stream<List<FoodItem>> watchActive({String search = ''}) =>
      _activeQuery(search).watch();

  Future<List<FoodItem>> findActive({String search = ''}) =>
      _activeQuery(search).get();

  /// When each food was last logged; null when never.
  static const _lastLogged = CustomExpression<int>(
    '(SELECT MAX(e.created_at) FROM food_log_entries e '
    'WHERE e.food_item_id = food_items.id)',
  );

  SimpleSelectStatement<$FoodItemsTable, FoodItem> _activeQuery(String search) {
    final words = searchWords(search);
    return select(foodItems)
      ..where((t) {
        var matches = t.archived.equals(false);
        for (final word in words) {
          matches =
              matches & (_contains(t.name, word) | _contains(t.brand, word));
        }
        return matches;
      })
      ..orderBy([
        // SQLite sorts null last when descending, so unlogged foods follow.
        if (words.isNotEmpty) (t) => OrderingTerm.desc(_lastLogged),
        (t) => OrderingTerm.asc(t.name),
      ]);
  }

  /// Literal substring match: '%', '_' and the escape character '\' in
  /// [text] are escaped so they are not LIKE wildcards.
  Expression<bool> _contains(GeneratedColumn<String> column, String text) {
    final escaped = text.replaceAllMapped(
      RegExp(r'[\\%_]'),
      (m) => '\\${m[0]}',
    );
    return column.like('%$escaped%', escapeChar: r'\');
  }
}
