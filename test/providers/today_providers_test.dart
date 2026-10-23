import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/providers/log_providers.dart';
import 'package:nutriton_project/providers/today_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Day D is 2026-10-21. Tests move the clock by reassigning `now`.
  late DateTime now;

  /// A container whose clock reads [now]. Plain tests dispose it with
  /// addTearDown. testWidgets bodies must dispose it themselves (see
  /// [disposeAtEnd]), because the pending-timer check runs before tearDown
  /// callbacks.
  ProviderContainer makeContainer() => ProviderContainer(
    overrides: [clockProvider.overrideWithValue(() => now)],
  );

  setUp(() {
    now = DateTime(2026, 10, 21, 9, 30);
  });

  test('todayProvider reads the injected clock', () {
    final container = makeContainer();
    addTearDown(container.dispose);

    expect(container.read(todayProvider), '2026-10-21');
  });

  test('refresh() after moving the clock past midnight updates the key', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    expect(container.read(todayProvider), '2026-10-21');

    now = DateTime(2026, 10, 22, 0, 5);
    container.read(todayProvider.notifier).refresh();

    expect(container.read(todayProvider), '2026-10-22');
  });

  test('refresh() with an unchanged clock changes neither today nor the '
      'selected date', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    expect(container.read(selectedDateProvider), '2026-10-21');

    container.read(todayProvider.notifier).refresh();

    expect(container.read(todayProvider), '2026-10-21');
    expect(container.read(selectedDateProvider), '2026-10-21');
  });

  test('selected date follows today when it was on the old today', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    expect(container.read(selectedDateProvider), '2026-10-21');

    now = DateTime(2026, 10, 22, 0, 5);
    container.read(todayProvider.notifier).refresh();

    expect(container.read(selectedDateProvider), '2026-10-22');
  });

  test('selected date stays put when the user had picked another day', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    container.read(selectedDateProvider.notifier).select('2026-10-19');

    now = DateTime(2026, 10, 22, 0, 5);
    container.read(todayProvider.notifier).refresh();

    expect(container.read(todayProvider), '2026-10-22');
    expect(container.read(selectedDateProvider), '2026-10-19');
  });

  test('goToToday() goes to the current, post-rollover today', () {
    final container = makeContainer();
    addTearDown(container.dispose);
    container.read(selectedDateProvider.notifier).select('2026-10-18');

    now = DateTime(2026, 10, 22, 0, 5);
    container.read(todayProvider.notifier).refresh();
    container.read(selectedDateProvider.notifier).goToToday();

    expect(container.read(selectedDateProvider), '2026-10-22');
  });

  testWidgets('the midnight timer moves today forward without a resume', (
    tester,
  ) async {
    now = DateTime(2026, 10, 21, 23, 59, 30);
    final container = makeContainer();
    try {
      // Read both before the clock moves, so the selected date is already
      // listening to today when the timer fires.
      expect(container.read(todayProvider), '2026-10-21');
      expect(container.read(selectedDateProvider), '2026-10-21');

      // The timer was armed for the 30 s left before midnight.
      now = DateTime(2026, 10, 22, 0, 0, 1);
      await tester.pump(const Duration(seconds: 31));

      expect(container.read(todayProvider), '2026-10-22');
      expect(container.read(selectedDateProvider), '2026-10-22');
    } finally {
      // Cancels the timer that refresh() re-armed for the next midnight.
      container.dispose();
    }
  });

  testWidgets('the timer re-arms for the following midnight', (tester) async {
    now = DateTime(2026, 10, 21, 23, 59, 30);
    final container = makeContainer();
    try {
      expect(container.read(todayProvider), '2026-10-21');
      expect(container.read(selectedDateProvider), '2026-10-21');

      now = DateTime(2026, 10, 22, 0, 0, 1);
      await tester.pump(const Duration(seconds: 31));
      expect(container.read(todayProvider), '2026-10-22');
      expect(container.read(selectedDateProvider), '2026-10-22');

      // The timer armed by that rollover fires at the next midnight, about
      // 24 h later.
      now = DateTime(2026, 10, 23, 0, 0, 1);
      await tester.pump(const Duration(hours: 24));

      expect(container.read(todayProvider), '2026-10-23');
      expect(container.read(selectedDateProvider), '2026-10-23');
    } finally {
      container.dispose();
    }
  });
}
