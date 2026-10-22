import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/preferences_providers.dart';
import '../../providers/tour_providers.dart';
import 'preferences_form.dart';
import 'welcome_pages.dart';

/// First launch: the welcome pages, then the setup form. Shown until
/// `onboarding_complete` is saved; saving the form flips the app gate in
/// `app.dart` to the tabs and starts the app tour.
class OnboardingView extends StatelessWidget {
  const OnboardingView({super.key});

  @override
  Widget build(BuildContext context) {
    // A nested navigator, so setup can be swiped back to the welcome pages,
    // and finishing removes both at once when the gate swaps in the tabs.
    return Navigator(
      onGenerateRoute: (_) => CupertinoPageRoute<void>(
        builder: (context) => WelcomePages(
          onDone: () => Navigator.of(
            context,
          ).push(CupertinoPageRoute<void>(builder: (_) => const _SetupView())),
        ),
      ),
    );
  }
}

class _SetupView extends ConsumerWidget {
  const _SetupView();

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
                onSubmit: (settings) {
                  ref.read(tourProvider.notifier).start();
                  ref
                      .read(preferencesProvider.notifier)
                      .save(settings.copyWith(onboardingComplete: true));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
