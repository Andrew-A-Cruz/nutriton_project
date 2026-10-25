import '../../core/date_key.dart';
import '../backup/backup_codec.dart';
import '../database/app_database.dart';
import '../preferences/user_preferences.dart';

export '../backup/backup_codec.dart' show BackupData, BackupException;

/// Exports all app data to JSON and replaces it from JSON. Both run inside one
/// database transaction, so an export is a consistent snapshot and a failed
/// import leaves the existing data untouched.
class BackupRepository {
  BackupRepository(
    this._db,
    this._prefs, {
    BackupCodec codec = const BackupCodec(),
  }) : _codec = codec;

  final AppDatabase _db;
  final UserPreferences _prefs;
  final BackupCodec _codec;

  /// Suggested file name, e.g. `nutriton-backup-2026-10-21.json`.
  static String fileNameFor(DateTime date) =>
      'nutriton-backup-${dateKey(date)}.json';

  Future<String> exportJson() {
    return _db.transaction(() async {
      return _codec.encode(
        BackupData(
          foodItems: await _db.select(_db.foodItems).get(),
          meals: await _db.select(_db.meals).get(),
          mealFoodItems: await _db.select(_db.mealFoodItems).get(),
          logEntries: await _db.select(_db.foodLogEntries).get(),
          logEntryItems: await _db.select(_db.foodLogEntryItems).get(),
          scheduledMeals: await _db.select(_db.scheduledMeals).get(),
          scheduledMealOutcomes: await _db
              .select(_db.scheduledMealOutcomes)
              .get(),
          bodyWeights: await _db.select(_db.bodyWeights).get(),
          settings: _prefs.read(),
        ),
      );
    });
  }

  /// Parses and validates [json] without touching any data. Throws
  /// [BackupException] if the file is unusable.
  BackupData readBackup(String json) => _codec.decode(json);

  /// [readBackup] then [restore], for a file given as text.
  Future<UserSettings> importJson(String json) async =>
      restore(readBackup(json));

  /// Replaces every row and the preferences with [data]. Throws
  /// [BackupException] if the data breaks a database rule (the transaction then
  /// rolls back and nothing changes, preferences included). Returns the
  /// restored preferences.
  Future<UserSettings> restore(BackupData data) async {
    try {
      await _db.transaction(() async {
        // Children first, so no delete trips a foreign key.
        await _db.delete(_db.bodyWeights).go();
        await _db.delete(_db.scheduledMealOutcomes).go();
        await _db.delete(_db.scheduledMeals).go();
        await _db.delete(_db.foodLogEntryItems).go();
        await _db.delete(_db.foodLogEntries).go();
        await _db.delete(_db.mealFoodItems).go();
        await _db.delete(_db.meals).go();
        await _db.delete(_db.foodItems).go();

        // Parents first.
        await _db.batch((b) {
          b.insertAll(_db.foodItems, data.foodItems);
          b.insertAll(_db.meals, data.meals);
          b.insertAll(_db.mealFoodItems, data.mealFoodItems);
          b.insertAll(_db.foodLogEntries, data.logEntries);
          b.insertAll(_db.foodLogEntryItems, data.logEntryItems);
          b.insertAll(_db.scheduledMeals, data.scheduledMeals);
          b.insertAll(_db.scheduledMealOutcomes, data.scheduledMealOutcomes);
          b.insertAll(_db.bodyWeights, data.bodyWeights);
        });
      });
    } on Exception {
      throw BackupException(
        "The backup contains data that breaks the app's rules, "
        'so nothing was changed.',
      );
    }
    await _prefs.write(data.settings);
    return data.settings;
  }
}
