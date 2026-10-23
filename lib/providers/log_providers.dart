import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/date_key.dart';
import '../data/database/app_database.dart';
import 'infrastructure_providers.dart';
import 'today_providers.dart';

/// The day the Home view shows, as a 'yyyy-MM-dd' key.
class SelectedDateNotifier extends Notifier<String> {
  @override
  String build() {
    ref.keepAlive();
    // Follow the day rollover, but only when the user is on the old "today".
    ref.listen(todayProvider, (previous, next) {
      if (state == previous) state = next;
    });
    return ref.read(todayProvider);
  }

  void select(String key) => state = key;

  void shift(int days) => state = addDays(state, days);

  void goToToday() => state = ref.read(todayProvider);
}

final selectedDateProvider = NotifierProvider<SelectedDateNotifier, String>(
  SelectedDateNotifier.new,
);

/// Entries for one day ('yyyy-MM-dd'), oldest first. Re-emits on every write.
final dayEntriesProvider = StreamProvider.family<List<FoodLogEntry>, String>(
  (ref, logDate) =>
      ref.watch(logRepositoryProvider).watchEntriesForDate(logDate),
);

/// Breakdown rows of one logged meal, keyed by entry id.
final entryItemsProvider =
    StreamProvider.family<List<FoodLogEntryItem>, String>(
      (ref, entryId) =>
          ref.watch(logRepositoryProvider).watchEntryItems(entryId),
    );

/// Active catalog foods logged before, most recent first. Re-emits on writes.
final recentFoodsProvider = StreamProvider<List<FoodItem>>(
  (ref) => ref.watch(logRepositoryProvider).watchRecentFoods(),
);
