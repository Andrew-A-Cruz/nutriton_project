import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/fasts.dart';

part 'fast_dao.g.dart';

@DriftAccessor(tables: [Fasts])
class FastDao extends DatabaseAccessor<AppDatabase> with _$FastDaoMixin {
  FastDao(super.attachedDatabase);

  SimpleSelectStatement<$FastsTable, Fast> _active() => select(fasts)
    ..where((t) => t.endedAt.isNull())
    ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
    ..limit(1);

  /// The fast in progress, or null.
  Future<Fast?> active() => _active().getSingleOrNull();

  /// The fast in progress, or null. Re-emits on every change.
  Stream<Fast?> watchActive() => _active().watchSingleOrNull();

  Future<void> insertFast(FastsCompanion fast) => into(fasts).insert(fast);

  Future<int> endFast(String id, DateTime endedAt) =>
      (update(fasts)..where((t) => t.id.equals(id))).write(
        FastsCompanion(endedAt: Value(endedAt)),
      );

  Future<int> deleteFast(String id) =>
      (delete(fasts)..where((t) => t.id.equals(id))).go();

  /// Finished fasts, newest first.
  Stream<List<Fast>> watchFinished() =>
      (select(fasts)
            ..where((t) => t.endedAt.isNotNull())
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
          .watch();
}
