import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/food_items.dart';
import '../tables/food_log_entries.dart';
import '../tables/food_log_entry_items.dart';

part 'log_dao.g.dart';

@DriftAccessor(tables: [FoodLogEntries, FoodLogEntryItems, FoodItems])
class LogDao extends DatabaseAccessor<AppDatabase> with _$LogDaoMixin {
  LogDao(super.attachedDatabase);

  /// Entries for one day ('yyyy-MM-dd'), oldest first. drift stores
  /// `created_at` to the second, so entries saved within the same second fall
  /// back to insertion order (rowid).
  Stream<List<FoodLogEntry>> watchEntriesForDate(String logDate) =>
      (select(foodLogEntries)
            ..where((t) => t.logDate.equals(logDate))
            ..orderBy([
              (t) => OrderingTerm.asc(t.createdAt),
              (t) => OrderingTerm.asc(t.rowId),
            ]))
          .watch();

  Future<FoodLogEntry?> findEntry(String id) =>
      (select(foodLogEntries)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> insertEntry(FoodLogEntriesCompanion entry) =>
      into(foodLogEntries).insert(entry);

  Future<int> updateEntry(String id, FoodLogEntriesCompanion changes) =>
      (update(foodLogEntries)..where((t) => t.id.equals(id))).write(changes);

  /// Deletes the entry and, via cascade, its breakdown rows.
  Future<int> deleteEntry(String id) =>
      (delete(foodLogEntries)..where((t) => t.id.equals(id))).go();

  /// The SQLite rowid of the entry, which breaks ties in the day's order.
  Future<int?> findRowId(String id) async {
    final row = await customSelect(
      'SELECT rowid AS r FROM food_log_entries WHERE id = ?',
      variables: [Variable<String>(id)],
      readsFrom: {foodLogEntries},
    ).getSingleOrNull();
    return row?.read<int>('r');
  }

  /// Gives the entry back a rowid it used to have, if that rowid is free.
  Future<void> restoreRowId(String id, int rowId) async {
    final taken = await customSelect(
      'SELECT 1 AS x FROM food_log_entries WHERE rowid = ?',
      variables: [Variable<int>(rowId)],
      readsFrom: {foodLogEntries},
    ).get();
    if (taken.isNotEmpty) return;
    await customUpdate(
      'UPDATE food_log_entries SET rowid = ? WHERE id = ?',
      variables: [Variable<int>(rowId), Variable<String>(id)],
      updates: {foodLogEntries},
      updateKind: UpdateKind.update,
    );
  }

  /// Moves the entry to [logDate] ('yyyy-MM-dd').
  Future<int> updateEntryDate(String id, String logDate) =>
      updateEntry(id, FoodLogEntriesCompanion(logDate: Value(logDate)));

  Future<void> insertEntryItems(List<FoodLogEntryItemsCompanion> items) =>
      batch((b) => b.insertAll(foodLogEntryItems, items));

  Future<List<FoodLogEntryItem>> findEntryItems(String entryId) => (select(
    foodLogEntryItems,
  )..where((t) => t.entryId.equals(entryId))).get();

  Stream<List<FoodLogEntryItem>> watchEntryItems(String entryId) => (select(
    foodLogEntryItems,
  )..where((t) => t.entryId.equals(entryId))).watch();

  /// Entries for one day, oldest first (same order as [watchEntriesForDate]).
  Future<List<FoodLogEntry>> findEntriesForDate(String logDate) =>
      (select(foodLogEntries)
            ..where((t) => t.logDate.equals(logDate))
            ..orderBy([
              (t) => OrderingTerm.asc(t.createdAt),
              (t) => OrderingTerm.asc(t.rowId),
            ]))
          .get();

  /// Breakdown rows for several entries at once.
  Future<List<FoodLogEntryItem>> findItemsForEntries(List<String> entryIds) =>
      (select(foodLogEntryItems)..where((t) => t.entryId.isIn(entryIds))).get();

  /// Catalog foods and meals that were logged, most recently logged first, at
  /// most [limit]. A source appears once however often it was logged. Archived
  /// sources and one-off entries do not count. Re-emits on log, food and meal
  /// writes.
  Stream<List<RecentSource>> watchRecentSources({int limit = 8}) =>
      _watchSources(orderBy: 'last_used DESC, last_row DESC', limit: limit);

  /// Like [watchRecentSources], but ranked by how often each source was logged
  /// on or after [sinceDate] ('yyyy-MM-dd'), newest first among equals. Sources
  /// not logged since then are left out.
  Stream<List<RecentSource>> watchFrequentSources({
    required String sinceDate,
    int limit = 8,
  }) => _watchSources(
    since: sinceDate,
    orderBy: 'uses DESC, last_used DESC, last_row DESC',
    limit: limit,
  );

  /// Servings of the latest food entry for [foodItemId], or null if it was
  /// never logged.
  Future<double?> findLastServings(String foodItemId) async {
    final entry =
        await (select(foodLogEntries)
              ..where(
                (t) =>
                    t.foodItemId.equals(foodItemId) &
                    t.entryType.equals('food') &
                    t.servings.isNotNull(),
              )
              ..orderBy([
                (t) => OrderingTerm.desc(t.createdAt),
                (t) => OrderingTerm.desc(t.rowId),
              ])
              ..limit(1))
            .getSingleOrNull();
    return entry?.servings;
  }

  Stream<List<RecentSource>> _watchSources({
    String? since,
    required String orderBy,
    required int limit,
  }) {
    final where = since == null ? '' : 'AND e.log_date >= ?';
    String half(String kind, String entryColumn, String table) =>
        '''
      SELECT '$kind' AS kind, s.id AS id, MAX(e.created_at) AS last_used,
             MAX(e.rowid) AS last_row, COUNT(*) AS uses
      FROM food_log_entries e JOIN $table s ON s.id = e.$entryColumn
      WHERE e.entry_type = '$kind' AND s.archived = 0 $where
      GROUP BY s.id''';
    final db = attachedDatabase;
    return customSelect(
      '${half('food', 'food_item_id', 'food_items')} UNION ALL '
      '${half('meal', 'meal_id', 'meals')} ORDER BY $orderBy LIMIT ?',
      variables: [
        if (since != null) ...[
          Variable<String>(since),
          Variable<String>(since),
        ],
        Variable<int>(limit),
      ],
      readsFrom: {foodLogEntries, db.foodItems, db.meals},
    ).watch().asyncMap((rows) async {
      final sources = <RecentSource>[];
      for (final row in rows) {
        final id = row.read<String>('id');
        if (row.read<String>('kind') == 'food') {
          final food = await db.foodDao.findById(id);
          if (food != null) sources.add(RecentSource.food(food));
        } else {
          final meal = await db.mealDao.findById(id);
          if (meal != null) sources.add(RecentSource.meal(meal));
        }
      }
      return sources;
    });
  }
}

/// A catalog food or meal that has been logged before: exactly one of [food]
/// and [meal] is set.
class RecentSource {
  const RecentSource.food(FoodItem this.food) : meal = null;
  const RecentSource.meal(Meal this.meal) : food = null;

  final FoodItem? food;
  final Meal? meal;

  String get id => food?.id ?? meal!.id;
  String get name => food?.name ?? meal!.name;
}
