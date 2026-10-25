import '../../core/body_weight.dart';
import '../../core/health.dart';

/// What the app needs from the phone's health store (Apple Health). The real
/// implementation wraps the `health` package (`PluginHealthService`); tests use
/// a fake.
abstract class HealthService {
  /// Asks the user for access to [group]'s data types, showing the system
  /// prompt if needed. Returns false when the request failed or was refused.
  ///
  /// HealthKit never says whether read access was granted, so for
  /// [HealthGroup.weight] true means only that the prompt was shown; a
  /// refused read simply returns no readings.
  Future<bool> requestAuthorization(HealthGroup group);

  /// Makes the app's own nutrition samples for [date] ('yyyy-MM-dd') exactly
  /// [samples]: deletes what the app wrote for that day, then writes the new
  /// ones. An empty list just deletes. Samples from other apps are untouched.
  Future<void> replaceDailyNutrition(
    String date,
    List<NutritionSample> samples,
  );

  /// Body weights recorded from [startDate] to [endDate] inclusive, at most
  /// one per day (the latest), oldest first.
  Future<List<WeightReading>> readBodyWeights(String startDate, String endDate);
}

/// For platforms without a health store, and the default until `main`
/// installs the real one.
class NoopHealthService implements HealthService {
  const NoopHealthService();

  @override
  Future<bool> requestAuthorization(HealthGroup group) async => false;

  @override
  Future<void> replaceDailyNutrition(
    String date,
    List<NutritionSample> samples,
  ) async {}

  @override
  Future<List<WeightReading>> readBodyWeights(
    String startDate,
    String endDate,
  ) async => const [];
}
