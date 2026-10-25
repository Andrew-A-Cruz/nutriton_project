import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/body_weight_repository.dart';

void main() {
  late AppDatabase db;
  late BodyWeightRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = BodyWeightRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('setting a day twice keeps one row with the newer value', () async {
    await repo.setWeight('2026-10-20', 80.5);
    await repo.setWeight('2026-10-20', 80.1);
    final rows = await db.select(db.bodyWeights).get();
    expect(rows, hasLength(1));
    expect(rows.single.weightKg, 80.1);
  });

  test('clearing a day removes it and ignores an empty day', () async {
    await repo.setWeight('2026-10-20', 80);
    await repo.clearWeight('2026-10-20');
    await repo.clearWeight('2026-10-21');
    expect(await db.select(db.bodyWeights).get(), isEmpty);
  });

  test('watchWeight emits the value, its replacement and null', () async {
    final values = <double?>[];
    final sub = repo.watchWeight('2026-10-20').listen(values.add);
    addTearDown(sub.cancel);
    Future<void> pump() =>
        Future<void>.delayed(const Duration(milliseconds: 20));

    await pump();
    await repo.setWeight('2026-10-20', 80);
    await pump();
    await repo.setWeight('2026-10-20', 79.5);
    await pump();
    await repo.clearWeight('2026-10-20');
    await pump();
    expect(values, [null, 80, 79.5, null]);
  });

  test('watchRange returns only the range, oldest first', () async {
    await repo.setWeight('2026-10-22', 79);
    await repo.setWeight('2026-10-18', 81);
    await repo.setWeight('2026-10-20', 80);
    await repo.setWeight('2026-10-25', 78);
    final out = await repo.watchRange('2026-10-19', '2026-10-24').first;
    expect(out, [
      (date: '2026-10-20', kg: 80.0),
      (date: '2026-10-22', kg: 79.0),
    ]);
  });

  test('the range is inclusive at both ends', () async {
    await repo.setWeight('2026-10-19', 81);
    await repo.setWeight('2026-10-24', 78);
    final out = await repo.watchRange('2026-10-19', '2026-10-24').first;
    expect(out.map((r) => r.date), ['2026-10-19', '2026-10-24']);
  });

  test('rejects weights outside the accepted range', () async {
    expect(() => repo.setWeight('2026-10-20', 0), throwsArgumentError);
    expect(() => repo.setWeight('2026-10-20', 10), throwsArgumentError);
    expect(() => repo.setWeight('2026-10-20', 600), throwsArgumentError);
    expect(() => repo.setWeight('2026-10-20', double.nan), throwsArgumentError);
    expect(await db.select(db.bodyWeights).get(), isEmpty);
  });
}
