import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/repositories/fasting_repository.dart';

void main() {
  late AppDatabase db;
  late FastingRepository repo;
  final start = DateTime(2026, 11, 11, 20);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = FastingRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('start then end makes one finished fast', () async {
    final id = await repo.start(start);
    expect((await repo.watchActive().first)!.id, id);
    expect(await repo.watchFinished().first, isEmpty);

    await repo.end(start.add(const Duration(hours: 16)));

    expect(await repo.watchActive().first, isNull);
    final done = (await repo.watchFinished().first).single;
    expect(done.id, id);
    expect(done.endedAt!.difference(done.startedAt), const Duration(hours: 16));
  });

  test('starting while one runs keeps the first', () async {
    final first = await repo.start(start);
    final second = await repo.start(start.add(const Duration(hours: 1)));
    expect(second, first);
    expect(await db.select(db.fasts).get(), hasLength(1));
  });

  test('ending with none running does nothing', () async {
    await repo.end(start);
    expect(await db.select(db.fasts).get(), isEmpty);
  });

  test('a clock that moved back ends the fast at its start', () async {
    await repo.start(start);
    await repo.end(start.subtract(const Duration(hours: 2)));
    final done = (await repo.watchFinished().first).single;
    expect(done.endedAt, done.startedAt);
  });

  test('finished fasts come newest first, and delete removes one', () async {
    await repo.start(start);
    await repo.end(start.add(const Duration(hours: 12)));
    final later = start.add(const Duration(days: 1));
    final second = await repo.start(later);
    await repo.end(later.add(const Duration(hours: 14)));

    final done = await repo.watchFinished().first;
    expect([for (final f in done) f.id].first, second);
    expect(done, hasLength(2));

    await repo.delete(second);
    expect(await repo.watchFinished().first, hasLength(1));
  });
}
