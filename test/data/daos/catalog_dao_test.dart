import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/data/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  FoodItemsCompanion food(String id, String name, {bool archived = false}) =>
      FoodItemsCompanion.insert(
        id: id,
        name: name,
        calories: 100,
        protein: 10,
        carbs: 5,
        fat: 2,
        servingWeightG: 100,
      ).copyWith(archived: Value(archived));

  group('FoodDao', () {
    test('insert then findById returns the row with defaults', () async {
      await db.foodDao.insertFood(food('f1', 'Chicken breast'));

      final row = await db.foodDao.findById('f1');
      expect(row, isNotNull);
      expect(row!.name, 'Chicken breast');
      expect(row.servingWeightG, 100);
      expect(row.displayUnit, 'g');
      expect(row.archived, isFalse);
    });

    test('findById returns null for an unknown id', () async {
      expect(await db.foodDao.findById('nope'), isNull);
    });

    test('updateFood changes only the given fields', () async {
      await db.foodDao.insertFood(food('f1', 'Rice'));

      await db.foodDao.updateFood(
        'f1',
        const FoodItemsCompanion(
          calories: Value(130),
          displayUnit: Value('oz'),
        ),
      );

      final row = await db.foodDao.findById('f1');
      expect(row!.calories, 130);
      expect(row.displayUnit, 'oz');
      expect(row.name, 'Rice');
    });

    test('search treats % and _ as literal characters', () async {
      await db.foodDao.insertFood(food('f1', '100% juice'));
      await db.foodDao.insertFood(food('f2', 'Rice'));
      await db.foodDao.insertFood(food('f3', 'snack_bar'));
      await db.foodDao.insertFood(food('f4', 'snackXbar'));
      await db.foodDao.insertFood(food(r'f5', r'back\slash'));

      expect((await db.foodDao.findActive(search: '%')).map((f) => f.id), [
        'f1',
      ]);
      expect((await db.foodDao.findActive(search: '_')).map((f) => f.id), [
        'f3',
      ]);
      expect(
        (await db.foodDao.findActive(search: 'snack_b')).map((f) => f.id),
        ['f3'],
      );
      expect((await db.foodDao.findActive(search: r'\')).map((f) => f.id), [
        'f5',
      ]);
      expect(await db.foodDao.findActive(search: '%%'), isEmpty);
    });

    test(
      'search matches part of the name and ignores archived items',
      () async {
        await db.foodDao.insertFood(food('f1', 'Chicken breast'));
        await db.foodDao.insertFood(food('f2', 'Rice'));
        await db.foodDao.insertFood(food('f3', 'Chicken thigh'));
        await db.foodDao.setArchived('f3', archived: true);

        final results = await db.foodDao.findActive(search: 'chick');
        expect(results.map((f) => f.id), ['f1']);

        final all = await db.foodDao.findActive();
        expect(all.map((f) => f.name), ['Chicken breast', 'Rice']);
      },
    );

    test('archived items are still findable by id', () async {
      await db.foodDao.insertFood(food('f1', 'Oats'));
      await db.foodDao.setArchived('f1', archived: true);

      expect((await db.foodDao.findById('f1'))!.archived, isTrue);
    });

    test('watchActive emits again when a food is added', () async {
      final emissions = <List<String>>[];
      final sub = db.foodDao.watchActive().listen(
        (rows) => emissions.add(rows.map((f) => f.id).toList()),
      );

      await db.foodDao.insertFood(food('f1', 'Oats'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(emissions.last, ['f1']);
    });

    test('deleteFood removes an unused food', () async {
      await db.foodDao.insertFood(food('f1', 'Oats'));
      await db.foodDao.deleteFood('f1');

      expect(await db.foodDao.findById('f1'), isNull);
    });

    test('CHECK constraints reject a zero serving weight', () async {
      await expectLater(
        db.foodDao.insertFood(
          FoodItemsCompanion.insert(
            id: 'bad',
            name: 'Bad food',
            calories: 1,
            protein: 1,
            carbs: 1,
            fat: 1,
            servingWeightG: 0,
          ),
        ),
        throwsA(isA<SqliteException>()),
      );
    });

    test('CHECK constraints reject negative macros', () async {
      await expectLater(
        db.foodDao.insertFood(
          FoodItemsCompanion.insert(
            id: 'bad',
            name: 'Bad food',
            calories: -1,
            protein: 1,
            carbs: 1,
            fat: 1,
            servingWeightG: 10,
          ),
        ),
        throwsA(isA<SqliteException>()),
      );
    });
  });
}
