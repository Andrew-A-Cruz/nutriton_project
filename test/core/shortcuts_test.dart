import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/metrics.dart';
import 'package:nutriton_project/core/shortcuts.dart';

void main() {
  group('buildShortcutsSummary', () {
    ShortcutsSummary summary(
      double consumed,
      double? goal, [
      Metric metric = Metric.calories,
    ]) => buildShortcutsSummary(
      dateKey: '2026-11-12',
      metric: metric,
      consumed: consumed,
      goal: goal,
    );

    test('what is left of the goal', () {
      final s = summary(750, 2000);
      expect(s.dateKey, '2026-11-12');
      expect(s.sentence, 'You have 1250 calories left today.');
      expect(s.emptySentence, 'You have 2000 calories left today.');
    });

    test('over the goal', () {
      expect(
        summary(2200, 2000).sentence,
        'You are 200 calories over your goal today.',
      );
    });

    test('no goal says what was had', () {
      expect(summary(850, null).sentence, 'You have had 850 calories today.');
      expect(
        summary(850, 0).emptySentence,
        'You have not logged anything today.',
      );
    });

    test('grams for a macro, singular for one', () {
      expect(
        summary(149, 150, Metric.protein).sentence,
        'You have 1 gram of protein left today.',
      );
      expect(
        summary(100, 150, Metric.protein).sentence,
        'You have 50 grams of protein left today.',
      );
    });
  });

  group('ShortcutItem', () {
    test('ids name the kind and the catalog id', () {
      const meal = ShortcutItem(
        kind: ShortcutItemKind.meal,
        targetId: 'abc',
        name: 'Breakfast',
      );
      expect(meal.id, 'meal:abc');
      expect(ShortcutItem.parseId('meal:abc'), (
        kind: ShortcutItemKind.meal,
        targetId: 'abc',
      ));
      expect(ShortcutItem.parseId('food:x:y'), (
        kind: ShortcutItemKind.food,
        targetId: 'x:y',
      ));
    });

    test('anything else is not an id', () {
      for (final id in ['', 'meal', 'meal:', ':abc', 'drink:abc']) {
        expect(ShortcutItem.parseId(id), isNull, reason: id);
      }
    });

    test('encoded as a list sorted by name', () {
      final json = encodeShortcutItems(const [
        ShortcutItem(kind: ShortcutItemKind.food, targetId: '2', name: 'oats'),
        ShortcutItem(kind: ShortcutItemKind.meal, targetId: '1', name: 'Lunch'),
      ]);
      expect(jsonDecode(json), [
        {'id': 'meal:1', 'name': 'Lunch'},
        {'id': 'food:2', 'name': 'oats'},
      ]);
    });
  });
}
