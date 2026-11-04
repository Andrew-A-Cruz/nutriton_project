import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// One recorded failure.
class ErrorLogEntry {
  const ErrorLogEntry({
    required this.at,
    required this.context,
    required this.message,
    this.stack,
  });

  factory ErrorLogEntry.fromJson(Map<String, dynamic> json) => ErrorLogEntry(
    at: DateTime.parse(json['at'] as String),
    context: json['context'] as String,
    message: json['message'] as String,
    stack: json['stack'] as String?,
  );

  final DateTime at;

  /// What the app was doing, e.g. "Log food".
  final String context;
  final String message;
  final String? stack;

  Map<String, dynamic> toJson() => {
    'at': at.toIso8601String(),
    'context': context,
    'message': message,
    if (stack != null) 'stack': stack,
  };
}

/// The most recent failures, newest first, kept on the device in preferences
/// so a problem can be looked at (and shared) after it happened. Nothing is
/// sent anywhere. Not part of the backup.
class ErrorLog {
  ErrorLog(this._prefs, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const prefsKey = 'error_log';

  /// Older entries are dropped beyond this many.
  static const maxEntries = 50;

  /// Stack traces are cut to this many characters.
  static const maxStackLength = 2000;

  final SharedPreferences _prefs;
  final DateTime Function() _clock;

  List<ErrorLogEntry> get entries {
    final raw = _prefs.getStringList(prefsKey) ?? const [];
    final result = <ErrorLogEntry>[];
    for (final line in raw) {
      try {
        result.add(
          ErrorLogEntry.fromJson(jsonDecode(line) as Map<String, dynamic>),
        );
      } on Object {
        // A damaged line is skipped rather than hiding the rest.
      }
    }
    return result;
  }

  /// Adds [error] under [context]. Never throws: a failure to record must not
  /// cause a second one.
  Future<void> record(
    Object error,
    StackTrace? stack, {
    required String context,
  }) async {
    try {
      var trace = stack?.toString();
      if (trace != null && trace.length > maxStackLength) {
        trace = trace.substring(0, maxStackLength);
      }
      final entry = ErrorLogEntry(
        at: _clock(),
        context: context,
        message: '$error',
        stack: trace == null || trace.isEmpty ? null : trace,
      );
      final raw = _prefs.getStringList(prefsKey) ?? const [];
      await _prefs.setStringList(prefsKey, [
        jsonEncode(entry.toJson()),
        ...raw.take(maxEntries - 1),
      ]);
    } on Object {
      // Recording is best effort.
    }
  }

  Future<void> clear() => _prefs.remove(prefsKey);

  /// Every entry as plain text, for sharing.
  String exportText() {
    final buffer = StringBuffer();
    for (final e in entries) {
      buffer
        ..writeln('${e.at.toIso8601String()}  ${e.context}')
        ..writeln(e.message);
      if (e.stack != null) buffer.writeln(e.stack);
      buffer.writeln();
    }
    return buffer.toString();
  }
}
