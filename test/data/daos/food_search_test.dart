import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/data/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    for (final (id, name, brand) in [
      ('f1', 'Chicken breast, grilled', null),
      ('f2', 'Chicken thigh', null),
      ('f3', 'Rolled oats', 'Acme'),
      ('f4', 'Oat milk', 'Barista Co'),
      ('f5', '100% juice', null),
    ]) {
      await db.foodDao.insertFood(
        FoodItemsCompanion.insert(
          id: id,
          name: name,
          calories: 100,
          protein: 1,
          carbs: 1,
          fat: 1,
          servingWeightG: 100,
          brand: Value(brand),
        ),
      );
    }
  });

  tearDown(() async {
    await db.close();
  });

  Future<List<String>> search(String text) async => [
    for (final f in await db.foodDao.findActive(search: text)) f.id,
  ];

  Future<void> logAt(String foodId, DateTime at) => db.logDao.insertEntry(
    FoodLogEntriesCompanion.insert(
      id: 'e-$foodId-${at.millisecondsSinceEpoch}',
      logDate: '2026-11-01',
      createdAt: at,
      entryType: 'food',
      name: foodId,
      calories: 100,
      protein: 1,
      carbs: 1,
      fat: 1,
      foodItemId: Value(foodId),
      servings: const Value(1),
    ),
  );

  test('every word must match, in any order', () async {
    expect(await search('chick breast'), ['f1']);
    expect(await search('grilled chicken'), ['f1']);
    expect(await search('chicken'), unorderedEquals(['f1', 'f2']));
    expect(await search('chicken oats'), isEmpty);
  });

  test('the brand is searched too', () async {
    expect(await search('acme'), ['f3']);
    expect(await search('acme oats'), ['f3']);
    expect(await search('oat'), unorderedEquals(['f3', 'f4']));
  });

  test('LIKE wildcards are matched literally', () async {
    expect(await search('100%'), ['f5']);
    expect(await search('%'), ['f5']);
    expect(await search('_'), isEmpty);
  });

  test('a search lists the most recently logged foods first', () async {
    expect(await search('chicken'), ['f1', 'f2']);
    await logAt('f2', DateTime(2026, 11, 1, 8));
    expect(await search('chicken'), ['f2', 'f1']);
    await logAt('f1', DateTime(2026, 11, 1, 12));
    expect(await search('chicken'), ['f1', 'f2']);
  });

  test('without a search the list stays alphabetical', () async {
    await logAt('f4', DateTime(2026, 11, 1, 8));
    expect(await search(''), ['f5', 'f1', 'f2', 'f4', 'f3']);
  });
}
