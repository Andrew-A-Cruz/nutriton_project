import 'package:uuid/uuid.dart';

import '../database/app_database.dart';

/// The fasting timer: at most one fast in progress, and the finished ones.
class FastingRepository {
  FastingRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// Starts a fast at [now] and returns its id. With one already running,
  /// returns that one's id and changes nothing.
  Future<String> start(DateTime now) => _db.transaction(() async {
    final running = await _db.fastDao.active();
    if (running != null) return running.id;
    final id = _uuid.v4();
    await _db.fastDao.insertFast(FastsCompanion.insert(id: id, startedAt: now));
    return id;
  });

  /// Ends the fast in progress at [now]. Does nothing when none is running.
  /// A clock that moved back before the start ends the fast at its start.
  Future<void> end(DateTime now) => _db.transaction(() async {
    final running = await _db.fastDao.active();
    if (running == null) return;
    final endedAt = now.isBefore(running.startedAt) ? running.startedAt : now;
    await _db.fastDao.endFast(running.id, endedAt);
  });

  /// Removes one fast, running or finished.
  Future<void> delete(String id) => _db.fastDao.deleteFast(id);

  /// The fast in progress, or null. Re-emits on every change.
  Stream<Fast?> watchActive() => _db.fastDao.watchActive();

  /// Finished fasts, newest first.
  Stream<List<Fast>> watchFinished() => _db.fastDao.watchFinished();
}
