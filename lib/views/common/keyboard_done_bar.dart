import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

/// Puts a "Done" bar above the iOS number keyboard, which has no return key.
///
/// Wrap the app's navigator with it (`CupertinoApp.builder`), so every number
/// field gets the bar: forms, Settings and dialogs alike. The bar shows only
/// while a number field has focus and the on-screen keyboard is up. While it
/// shows, the bar's height is added to the keyboard inset that pages see, so
/// they resize above it and a focused field is never hidden behind it.
///
/// Android's number keyboard has its own done key, so the bar is iOS only.
class KeyboardDoneBar extends StatefulWidget {
  const KeyboardDoneBar({super.key, required this.child});

  final Widget child;

  static const height = 44.0;

  @override
  State<KeyboardDoneBar> createState() => _KeyboardDoneBarState();
}

class _KeyboardDoneBarState extends State<KeyboardDoneBar> {
  bool _numberFieldFocused = false;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocusChange);
    _numberFieldFocused = _isNumberField(FocusManager.instance.primaryFocus);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    final focused = _isNumberField(FocusManager.instance.primaryFocus);
    if (focused != _numberFieldFocused && mounted) {
      setState(() => _numberFieldFocused = focused);
    }
  }

  /// Whether [node] belongs to a text field with a number keyboard.
  static bool _isNumberField(FocusNode? node) {
    final context = node?.context;
    if (context == null || !context.mounted) return false;
    final editable = context.widget is EditableText
        ? context.widget as EditableText
        : context.findAncestorWidgetOfExactType<EditableText>();
    // TextInputType has no ==; number and numberWithOptions share the index.
    return editable != null &&
        editable.focusNode == node &&
        editable.keyboardType.index == TextInputType.number.index;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final show =
        _numberFieldFocused &&
        keyboard > 0 &&
        defaultTargetPlatform == TargetPlatform.iOS;
    if (!show) return widget.child;

    return Stack(
      children: [
        MediaQuery(
          data: media.copyWith(
            viewInsets: media.viewInsets.copyWith(
              bottom: keyboard + KeyboardDoneBar.height,
            ),
          ),
          child: widget.child,
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: keyboard,
          height: KeyboardDoneBar.height,
          child: const _Bar(),
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
        border: Border(
          top: BorderSide(
            color: CupertinoColors.separator.resolveFrom(context),
            width: 0,
          ),
        ),
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: CupertinoButton(
          key: const Key('keyboard-done'),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: const Text(
            'Done',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
