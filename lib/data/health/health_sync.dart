import '../../core/date_key.dart';
import '../../core/health.dart';
import '../../core/nutrition_math.dart';
import '../repositories/body_weight_repository.dart';
import 'health_service.dart';

/// Keeps the health store in line with the app, in both directions. Safe to
/// call as often as wanted: each call only touches what differs from the last.
class HealthSync {
  HealthSync(this._service, this._bodyWeights);

  final HealthService _service;
  final BodyWeightRepository _bodyWeights;

  // Whether the last nutrition call was enabled; null before the first call.
  bool? _wasEnabled;

  // For each day in the window, the totals the health store is known to hold
  // (or, at launch, assumed to hold). A day missing here holds nothing.
  Map<String, Macros> _known = {};

  // Calls run one after another, so a slow earlier one cannot overwrite what
  // a later one has just stored.
  Future<void> _tail = Future.value();

  Future<void> _queue(Future<void> Function() task) {
    final run = _tail.then((_) => task());
    // A failed run must not block the next one.
    _tail = run.catchError((Object _) {});
    return run;
  }

  /// Writes the nutrition totals of the last [healthBackfillDays] days ending
  /// [today], given [totals] for every day in that window that has entries.
  ///
  /// - Disabled: does nothing, and forgets what it knew.
  /// - First call after being disabled (the user just switched it on): writes
  ///   every day in the window that has entries.
  /// - First call since launch with it already on: trusts the health store
  ///   for past days and writes only [today].
  /// - After that: rewrites exactly the days whose totals changed, including
  ///   a day whose entries were all deleted (its samples are removed).
  ///
  /// A day that fails to write is retried on the next call.
  Future<void> syncNutrition({
    required bool enabled,
    required String today,
    required Map<String, Macros> totals,
  }) => _queue(() async {
    if (!enabled) {
      _wasEnabled = false;
      _known = {};
      return;
    }
    final window = [
      for (var i = healthBackfillDays - 1; i >= 0; i--) addDays(today, -i),
    ];
    if (_wasEnabled == null) {
      // Launch: past days are assumed written by an earlier session.
      _known = {
        for (final d in window)
          if (d != today && totals[d] != null) d: totals[d]!,
      };
    } else if (_wasEnabled == false) {
      _known = {};
    }
    _wasEnabled = true;

    Object? failure;
    final next = <String, Macros>{};
    for (final date in window) {
      final current = totals[date];
      final known = _known[date];
      if (current == known) {
        if (known != null) next[date] = known;
        continue;
      }
      try {
        await _service.replaceDailyNutrition(
          date,
          current == null ? const [] : nutritionSamples(current),
        );
        if (current != null) next[date] = current;
      } catch (e) {
        failure ??= e;
        if (known != null) next[date] = known;
      }
    }
    _known = next;
    if (failure != null) throw failure;
  });

  /// Reads body weights from the last [healthWeightImportDays] days ending
  /// [today] into the app. Manual readings are never changed; see
  /// [BodyWeightRepository.importHealthReadings].
  Future<void> importWeights({required bool enabled, required String today}) =>
      _queue(() async {
        if (!enabled) return;
        final readings = await _service.readBodyWeights(
          addDays(today, 1 - healthWeightImportDays),
          today,
        );
        await _bodyWeights.importHealthReadings(readings);
      });
}
