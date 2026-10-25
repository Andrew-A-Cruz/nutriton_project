import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/preferences/user_preferences.dart';
import 'package:nutriton_project/data/repositories/backup_repository.dart';
import 'package:nutriton_project/data/repositories/catalog_repository.dart';
import 'package:nutriton_project/data/repositories/log_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Backups and the fiber, sugar and sodium columns added in M13. The backup
/// format version stays at 1: a missing nullable column reads as null.
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase source;
  late AppDatabase target;
  late BackupRepository sourceRepo;
  late BackupRepository targetRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = UserPreferences(await SharedPreferences.getInstance());
    source = AppDatabase(NativeDatabase.memory());
    target = AppDatabase(NativeDatabase.memory());
    sourceRepo = BackupRepository(source, prefs);
    targetRepo = BackupRepository(target, prefs);

    final catalog = CatalogRepository(source);
    final riceId = await catalog.createFood(
      name: 'Rice',
      perServing: const Macros(
        calories: 130,
        protein: 3,
        carbs: 28,
        fat: 0.3,
        fiber: 0.4,
        sodium: 1,
      ),
      servingWeightG: 100,
    );
    await catalog.createFood(
      name: 'Chicken',
      perServing: const Macros(calories: 165, protein: 31, carbs: 0, fat: 3.6),
      servingWeightG: 100,
    );
    final rice = (await catalog.findFood(riceId))!;
    final log = LogRepository(source);
    await log.logFood(logDate: '2026-10-20', food: rice, servings: 2);
    await log.logAdhoc(
      logDate: '2026-10-20',
      name: 'Cookie',
      macros: const Macros(calories: 90, protein: 1, carbs: 15, fat: 3),
    );
  });

  tearDown(() async {
    await source.close();
    await target.close();
  });

  Future<Map<String, dynamic>> export() async =>
      jsonDecode(await sourceRepo.exportJson()) as Map<String, dynamic>;

  const columns = ['fiber', 'sugar', 'sodium'];

  test('recorded values and nulls round-trip', () async {
    final json = await export();
    expect(json['version'], 1);

    await targetRepo.importJson(jsonEncode(json));
    final foods = {
      for (final f in await target.select(target.foodItems).get()) f.name: f,
    };
    expect(foods['Rice']!.fiber, 0.4);
    expect(foods['Rice']!.sugar, isNull);
    expect(foods['Rice']!.sodium, 1);
    expect(foods['Chicken']!.sodium, isNull);

    final entries = {
      for (final e in await target.select(target.foodLogEntries).get())
        e.name: e,
    };
    expect(entries['Rice']!.fiber, closeTo(0.8, 1e-9));
    expect(entries['Rice']!.sodium, 2);
    expect(entries['Cookie']!.fiber, isNull);
  });

  test('a file from before M13 (no nutrient keys) imports as null', () async {
    final json = await export();
    for (final table in [
      'food_items',
      'food_log_entries',
      'food_log_entry_items',
    ]) {
      for (final row in json[table] as List) {
        for (final c in columns) {
          (row as Map).remove(c);
        }
      }
    }

    await targetRepo.importJson(jsonEncode(json));
    final foods = await target.select(target.foodItems).get();
    final entries = await target.select(target.foodLogEntries).get();
    expect(foods, hasLength(2));
    expect(entries, hasLength(2));
    for (final f in foods) {
      expect((f.fiber, f.sugar, f.sodium), (null, null, null));
    }
    for (final e in entries) {
      expect((e.fiber, e.sugar, e.sodium), (null, null, null));
    }
    // The rest of the data is intact.
    expect(foods.map((f) => f.calories), containsAll([130, 165]));
  });

  test('the real version 1 fixture imports with null nutrients', () async {
    final text = File(
      'test/data/backup/fixtures/backup_v1.json',
    ).readAsStringSync();
    await targetRepo.importJson(text);

    final foods = await target.select(target.foodItems).get();
    final entries = await target.select(target.foodLogEntries).get();
    final items = await target.select(target.foodLogEntryItems).get();
    expect(foods, isNotEmpty);
    expect(entries, isNotEmpty);
    expect(items, isNotEmpty);
    expect(foods.every((f) => f.fiber == null && f.sodium == null), isTrue);
    expect(entries.every((e) => e.sugar == null && e.sodium == null), isTrue);
    expect(items.every((i) => i.fiber == null && i.sodium == null), isTrue);
  });

  test('a negative value fails the import and changes nothing', () async {
    final json = await export();
    (json['food_log_entries'] as List).first['sodium'] = -5;

    await expectLater(
      targetRepo.importJson(jsonEncode(json)),
      throwsA(isA<Object>()),
    );
    expect(await target.select(target.foodLogEntries).get(), isEmpty);
  });
}
