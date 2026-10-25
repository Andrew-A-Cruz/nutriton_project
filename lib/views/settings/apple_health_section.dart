import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/health.dart';
import '../../providers/health_providers.dart';
import '../../providers/preferences_providers.dart';

/// Settings section for Apple Health, off by default and shown only where a
/// health store exists (iOS). Each switch asks for permission for its own data
/// when first turned on, and a refusal leaves it off. Changes save at once.
class AppleHealthSection extends ConsumerStatefulWidget {
  const AppleHealthSection({super.key});

  @override
  ConsumerState<AppleHealthSection> createState() => _AppleHealthSectionState();
}

class _AppleHealthSectionState extends ConsumerState<AppleHealthSection> {
  String? _denied;

  Future<void> _toggle(HealthGroup group, bool on) async {
    if (on) {
      var granted = false;
      try {
        granted = await ref
            .read(healthServiceProvider)
            .requestAuthorization(group);
      } catch (_) {
        // Treated like a refusal: the switch stays off.
      }
      if (!mounted) return;
      if (!granted) {
        setState(
          () => _denied =
              'Nutriton does not have access to Apple Health. Allow it in '
              'the Health app, under Sharing, then try again.',
        );
        return;
      }
    }
    setState(() => _denied = null);
    final settings = ref.read(preferencesProvider);
    await ref.read(preferencesProvider.notifier).save(switch (group) {
      HealthGroup.nutrition => settings.copyWith(healthWriteNutrition: on),
      HealthGroup.weight => settings.copyWith(healthReadWeight: on),
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(healthSupportedProvider)) return const SizedBox.shrink();
    final write = ref.watch(
      preferencesProvider.select((s) => s.healthWriteNutrition),
    );
    final read = ref.watch(
      preferencesProvider.select((s) => s.healthReadWeight),
    );
    return CupertinoFormSection.insetGrouped(
      header: const Text('APPLE HEALTH'),
      footer: Text(
        _denied ??
            'Write nutrition sends each day\'s energy, protein, carbs, fat '
                'and, when recorded, fiber, sugar and sodium, for the last '
                '$healthBackfillDays days and onwards. Read body weight fills '
                'days where you have not entered a weight.',
        style: _denied == null
            ? null
            : const TextStyle(color: CupertinoColors.systemRed),
      ),
      children: [
        CupertinoListTile(
          title: const Text('Write nutrition'),
          trailing: CupertinoSwitch(
            key: const Key('health-write-switch'),
            value: write,
            onChanged: (on) => _toggle(HealthGroup.nutrition, on),
          ),
        ),
        CupertinoListTile(
          title: const Text('Read body weight'),
          trailing: CupertinoSwitch(
            key: const Key('health-read-switch'),
            value: read,
            onChanged: (on) => _toggle(HealthGroup.weight, on),
          ),
        ),
      ],
    );
  }
}
