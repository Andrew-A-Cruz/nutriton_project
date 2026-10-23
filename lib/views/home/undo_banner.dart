import 'dart:async';

import 'package:flutter/cupertino.dart';

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
