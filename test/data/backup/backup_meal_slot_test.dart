import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/meal_slot.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/preferences/user_preferences.dart';
import 'package:nutriton_project/data/repositories/backup_repository.dart';
import 'package:nutriton_project/data/repositories/log_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Backups and the meal_slot column added in M12. The backup format version
/// stays at 1: a missing nullable column reads as null.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase source;
  late AppDatabase target;
  late BackupRepository sourceRepo;
  late BackupRepository targetRepo;

  const macros = Macros(calories: 90, protein: 1, carbs: 15, fat: 3);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = UserPreferences(await SharedPreferences.getInstance());
    source = AppDatabase(NativeDatabase.memory());
    target = AppDatabase(NativeDatabase.memory());
    sourceRepo = BackupRepository(source, prefs);
    targetRepo = BackupRepository(target, prefs);
    final log = LogRepository(source);
    await log.logAdhoc(
      logDate: '2026-10-20',
      name: 'Cookie',
      macros: macros,
      mealSlot: MealSlot.snack,
    );
    await log.logAdhoc(logDate: '2026-10-20', name: 'Old', macros: macros);
  });

  tearDown(() async {
    await source.close();
    await target.close();
  });

  Future<Map<String, dynamic>> export() async =>
      jsonDecode(await sourceRepo.exportJson()) as Map<String, dynamic>;

  Future<Map<String?, String>> nameBySlot(AppDatabase db) async => {
    for (final e in await db.select(db.foodLogEntries).get())
      e.mealSlot: e.name,
  };

  test('a row with a mealSlot round-trips', () async {
    final json = await export();
    expect(json['version'], 1);
    final rows = json['food_log_entries'] as List;
    expect(rows.map((r) => r['mealSlot']), containsAll(['snack', null]));

    await targetRepo.importJson(jsonEncode(json));
    expect(await nameBySlot(target), {'snack': 'Cookie', null: 'Old'});
  });

  test('a file from before M12 (no mealSlot key) imports as null', () async {
    final json = await export();
    for (final row in json['food_log_entries'] as List) {
      (row as Map).remove('mealSlot');
    }
    await targetRepo.importJson(jsonEncode(json));
    final entries = await target.select(target.foodLogEntries).get();
    expect(entries, hasLength(2));
    expect(entries.every((e) => e.mealSlot == null), isTrue);
  });

  test('an invalid slot fails the import and changes nothing', () async {
    final json = await export();
    (json['food_log_entries'] as List).first['mealSlot'] = 'brunch';

    await LogRepository(target).logAdhoc(
      logDate: '2026-10-19',
      name: 'Keep me',
      macros: macros,
      mealSlot: MealSlot.lunch,
    );

    await expectLater(
      targetRepo.importJson(jsonEncode(json)),
      throwsA(isA<BackupException>()),
    );
    expect(await nameBySlot(target), {'lunch': 'Keep me'});
  });
}
