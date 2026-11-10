import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/portions.dart';

void main() {
  test('reads the portion from a serving text', () {
    expect(parsePortion('1 cup (240 g)'), (name: 'cup', count: 1));
    expect(parsePortion('2 slices (56g)'), (name: 'slice', count: 2));
    expect(parsePortion('1/2 bar (25 g)'), (name: 'bar', count: 0.5));
    expect(parsePortion('1,5 Glass (300 ml)'), (name: 'glass', count: 1.5));
    expect(parsePortion('Tablespoon (15 g)'), (name: 'tablespoon', count: 1));
  });

  test('no name, no portion', () {
    expect(parsePortion('30 g'), isNull);
    expect(parsePortion('30 g (1 oz)'), isNull);
    expect(parsePortion(null), isNull);
    expect(parsePortion(''), isNull);
  });

  test('portions to servings', () {
    expect(
      servingsForPortions(count: 1.5, portionWeightG: 240, servingWeightG: 120),
      3,
    );
  });
}
