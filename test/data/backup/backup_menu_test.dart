import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/preferences/user_preferences.dart';
import 'package:nutriton_project/data/repositories/backup_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Backups and the restaurant menu columns added in schema v14. The backup
/// format version stays at 1: both keys are optional on read.
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
    Future<void> food(String id, String? menuItemId, int? menuVersion) =>
        source.foodDao.insertFood(
          FoodItemsCompanion.insert(
            id: id,
            name: 'Food $id',
            calories: 100,
            protein: 1,
            carbs: 2,
            fat: 3,
            servingWeightG: 50,
            menuItemId: Value(menuItemId),
            menuVersion: Value(menuVersion),
            weightUnknown: Value(id == 'untouched'),
          ),
        );
    await food('untouched', 'example-burger/fries-medium', 3);
    await food('edited', 'example-burger/cheeseburger', null);
    await food('own', null, null);
  });

  tearDown(() async {
    await source.close();
    await target.close();
  });

  Future<Map<String, (String?, int?)>> menuColumns(AppDatabase db) async => {
    for (final f in await db.select(db.foodItems).get())
      f.id: (f.menuItemId, f.menuVersion),
  };

  test('the file carries the menu columns; version stays 1', () async {
    final json =
        jsonDecode(await sourceRepo.exportJson()) as Map<String, dynamic>;
    expect(json['version'], 1);
    final food = (json['food_items'] as List).firstWhere(
      (f) => (f as Map)['id'] == 'untouched',
    );
    expect((food as Map)['menuItemId'], 'example-burger/fries-medium');
    expect(food['menuVersion'], 3);
    expect(food['weightUnknown'], isTrue);
  });

  test('a round trip keeps them, null ones included', () async {
    await targetRepo.importJson(await sourceRepo.exportJson());
    expect(await menuColumns(target), {
      'untouched': ('example-burger/fries-medium', 3),
      'edited': ('example-burger/cheeseburger', null),
      'own': (null, null),
    });
    final foods = await target.select(target.foodItems).get();
    expect(
      {for (final f in foods) f.id: f.weightUnknown},
      {'untouched': true, 'edited': false, 'own': false},
    );
  });

  test('a file without the keys imports with both null', () async {
    final json =
        jsonDecode(await sourceRepo.exportJson()) as Map<String, dynamic>;
    for (final f in json['food_items'] as List) {
      (f as Map)
        ..remove('menuItemId')
        ..remove('menuVersion')
        ..remove('weightUnknown');
    }
    await targetRepo.importJson(jsonEncode(json));
    expect(await menuColumns(target), {
      'untouched': (null, null),
      'edited': (null, null),
      'own': (null, null),
    });
    final foods = await target.select(target.foodItems).get();
    expect(foods.every((f) => !f.weightUnknown), isTrue);
  });

  test('the real version 1 fixture still imports', () async {
    final text = File(
      'test/data/backup/fixtures/backup_v1.json',
    ).readAsStringSync();
    await targetRepo.importJson(text);
    final foods = await target.select(target.foodItems).get();
    expect(foods, isNotEmpty);
    expect(
      foods.every(
        (f) =>
            f.menuItemId == null && f.menuVersion == null && !f.weightUnknown,
      ),
      isTrue,
    );
  });
}
