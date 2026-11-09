import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/body_weight.dart';
import 'package:nutriton_project/core/metrics.dart';
import 'package:nutriton_project/core/number_locale.dart';
import 'package:nutriton_project/core/validation.dart';

void main() {
  tearDown(resetDecimalSeparator);

  test('a comma locale shows decimals with a comma', () {
    useDecimalSeparatorOf('de_DE');
    expect(decimalSeparator, ',');
    expect(Metric.protein.format(12.5), '12,5');
    expect(Metric.protein.formatWithUnit(30), '30,0 g');
    expect(Metric.calories.format(1234.4), '1234');
    expect(plainNumber(1.5), '1,5');
    expect(plainNumber(2000), '2000');
    expect(formatBodyWeight(80.5, BodyWeightUnit.kg), '80,5 kg');
  });

  test('a prefilled field reads back the same number', () {
    useDecimalSeparatorOf('fr_FR');
    expect(parseNumber(plainNumber(66.7)), 66.7);
  });

  test('dot locales and unknown or missing locales keep a dot', () {
    useDecimalSeparatorOf('en_US');
    expect(Metric.protein.format(12.5), '12.5');
    useDecimalSeparatorOf('xx_YY');
    expect(decimalSeparator, '.');
    useDecimalSeparatorOf(null);
    expect(plainNumber(1.5), '1.5');
  });
}
