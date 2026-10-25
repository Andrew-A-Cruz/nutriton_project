import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:health/health.dart';

import '../../core/body_weight.dart';
import '../../core/date_key.dart';
import '../../core/health.dart';
import 'health_service.dart';

/// Apple Health through the `health` package. iOS only: Health Connect on
/// Android is not wired up, so [isSupported] is false there.
///
/// Each nutrient gets one sample per day, spanning the day, which HealthKit
/// adds up with the day's other samples. Rewriting a day deletes the app's own
/// samples in that day's range first (the plugin's `delete` only ever touches
/// samples this app wrote) and writes the new ones.
///
/// Not run in tests, and it needs the HealthKit capability in Xcode; see
/// `ios/HEALTHKIT.md`.
class PluginHealthService implements HealthService {
  PluginHealthService([Health? health]) : _health = health ?? Health();

  /// Only iOS has a health store this app talks to.
  static bool get isSupported => !kIsWeb && Platform.isIOS;

  final Health _health;
  Future<void>? _configured;

  // `configure` must run once before any other call.
  Future<void> _ready() => _configured ??= _health.configure();

  static const _types = {
    HealthNutrient.energy: HealthDataType.DIETARY_ENERGY_CONSUMED,
    HealthNutrient.protein: HealthDataType.DIETARY_PROTEIN_CONSUMED,
    HealthNutrient.carbs: HealthDataType.DIETARY_CARBS_CONSUMED,
    HealthNutrient.fat: HealthDataType.DIETARY_FATS_CONSUMED,
    HealthNutrient.fiber: HealthDataType.DIETARY_FIBER,
    HealthNutrient.sugar: HealthDataType.DIETARY_SUGAR,
    HealthNutrient.sodium: HealthDataType.DIETARY_SODIUM,
  };

  static HealthDataUnit _unit(HealthUnit unit) => switch (unit) {
    HealthUnit.kilocalorie => HealthDataUnit.KILOCALORIE,
    HealthUnit.gram => HealthDataUnit.GRAM,
  };

  @override
  Future<bool> requestAuthorization(HealthGroup group) async {
    await _ready();
    return switch (group) {
      HealthGroup.nutrition => _health.requestAuthorization(
        _types.values.toList(),
        permissions: [for (final _ in _types.values) HealthDataAccess.WRITE],
      ),
      HealthGroup.weight => _health.requestAuthorization(
        [HealthDataType.WEIGHT],
        permissions: [HealthDataAccess.READ],
      ),
    };
  }

  @override
  Future<void> replaceDailyNutrition(
    String date,
    List<NutritionSample> samples,
  ) async {
    await _ready();
    final day = dateFromKey(date);
    final start = day;
    final nextDay = DateTime(day.year, day.month, day.day + 1);
    for (final type in _types.values) {
      await _health.delete(type: type, startTime: start, endTime: nextDay);
    }
    // Ends a second before midnight, so the sample lies inside the range that
    // the next rewrite deletes.
    final end = nextDay.subtract(const Duration(seconds: 1));
    for (final s in samples) {
      final ok = await _health.writeHealthData(
        value: s.value,
        unit: _unit(s.unit),
        type: _types[s.type]!,
        startTime: start,
        endTime: end,
      );
      if (!ok) throw StateError('Health refused the ${s.type.name} sample');
    }
  }

  @override
  Future<List<WeightReading>> readBodyWeights(
    String startDate,
    String endDate,
  ) async {
    await _ready();
    final points = await _health.getHealthDataFromTypes(
      types: [HealthDataType.WEIGHT],
      startTime: dateFromKey(startDate),
      endTime: dateFromKey(addDays(endDate, 1)),
      preferredUnits: {HealthDataType.WEIGHT: HealthDataUnit.KILOGRAM},
    );
    return dailyWeights([
      for (final p in points)
        if (p.value case final NumericHealthValue v)
          (when: p.dateFrom, kg: v.numericValue.toDouble()),
    ]);
  }
}
