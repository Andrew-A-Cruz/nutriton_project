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
///
/// A comma is accepted as the decimal separator ("1,5"), as typed on many
/// European keyboards. Only a lone comma with no dot is read that way; text
/// with more separators ("1.234,5", "1,234,567") is rejected rather than
/// guessed at.
double? parseNumber(String value) {
  var text = value.trim();
  if (!text.contains('.') && ','.allMatches(text).length == 1) {
    text = text.replaceFirst(',', '.');
  }
  final n = double.tryParse(text);
  return n == null || !n.isFinite ? null : n;
}
