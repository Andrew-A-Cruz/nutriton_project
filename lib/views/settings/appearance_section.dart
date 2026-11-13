import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/appearance.dart';
import '../../providers/appearance_providers.dart';
import '../../providers/entitlement_providers.dart';
import '../common/error_feedback.dart';
import '../common/pro_gate.dart';

/// The color of [theme] for the current light or dark appearance.
CupertinoDynamicColor themeColor(AppTheme theme) =>
    CupertinoDynamicColor.withBrightness(
      color: Color(theme.light),
      darkColor: Color(theme.dark),
    );

/// Settings section for the accent color and the app icon (Pro). Without
/// Pro each picker is a lock badge that opens the paywall. Choices apply at
/// once. The icon picker shows only where the system can change the icon.
class AppearanceSection extends ConsumerWidget {
  const AppearanceSection({super.key});

  Future<void> _chooseIcon(
    BuildContext context,
    WidgetRef ref,
    AppIconChoice choice,
  ) async {
    try {
      await ref.read(appIconProvider.notifier).choose(choice);
    } catch (e, stack) {
      if (context.mounted) {
        await showErrorDialog(
          context,
          reportError(ref, e, stack, 'Could not change the app icon'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pro = ref.watch(proProvider);
    // Where Pro is not sold, a section of two locks would offer nothing.
    if (!pro && !ref.watch(proOfferedProvider)) return const SizedBox.shrink();
    final theme = ref.watch(themeChoiceProvider);
    final iconSupported = ref.watch(appIconServiceProvider).isSupported;
    final icon = ref.watch(appIconProvider).value ?? AppIconChoice.standard;
    return CupertinoFormSection.insetGrouped(
      header: const Text('APPEARANCE'),
      footer: const Text(
        'The accent color is used for buttons and links. Light and dark '
        'mode still follow your device.',
      ),
      children: [
        _Picker(
          label: 'Accent Color',
          pro: pro,
          children: [
            for (final t in AppTheme.values)
              _Swatch(
                key: Key('theme-${t.name}'),
                label: t.label,
                selected: t == theme,
                onTap: () => ref.read(themeChoiceProvider.notifier).set(t),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: themeColor(t).resolveFrom(context),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        if (iconSupported)
          _Picker(
            label: 'App Icon',
            pro: pro,
            children: [
              for (final c in AppIconChoice.values)
                _Swatch(
                  key: Key('icon-${c.name}'),
                  label: c.label,
                  selected: c == icon,
                  onTap: () => _chooseIcon(context, ref, c),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Image.asset(c.preview, fit: BoxFit.cover),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// A label with its choices underneath, or with the Pro lock beside it.
class _Picker extends StatelessWidget {
  const _Picker({
    required this.label,
    required this.pro,
    required this.children,
  });

  final String label;
  final bool pro;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (!pro) {
      return CupertinoListTile(
        title: Text(label),
        trailing: const ProGate(child: SizedBox.shrink()),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          const SizedBox(height: 10),
          // Wraps onto more lines at large text sizes or on a narrow screen.
          Wrap(spacing: 12, runSpacing: 12, children: children),
        ],
      ),
    );
  }
}

/// One choice: [child] in a 40 pt square, ringed when selected.
class _Swatch extends StatelessWidget {
  const _Swatch({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              width: 2,
              color: selected
                  ? CupertinoColors.label.resolveFrom(context)
                  : const Color(0x00000000),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
