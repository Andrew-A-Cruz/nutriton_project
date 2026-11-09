import 'package:flutter_test/flutter_test.dart';
import 'package:nutriton_project/core/auto_backup.dart';
import 'package:nutriton_project/core/backup_labels.dart';

void main() {
  final now = DateTime(2026, 11, 3, 9);

  test('due when never written, or a week or more ago', () {
    expect(autoBackupDue(null, now), isTrue);
    expect(autoBackupDue(DateTime(2026, 11, 3, 1), now), isFalse);
    expect(autoBackupDue(DateTime(2026, 10, 28, 23), now), isFalse);
    expect(autoBackupDue(DateTime(2026, 10, 27, 23), now), isTrue);
  });

  test('a week counts calendar days, so a DST change does not matter', () {
    // Clocks went back on 2026-10-25 in Europe.
    expect(
      autoBackupDue(DateTime(2026, 10, 20, 9), DateTime(2026, 10, 27, 8)),
      isTrue,
    );
  });

  test('file names carry the date and round-trip', () {
    final name = autoBackupFileName(now);
    expect(name, 'logbite-auto-2026-11-03.json');
    expect(autoBackupDate(name), DateTime(2026, 11, 3));
    expect(autoBackupDate('logbite-backup-2026-11-03.json'), isNull);
    expect(autoBackupDate('logbite-auto-2026-02-30.json'), isNull);
    expect(autoBackupDate('notes.txt'), isNull);
  });

  test('keeps the newest few and ignores other files', () {
    final names = [
      for (var d = 1; d <= 8; d++)
        autoBackupFileName(DateTime(2026, 10, d * 3)),
      'notes.txt',
    ];
    expect(autoBackupsNewestFirst(names).first, 'logbite-auto-2026-10-24.json');
    final pruned = autoBackupsToPrune(names);
    expect(pruned, hasLength(8 - autoBackupsKept));
    expect(pruned, isNot(contains('notes.txt')));
    expect(pruned.last, 'logbite-auto-2026-10-03.json');
  });

  test('backups named before the rename still count and are pruned first', () {
    final names = [
      'nutriton-auto-2026-10-01.json',
      'nutriton-auto-2026-10-08.json',
      for (var d = 15; d <= 36; d += 7)
        autoBackupFileName(DateTime(2026, 10, d)),
    ];
    expect(
      autoBackupDate('nutriton-auto-2026-10-08.json'),
      DateTime(2026, 10, 8),
    );
    expect(autoBackupsNewestFirst(names).last, 'nutriton-auto-2026-10-01.json');
    expect(autoBackupsToPrune(names), ['nutriton-auto-2026-10-01.json']);
  });

  test('labels the last automatic backup', () {
    expect(lastAutoBackupLabel(null, now), 'No automatic backup yet');
    expect(
      lastAutoBackupLabel(DateTime(2026, 11, 1), now),
      'Last automatic backup: 2 days ago',
    );
  });
}
