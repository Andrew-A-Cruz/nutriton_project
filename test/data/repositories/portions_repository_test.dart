import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/backup/backup_codec.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/preferences/user_preferences.dart';
import 'package:nutriton_project/data/remote/open_food_facts_client.dart';
import 'package:nutriton_project/data/repositories/catalog_repository.dart';

void main() {
  late AppDatabase db;
  late CatalogRepository catalog;
  late String oats;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    catalog = CatalogRepository(db);
    oats = await catalog.createFood(
      name: 'Oats',
      perServing: const Macros(calories: 150, protein: 5, carbs: 27, fat: 3),
      servingWeightG: 40,
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('portions are added, listed smallest first and removed', () async {
    final cup = await catalog.addServing(oats, name: ' cup ', weightG: 80);
    await catalog.addServing(oats, name: 'spoon', weightG: 10);
    final list = await catalog.watchServings(oats).first;
    expect([for (final p in list) p.name], ['spoon', 'cup']);

    await catalog.removeServing(cup);
    expect(await catalog.watchServings(oats).first, hasLength(1));
  });

  test('a blank name or a non-positive weight is refused', () {
    expect(
      () => catalog.addServing(oats, name: '  ', weightG: 10),
      throwsArgumentError,
    );
    expect(
      () => catalog.addServing(oats, name: 'cup', weightG: 0),
      throwsArgumentError,
    );
  });

  test('backups keep portions and read older files without them', () async {
    await catalog.addServing(oats, name: 'cup', weightG: 80);
    const codec = BackupCodec();
    final data = BackupData(
      foodItems: await db.select(db.foodItems).get(),
      foodServings: await db.select(db.foodServings).get(),
      settings: UserSettings(),
    );
    final json = jsonDecode(codec.encode(data)) as Map<String, dynamic>;
    expect((json['food_servings'] as List).single['name'], 'cup');
    expect(codec.decode(jsonEncode(json)).foodServings.single.weightG, 80);

    json.remove('food_servings');
    expect(codec.decode(jsonEncode(json)).foodServings, isEmpty);
  });

  test('a lookup keeps the label serving text', () {
    final result = parseOffProduct({
      'product_name': 'Milk',
      'serving_quantity': 240,
      'serving_size': '1 cup (240 ml)',
      'nutriments': {'energy-kcal_100g': 60},
    })!;
    expect(result.servingText, '1 cup (240 ml)');
    expect(
      parseOffProduct({
        'product_name': 'Milk',
        'serving_size': '1 cup',
      })!.servingText,
      isNull,
    );
  });
}
