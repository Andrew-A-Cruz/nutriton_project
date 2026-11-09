import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/metrics.dart';
import 'package:nutriton_project/core/nutrition_math.dart';
import 'package:nutriton_project/core/summary_math.dart';
import 'package:nutriton_project/data/backup/backup_codec.dart';
import 'package:nutriton_project/data/preferences/user_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // 2026-11-09 is a Monday.
  const monday = '2026-11-09';
  const tuesday = '2026-11-10';

  final settings = UserSettings(
    goals: {Metric.calories: 2000, Metric.protein: 150},
    weekdayGoals: {
      DateTime.monday: {Metric.calories: 2600},
    },
  );

  test('a weekday goal applies on that day and falls back otherwise', () {
    expect(settings.goalFor(Metric.calories, date: monday), 2600);
    expect(settings.goalFor(Metric.protein, date: monday), 150);
    expect(settings.goalFor(Metric.calories, date: tuesday), 2000);
    expect(settings.goalFor(Metric.calories), 2000);
    expect(settings.hasWeekdayGoals, isTrue);
  });

  test('in percent mode a day\'s macro grams follow its calorie goal', () {
    final s = UserSettings(
      goals: {Metric.calories: 2000},
      macroGoalPercents: (protein: 30, carbs: 40, fat: 30),
      weekdayGoals: {
        DateTime.monday: {Metric.calories: 2400},
      },
    );
    expect(s.goalFor(Metric.protein, date: monday), 180);
    expect(s.goalFor(Metric.protein, date: tuesday), 150);
  });

  test('the average goal over a range', () {
    // Mon..Sun: one day at 2600, six at 2000.
    expect(
      settings.averageGoal(Metric.calories, monday, '2026-11-15'),
      closeTo((2600 + 6 * 2000) / 7, 1e-9),
    );
    expect(
      UserSettings().averageGoal(Metric.calories, monday, tuesday),
      isNull,
    );
  });

  test('days on target use each day\'s goal', () {
    Macros kcal(double c) => Macros(calories: c, protein: 0, carbs: 0, fat: 0);
    final days = {monday: kcal(2600), tuesday: kcal(2600)};
    expect(
      daysOnTargetEach(
        days,
        Metric.calories,
        (d) => settings.goalFor(Metric.calories, date: d),
      ),
      1,
    );
  });

  test('empty days are dropped', () {
    final s = settings.copyWith(
      weekdayGoals: {...settings.weekdayGoals, DateTime.friday: {}},
    );
    expect(s.weekdayGoals.keys, [DateTime.monday]);
  });

  test('preferences and backups keep them', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = UserPreferences(await SharedPreferences.getInstance());
    await prefs.write(settings);
    expect(prefs.read().goalFor(Metric.calories, date: monday), 2600);
    expect(
      (await SharedPreferences.getInstance()).getDouble('goal_calories_mon'),
      2600,
    );

    await prefs.write(settings.copyWith(weekdayGoals: {}));
    expect(prefs.read().hasWeekdayGoals, isFalse);

    const codec = BackupCodec();
    final json =
        jsonDecode(codec.encode(BackupData(settings: settings)))
            as Map<String, dynamic>;
    expect(json['preferences']['weekdayGoals'], {
      'mon': {'calories': 2600},
    });
    final back = codec.decode(jsonEncode(json)).settings;
    expect(back.goalFor(Metric.calories, date: monday), 2600);

    json['preferences']['weekdayGoals'] = {
      'funday': {'calories': 1},
    };
    expect(
      () => codec.decode(jsonEncode(json)),
      throwsA(isA<BackupException>()),
    );
  });
}
