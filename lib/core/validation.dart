/// Form rules shared by the food, adhoc and meal forms. Each returns the error
/// to show, or null when the input is valid.
library;

/// Longest name the `food_items` and `meals` tables accept.
const maxNameLength = 100;

/// Names need 2 to [maxNameLength] characters after trimming.
String? requiredName(String value) {
  final length = value.trim().length;
  if (length < 2) return 'Enter a name (at least 2 characters)';
  if (length > maxNameLength) {
    return 'Use at most $maxNameLength characters';
  }
  return null;
}

/// A finite number that is zero or more.
String? nonNegativeNumber(String value) {
  final n = parseNumber(value);
  if (n == null) return 'Enter a number';
  if (n < 0) return 'Cannot be negative';
  return null;
}

/// A finite number greater than zero.
String? positiveNumber(String value) {
  final n = parseNumber(value);
  if (n == null) return 'Enter a number';
  if (n <= 0) return 'Enter a number greater than 0';
  return null;
}

/// The number typed into [value], or null if it is not a finite number.
double? parseNumber(String value) {
  final n = double.tryParse(value.trim());
  return n == null || !n.isFinite ? null : n;
}
