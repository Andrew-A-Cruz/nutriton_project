import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/pro.dart';
import 'package:nutriton_project/core/review_prompt.dart';

void main() {
  final start = DateTime(2026, 11, 1, 9);

  group('proAccess', () {
    test('nothing owned is free', () {
      expect(proAccess(ProStatus.none, start), ProAccess.free);
    });

    test('a purchase or grandfathering is owned, whatever the trial', () {
      expect(
        proAccess(const ProStatus(purchased: true), start),
        ProAccess.owned,
      );
      expect(
        proAccess(const ProStatus(grandfathered: true), start),
        ProAccess.owned,
      );
      expect(
        proAccess(
          ProStatus(purchased: true, trialStartedAt: start),
          start.add(const Duration(days: 100)),
        ),
        ProAccess.owned,
      );
    });

    test('the trial lasts exactly 14 days from its start', () {
      final status = ProStatus(trialStartedAt: start);
      expect(proAccess(status, start), ProAccess.trial);
      expect(
        proAccess(status, start.add(const Duration(days: 14, minutes: -1))),
        ProAccess.trial,
      );
      expect(
        proAccess(status, start.add(const Duration(days: 14))),
        ProAccess.free,
      );
    });
  });

  group('trialDaysLeft', () {
    test('counts a part day as a day', () {
      final status = ProStatus(trialStartedAt: start);
      expect(trialDaysLeft(status, start), 14);
      expect(trialDaysLeft(status, start.add(const Duration(hours: 1))), 14);
      expect(
        trialDaysLeft(status, start.add(const Duration(days: 13, hours: 23))),
        1,
      );
    });

    test('is null outside a trial', () {
      expect(trialDaysLeft(ProStatus.none, start), isNull);
      expect(
        trialDaysLeft(ProStatus(purchased: true, trialStartedAt: start), start),
        isNull,
      );
      expect(
        trialDaysLeft(
          ProStatus(trialStartedAt: start),
          start.add(const Duration(days: 15)),
        ),
        isNull,
      );
    });
  });

  group('trialHasEnded', () {
    test('only after a trial that ran out without a purchase', () {
      final later = start.add(const Duration(days: 20));
      expect(trialHasEnded(ProStatus.none, later), isFalse);
      expect(trialHasEnded(ProStatus(trialStartedAt: start), start), isFalse);
      expect(trialHasEnded(ProStatus(trialStartedAt: start), later), isTrue);
      expect(
        trialHasEnded(ProStatus(purchased: true, trialStartedAt: start), later),
        isFalse,
      );
    });
  });

  group('isGrandfathered', () {
    test('off without a cutoff', () {
      expect(isGrandfathered('1'), isFalse);
      expect(isGrandfathered('1', beforeBuild: null), isFalse);
    });

    test('original builds below the cutoff qualify', () {
      expect(isGrandfathered('41', beforeBuild: 42), isTrue);
      expect(isGrandfathered('41.0', beforeBuild: 42), isTrue);
      expect(isGrandfathered(' 3 ', beforeBuild: 42), isTrue);
      expect(isGrandfathered('42', beforeBuild: 42), isFalse);
      expect(isGrandfathered('50', beforeBuild: 42), isFalse);
    });

    test('anything unreadable does not', () {
      expect(isGrandfathered(null, beforeBuild: 42), isFalse);
      expect(isGrandfathered('', beforeBuild: 42), isFalse);
      expect(isGrandfathered('1.0.3', beforeBuild: 42), isFalse);
      expect(isGrandfathered('41.5', beforeBuild: 42), isFalse);
    });
  });

  test('the paywall lists only built Pro features', () {
    expect(ProFeature.shipped, [ProFeature.widget, ProFeature.appleHealth]);
  });

  group('shouldAskForReview', () {
    test('asks once, right after logging, from the 7th logged day', () {
      expect(
        shouldAskForReview(
          loggedDays: 7,
          alreadyAsked: false,
          justLogged: true,
        ),
        isTrue,
      );
      expect(
        shouldAskForReview(
          loggedDays: 30,
          alreadyAsked: false,
          justLogged: true,
        ),
        isTrue,
      );
    });

    test('not before 7 days, not twice, and not without a new entry', () {
      expect(
        shouldAskForReview(
          loggedDays: 6,
          alreadyAsked: false,
          justLogged: true,
        ),
        isFalse,
      );
      expect(
        shouldAskForReview(loggedDays: 7, alreadyAsked: true, justLogged: true),
        isFalse,
      );
      expect(
        shouldAskForReview(
          loggedDays: 7,
          alreadyAsked: false,
          justLogged: false,
        ),
        isFalse,
      );
    });
  });
}
