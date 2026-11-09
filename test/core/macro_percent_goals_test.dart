import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/macro_split.dart';
import 'package:nutriton_project/core/metrics.dart';
import 'package:nutriton_project/data/backup/backup_codec.dart';
import 'package:nutriton_project/data/preferences/user_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const split = (protein: 30, carbs: 40, fat: 30);

  test('gram goals follow from calories and percentages', () {
    expect(macroGoalsFromPercents(2000, split), {
      Metric.protein: 150,
      Metric.carbs: 200,
      Metric.fat: 66.7,
    });
  });

  test('a split must be 0 to 100 each and add up to 100', () {
    expect(validMacroSplit(30, 40, 30), split);
    expect(validMacroSplit(30, 40, 31), isNull);
    expect(validMacroSplit(-10, 80, 30), isNull);
    expect(validMacroSplit(0, 100, 0), (protein: 0, carbs: 100, fat: 0));
  });

  test('settings derive the gram goals and update them with calories', () {
    final s = UserSettings(
      goals: {Metric.calories: 2000, Metric.protein: 999},
      macroGoalPercents: split,
    );
    expect(s.goalFor(Metric.protein), 150);
    expect(s.goalFor(Metric.fat), 66.7);
    final more = s.copyWith(goals: {...s.goals, Metric.calories: 2500});
    expect(more.goalFor(Metric.protein), 187.5);
  });

  test('without a calorie goal the gram goals are left as they are', () {
    final s = UserSettings(
      primaryMetric: Metric.protein,
      goals: {Metric.protein: 120},
      macroGoalPercents: split,
    );
    expect(s.goalFor(Metric.protein), 120);
    expect(s.goalFor(Metric.fat), isNull);
  });

  test('preferences keep the percentages', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = UserPreferences(await SharedPreferences.getInstance());
    await prefs.write(
      UserSettings(goals: {Metric.calories: 2000}, macroGoalPercents: split),
    );
    final read = prefs.read();
    expect(read.macroGoalPercents, split);
    expect(read.goalFor(Metric.carbs), 200);

    await prefs.write(read.copyWith(goals: read.goals).withGrams());
    expect(prefs.read().macroGoalPercents, isNull);
  });

  group('backups', () {
    const codec = BackupCodec();
    Map<String, dynamic> encode(UserSettings s) =>
        jsonDecode(codec.encode(BackupData(settings: s)))
            as Map<String, dynamic>;

    test('keep the percentages', () {
      final json = encode(
        UserSettings(goals: {Metric.calories: 2000}, macroGoalPercents: split),
      );
      expect(json['preferences']['macroGoalPercents'], {
        'protein': 30,
        'carbs': 40,
        'fat': 30,
      });
      // The derived grams are there too, for apps that predate percentages.
      expect(json['preferences']['goals']['protein'], 150);
      final back = codec.decode(jsonEncode(json)).settings;
      expect(back.macroGoalPercents, split);
    });

    test('older backups read as grams; bad percentages are rejected', () {
      final json = encode(UserSettings(goals: {Metric.calories: 2000}));
      expect(json['preferences'].containsKey('macroGoalPercents'), isFalse);
      expect(codec.decode(jsonEncode(json)).settings.macroGoalPercents, isNull);

      json['preferences']['macroGoalPercents'] = {
        'protein': 50,
        'carbs': 50,
        'fat': 50,
      };
      expect(
        () => codec.decode(jsonEncode(json)),
        throwsA(isA<BackupException>()),
      );
    });
  });
}

extension on UserSettings {
  /// A copy with the macro goals in grams again.
  UserSettings withGrams() => UserSettings(
    primaryMetric: primaryMetric,
    trackedMetrics: trackedMetrics,
    goals: goals,
  );
}
