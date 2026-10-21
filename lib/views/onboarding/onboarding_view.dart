import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/preferences_providers.dart';
import 'preferences_form.dart';

/// First-launch screen. Shown until `onboarding_complete` is saved; saving
/// the form flips the app gate in `app.dart` to the tabs.
class OnboardingView extends ConsumerWidget {
  const OnboardingView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initial = ref.read(preferencesProvider);
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Set up Nutriton'),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Choose what to track and set a daily goal. You can change '
                'this later in Settings.',
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: PreferencesForm(
                initial: initial,
                submitLabel: 'Get started',
                onSubmit: (settings) => ref
                    .read(preferencesProvider.notifier)
                    .save(settings.copyWith(onboardingComplete: true)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
