import 'package:nutriton_project/core/body_weight.dart';
import 'package:nutriton_project/core/health.dart';
import 'package:nutriton_project/data/health/health_service.dart';

/// A health store that records every call. [weights] is what a read returns
/// (filtered to the asked range), [grant] decides authorization.
class FakeHealthService implements HealthService {
  FakeHealthService({this.grant = true});

  bool grant;
  List<WeightReading> weights = [];

  final List<HealthGroup> authorizations = [];

  /// Every `replaceDailyNutrition` call, in order.
  final List<({String date, List<NutritionSample> samples})> writes = [];

  /// Every `readBodyWeights` range, in order.
  final List<({String start, String end})> reads = [];

  /// The dates written, in order.
  List<String> get writtenDates => [for (final w in writes) w.date];

  /// Samples last written for [date], or null if never written.
  List<NutritionSample>? samplesFor(String date) {
    for (final w in writes.reversed) {
      if (w.date == date) return w.samples;
    }
    return null;
  }

  @override
  Future<bool> requestAuthorization(HealthGroup group) async {
    authorizations.add(group);
    return grant;
  }

  @override
  Future<void> replaceDailyNutrition(
    String date,
    List<NutritionSample> samples,
  ) async {
    writes.add((date: date, samples: samples));
  }

  @override
  Future<List<WeightReading>> readBodyWeights(
    String startDate,
    String endDate,
  ) async {
    reads.add((start: startDate, end: endDate));
    return [
      for (final w in weights)
        if (w.date.compareTo(startDate) >= 0 && w.date.compareTo(endDate) <= 0)
          w,
    ];
  }
}
