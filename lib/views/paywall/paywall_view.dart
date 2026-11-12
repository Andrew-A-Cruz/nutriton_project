import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/pro.dart';
import '../../data/store/store_service.dart';
import '../../providers/entitlement_providers.dart';
import '../../providers/today_providers.dart';

/// Opens the paywall. The only way in is the user asking: a locked Pro
/// feature, or Settings. It is never shown on its own. Pushed on the tab's
/// navigator, like Add Food, so the root (and the plans it keeps running)
/// stays active underneath.
Future<void> showPaywall(BuildContext context) => Navigator.of(context).push(
  CupertinoPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => const PaywallView(),
  ),
);

/// The one paywall: what Pro adds, that everything else stays free, and the
/// store's price. Lists only Pro features that are built.
class PaywallView extends ConsumerStatefulWidget {
  const PaywallView({super.key});

  @override
  ConsumerState<PaywallView> createState() => _PaywallViewState();
}

class _PaywallViewState extends ConsumerState<PaywallView> {
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on StoreException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'The App Store could not complete this.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _buy(String id) =>
      _run(() => ref.read(proStatusProvider.notifier).buy(id));

  Future<void> _restore() => _run(() async {
    await ref.read(proStatusProvider.notifier).restore();
    if (mounted && !ref.read(proProvider)) {
      setState(() => _error = 'No earlier Pro purchase was found.');
    }
  });

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(proAccessProvider);
    final status = ref.watch(proStatusProvider);
    final storeAvailable = ref.watch(storeServiceProvider).isAvailable;
    final items = ref.watch(storeItemsProvider);
    final pro = items.value?[ProProducts.pro];
    final trial = items.value?[ProProducts.trial];
    final daysLeft = trialDaysLeft(status, ref.read(clockProvider)());
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Logbite Pro'),
        leading: CupertinoButton(
          key: const Key('paywall-close'),
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text(
              'A few extras, one purchase.',
              style: CupertinoTheme.of(context).textTheme.navTitleTextStyle,
            ),
            const SizedBox(height: 16),
            for (final feature in ProFeature.shipped)
              _FeatureRow(feature: feature),
            const SizedBox(height: 8),
            Text(
              'Everything else stays free: logging, the catalog, barcode '
              'scan, planned meals, all your history and charts, and backups. '
              'No account, no ads, no tracking.',
              style: TextStyle(color: secondary),
            ),
            const SizedBox(height: 24),
            // Above the buttons, so it is on screen on a small phone.
            if (_error case final error?)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  error,
                  key: const Key('paywall-error'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: CupertinoColors.systemRed),
                ),
              ),
            switch (access) {
              ProAccess.owned => const Text(
                'Pro is unlocked. Thank you for supporting Logbite.',
                key: Key('paywall-owned'),
                textAlign: TextAlign.center,
              ),
              ProAccess.trial || ProAccess.free => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (daysLeft != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Your trial has $daysLeft '
                        '${daysLeft == 1 ? 'day' : 'days'} left.',
                        key: const Key('paywall-trial-left'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (!storeAvailable)
                    Text(
                      'Purchases are not available in this build.',
                      key: const Key('paywall-unavailable'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: secondary),
                    )
                  else if (items.isLoading)
                    const CupertinoActivityIndicator()
                  else if (pro == null)
                    Text(
                      'Could not reach the App Store. Try again later.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: secondary),
                    )
                  else ...[
                    CupertinoButton.filled(
                      key: const Key('paywall-buy'),
                      onPressed: _busy ? null : () => _buy(pro.id),
                      child: Text('Unlock Pro for ${pro.priceText}'),
                    ),
                    if (trial != null && status.trialStartedAt == null)
                      CupertinoButton(
                        key: const Key('paywall-trial'),
                        onPressed: _busy ? null : () => _buy(trial.id),
                        child: const Text('Try it free for $proTrialDays days'),
                      ),
                  ],
                  if (storeAvailable)
                    CupertinoButton(
                      key: const Key('paywall-restore'),
                      onPressed: _busy ? null : _restore,
                      child: const Text('Restore Purchases'),
                    ),
                ],
              ),
            },
            const SizedBox(height: 16),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LinkButton(label: 'Privacy Policy', url: privacyPolicyUrl),
                _LinkButton(label: 'Terms of Use', url: termsOfUseUrl),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.feature});

  final ProFeature feature;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            CupertinoIcons.checkmark_circle_fill,
            color: CupertinoTheme.of(context).primaryColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  feature.description,
                  style: TextStyle(
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      onPressed: () => launchUrl(Uri.parse(url)),
      child: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}
