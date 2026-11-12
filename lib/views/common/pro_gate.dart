import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/entitlement_providers.dart';
import '../paywall/paywall_view.dart';

/// Wraps a Pro feature's entry point: [child] with Pro, otherwise a "Pro"
/// lock badge that opens the paywall. Only Pro entry points use it, so free
/// features never see a paywall. Where Pro is not sold (see
/// [proOfferedProvider]) there is nothing to offer, so it shows nothing.
class ProGate extends ConsumerWidget {
  const ProGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(proProvider)) return child;
    if (!ref.watch(proOfferedProvider)) return const SizedBox.shrink();
    final color = CupertinoTheme.of(context).primaryColor;
    return CupertinoButton(
      key: const Key('pro-lock'),
      padding: EdgeInsets.zero,
      onPressed: () => showPaywall(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.lock_fill, size: 16, color: color),
          const SizedBox(width: 4),
          Text('Pro', style: TextStyle(color: color)),
        ],
      ),
    );
  }
}
