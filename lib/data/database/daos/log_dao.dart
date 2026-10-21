import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/food_log_entries.dart';
import '../tables/food_log_entry_items.dart';

part 'log_dao.g.dart';

@DriftAccessor(tables: [FoodLogEntries, FoodLogEntryItems])
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

  Future<void> insertEntryItems(List<FoodLogEntryItemsCompanion> items) =>
      batch((b) => b.insertAll(foodLogEntryItems, items));

  Future<List<FoodLogEntryItem>> findEntryItems(String entryId) => (select(
    foodLogEntryItems,
  )..where((t) => t.entryId.equals(entryId))).get();

  Stream<List<FoodLogEntryItem>> watchEntryItems(String entryId) => (select(
    foodLogEntryItems,
  )..where((t) => t.entryId.equals(entryId))).watch();
}
