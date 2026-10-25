import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/preferences_providers.dart';
import '../../providers/tour_providers.dart';
import '../onboarding/preferences_form.dart';
import 'apple_health_section.dart';
import 'backup_section.dart';
import 'reminders_section.dart';

/// Settings, opened from the gear on Home. Reuses the onboarding form, so the
/// two screens cannot drift apart. Saving applies at once and pops back.
class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initial = ref.read(preferencesProvider);
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Settings')),
      child: SafeArea(
        child: PreferencesForm(
          initial: initial,
          submitLabel: 'Save',
          extraSections: const [
            RemindersSection(),
            AppleHealthSection(),
            BackupSection(),
            _HelpSection(),
          ],
          onSubmit: (settings) async {
            final notifier = ref.read(preferencesProvider.notifier);
            // Reminders and Health switches save as they change, so the form's
            // copy may be stale.
            final current = ref.read(preferencesProvider);
            await notifier.save(
              settings.copyWith(
                reminders: current.reminders,
                healthWriteNutrition: current.healthWriteNutrition,
                healthReadWeight: current.healthReadWeight,
              ),
            );
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}

/// Replays the app tour. Goes back to Today first, where the tour points.
class _HelpSection extends ConsumerWidget {
  const _HelpSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CupertinoFormSection.insetGrouped(
      header: const Text('HELP'),
      children: [
        CupertinoListTile(
          key: const Key('show-tour'),
          title: const Text('Show app tour'),
          trailing: const CupertinoListTileChevron(),
          onTap: () {
            ref.read(tourProvider.notifier).start();
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
