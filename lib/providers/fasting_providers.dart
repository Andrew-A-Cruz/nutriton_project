import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../data/repositories/fasting_repository.dart';
import 'infrastructure_providers.dart';

final fastingRepositoryProvider = Provider<FastingRepository>(
  (ref) => FastingRepository(ref.watch(databaseProvider)),
);

/// The fast in progress, or null.
final activeFastProvider = StreamProvider<Fast?>(
  (ref) => ref.watch(fastingRepositoryProvider).watchActive(),
);

/// Finished fasts, newest first.
final finishedFastsProvider = StreamProvider<List<Fast>>(
  (ref) => ref.watch(fastingRepositoryProvider).watchFinished(),
);
