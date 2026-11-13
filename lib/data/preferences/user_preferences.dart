import 'package:shared_preferences/shared_preferences.dart';

import '../../core/appearance.dart';
import '../../core/body_weight.dart';
import '../../core/date_key.dart';
import '../../core/macro_split.dart';
import '../../core/metrics.dart';
import '../../core/nutrition_math.dart';
import '../../core/pro.dart';
import '../../core/reminder.dart';
import '../../core/water.dart';

/// User settings. Loaded from [UserPreferences] at launch and saved back on
/// every change.
class UserSettings {
  UserSettings({
    this.onboardingComplete = false,
    this.primaryMetric = Metric.calories,
    Set<Metric> trackedMetrics = const {},
    Map<Metric, double> goals = const {},
    this.displayUnit = WeightUnit.g,
    this.bodyWeightUnit = BodyWeightUnit.kg,
    List<Reminder> reminders = Reminder.defaults,
    this.healthWriteNutrition = false,
    this.healthReadWeight = false,
    this.macroGoalPercents,
    Map<int, Map<Metric, double>> weekdayGoals = const {},
    this.water = const WaterSettings(),
    this.fastingEnabled = false,
  }) : trackedMetrics = {...trackedMetrics, primaryMetric},
       goals = Map.unmodifiable(_withMacroGoals(goals, macroGoalPercents)),
       weekdayGoals = Map.unmodifiable({
         for (final e in weekdayGoals.entries)
           if (e.value.isNotEmpty)
             e.key: Map<Metric, double>.unmodifiable(e.value),
       }),
       _goalsByWeekday = List.unmodifiable([
         for (var d = DateTime.monday; d <= DateTime.sunday; d++)
           Map<Metric, double>.unmodifiable(
             _withMacroGoals({
               ...goals,
               ...?weekdayGoals[d],
             }, macroGoalPercents),
           ),
       ]),
       reminders = List.unmodifiable([
         for (var i = 0; i < reminderSlots; i++)
           i < reminders.length ? reminders[i] : Reminder.defaults[i],
       ]);

  final bool onboardingComplete;
  final Metric primaryMetric;

  /// Always contains [primaryMetric].
  final Set<Metric> trackedMetrics;

  /// Goal per metric. A metric with no entry has no goal.
  final Map<Metric, double> goals;
  final WeightUnit displayUnit;

  /// Unit for body weight, separate from the food [displayUnit].
  final BodyWeightUnit bodyWeightUnit;

  /// Always [reminderSlots] long, all off until the user turns them on.
  final List<Reminder> reminders;

  /// Whether each day's nutrition totals are written to Apple Health.
  final bool healthWriteNutrition;

  /// Whether body weight is read from Apple Health.
  final bool healthReadWeight;

  /// Protein, carbs and fat goals as percentages of the calorie goal, or null
  /// when they are set in grams. While set (and there is a calorie goal),
  /// [goals] holds the grams derived from it, so everything else reads grams.
  final MacroSplit? macroGoalPercents;

  /// Goals that differ on one weekday ([DateTime.monday] .. [DateTime.sunday]),
  /// e.g. more calories on training days. A metric missing here uses
  /// [goals]. In percent mode a day's macro grams follow its calorie goal.
  final Map<int, Map<Metric, double>> weekdayGoals;

  /// Whether the water row shows on Today, its unit and its daily goal.
  final WaterSettings water;

  /// Whether the fasting timer shows on Today. Off until switched on.
  final bool fastingEnabled;

  /// The goals in effect on each weekday, Monday first.
  final List<Map<Metric, double>> _goalsByWeekday;

  static Map<Metric, double> _withMacroGoals(
    Map<Metric, double> goals,
    MacroSplit? percents,
  ) {
    final calories = goals[Metric.calories];
    if (percents == null || calories == null || calories <= 0) return goals;
    return {...goals, ...macroGoalsFromPercents(calories, percents)};
  }

  /// Tracked metrics other than the primary one, in [Metric.values] order.
  List<Metric> get secondaryMetrics => [
    for (final m in Metric.values)
      if (m != primaryMetric && trackedMetrics.contains(m)) m,
  ];

  /// The goal for [metric]: on the day [date] ('yyyy-MM-dd') when given, so
  /// a weekday goal applies, otherwise the usual one.
  double? goalFor(Metric metric, {String? date}) =>
      date == null ? goals[metric] : goalsOn(date)[metric];

  /// Every goal in effect on [date] ('yyyy-MM-dd').
  Map<Metric, double> goalsOn(String date) =>
      _goalsByWeekday[dateFromKey(date).weekday - 1];

  /// Whether any weekday has goals of its own.
  bool get hasWeekdayGoals => weekdayGoals.isNotEmpty;

  /// The mean goal for [metric] over [startKey]..[endKey] (inclusive), counting
  /// only days that have one; null when none does. Summary's goal line.
  double? averageGoal(Metric metric, String startKey, String endKey) {
    var sum = 0.0;
    var days = 0;
    for (var k = startKey; k.compareTo(endKey) <= 0; k = addDays(k, 1)) {
      final g = goalFor(metric, date: k);
      if (g != null && g > 0) {
        sum += g;
        days++;
      }
    }
    return days == 0 ? null : sum / days;
  }

  UserSettings copyWith({
    bool? onboardingComplete,
    Metric? primaryMetric,
    Set<Metric>? trackedMetrics,
    Map<Metric, double>? goals,
    WeightUnit? displayUnit,
    BodyWeightUnit? bodyWeightUnit,
    List<Reminder>? reminders,
    bool? healthWriteNutrition,
    bool? healthReadWeight,
    Map<int, Map<Metric, double>>? weekdayGoals,
    WaterSettings? water,
    bool? fastingEnabled,
  }) => UserSettings(
    onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    primaryMetric: primaryMetric ?? this.primaryMetric,
    trackedMetrics: trackedMetrics ?? this.trackedMetrics,
    goals: goals ?? this.goals,
    displayUnit: displayUnit ?? this.displayUnit,
    bodyWeightUnit: bodyWeightUnit ?? this.bodyWeightUnit,
    reminders: reminders ?? this.reminders,
    healthWriteNutrition: healthWriteNutrition ?? this.healthWriteNutrition,
    healthReadWeight: healthReadWeight ?? this.healthReadWeight,
    macroGoalPercents: macroGoalPercents,
    weekdayGoals: weekdayGoals ?? this.weekdayGoals,
    water: water ?? this.water,
    fastingEnabled: fastingEnabled ?? this.fastingEnabled,
  );
}

/// Short keys for weekdays in storage and backups, Monday first.
const weekdayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

/// Typed access to the `shared_preferences` keys. Metrics are stored by name,
/// so adding a [Metric] needs no migration: its goal key simply starts to exist.
class UserPreferences {
  UserPreferences(this._prefs);

  static const onboardingKey = 'onboarding_complete';
  static const primaryKey = 'primary_metric';
  static const trackedKey = 'tracked_metrics';
  static const unitKey = 'display_unit';
  static const bodyWeightUnitKey = 'body_weight_unit';
  static const healthWriteNutritionKey = 'health_write_nutrition';
  static const healthReadWeightKey = 'health_read_weight';
  static const lastBackupKey = 'last_backup_at';
  static const proPurchasedKey = 'pro_purchased';
  static const proTrialStartedKey = 'pro_trial_started_at';
  static const proGrandfatheredKey = 'pro_grandfathered';
  static const trialEndedNoticeKey = 'pro_trial_ended_notice_shown';
  static const reviewAskedKey = 'review_prompt_asked';
  static const autoBackupEnabledKey = 'auto_backup_enabled';
  static const lastAutoBackupKey = 'last_auto_backup_at';
  static const mindfulModeKey = 'mindful_mode';
  static const themeKey = 'theme';
  static const waterEnabledKey = 'water_enabled';
  static const waterUnitKey = 'water_unit';
  static const waterGoalKey = 'water_goal_ml';
  static const fastingEnabledKey = 'fasting_enabled';
  static const healthShowStepsKey = 'health_show_steps';
  static const stepsGoalKey = 'steps_goal';
  static String goalKey(Metric metric) => 'goal_${metric.name}';
  static String weekdayGoalKey(Metric metric, int weekday) =>
      'goal_${metric.name}_${weekdayKeys[weekday - 1]}';
  static String goalPercentKey(Metric metric) => 'goal_percent_${metric.name}';
  static String reminderEnabledKey(int slot) => 'reminder_${slot}_enabled';
  static String reminderMinutesKey(int slot) => 'reminder_${slot}_minutes';

  final SharedPreferences _prefs;

  UserSettings read() {
    final metricsByName = Metric.values.asNameMap();
    final primary =
        metricsByName[_prefs.getString(primaryKey)] ?? Metric.calories;
    // Unknown names (from a newer or older build) are ignored.
    final tracked = {
      for (final name in _prefs.getStringList(trackedKey) ?? const <String>[])
        if (metricsByName[name] case final Metric m) m,
    };
    final goals = <Metric, double>{
      for (final m in Metric.values)
        if (_prefs.getDouble(goalKey(m)) case final double g) m: g,
    };
    return UserSettings(
      onboardingComplete: _prefs.getBool(onboardingKey) ?? false,
      primaryMetric: primary,
      trackedMetrics: tracked,
      goals: goals,
      displayUnit:
          WeightUnit.values.asNameMap()[_prefs.getString(unitKey)] ??
          WeightUnit.g,
      bodyWeightUnit:
          BodyWeightUnit.values.asNameMap()[_prefs.getString(
            bodyWeightUnitKey,
          )] ??
          BodyWeightUnit.kg,
      reminders: [
        for (var i = 0; i < reminderSlots; i++)
          Reminder(
            minutes:
                _validMinutes(_prefs.getInt(reminderMinutesKey(i))) ??
                Reminder.defaults[i].minutes,
            enabled: _prefs.getBool(reminderEnabledKey(i)) ?? false,
          ),
      ],
      healthWriteNutrition: _prefs.getBool(healthWriteNutritionKey) ?? false,
      healthReadWeight: _prefs.getBool(healthReadWeightKey) ?? false,
      macroGoalPercents: _readMacroGoalPercents(),
      weekdayGoals: {
        for (var d = DateTime.monday; d <= DateTime.sunday; d++)
          d: {
            for (final m in Metric.values)
              if (_prefs.getDouble(weekdayGoalKey(m, d)) case final double g)
                m: g,
          },
      },
      water: WaterSettings(
        enabled: _prefs.getBool(waterEnabledKey) ?? true,
        unit:
            WaterUnit.values.asNameMap()[_prefs.getString(waterUnitKey)] ??
            WaterUnit.glasses,
        goalMl: switch (_prefs.getDouble(waterGoalKey)) {
          final double g when g > 0 => g,
          _ => null,
        },
      ),
      fastingEnabled: _prefs.getBool(fastingEnabledKey) ?? false,
    );
  }

  /// Null unless all three are stored and add up to 100.
  MacroSplit? _readMacroGoalPercents() {
    final p = [for (final m in macroMetrics) _prefs.getInt(goalPercentKey(m))];
    if (p.contains(null)) return null;
    return validMacroSplit(p[0]!, p[1]!, p[2]!);
  }

  static int? _validMinutes(int? m) =>
      m != null && m >= 0 && m < 24 * 60 ? m : null;

  Future<void> write(UserSettings settings) async {
    await _prefs.setBool(onboardingKey, settings.onboardingComplete);
    await _prefs.setString(primaryKey, settings.primaryMetric.name);
    await _prefs.setStringList(trackedKey, [
      for (final m in settings.trackedMetrics) m.name,
    ]);
    await _prefs.setString(unitKey, settings.displayUnit.name);
    await _prefs.setString(bodyWeightUnitKey, settings.bodyWeightUnit.name);
    for (var i = 0; i < reminderSlots; i++) {
      await _prefs.setBool(
        reminderEnabledKey(i),
        settings.reminders[i].enabled,
      );
      await _prefs.setInt(reminderMinutesKey(i), settings.reminders[i].minutes);
    }
    await _prefs.setBool(
      healthWriteNutritionKey,
      settings.healthWriteNutrition,
    );
    await _prefs.setBool(healthReadWeightKey, settings.healthReadWeight);
    await _prefs.setBool(fastingEnabledKey, settings.fastingEnabled);
    await _prefs.setBool(waterEnabledKey, settings.water.enabled);
    await _prefs.setString(waterUnitKey, settings.water.unit.name);
    if (settings.water.goalMl case final goal?) {
      await _prefs.setDouble(waterGoalKey, goal);
    } else {
      await _prefs.remove(waterGoalKey);
    }
    for (var d = DateTime.monday; d <= DateTime.sunday; d++) {
      for (final m in Metric.values) {
        final goal = settings.weekdayGoals[d]?[m];
        if (goal == null) {
          await _prefs.remove(weekdayGoalKey(m, d));
        } else {
          await _prefs.setDouble(weekdayGoalKey(m, d), goal);
        }
      }
    }
    for (final m in macroMetrics) {
      final percents = settings.macroGoalPercents;
      if (percents == null) {
        await _prefs.remove(goalPercentKey(m));
      } else {
        await _prefs.setInt(goalPercentKey(m), percentOf(percents, m));
      }
    }
    for (final m in Metric.values) {
      final goal = settings.goalFor(m);
      if (goal == null) {
        await _prefs.remove(goalKey(m));
      } else {
        await _prefs.setDouble(goalKey(m), goal);
      }
    }
  }

  /// When the last export succeeded. Not part of [UserSettings], so a backup
  /// import neither contains nor changes it.
  DateTime? readLastBackup() {
    final ms = _prefs.getInt(lastBackupKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> writeLastBackup(DateTime when) =>
      _prefs.setInt(lastBackupKey, when.millisecondsSinceEpoch);

  /// The last [ProStatus] the store reported, so Pro works offline and at
  /// launch. Like the backup date, not part of [UserSettings] or a backup.
  ProStatus readProStatus() {
    final trialMs = _prefs.getInt(proTrialStartedKey);
    return ProStatus(
      purchased: _prefs.getBool(proPurchasedKey) ?? false,
      trialStartedAt: trialMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(trialMs),
      grandfathered: _prefs.getBool(proGrandfatheredKey) ?? false,
    );
  }

  Future<void> writeProStatus(ProStatus status) async {
    await _prefs.setBool(proPurchasedKey, status.purchased);
    final trial = status.trialStartedAt;
    if (trial == null) {
      await _prefs.remove(proTrialStartedKey);
    } else {
      await _prefs.setInt(proTrialStartedKey, trial.millisecondsSinceEpoch);
    }
    await _prefs.setBool(proGrandfatheredKey, status.grandfathered);
  }

  /// Whether "Your trial ended" has been shown.
  bool readTrialEndedNoticeShown() =>
      _prefs.getBool(trialEndedNoticeKey) ?? false;

  Future<void> writeTrialEndedNoticeShown() =>
      _prefs.setBool(trialEndedNoticeKey, true);

  /// Whether the App Store review prompt has been asked for.
  bool readReviewAsked() => _prefs.getBool(reviewAskedKey) ?? false;

  Future<void> writeReviewAsked() => _prefs.setBool(reviewAskedKey, true);

  /// Whether automatic backups are on (the default). Device-local like
  /// [readLastBackup], so an import does not change it.
  bool readAutoBackupEnabled() => _prefs.getBool(autoBackupEnabledKey) ?? true;

  Future<void> writeAutoBackupEnabled(bool enabled) =>
      _prefs.setBool(autoBackupEnabledKey, enabled);

  /// Whether mindful mode hides the numbers (off by default). Device-local,
  /// like [readAutoBackupEnabled].
  bool readMindfulMode() => _prefs.getBool(mindfulModeKey) ?? false;

  Future<void> writeMindfulMode(bool on) => _prefs.setBool(mindfulModeKey, on);

  /// The accent color picked in Settings (Pro). Device-local, and kept when
  /// Pro is lost so it returns with it.
  AppTheme readTheme() => AppTheme.fromName(_prefs.getString(themeKey));

  Future<void> writeTheme(AppTheme theme) =>
      _prefs.setString(themeKey, theme.name);

  /// When the last automatic backup was written, or null if never.
  DateTime? readLastAutoBackup() {
    final ms = _prefs.getInt(lastAutoBackupKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<void> writeLastAutoBackup(DateTime when) =>
      _prefs.setInt(lastAutoBackupKey, when.millisecondsSinceEpoch);

  /// Whether Today shows the step count from Apple Health (off by default).
  /// Device-local: Health access belongs to this phone, so a backup neither
  /// contains nor changes it.
  bool readShowSteps() => _prefs.getBool(healthShowStepsKey) ?? false;

  Future<void> writeShowSteps(bool on) =>
      _prefs.setBool(healthShowStepsKey, on);

  /// The daily step goal, or null for none. Device-local, like
  /// [readShowSteps].
  int? readStepsGoal() {
    final goal = _prefs.getInt(stepsGoalKey);
    return goal == null || goal <= 0 ? null : goal;
  }

  Future<void> writeStepsGoal(int? goal) => goal == null || goal <= 0
      ? _prefs.remove(stepsGoalKey)
      : _prefs.setInt(stepsGoalKey, goal);
}
