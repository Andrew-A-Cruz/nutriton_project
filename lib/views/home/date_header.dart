import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/date_key.dart';
import '../../providers/log_providers.dart';

/// 'Today', 'Yesterday', 'Mon, Oct 20', or 'Mon, Oct 20, 2025' when the
/// date is not in the same year as [today].
String dayLabel(String key, {required String today}) {
  if (key == today) return 'Today';
  if (key == addDays(today, -1)) return 'Yesterday';
  final date = dateFromKey(key);
  final sameYear = date.year == dateFromKey(today).year;
  return DateFormat(sameYear ? 'EEE, MMM d' : 'EEE, MMM d, y').format(date);
}

/// Day title with previous/next arrows. Tapping the title returns to today.
class DateHeader extends ConsumerWidget {
  const DateHeader({super.key, required this.date});

  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.read(selectedDateProvider.notifier);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          CupertinoButton(
            key: const Key('previous-day'),
            onPressed: () => days.shift(-1),
            child: const Icon(CupertinoIcons.chevron_left),
          ),
          Expanded(
            child: GestureDetector(
              key: const Key('date-title'),
              behavior: HitTestBehavior.opaque,
              onTap: days.goToToday,
              child: Text(
                dayLabel(date, today: todayKey()),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          CupertinoButton(
            key: const Key('next-day'),
            onPressed: () => days.shift(1),
            child: const Icon(CupertinoIcons.chevron_right),
          ),
        ],
      ),
    );
  }
}
