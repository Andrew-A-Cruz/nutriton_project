import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/review_prompt.dart';
import 'infrastructure_providers.dart';
import 'log_providers.dart';
import 'preferences_providers.dart';
import 'today_providers.dart';

/// Shows the system App Store review prompt. A no-op until `main` overrides
/// it with `in_app_review`, so tests never touch the plugin. iOS decides
/// whether the prompt actually appears (at most 3 times a year).
final requestReviewProvider = Provider<Future<void> Function()>(
  (ref) => () async {},
);

/// Asks for one App Store review, right after something is logged for today
/// once [reviewPromptLoggedDays] different days have entries. Watched from
/// the root. See [shouldAskForReview].
final reviewPromptPlanProvider = Provider<void>((ref) {
  final today = ref.watch(todayProvider);
  ref.listen(dayEntriesProvider(today), (previous, next) {
    final before = previous?.value?.length;
    final after = next.value?.length;
    // Only a new entry counts, not the day loading or an entry deleted.
    if (before == null || after == null || after <= before) return;
    unawaited(_maybeAsk(ref, today).catchError((Object _) {}));
  });
});

Future<void> _maybeAsk(Ref ref, String today) async {
  final prefs = ref.read(userPreferencesProvider);
  if (prefs.readReviewAsked()) return;
  final days = await ref.read(summaryRepositoryProvider).loggedDayCount(today);
  if (!shouldAskForReview(
    loggedDays: days,
    alreadyAsked: prefs.readReviewAsked(),
    justLogged: true,
  )) {
    return;
  }
  await prefs.writeReviewAsked();
  await ref.read(requestReviewProvider)();
}
