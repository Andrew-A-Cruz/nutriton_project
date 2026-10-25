import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/reminder.dart';
import '../../providers/preferences_providers.dart';
import '../../providers/reminder_providers.dart';

/// Settings section for up to three daily reminders, off by default. Changes
/// save at once. Notification permission is asked for when a reminder is first
/// turned on, and a refusal leaves it off.
class RemindersSection extends ConsumerStatefulWidget {
  const RemindersSection({super.key});

  @override
  ConsumerState<RemindersSection> createState() => _RemindersSectionState();
}

class _RemindersSectionState extends ConsumerState<RemindersSection> {
  String? _denied;

  Future<void> _update(int slot, Reminder Function(Reminder) change) {
    final settings = ref.read(preferencesProvider);
    final reminders = [...settings.reminders];
    reminders[slot] = change(reminders[slot]);
    return ref
        .read(preferencesProvider.notifier)
        .save(settings.copyWith(reminders: reminders));
  }

  Future<void> _toggle(int slot, bool on) async {
    if (on) {
      final granted = await ref
          .read(notificationSchedulerProvider)
          .requestPermission();
      if (!mounted) return;
      if (!granted) {
        setState(
          () => _denied =
              'Notifications are not allowed for Nutriton. Turn them on in '
              'your device settings to use reminders.',
        );
        return;
      }
    }
    setState(() => _denied = null);
    await _update(slot, (r) => r.copyWith(enabled: on));
  }

  Future<void> _pickTime(int slot) async {
    final current = ref.read(preferencesProvider).reminders[slot];
    var picked = current.minutes;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => Container(
        height: 280,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: CupertinoButton(
                  key: const Key('reminder-time-done'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: DateTime(
                    2000,
                    1,
                    1,
                    current.hour,
                    current.minute,
                  ),
                  onDateTimeChanged: (t) => picked = t.hour * 60 + t.minute,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != current.minutes) {
      await _update(slot, (r) => r.copyWith(minutes: picked));
    }
  }

  static String _format(Reminder r) =>
      DateFormat.jm().format(DateTime(2000, 1, 1, r.hour, r.minute));

  @override
  Widget build(BuildContext context) {
    final reminders = ref.watch(preferencesProvider.select((s) => s.reminders));
    return CupertinoFormSection.insetGrouped(
      header: const Text('REMINDERS'),
      footer: Text(
        _denied ??
            'A daily notification when nothing is logged yet. It is skipped '
                'on days you have already logged.',
        style: _denied == null
            ? null
            : const TextStyle(color: CupertinoColors.systemRed),
      ),
      children: [
        for (var i = 0; i < reminders.length; i++)
          CupertinoListTile(
            title: Text('Reminder ${i + 1}'),
            additionalInfo: CupertinoButton(
              key: Key('reminder-time-$i'),
              padding: EdgeInsets.zero,
              onPressed: () => _pickTime(i),
              child: Text(_format(reminders[i])),
            ),
            trailing: CupertinoSwitch(
              key: Key('reminder-switch-$i'),
              value: reminders[i].enabled,
              onChanged: (on) => _toggle(i, on),
            ),
          ),
      ],
    );
  }
}
