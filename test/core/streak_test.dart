import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/streak.dart';

void main() {
  test('no entries is no streak', () {
    expect(currentStreak(const [], today: '2026-10-21'), 0);
  });

  test('counts consecutive days ending today', () {
    expect(
      currentStreak([
        '2026-10-21',
        '2026-10-20',
        '2026-10-19',
      ], today: '2026-10-21'),
      3,
    );
  });

  test('an empty today does not break the streak', () {
    expect(currentStreak(['2026-10-20', '2026-10-19'], today: '2026-10-21'), 2);
  });

  test('the streak is gone once yesterday is also empty', () {
    expect(currentStreak(['2026-10-19', '2026-10-18'], today: '2026-10-21'), 0);
  });

  test('a gap ends the count', () {
    expect(
      currentStreak([
        '2026-10-21',
        '2026-10-20',
        '2026-10-18',
        '2026-10-17',
      ], today: '2026-10-21'),
      2,
    );
  });

  test('only today logged is a streak of 1', () {
    expect(currentStreak(['2026-10-21'], today: '2026-10-21'), 1);
  });

  test('dates after today are ignored', () {
    expect(currentStreak(['2026-10-23', '2026-10-22'], today: '2026-10-21'), 0);
    expect(currentStreak(['2026-10-22', '2026-10-21'], today: '2026-10-21'), 1);
  });

  test('crosses month and year boundaries, including a leap day', () {
    expect(
      currentStreak([
        '2026-11-01',
        '2026-10-31',
        '2026-10-30',
      ], today: '2026-11-01'),
      3,
    );
    expect(
      currentStreak([
        '2027-01-01',
        '2026-12-31',
        '2026-12-30',
      ], today: '2027-01-01'),
      3,
    );
    expect(
      currentStreak([
        '2028-03-01',
        '2028-02-29',
        '2028-02-28',
      ], today: '2028-03-01'),
      3,
    );
  });

  test('crosses daylight-saving changes (keys are calendar days)', () {
    // US spring-forward (2026-03-08) and fall-back (2026-11-01).
    expect(
      currentStreak([
        '2026-03-09',
        '2026-03-08',
        '2026-03-07',
      ], today: '2026-03-09'),
      3,
    );
    expect(
      currentStreak([
        '2026-11-02',
        '2026-11-01',
        '2026-10-31',
      ], today: '2026-11-02'),
      3,
    );
  });

  test('duplicates and order do not matter', () {
    expect(
      currentStreak([
        '2026-10-19',
        '2026-10-21',
        '2026-10-20',
        '2026-10-21',
      ], today: '2026-10-21'),
      3,
    );
  });
}
