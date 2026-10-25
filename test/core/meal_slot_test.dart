import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/meal_slot.dart';

void main() {
  MealSlot at(int h, int m) => MealSlot.forTime(DateTime(2026, 10, 23, h, m));

  test('forTime boundaries', () {
    expect(at(0, 0), MealSlot.breakfast);
    expect(at(10, 29), MealSlot.breakfast);
    expect(at(10, 30), MealSlot.lunch);
    expect(at(14, 59), MealSlot.lunch);
    expect(at(15, 0), MealSlot.dinner);
    expect(at(19, 59), MealSlot.dinner);
    expect(at(20, 0), MealSlot.snack);
    expect(at(23, 59), MealSlot.snack);
  });

  test('fromName and label', () {
    expect(MealSlot.fromName('lunch'), MealSlot.lunch);
    expect(MealSlot.fromName(null), isNull);
    expect(MealSlot.fromName('brunch'), isNull);
    expect(MealSlot.breakfast.label, 'Breakfast');
  });
}
