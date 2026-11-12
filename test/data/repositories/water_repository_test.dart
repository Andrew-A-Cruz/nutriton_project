import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/water.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/water_repository.dart';

void main() {
  late AppDatabase db;
  late WaterRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = WaterRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('adding builds one row per day', () async {
    expect(await repo.add('2026-11-11', 250), 250);
    expect(await repo.add('2026-11-11', 250), 500);
    await repo.add('2026-11-12', 250);
    final rows = await db.select(db.waterLog).get();
    expect(
      {for (final r in rows) r.logDate: r.amountMl},
      {'2026-11-11': 500.0, '2026-11-12': 250.0},
    );
  });

  test('taking the last glass away removes the row', () async {
    await repo.add('2026-11-11', 250);
    expect(await repo.add('2026-11-11', -250), 0);
    expect(await repo.add('2026-11-11', -250), 0);
    expect(await db.select(db.waterLog).get(), isEmpty);
  });

  test('the total stops at the cap', () async {
    expect(await repo.add('2026-11-11', maxWaterMl + 500), maxWaterMl);
  });

  test('a non-finite amount is refused', () {
    expect(() => repo.add('2026-11-11', double.nan), throwsArgumentError);
  });

  test('watchAmount emits 0, the total and 0 again', () async {
    final values = <double>[];
    final sub = repo.watchAmount('2026-11-11').listen(values.add);
    addTearDown(sub.cancel);
    Future<void> pump() =>
        Future<void>.delayed(const Duration(milliseconds: 20));

    await pump();
    await repo.add('2026-11-11', 250);
    await pump();
    await repo.add('2026-11-11', -250);
    await pump();
    expect(values, [0, 250, 0]);
  });

  test('watchRange returns only the days in range, oldest first', () async {
    await repo.add('2026-11-12', 500);
    await repo.add('2026-11-01', 250);
    await repo.add('2026-11-10', 750);
    expect(await repo.watchRange('2026-11-05', '2026-11-12').first, [750, 500]);
  });
}
