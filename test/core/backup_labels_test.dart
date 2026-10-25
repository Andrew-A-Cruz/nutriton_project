import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/backup_labels.dart';

void main() {
  group('backupSummary', () {
    test('pluralizes each count', () {
      expect(
        backupSummary(entries: 212, foods: 48, meals: 6),
        '212 entries, 48 foods, 6 meals',
      );
      expect(
        backupSummary(entries: 1, foods: 1, meals: 1),
        '1 entry, 1 food, 1 meal',
      );
      expect(
        backupSummary(entries: 0, foods: 0, meals: 0),
        '0 entries, 0 foods, 0 meals',
      );
    });

    test('lists plans only when there are some', () {
      expect(
        backupSummary(entries: 1, foods: 2, meals: 3, plans: 1),
        '1 entry, 2 foods, 3 meals, 1 scheduled plan',
      );
      expect(
        backupSummary(entries: 1, foods: 2, meals: 3, plans: 4),
        endsWith('4 scheduled plans'),
      );
    });

    test('adds the export date when known', () {
      expect(
        backupSummary(
          entries: 1,
          foods: 1,
          meals: 1,
          exportedAt: DateTime(2026, 10, 21, 8),
        ),
        '1 entry, 1 food, 1 meal\nExported Oct 21, 2026',
      );
    });
  });

  group('lastBackupLabel', () {
    final now = DateTime(2026, 10, 23, 0, 30);

    test('never', () => expect(lastBackupLabel(null, now), 'Never backed up'));

    test('counts calendar days, not 24-hour periods', () {
      expect(lastBackupLabel(DateTime(2026, 10, 23), now), contains('today'));
      // 1 hour earlier but the previous calendar day.
      expect(
        lastBackupLabel(DateTime(2026, 10, 22, 23, 30), now),
        'Last backup: yesterday',
      );
      // Almost 48 hours earlier, still 2 calendar days.
      expect(
        lastBackupLabel(DateTime(2026, 10, 21, 0, 45), now),
        'Last backup: 2 days ago',
      );
      expect(
        lastBackupLabel(DateTime(2026, 9, 23, 12), now),
        'Last backup: 30 days ago',
      );
    });

    test('a time in the future counts as today', () {
      expect(lastBackupLabel(DateTime(2026, 10, 24), now), contains('today'));
    });
  });
}
