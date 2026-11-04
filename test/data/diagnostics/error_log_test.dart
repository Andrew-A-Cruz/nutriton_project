import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/data/diagnostics/error_log.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  var now = DateTime(2026, 11, 3, 9);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    now = DateTime(2026, 11, 3, 9);
  });

  ErrorLog log() => ErrorLog(prefs, clock: () => now);

  test('starts empty', () {
    expect(log().entries, isEmpty);
    expect(log().exportText(), isEmpty);
  });

  test('records newest first, with context, message and stack', () async {
    await log().record(StateError('first'), null, context: 'Could not save');
    now = now.add(const Duration(minutes: 1));
    await log().record(
      Exception('second'),
      StackTrace.fromString('#0 main'),
      context: 'Could not log food',
    );

    final entries = log().entries;
    expect(entries.map((e) => e.context), [
      'Could not log food',
      'Could not save',
    ]);
    expect(entries.first.message, 'Exception: second');
    expect(entries.first.stack, '#0 main');
    expect(entries.first.at, DateTime(2026, 11, 3, 9, 1));
    expect(entries.last.stack, isNull);
  });

  test('keeps at most maxEntries, dropping the oldest', () async {
    for (var i = 0; i < ErrorLog.maxEntries + 5; i++) {
      await log().record('error $i', null, context: 'c');
    }
    final entries = log().entries;
    expect(entries, hasLength(ErrorLog.maxEntries));
    expect(entries.first.message, 'error ${ErrorLog.maxEntries + 4}');
    expect(entries.last.message, 'error 5');
  });

  test('cuts long stack traces', () async {
    await log().record(
      'boom',
      StackTrace.fromString('x' * (ErrorLog.maxStackLength + 100)),
      context: 'c',
    );
    expect(log().entries.single.stack, hasLength(ErrorLog.maxStackLength));
  });

  test('skips a damaged line instead of losing the rest', () async {
    await log().record('good', null, context: 'c');
    await prefs.setStringList(ErrorLog.prefsKey, [
      'not json',
      ...prefs.getStringList(ErrorLog.prefsKey)!,
    ]);
    expect(log().entries.single.message, 'good');
  });

  test('clear removes everything', () async {
    await log().record('boom', null, context: 'c');
    await log().clear();
    expect(log().entries, isEmpty);
  });

  test('exportText lists each entry with its time and context', () async {
    await log().record(
      'boom',
      StackTrace.fromString('#0 f'),
      context: 'Could not save',
    );
    final text = log().exportText();
    expect(text, contains('2026-11-03T09:00:00.000  Could not save'));
    expect(text, contains('boom'));
    expect(text, contains('#0 f'));
  });
}
