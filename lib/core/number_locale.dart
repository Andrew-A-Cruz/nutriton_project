/// The decimal separator numbers are shown with, from the phone's locale.
/// Pure Dart. Only the separator follows the locale: no grouping (2000, not
/// 2,000) and no other formatting, and dates stay in English with the rest of
/// the app's text. Typed input accepts either separator (`parseNumber`).
library;

import 'package:intl/intl.dart';

String _separator = '.';

/// '.' or ',' (or another locale's symbol).
String get decimalSeparator => _separator;

/// Uses the decimal separator of [localeTag] (e.g. 'de_DE'). An unknown or
/// null locale keeps '.'. Called once at launch.
void useDecimalSeparatorOf(String? localeTag) {
  final locale = localeTag == null
      ? null
      : Intl.verifiedLocale(
          localeTag,
          NumberFormat.localeExists,
          onFailure: (_) => null,
        );
  _separator = locale == null
      ? '.'
      : NumberFormat.decimalPattern(locale).symbols.DECIMAL_SEP;
}

/// Puts the locale's separator into [text], a number written with '.'.
String localizeDecimal(String text) =>
    _separator == '.' ? text : text.replaceAll('.', _separator);

/// Back to '.', for tests.
void resetDecimalSeparator() => _separator = '.';
