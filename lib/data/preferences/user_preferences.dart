import 'package:shared_preferences/shared_preferences.dart';

import '../../core/metrics.dart';
import '../../core/nutrition_math.dart';
import '../../core/reminder.dart';

/// User settings. Loaded from [UserPreferences] at launch and saved back on
/// every change.
class UserSettings {
  UserSettings({
    this.onboardingComplete = false,
    this.primaryMetric = Metric.calories,
    Set<Metric> trackedMetrics = const {},
    Map<Metric, double> goals = const {},
    this.displayUnit = WeightUnit.g,
    List<Reminder> reminders = Reminder.defaults,
  }) : trackedMetrics = {...trackedMetrics, primaryMetric},
       goals = Map.unmodifiable(goals),
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

  /// Always [reminderSlots] long, all off until the user turns them on.
  final List<Reminder> reminders;

  /// Tracked metrics other than the primary one, in [Metric.values] order.
  List<Metric> get secondaryMetrics => [
    for (final m in Metric.values)
      if (m != primaryMetric && trackedMetrics.contains(m)) m,
  ];

  double? goalFor(Metric metric) => goals[metric];

  UserSettings copyWith({
    bool? onboardingComplete,
    Metric? primaryMetric,
    Set<Metric>? trackedMetrics,
    Map<Metric, double>? goals,
    WeightUnit? displayUnit,
    List<Reminder>? reminders,
  }) => UserSettings(
    onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    primaryMetric: primaryMetric ?? this.primaryMetric,
    trackedMetrics: trackedMetrics ?? this.trackedMetrics,
    goals: goals ?? this.goals,
    displayUnit: displayUnit ?? this.displayUnit,
    reminders: reminders ?? this.reminders,
  );
}

/// Typed access to the `shared_preferences` keys. Metrics are stored by name,
/// so adding a [Metric] needs no migration: its goal key simply starts to exist.
class UserPreferences {
  UserPreferences(this._prefs);

  static const onboardingKey = 'onboarding_complete';
  static const primaryKey = 'primary_metric';
  static const trackedKey = 'tracked_metrics';
  static const unitKey = 'display_unit';
  static const lastBackupKey = 'last_backup_at';
  static String goalKey(Metric metric) => 'goal_${metric.name}';
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
      reminders: [
        for (var i = 0; i < reminderSlots; i++)
          Reminder(
            minutes:
                _validMinutes(_prefs.getInt(reminderMinutesKey(i))) ??
                Reminder.defaults[i].minutes,
            enabled: _prefs.getBool(reminderEnabledKey(i)) ?? false,
          ),
      ],
    );
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
    for (var i = 0; i < reminderSlots; i++) {
      await _prefs.setBool(
        reminderEnabledKey(i),
        settings.reminders[i].enabled,
      );
      await _prefs.setInt(reminderMinutesKey(i), settings.reminders[i].minutes);
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
}
