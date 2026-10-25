import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/summary_repository.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> entry(String id, String date) => db.logDao.insertEntry(
    FoodLogEntriesCompanion.insert(
      id: id,
      logDate: date,
      createdAt: DateTime(2026, 1, 1),
      entryType: 'adhoc',
      name: 'Thing $id',
      calories: 100,
      protein: 1,
      carbs: 1,
      fat: 1,
    ),
  );

  test('watchLoggedDatesUpTo is distinct, newest first and capped', () async {
    await entry('a', '2026-10-20');
    await entry('b', '2026-10-20');
    await entry('c', '2026-10-18');
    await entry('d', '2026-10-25');

    expect(await db.summaryDao.watchLoggedDatesUpTo('2026-10-21').first, [
      '2026-10-20',
      '2026-10-18',
    ]);
  });

  test('watchStreak follows the log', () async {
    await entry('a', '2026-10-20');
    await entry('b', '2026-10-19');
    final streaks = SummaryRepository(db).watchStreak('2026-10-21');
    expect(await streaks.first, 2);
  });
}
