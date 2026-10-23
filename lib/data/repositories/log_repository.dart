import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/date_key.dart';
import '../../core/nutrition_math.dart';
import '../database/app_database.dart';
import 'catalog_repository.dart';

const _uuid = Uuid();

/// A deleted log entry with everything needed to put it back: its breakdown
/// rows and the scheduled-meal outcomes that pointed at it.
class DeletedLogEntry {
  const DeletedLogEntry({
    required this.entry,
    required this.items,
    required this.outcomeIds,
    this.rowId,
  });

  final FoodLogEntry entry;
  final List<FoodLogEntryItem> items;
  final List<String> outcomeIds;

  /// The entry's rowid, so undo keeps same-second entries in order.
  final int? rowId;
}

/// Writes to the daily food log. Every entry stores a snapshot of its macros
/// at the time it was logged, so later catalog edits do not change history.
class LogRepository {
  LogRepository(this._db);

  final AppDatabase _db;

  Stream<List<FoodLogEntry>> watchEntriesForDate(String logDate) =>
      _db.logDao.watchEntriesForDate(logDate);

  Stream<List<FoodLogEntryItem>> watchEntryItems(String entryId) =>
      _db.logDao.watchEntryItems(entryId);

  /// Active catalog foods logged before, most recent first.
  Stream<List<FoodItem>> watchRecentFoods({int limit = 8}) =>
      _db.logDao.watchRecentFoods(limit: limit);

  /// Copies every entry of [fromDate] onto [toDate] ('yyyy-MM-dd') as new
  /// entries, with their stored snapshots and meal breakdowns (not recomputed
  /// from the catalog). Existing entries on [toDate] are kept. Returns how
  /// many entries were copied.
  Future<int> copyDay({required String fromDate, required String toDate}) {
    if (fromDate == toDate) {
      throw ArgumentError('cannot copy a day onto itself');
    }
    return _db.transaction(() async {
      final entries = await _db.logDao.findEntriesForDate(fromDate);
      if (entries.isEmpty) return 0;
      final items = await _db.logDao.findItemsForEntries([
        for (final e in entries) e.id,
      ]);
      final now = DateTime.now();
      for (final e in entries) {
        final newId = _uuid.v4();
        await _db.logDao.insertEntry(
          FoodLogEntriesCompanion.insert(
            id: newId,
            logDate: toDate,
            createdAt: now,
            entryType: e.entryType,
            name: e.name,
            calories: e.calories,
            protein: e.protein,
            carbs: e.carbs,
            fat: e.fat,
            foodItemId: Value(e.foodItemId),
            mealId: Value(e.mealId),
            servings: Value(e.servings),
          ),
        );
        final breakdown = [
          for (final i in items)
            if (i.entryId == e.id)
              FoodLogEntryItemsCompanion.insert(
                id: _uuid.v4(),
                entryId: newId,
                foodItemId: Value(i.foodItemId),
                name: i.name,
                weightG: i.weightG,
                calories: i.calories,
                protein: i.protein,
                carbs: i.carbs,
                fat: i.fat,
              ),
        ];
        if (breakdown.isNotEmpty) await _db.logDao.insertEntryItems(breakdown);
      }
      return entries.length;
    });
  }

  /// Logs [servings] of a catalog food for [logDate] ('yyyy-MM-dd').
  Future<String> logFood({
    required String logDate,
    required FoodItem food,
    required double servings,
  }) async {
    _checkServings(servings);
    final id = _uuid.v4();
    final totals = scaleByServings(_perServing(food), servings);
    await _db.logDao.insertEntry(
      FoodLogEntriesCompanion.insert(
        id: id,
        logDate: logDate,
        createdAt: DateTime.now(),
        entryType: 'food',
        name: food.name,
        calories: totals.calories,
        protein: totals.protein,
        carbs: totals.carbs,
        fat: totals.fat,
        foodItemId: Value(food.id),
        servings: Value(servings),
      ),
    );
    return id;
  }

  /// Logs a meal as eaten: [items] may differ from the template. Writes the
  /// entry and its breakdown in one transaction. If [updateTemplate] is true,
  /// the meal's catalog items are replaced with [items] in the same transaction.
  Future<String> logMeal({
    required String logDate,
    required Meal meal,
    required List<MealItemInput> items,
    bool updateTemplate = false,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError('a logged meal needs at least one item');
    }
    final entryId = _uuid.v4();
    await _db.transaction(() async {
      final snapshots = <FoodLogEntryItemsCompanion>[];
      final foods = <String, FoodItem>{};
      for (final item in items) {
        if (!item.weightG.isFinite || item.weightG <= 0) {
          throw ArgumentError.value(item.weightG, 'weightG', 'must be > 0');
        }
        var food = foods[item.foodItemId];
        if (food == null) {
          food = await _db.foodDao.findById(item.foodItemId);
          if (food == null) {
            throw StateError('Unknown food item ${item.foodItemId}');
          }
          foods[item.foodItemId] = food;
        }
        final macros = CatalogRepository.macrosForWeight(food, item.weightG);
        snapshots.add(
          FoodLogEntryItemsCompanion.insert(
            id: _uuid.v4(),
            entryId: entryId,
            foodItemId: Value(food.id),
            name: food.name,
            weightG: item.weightG,
            calories: macros.calories,
            protein: macros.protein,
            carbs: macros.carbs,
            fat: macros.fat,
          ),
        );
      }

      final total = sumMacros(snapshots.map(_macrosOfSnapshot));
      await _db.logDao.insertEntry(
        FoodLogEntriesCompanion.insert(
          id: entryId,
          logDate: logDate,
          createdAt: DateTime.now(),
          entryType: 'meal',
          name: meal.name,
          calories: total.calories,
          protein: total.protein,
          carbs: total.carbs,
          fat: total.fat,
          mealId: Value(meal.id),
        ),
      );
      await _db.logDao.insertEntryItems(snapshots);

      if (updateTemplate) {
        // Nested transaction: drift turns this into a savepoint.
        await CatalogRepository(
          _db,
        ).updateMeal(meal.id, name: meal.name, items: items);
      }
    });
    return entryId;
  }

  /// Logs a one-off food that is not saved to the catalog.
  Future<String> logAdhoc({
    required String logDate,
    required String name,
    required Macros macros,
  }) async {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
    }
    CatalogRepository.validateMacros(macros);
    final id = _uuid.v4();
    await _db.logDao.insertEntry(
      FoodLogEntriesCompanion.insert(
        id: id,
        logDate: logDate,
        createdAt: DateTime.now(),
        entryType: 'adhoc',
        name: name.trim(),
        calories: macros.calories,
        protein: macros.protein,
        carbs: macros.carbs,
        fat: macros.fat,
      ),
    );
    return id;
  }

  /// Changes the serving count of a food entry. The snapshot is rescaled by
  /// the ratio of new to old servings, so it does not depend on the catalog.
  Future<void> updateServings(
    String entryId, {
    required double servings,
  }) async {
    _checkServings(servings);
    await _db.transaction(() async {
      final entry = await _db.logDao.findEntry(entryId);
      if (entry == null) throw StateError('No log entry $entryId');
      final oldServings = entry.servings;
      if (entry.entryType != 'food' ||
          oldServings == null ||
          oldServings <= 0) {
        throw StateError('Entry $entryId is not a food entry with servings');
      }
      final totals = _macrosOfEntry(entry).times(servings / oldServings);
      await _db.logDao.updateEntry(
        entryId,
        FoodLogEntriesCompanion(
          servings: Value(servings),
          calories: Value(totals.calories),
          protein: Value(totals.protein),
          carbs: Value(totals.carbs),
          fat: Value(totals.fat),
        ),
      );
    });
  }

  /// Changes the name and macros of a one-off entry. Other entry types keep
  /// their snapshots, so they are rejected.
  Future<void> updateAdhoc(
    String entryId, {
    required String name,
    required Macros macros,
  }) async {
    if (name.trim().isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty');
    }
    CatalogRepository.validateMacros(macros);
    await _db.transaction(() async {
      final entry = await _db.logDao.findEntry(entryId);
      if (entry == null) throw StateError('No log entry $entryId');
      if (entry.entryType != 'adhoc') {
        throw StateError('Entry $entryId is not a one-off entry');
      }
      await _db.logDao.updateEntry(
        entryId,
        FoodLogEntriesCompanion(
          name: Value(name.trim()),
          calories: Value(macros.calories),
          protein: Value(macros.protein),
          carbs: Value(macros.carbs),
          fat: Value(macros.fat),
        ),
      );
    });
  }

  /// Moves an entry of any type to [logDate] ('yyyy-MM-dd').
  Future<void> moveEntry(String entryId, String logDate) async {
    dateFromKey(logDate); // throws FormatException for a malformed key
    final changed = await _db.logDao.updateEntryDate(entryId, logDate);
    if (changed == 0) throw StateError('No log entry $entryId');
  }

  /// Deletes an entry; its breakdown rows cascade.
  Future<void> deleteEntry(String entryId) => _db.logDao.deleteEntry(entryId);

  /// Deletes an entry like [deleteEntry] and returns what [restoreEntry] needs
  /// to undo it, or null if there was no such entry.
  Future<DeletedLogEntry?> deleteEntryForUndo(String entryId) {
    return _db.transaction(() async {
      final entry = await _db.logDao.findEntry(entryId);
      if (entry == null) return null;
      final items = await _db.logDao.findEntryItems(entryId);
      final rowId = await _db.logDao.findRowId(entryId);
      // Deleting the entry nulls these provenance links; keep them to relink.
      final outcomes = await _db.scheduledMealDao.findOutcomesForEntry(entryId);
      await _db.logDao.deleteEntry(entryId);
      return DeletedLogEntry(
        entry: entry,
        items: items,
        outcomeIds: [for (final o in outcomes) o.id],
        rowId: rowId,
      );
    });
  }

  /// Puts back an entry deleted by [deleteEntryForUndo], with the same id,
  /// date, macros and breakdown. Catalog links to foods or meals that have
  /// since been removed are dropped rather than failing the restore.
  Future<void> restoreEntry(DeletedLogEntry deleted) {
    return _db.transaction(() async {
      final e = deleted.entry;
      if (await _db.logDao.findEntry(e.id) != null) return;
      final liveFoods = <String, String?>{};
      Future<String?> liveFood(String? id) async {
        if (id == null) return null;
        if (!liveFoods.containsKey(id)) {
          liveFoods[id] = await _db.foodDao.findById(id) == null ? null : id;
        }
        return liveFoods[id];
      }

      final mealId = e.mealId;
      final liveMeal =
          mealId != null && await _db.mealDao.findById(mealId) != null;
      await _db.logDao.insertEntry(
        e
            .toCompanion(true)
            .copyWith(
              foodItemId: Value(await liveFood(e.foodItemId)),
              mealId: Value(liveMeal ? mealId : null),
            ),
      );
      final items = <FoodLogEntryItemsCompanion>[];
      for (final i in deleted.items) {
        items.add(
          i
              .toCompanion(true)
              .copyWith(foodItemId: Value(await liveFood(i.foodItemId))),
        );
      }
      final rowId = deleted.rowId;
      if (rowId != null) await _db.logDao.restoreRowId(e.id, rowId);
      if (items.isNotEmpty) await _db.logDao.insertEntryItems(items);
      for (final outcomeId in deleted.outcomeIds) {
        await _db.scheduledMealDao.setOutcomeEntry(outcomeId, e.id);
      }
    });
  }

  /// Servings must be a finite number above zero; anything else would store
  /// infinite or NaN macros.
  static void _checkServings(double servings) {
    if (!servings.isFinite || servings <= 0) {
      throw ArgumentError.value(servings, 'servings', 'must be finite and > 0');
    }
  }

  static Macros _perServing(FoodItem food) => Macros(
    calories: food.calories,
    protein: food.protein,
    carbs: food.carbs,
    fat: food.fat,
  );

  static Macros _macrosOfEntry(FoodLogEntry entry) => Macros(
    calories: entry.calories,
    protein: entry.protein,
    carbs: entry.carbs,
    fat: entry.fat,
  );

  static Macros _macrosOfSnapshot(FoodLogEntryItemsCompanion item) => Macros(
    calories: item.calories.value,
    protein: item.protein.value,
    carbs: item.carbs.value,
    fat: item.fat.value,
  );
}
