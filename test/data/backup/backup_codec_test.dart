import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/metrics.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/data/backup/backup_codec.dart';
import 'package:nutriton_project/data/database/app_database.dart';
import 'package:nutriton_project/data/preferences/user_preferences.dart';

void main() {
  const codec = BackupCodec();
  final settings = UserSettings(
    onboardingComplete: true,
    primaryMetric: Metric.protein,
    trackedMetrics: {Metric.protein, Metric.fat},
    goals: {Metric.protein: 150, Metric.fat: 60.5},
    displayUnit: WeightUnit.oz,
  );
  const food = FoodItem(
    id: 'f1',
    name: 'Rice',
    calories: 130,
    protein: 3,
    carbs: 28,
    fat: 0.3,
    servingWeightG: 100,
    displayUnit: 'g',
    archived: false,
  );

  Map<String, dynamic> valid() =>
      jsonDecode(
            codec.encode(BackupData(foodItems: [food], settings: settings)),
          )
          as Map<String, dynamic>;

  BackupException failure(Object? json) {
    try {
      codec.decode(json is String ? json : jsonEncode(json));
    } on BackupException catch (e) {
      return e;
    }
    fail('expected a BackupException');
  }

  test('round trip keeps rows and preferences', () {
    final out = codec.decode(
      codec.encode(BackupData(foodItems: [food], settings: settings)),
    );
    expect(out.foodItems.single, food);
    expect(out.settings.primaryMetric, Metric.protein);
    expect(out.settings.trackedMetrics, {Metric.protein, Metric.fat});
    expect(out.settings.goals, {Metric.protein: 150, Metric.fat: 60.5});
    expect(out.settings.displayUnit, WeightUnit.oz);
    expect(out.settings.onboardingComplete, isTrue);
  });

  test('the file carries app id, version and every table', () {
    final json = valid();
    expect(json['app'], 'nutriton');
    expect(json['version'], backupFormatVersion);
    for (final key in [
      'food_items',
      'meals',
      'meal_food_items',
      'food_log_entries',
      'food_log_entry_items',
      'scheduled_meals',
      'scheduled_meal_outcomes',
      'preferences',
    ]) {
      expect(json, contains(key));
    }
  });

  test('rejects text that is not JSON', () {
    expect(failure('not json {').message, contains('not valid JSON'));
  });

  test('rejects JSON that is not a Nutriton backup', () {
    expect(failure([1, 2]).message, contains('not a Nutriton backup'));
    expect(failure({'version': 1}).message, contains('not a Nutriton backup'));
  });

  test('rejects a newer version with a clear message', () {
    final json = valid()..['version'] = backupFormatVersion + 1;
    expect(failure(json).message, contains('newer version'));
  });

  test('rejects a missing or non-integer version', () {
    expect(failure(valid()..remove('version')).message, contains('version'));
    expect(failure(valid()..['version'] = '1').message, contains('version'));
    expect(failure(valid()..['version'] = 0).message, contains('version'));
  });

  test('rejects a missing table', () {
    expect(failure(valid()..remove('meals')).message, contains('"meals"'));
  });

  test('rejects a malformed row and a row with a wrong type', () {
    expect(
      failure(valid()..['food_items'] = [5]).message,
      contains('malformed row'),
    );
    final bad = valid();
    (bad['food_items'] as List).first['calories'] = 'lots';
    expect(failure(bad).message, contains('damaged'));
  });

  test('rejects missing or invalid preferences', () {
    expect(failure(valid()..remove('preferences')).message, contains('prefer'));
    final bad = valid();
    (bad['preferences'] as Map)['primaryMetric'] = 'zinc';
    expect(failure(bad).message, contains('preferences'));
    final badGoal = valid();
    (badGoal['preferences'] as Map)['goals'] = {'calories': -5};
    expect(failure(badGoal).message, contains('goal'));
  });

  test('unknown metrics from another build are ignored', () {
    final json = valid();
    (json['preferences'] as Map)['goals'] = {'protein': 100, 'zinc': 2000};
    expect(codec.decode(jsonEncode(json)).settings.goals, {
      Metric.protein: 100,
    });
  });
}
