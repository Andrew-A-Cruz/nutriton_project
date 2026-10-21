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

  /// Inserts a food entry with the given calories (protein/carbs/fat fixed).
  Future<void> entry(
    String id,
    String date,
    double calories, {
    DateTime? createdAt,
  }) => db.logDao.insertEntry(
    FoodLogEntriesCompanion.insert(
      id: id,
      logDate: date,
      createdAt: createdAt ?? DateTime(2026, 1, 1),
      entryType: 'adhoc',
      name: 'Thing $id',
      calories: calories,
      protein: 10,
      carbs: 20,
      fat: 5,
    ),
  );

  group('LogDao', () {
    test('watchEntriesForDate returns only that day, oldest first', () async {
      await entry(
        'late',
        '2026-10-20',
        1,
        createdAt: DateTime(2026, 10, 20, 18),
      );
      await entry(
        'early',
        '2026-10-20',
        1,
        createdAt: DateTime(2026, 10, 20, 8),
      );
      await entry('other', '2026-10-19', 1);

      final rows = await db.logDao.watchEntriesForDate('2026-10-20').first;
      expect(rows.map((r) => r.id), ['early', 'late']);
    });

    test('entries saved in the same second keep insertion order', () async {
      final sameSecond = DateTime(2026, 10, 20, 12);
      // Ids sort the opposite way to insertion, so only rowid explains order.
      for (final id in ['z', 'm', 'a']) {
        await entry(id, '2026-10-20', 1, createdAt: sameSecond);
      }

      final rows = await db.logDao.watchEntriesForDate('2026-10-20').first;
      expect(rows.map((r) => r.id), ['z', 'm', 'a']);
    });

    test('watchEntriesForDate emits when an entry is inserted', () async {
      final emissions = <int>[];
      final sub = db.logDao
          .watchEntriesForDate('2026-10-20')
          .listen((rows) => emissions.add(rows.length));

      await entry('a', '2026-10-20', 100);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await sub.cancel();

      expect(emissions.last, 1);
    });

    test('deleting an entry cascades to its breakdown rows', () async {
      await entry('meal1', '2026-10-20', 500);
      await db.logDao.insertEntryItems([
        FoodLogEntryItemsCompanion.insert(
          id: 'row1',
          entryId: 'meal1',
          name: 'Chicken',
          weightG: 150,
          calories: 247.5,
          protein: 46.5,
          carbs: 0,
          fat: 5.4,
        ),
      ]);

      await db.logDao.deleteEntry('meal1');

      expect(await db.logDao.findEntry('meal1'), isNull);
      expect(await db.logDao.findEntryItems('meal1'), isEmpty);
    });

    test('an entry with an unknown entry_type is rejected', () async {
      await expectLater(
        db.logDao.insertEntry(
          FoodLogEntriesCompanion.insert(
            id: 'bad',
            logDate: '2026-10-20',
            createdAt: DateTime(2026),
            entryType: 'snack',
            name: 'Bad',
            calories: 1,
            protein: 1,
            carbs: 1,
            fat: 1,
          ),
        ),
        throwsA(isA<SqliteException>()),
      );
    });
  });

  group('SummaryDao.averagesForRange', () {
    test('averages only days that have entries', () async {
      await entry('a', '2026-10-01', 1000);
      await entry('b', '2026-10-01', 500); // same day: 1500 total
      await entry('c', '2026-10-03', 2000);
      // 2026-10-02 has nothing logged and must not count as zero.

      final result = await db.summaryDao.averagesForRange(
        '2026-10-01',
        '2026-10-07',
      );

      expect(result.daysLogged, 2);
      expect(result.averages!.calories, closeTo(1750, 1e-9));
      expect(result.averages!.protein, closeTo(15, 1e-9));
    });

    test('range bounds are inclusive and outside days are ignored', () async {
      await entry('before', '2026-09-30', 9999);
      await entry('start', '2026-10-01', 100);
      await entry('end', '2026-10-07', 300);
      await entry('after', '2026-10-08', 9999);

      final result = await db.summaryDao.averagesForRange(
        '2026-10-01',
        '2026-10-07',
      );

      expect(result.daysLogged, 2);
      expect(result.averages!.calories, closeTo(200, 1e-9));
    });

    test('returns no averages when nothing is logged in range', () async {
      await entry('a', '2026-09-01', 100);

      final result = await db.summaryDao.averagesForRange(
        '2026-10-01',
        '2026-10-07',
      );

      expect(result.daysLogged, 0);
      expect(result.averages, isNull);
    });
  });

  group('SummaryDao.dailyTotalsForRange', () {
    test('sums per day, oldest first', () async {
      await entry('a', '2026-10-03', 200);
      await entry('b', '2026-10-01', 100);
      await entry('c', '2026-10-01', 50);

      final days = await db.summaryDao.dailyTotalsForRange(
        '2026-10-01',
        '2026-10-03',
      );

      expect(days.map((d) => d.logDate), ['2026-10-01', '2026-10-03']);
      expect(days.first.totals.calories, 150);
      expect(days.last.totals.calories, 200);
    });
  });
}
