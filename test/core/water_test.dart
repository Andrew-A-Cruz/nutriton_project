import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/water.dart';

void main() {
  group('adjustWater', () {
    test('adds and takes away', () {
      expect(adjustWater(0, 250), 250);
      expect(adjustWater(750, -250), 500);
    });

    test('never goes below 0 or above the cap', () {
      expect(adjustWater(100, -250), 0);
      expect(adjustWater(0, -250), 0);
      expect(adjustWater(maxWaterMl - 100, 250), maxWaterMl);
    });
  });

  group('formatting', () {
    test('glasses are singular at exactly one', () {
      expect(formatWater(250, WaterUnit.glasses), '1 glass');
      expect(formatWater(0, WaterUnit.glasses), '0 glasses');
      expect(formatWater(750, WaterUnit.glasses), '3 glasses');
      expect(formatWater(625, WaterUnit.glasses), '2.5 glasses');
    });

    test('ml are whole numbers', () {
      expect(formatWater(750, WaterUnit.ml), '750 ml');
      expect(formatWater(333.4, WaterUnit.ml), '333 ml');
    });

    test('progress shows the goal only when there is one', () {
      expect(waterProgressText(750, const WaterSettings()), '3 glasses');
      expect(
        waterProgressText(750, const WaterSettings(goalMl: 2000)),
        '3 of 8 glasses',
      );
      expect(
        waterProgressText(
          750,
          const WaterSettings(unit: WaterUnit.ml, goalMl: 2000),
        ),
        '750 of 2000 ml',
      );
    });
  });

  test('a goal typed in glasses is stored in ml', () {
    expect(waterGoalToMl(8, WaterUnit.glasses), 2000);
    expect(waterGoalToMl(1800, WaterUnit.ml), 1800);
  });

  test('the average leaves out nothing it is given and is null when empty', () {
    expect(averageWaterMl(const []), isNull);
    expect(averageWaterMl(const [1000, 2000]), 1500);
  });

  test('settings compare by value and keep the other fields', () {
    const base = WaterSettings(goalMl: 2000);
    expect(base.withUnit(WaterUnit.ml).goalMl, 2000);
    expect(base.withEnabled(false).unit, WaterUnit.glasses);
    expect(base.withGoalMl(null).goalMl, isNull);
    expect(base, const WaterSettings(goalMl: 2000));
  });
}
