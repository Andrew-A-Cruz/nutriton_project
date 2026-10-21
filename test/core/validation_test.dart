import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/validation.dart';

void main() {
  group('requiredName', () {
    test('needs at least two characters after trimming', () {
      expect(requiredName(''), isNotNull);
      expect(requiredName(' a '), isNotNull);
      expect(requiredName('ab'), isNull);
    });

    test('rejects names longer than the database allows', () {
      expect(requiredName('a' * maxNameLength), isNull);
      expect(requiredName('  ${'a' * maxNameLength}  '), isNull);
      expect(requiredName('a' * (maxNameLength + 1)), isNotNull);
    });
  });

  group('parseNumber', () {
    test('rejects non-finite values', () {
      expect(parseNumber('Infinity'), isNull);
      expect(parseNumber('1e400'), isNull);
      expect(parseNumber('NaN'), isNull);
      expect(parseNumber('2.5'), 2.5);
    });
  });

  group('nonNegativeNumber', () {
    test('accepts zero and positive numbers', () {
      expect(nonNegativeNumber('0'), isNull);
      expect(nonNegativeNumber(' 2.5 '), isNull);
    });

    test('rejects negatives, blanks and text', () {
      expect(nonNegativeNumber('-1'), 'Cannot be negative');
      expect(nonNegativeNumber(''), 'Enter a number');
      expect(nonNegativeNumber('abc'), 'Enter a number');
      expect(nonNegativeNumber('NaN'), 'Enter a number');
    });
  });

  group('positiveNumber', () {
    test('rejects zero', () {
      expect(positiveNumber('0'), 'Enter a number greater than 0');
      expect(positiveNumber('0.1'), isNull);
    });
  });
}
