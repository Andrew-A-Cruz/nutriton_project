import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/database/app_database.dart';
import '../data/repositories/catalog_repository.dart';
import '../data/repositories/log_repository.dart';
import '../data/repositories/summary_repository.dart';

/// Overridden in `main.dart` with the instance loaded before `runApp`.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

/// One database for the app's lifetime. Tests override this with an in-memory
/// database.
final databaseProvider = Provider<AppDatabase>((ref) {
  ref.keepAlive();
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepository(ref.watch(databaseProvider)),
);

final logRepositoryProvider = Provider<LogRepository>(
  (ref) => LogRepository(ref.watch(databaseProvider)),
);

final summaryRepositoryProvider = Provider<SummaryRepository>(
  (ref) => SummaryRepository(ref.watch(databaseProvider)),
);
