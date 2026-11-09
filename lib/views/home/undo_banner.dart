import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/infrastructure_providers.dart';
import '../common/error_feedback.dart';

/// How long the "Entry deleted" banner stays up. Tests can read it to pump past
/// the banner.
const undoBannerDuration = Duration(seconds: 4);

OverlayEntry? _current;
Timer? _timer;

/// Shows a small banner at the bottom of the screen with [message] and an
/// "Undo" button. Cupertino has no SnackBar, so this is an overlay entry on
/// the root overlay; it outlives the widget that asked for it (the list
/// disappears when its last entry is deleted). Only one banner is shown at a
/// time: a new one replaces the old.
void showUndoBanner(
  OverlayState overlay, {
  required String message,
  required VoidCallback onUndo,
}) {
  hideUndoBanner();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _UndoBanner(
      message: message,
      onUndo: () {
        if (_current == entry) hideUndoBanner();
        onUndo();
      },
    ),
  );
  _current = entry;
  overlay.insert(entry);
  _timer = Timer(undoBannerDuration, () {
    if (_current == entry) hideUndoBanner();
  });
}

/// Removes the banner now, if one is showing.
void hideUndoBanner() {
  _timer?.cancel();
  _timer = null;
  final entry = _current;
  if (entry != null && entry.mounted) entry.remove();
  entry?.dispose();
  _current = null;
}

class _UndoBanner extends StatelessWidget {
  const _UndoBanner({required this.message, required this.onUndo});

  final String message;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 56),
          child: DecoratedBox(
            key: const Key('undo-banner'),
            decoration: BoxDecoration(
              color: CupertinoColors.secondarySystemBackground.resolveFrom(
                context,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(color: Color(0x33000000), blurRadius: 12),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Row(
                children: [
                  Expanded(
                    child: DefaultTextStyle(
                      style: TextStyle(
                        fontSize: 15,
                        color: CupertinoColors.label.resolveFrom(context),
                      ),
                      child: Text(message),
                    ),
                  ),
                  CupertinoButton(
                    key: const Key('undo-button'),
                    onPressed: onUndo,
                    child: const Text('Undo'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows the Undo banner for a change whose [undo] puts things back. A
/// failed undo goes to the error log and says so in a dialog.
void offerUndo(
  BuildContext context, {
  required String message,
  required Future<void> Function() undo,
}) => UndoOffer.of(context).show(message: message, undo: undo);

/// What the Undo banner needs, taken from a context up front. Use it when the
/// widget may be gone by the time the change is done (the empty-day view is
/// replaced as soon as copied entries arrive).
class UndoOffer {
  UndoOffer.of(BuildContext context)
    : _container = ProviderScope.containerOf(context, listen: false),
      _navigator = Navigator.of(context, rootNavigator: true),
      _overlay = Overlay.of(context, rootOverlay: true);

  final ProviderContainer _container;
  final NavigatorState _navigator;
  final OverlayState _overlay;

  void show({required String message, required Future<void> Function() undo}) {
    if (!_overlay.mounted) return;
    showUndoBanner(
      _overlay,
      message: message,
      onUndo: () async {
        try {
          await undo();
        } catch (e, stack) {
          unawaited(
            _container
                .read(errorLogProvider)
                .record(e, stack, context: 'Could not undo'),
          );
          if (_navigator.mounted) {
            await showErrorDialog(
              _navigator.context,
              'Could not undo. Try again.',
            );
          }
        }
      },
    );
  }
}
