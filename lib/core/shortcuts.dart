/// What Siri, Spotlight and the Shortcuts app get from the app: a sentence
/// about today and the items that can be logged by voice. Pure Dart; the
/// Swift side (`ios/Runner/LogbiteShortcuts.swift`) only reads these.
library;

import 'dart:convert';

import 'metrics.dart';
import 'widget_snapshot.dart';

/// What the "How much is left today?" shortcut says, for one day.
class ShortcutsSummary {
  const ShortcutsSummary({
    required this.dateKey,
    required this.sentence,
    required this.emptySentence,
  });

  /// The day [sentence] is about ('yyyy-MM-dd').
  final String dateKey;

  /// Said on [dateKey].
  final String sentence;

  /// Said on a later day, before the app has published again: nothing is
  /// logged yet.
  final String emptySentence;
}

/// The sentence for a day where [consumed] of the primary [metric] has been
/// logged against [goal] (null or 0 for none). Uses the same rounding as the
/// home screen widget, so the two never disagree.
ShortcutsSummary buildShortcutsSummary({
  required String dateKey,
  required Metric metric,
  required double consumed,
  required double? goal,
}) {
  String say(double amount, {required double? goalNow}) {
    final s = buildWidgetSnapshot(
      dateKey: dateKey,
      metric: metric,
      consumed: amount,
      goal: goalNow,
    );
    // "12.0 g" reads well on the widget; Siri says "12 grams".
    final value = s.valueText.endsWith('.0')
        ? s.valueText.substring(0, s.valueText.length - 2)
        : s.valueText;
    final what = _spokenUnit(metric, value);
    if (goalNow == null || goalNow <= 0) {
      return amount <= 0
          ? 'You have not logged anything today.'
          : 'You have had $value $what today.';
    }
    return s.overGoal
        ? 'You are $value $what over your goal today.'
        : 'You have $value $what left today.';
  }

  return ShortcutsSummary(
    dateKey: dateKey,
    sentence: say(consumed, goalNow: goal),
    emptySentence: say(0, goalNow: goal),
  );
}

/// "calories", "grams of protein", "milligrams of sodium", singular for 1.
String _spokenUnit(Metric metric, String value) {
  final one = value == '1';
  if (metric == Metric.calories) return one ? 'calorie' : 'calories';
  final unit = switch (metric.unit) {
    'mg' => one ? 'milligram' : 'milligrams',
    _ => one ? 'gram' : 'grams',
  };
  return '$unit of ${metric.label.toLowerCase()}';
}

/// What a shortcut can log.
enum ShortcutItemKind { meal, food }

/// A saved meal or a favorite food offered to Siri. Its [id] is stable, so a
/// shortcut the user made keeps working after a rename.
class ShortcutItem {
  const ShortcutItem({
    required this.kind,
    required this.targetId,
    required this.name,
  });

  final ShortcutItemKind kind;

  /// The meal's or food's id in the catalog.
  final String targetId;
  final String name;

  /// `"meal:<id>"` or `"food:<id>"`.
  String get id => '${kind.name}:$targetId';

  /// The item an [id] names, or null when it is not one.
  static ({ShortcutItemKind kind, String targetId})? parseId(String id) {
    final colon = id.indexOf(':');
    if (colon <= 0 || colon == id.length - 1) return null;
    final kind = switch (id.substring(0, colon)) {
      'meal' => ShortcutItemKind.meal,
      'food' => ShortcutItemKind.food,
      _ => null,
    };
    if (kind == null) return null;
    return (kind: kind, targetId: id.substring(colon + 1));
  }

  @override
  bool operator ==(Object other) =>
      other is ShortcutItem && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

/// The items as the JSON list the Swift side reads: `[{"id", "name"}]`,
/// sorted by name.
String encodeShortcutItems(Iterable<ShortcutItem> items) {
  final sorted = [...items]
    ..sort((a, b) {
      final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return byName != 0 ? byName : a.id.compareTo(b.id);
    });
  return jsonEncode([
    for (final i in sorted) {'id': i.id, 'name': i.name},
  ]);
}

/// How long a "log this" request from Siri stays valid. One left behind (say,
/// the app was killed before it was handled) is dropped after this, so an old
/// request never logs on a later day.
const shortcutRequestLifetime = Duration(minutes: 10);
