import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/preferences/user_preferences.dart';
import 'package:nutriton_project/data/repositories/backup_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Backups and the food barcode added in M16. The backup format version stays
/// at 1: `barcode` is optional on read.
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
    Future<void> food(String id, String name, String? barcode) =>
        source.foodDao.insertFood(
          FoodItemsCompanion.insert(
            id: id,
            name: name,
            calories: 100,
            protein: 1,
            carbs: 2,
            fat: 3,
            servingWeightG: 50,
            barcode: Value(barcode),
          ),
        );
    await food('f1', 'Soda', '4006381333931');
    await food('f2', 'Apple', null);
  });

  tearDown(() async {
    await source.close();
    await target.close();
  });

  Future<Map<String, String?>> barcodes(AppDatabase db) async => {
    for (final f in await db.select(db.foodItems).get()) f.id: f.barcode,
  };

  test('the file carries barcode on foods; version stays 1', () async {
    final json =
        jsonDecode(await sourceRepo.exportJson()) as Map<String, dynamic>;
    expect(json['version'], 1);
    final foods = json['food_items'] as List;
    expect(
      foods.firstWhere((f) => f['id'] == 'f1')['barcode'],
      '4006381333931',
    );
  });

  test('round trip restores barcodes, null ones included', () async {
    await targetRepo.importJson(await sourceRepo.exportJson());
    expect(await barcodes(target), {'f1': '4006381333931', 'f2': null});
  });

  test('a file without barcode keys imports with null barcodes', () async {
    final json =
        jsonDecode(await sourceRepo.exportJson()) as Map<String, dynamic>;
    for (final f in json['food_items'] as List) {
      (f as Map).remove('barcode');
    }
    await targetRepo.importJson(jsonEncode(json));
    expect(await barcodes(target), {'f1': null, 'f2': null});
  });

  test('the real pre-M16 version 1 fixture still imports', () async {
    final text = File(
      'test/data/backup/fixtures/backup_v1.json',
    ).readAsStringSync();
    await targetRepo.importJson(text);
    final foods = await target.select(target.foodItems).get();
    expect(foods, isNotEmpty);
    expect(foods.every((f) => f.barcode == null), isTrue);
  });
}
