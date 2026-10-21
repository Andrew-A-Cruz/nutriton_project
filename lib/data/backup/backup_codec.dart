import 'dart:convert';

import '../../core/metrics.dart';
import '../../core/nutrition_math.dart';
import '../database/app_database.dart';
import '../preferences/user_preferences.dart';

/// Version written by [BackupCodec.encode]. Bump when the file layout changes;
/// files with a higher version are rejected, lower ones are still read.
const backupFormatVersion = 1;

/// The file is not a usable backup (malformed, wrong shape, or too new). The
/// [message] is safe to show to the user.
class BackupException implements Exception {
  BackupException(this.message);

  final String message;

  @override
  String toString() => 'BackupException: $message';
}

/// Everything in a backup, as plain objects.
class BackupData {
  const BackupData({
    this.foodItems = const [],
    this.meals = const [],
    this.mealFoodItems = const [],
    this.logEntries = const [],
    this.logEntryItems = const [],
    this.scheduledMeals = const [],
    this.scheduledMealOutcomes = const [],
    required this.settings,
  });

  final List<FoodItem> foodItems;
  final List<Meal> meals;
  final List<MealFoodItem> mealFoodItems;
  final List<FoodLogEntry> logEntries;
  final List<FoodLogEntryItem> logEntryItems;
  final List<ScheduledMeal> scheduledMeals;
  final List<ScheduledMealOutcome> scheduledMealOutcomes;
  final UserSettings settings;
}

/// Pure-Dart JSON (de)serializer for [BackupData]. No Flutter, no database
/// access. Layout:
///
/// ```
/// { "app": "nutriton", "version": 1, "exportedAt": "...Z",
///   "food_items": [...], "meals": [...], "meal_food_items": [...],
///   "food_log_entries": [...], "food_log_entry_items": [...],
///   "scheduled_meals": [...], "scheduled_meal_outcomes": [...],
///   "preferences": {...} }
/// ```
///
/// Rows use drift's generated JSON (camelCase keys, DateTime as epoch ms).
/// Referential integrity and CHECK rules are enforced by the database during
/// import.
class BackupCodec {
  const BackupCodec();

  static const appId = 'nutriton';

  String encode(BackupData data, {DateTime? exportedAt}) {
    final map = <String, Object?>{
      'app': appId,
      'version': backupFormatVersion,
      'exportedAt': (exportedAt ?? DateTime.now()).toUtc().toIso8601String(),
      'food_items': [for (final r in data.foodItems) r.toJson()],
      'meals': [for (final r in data.meals) r.toJson()],
      'meal_food_items': [for (final r in data.mealFoodItems) r.toJson()],
      'food_log_entries': [for (final r in data.logEntries) r.toJson()],
      'food_log_entry_items': [for (final r in data.logEntryItems) r.toJson()],
      'scheduled_meals': [for (final r in data.scheduledMeals) r.toJson()],
      'scheduled_meal_outcomes': [
        for (final r in data.scheduledMealOutcomes) r.toJson(),
      ],
      'preferences': _encodeSettings(data.settings),
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  /// Parses and validates [source]. Throws [BackupException] on any problem.
  BackupData decode(String source) {
    final Object? root;
    try {
      root = jsonDecode(source);
    } on FormatException {
      throw BackupException('This file is not valid JSON.');
    }
    if (root is! Map<String, dynamic> || root['app'] != appId) {
      throw BackupException('This file is not a Nutriton backup.');
    }
    final version = root['version'];
    if (version is! int || version < 1) {
      throw BackupException('The backup has no valid version number.');
    }
    if (version > backupFormatVersion) {
      throw BackupException(
        'This backup was made by a newer version of the app '
        '(format $version). Update the app to restore it.',
      );
    }
    try {
      return BackupData(
        foodItems: _rows(root, 'food_items', FoodItem.fromJson),
        meals: _rows(root, 'meals', Meal.fromJson),
        mealFoodItems: _rows(root, 'meal_food_items', MealFoodItem.fromJson),
        logEntries: _rows(root, 'food_log_entries', FoodLogEntry.fromJson),
        logEntryItems: _rows(
          root,
          'food_log_entry_items',
          FoodLogEntryItem.fromJson,
        ),
        scheduledMeals: _rows(root, 'scheduled_meals', ScheduledMeal.fromJson),
        scheduledMealOutcomes: _rows(
          root,
          'scheduled_meal_outcomes',
          ScheduledMealOutcome.fromJson,
        ),
        settings: _decodeSettings(root['preferences']),
      );
    } on BackupException {
      rethrow;
    } catch (_) {
      // Wrong types inside a row surface as TypeError.
      throw BackupException('The backup is damaged or has unexpected data.');
    }
  }

  List<T> _rows<T>(
    Map<String, dynamic> root,
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final value = root[key];
    if (value is! List) {
      throw BackupException('The backup is missing "$key".');
    }
    return [
      for (final row in value)
        if (row is Map<String, dynamic>)
          fromJson(row)
        else
          throw BackupException('The backup has a malformed row in "$key".'),
    ];
  }

  Map<String, Object?> _encodeSettings(UserSettings s) => {
    'onboardingComplete': s.onboardingComplete,
    'primaryMetric': s.primaryMetric.name,
    'trackedMetrics': [for (final m in s.trackedMetrics) m.name],
    'displayUnit': s.displayUnit.name,
    'goals': {for (final e in s.goals.entries) e.key.name: e.value},
  };

  UserSettings _decodeSettings(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      throw BackupException('The backup is missing "preferences".');
    }
    final metrics = Metric.values.asNameMap();
    final primary = metrics[raw['primaryMetric']];
    final unit = WeightUnit.values.asNameMap()[raw['displayUnit']];
    final onboarding = raw['onboardingComplete'];
    final tracked = raw['trackedMetrics'];
    final goals = raw['goals'];
    if (primary == null ||
        unit == null ||
        onboarding is! bool ||
        tracked is! List ||
        goals is! Map) {
      throw BackupException('The backup has invalid preferences.');
    }
    final goalMap = <Metric, double>{};
    for (final e in goals.entries) {
      final metric = metrics[e.key];
      if (metric == null) continue; // from a newer build; ignore
      final v = e.value;
      if (v is! num || !v.isFinite || v <= 0) {
        throw BackupException('The backup has an invalid goal.');
      }
      goalMap[metric] = v.toDouble();
    }
    return UserSettings(
      onboardingComplete: onboarding,
      primaryMetric: primary,
      trackedMetrics: {
        for (final n in tracked)
          if (metrics[n] case final Metric m) m,
      },
      goals: goalMap,
      displayUnit: unit,
    );
  }
}
