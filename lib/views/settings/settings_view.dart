import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/preferences_providers.dart';
import '../onboarding/preferences_form.dart';
import 'backup_section.dart';

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
          extraSections: const [BackupSection()],
          onSubmit: (settings) async {
            await ref.read(preferencesProvider.notifier).save(settings);
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}
