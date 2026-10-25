import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_key.dart';
import '../../providers/infrastructure_providers.dart';
import '../../providers/log_providers.dart';
import '../../providers/today_providers.dart';
import 'date_header.dart';

/// Asks which day to copy and copies its entries onto [toDate]. Resolves to
/// true if a day was copied.
Future<bool> showCopyDaySheet(
  BuildContext context, {
  required String toDate,
}) async {
  final copied = await showCupertinoModalPopup<bool>(
    context: context,
    builder: (_) => _CopyDaySheet(toDate: toDate),
  );
  return copied ?? false;
}

class _CopyDaySheet extends ConsumerStatefulWidget {
  const _CopyDaySheet({required this.toDate});

  final String toDate;

  @override
  ConsumerState<_CopyDaySheet> createState() => _CopyDaySheetState();
}

class _CopyDaySheetState extends ConsumerState<_CopyDaySheet> {
  /// Starts on the day before the one being filled.
  late DateTime _picked = dateFromKey(addDays(widget.toDate, -1));
  bool _copying = false;
  String? _error;

  Future<void> _copy(String fromDate) async {
    if (_copying) return;
    setState(() {
      _copying = true;
      _error = null;
    });
    try {
      await ref
          .read(logRepositoryProvider)
          .copyDay(fromDate: fromDate, toDate: widget.toDate);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _copying = false;
          _error = 'Could not copy: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fromDate = dateKey(_picked);
    final today = ref.watch(todayProvider);
    final count = ref.watch(dayEntriesProvider(fromDate)).value?.length;
    final sameDay = fromDate == widget.toDate;
    final canCopy = !_copying && !sameDay && (count ?? 0) > 0;
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);

    final String summary;
    if (sameDay) {
      summary = 'Pick a different day to copy from.';
    } else if (count == null) {
      summary = '';
    } else {
      summary = count == 0
          ? 'Nothing logged on this day.'
          : '$count ${count == 1 ? 'entry' : 'entries'} on this day.';
    }

    return Container(
      color: CupertinoColors.systemBackground.resolveFrom(context),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const Expanded(
                    child: Text(
                      'Copy from…',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  CupertinoButton(
                    key: const Key('copy-day-confirm'),
                    onPressed: canCopy ? () => _copy(fromDate) : null,
                    child: const Text('Copy'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Copies onto ${dayLabel(widget.toDate, today: today)}. '
                'Entries already there are kept.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: secondary),
              ),
            ),
            SizedBox(
              height: 216,
              child: CupertinoDatePicker(
                key: const Key('copy-day-picker'),
                mode: CupertinoDatePickerMode.date,
                initialDateTime: _picked,
                onDateTimeChanged: (d) => setState(() => _picked = d),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                _error ?? summary,
                key: const Key('copy-day-count'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: _error == null ? secondary : CupertinoColors.systemRed,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
