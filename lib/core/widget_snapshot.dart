import 'metrics.dart';
import 'nutrition_math.dart';

/// What the home screen widget shows for one day. Pure data: the platform
/// widget only draws these values and does no arithmetic of its own.
class WidgetSnapshot {
  const WidgetSnapshot({
    required this.dateKey,
    required this.valueText,
    required this.caption,
    required this.emptyValueText,
    required this.progress,
    required this.overGoal,
  });

  /// The day these figures are for ('yyyy-MM-dd'). The widget shows
  /// [emptyValueText] instead once the device date has moved past it.
  final String dateKey;

  /// The large figure: the amount left, or over, or (with no goal) eaten.
  final String valueText;

  /// The words under [valueText], e.g. 'kcal left' or 'g protein over'.
  final String caption;

  /// [valueText] for a day with nothing logged: the whole goal, or '0'.
  final String emptyValueText;

  /// Fraction of the goal eaten, from 0 to 1. 0 when there is no goal.
  final double progress;

  /// Whether the day is past the goal.
  final bool overGoal;

  /// The shared-storage entries the widget reads, keyed by name.
  Map<String, Object> toMap() => {
    'date_key': dateKey,
    'value_text': valueText,
    'caption': caption,
    'empty_value_text': emptyValueText,
    'progress': progress,
    'over_goal': overGoal,
  };

  @override
  bool operator ==(Object other) =>
      other is WidgetSnapshot &&
      other.dateKey == dateKey &&
      other.valueText == valueText &&
      other.caption == caption &&
      other.emptyValueText == emptyValueText &&
      other.progress == progress &&
      other.overGoal == overGoal;

  @override
  int get hashCode => Object.hash(
    dateKey,
    valueText,
    caption,
    emptyValueText,
    progress,
    overGoal,
  );

  @override
  String toString() => 'WidgetSnapshot(${toMap()})';
}

/// Builds the widget figures for [dateKey] from the day's [consumed] amount
/// of the [metric] (the primary metric) and its [goal]. A null or non-positive
/// goal means no goal: the widget then shows what was eaten, with no ring.
///
/// Figures are rounded as the app displays them (whole kcal and mg, one
/// decimal for grams) before they are compared, so "over" never shows beside a
/// remaining amount of 0.
WidgetSnapshot buildWidgetSnapshot({
  required String dateKey,
  required Metric metric,
  required double consumed,
  required double? goal,
}) {
  final places = metric == Metric.calories || metric.unit == 'mg' ? 0 : 1;
  final eaten = roundTo(consumed, places);
  final name = metric == Metric.calories
      ? ''
      : ' ${metric.label.toLowerCase()}';
  String caption(String what) => '${metric.unit}$name $what';

  if (goal == null || goal <= 0) {
    return WidgetSnapshot(
      dateKey: dateKey,
      valueText: metric.format(eaten),
      caption: caption('eaten'),
      emptyValueText: metric.format(0),
      progress: 0,
      overGoal: false,
    );
  }

  final target = roundTo(goal, places);
  final remaining = roundTo(target - eaten, places);
  final over = remaining < 0;
  return WidgetSnapshot(
    dateKey: dateKey,
    valueText: metric.format(remaining.abs()),
    caption: caption(over ? 'over' : 'left'),
    emptyValueText: metric.format(target),
    progress: target <= 0 ? 0 : (eaten / target).clamp(0.0, 1.0),
    overGoal: over,
  );
}
