import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/pro.dart';
import '../../data/store/store_service.dart';
import '../../providers/entitlement_providers.dart';
import '../../providers/today_providers.dart';
import '../paywall/paywall_view.dart';

/// Settings section for Nutriton Pro (its status, opening the paywall,
/// restoring) and the tip jar.
class ProSection extends ConsumerStatefulWidget {
  const ProSection({super.key});

  @override
  ConsumerState<ProSection> createState() => _ProSectionState();
}

class _ProSectionState extends ConsumerState<ProSection> {
  bool _busy = false;
  String? _status;
  bool _statusIsError = false;

  Future<void> _run(
    Future<String?> Function() action, {
    String failure = 'The App Store could not complete this.',
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = null;
    });
    String? message;
    var error = false;
    try {
      message = await action();
    } on StoreException catch (e) {
      message = e.message;
      error = true;
    } catch (_) {
      message = failure;
      error = true;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = message;
      _statusIsError = error;
    });
  }

  Future<void> _restore() => _run(() async {
    await ref.read(proStatusProvider.notifier).restore();
    return ref.read(proProvider)
        ? 'Purchases restored.'
        : 'No earlier Pro purchase was found.';
  });

  Future<void> _tip(String id) => _run(() async {
    final done = await ref.read(proStatusProvider.notifier).buy(id);
    return done ? 'Thank you for the tip!' : null;
  });

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(proAccessProvider);
    final status = ref.watch(proStatusProvider);
    final storeAvailable = ref.watch(storeServiceProvider).isAvailable;
    final items = ref.watch(storeItemsProvider).value ?? const {};
    final tips = [
      for (final id in ProProducts.tips)
        if (items[id] case final StoreItem item) item,
    ];
    final daysLeft = trialDaysLeft(status, ref.read(clockProvider)());

    return CupertinoFormSection.insetGrouped(
      header: const Text('NUTRITON PRO'),
      footer: _status == null
          ? const Text(
              'Pro adds a few extras. Everything else is free, for good.',
            )
          : Text(
              _status!,
              key: const Key('pro-status-message'),
              style: _statusIsError
                  ? const TextStyle(color: CupertinoColors.systemRed)
                  : null,
            ),
      children: [
        CupertinoListTile(
          key: const Key('pro-row'),
          title: const Text('Nutriton Pro'),
          additionalInfo: Text(switch (access) {
            ProAccess.owned => 'Unlocked',
            ProAccess.trial =>
              'Trial, $daysLeft ${daysLeft == 1 ? 'day' : 'days'} left',
            ProAccess.free => 'See what\'s included',
          }),
          trailing: const CupertinoListTileChevron(),
          onTap: () => showPaywall(context),
        ),
        if (storeAvailable && access != ProAccess.owned)
          CupertinoListTile(
            key: const Key('restore-purchases'),
            title: const Text('Restore Purchases'),
            onTap: _busy ? null : _restore,
          ),
        for (final tip in tips)
          CupertinoListTile(
            key: Key('tip-${tip.id}'),
            title: Text(tip.title),
            additionalInfo: Text(tip.priceText),
            onTap: _busy ? null : () => _tip(tip.id),
          ),
      ],
    );
  }
}
