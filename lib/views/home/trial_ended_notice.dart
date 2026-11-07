import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/entitlement_providers.dart';
import '../paywall/paywall_view.dart';

/// "Your trial ended", shown once on Home after a Pro trial runs out. Nothing
/// is lost: it says so, and offers the paywall without opening it.
class TrialEndedNotice extends ConsumerWidget {
  const TrialEndedNotice({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(trialEndedNoticeProvider)) return const SizedBox.shrink();
    final notice = ref.read(trialEndedNoticeProvider.notifier);
    return Container(
      key: const Key('trial-ended-notice'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
          context,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Pro trial ended',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'Your log and everything Pro made are still here. The widget and '
            'Apple Health pause until you unlock Pro.',
            style: TextStyle(
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              CupertinoButton(
                key: const Key('trial-ended-see-pro'),
                onPressed: () {
                  notice.dismiss();
                  showPaywall(context);
                },
                child: const Text('See Pro'),
              ),
              CupertinoButton(
                key: const Key('trial-ended-dismiss'),
                onPressed: notice.dismiss,
                child: const Text('OK'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
