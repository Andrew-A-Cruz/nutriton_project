import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/infrastructure_providers.dart';

/// Records [error] in the error log under [failed] (e.g. "Could not log food")
/// and returns the text to show. The raw error stays in the log, under
/// Settings > Error log, rather than on screen.
String reportError(
  WidgetRef ref,
  Object error,
  StackTrace stack,
  String failed,
) {
  unawaited(ref.read(errorLogProvider).record(error, stack, context: failed));
  return '$failed. Try again.';
}

/// A one-button alert showing [message].
Future<void> showErrorDialog(BuildContext context, String message) =>
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );

/// Centered "[failed]." text for a list or chart that could not load. The
/// error is recorded once, when the text first shows.
class LoadErrorText extends ConsumerStatefulWidget {
  const LoadErrorText({
    super.key,
    required this.failed,
    required this.error,
    this.stack,
  });

  /// E.g. "Could not load foods".
  final String failed;
  final Object error;
  final StackTrace? stack;

  @override
  ConsumerState<LoadErrorText> createState() => _LoadErrorTextState();
}

class _LoadErrorTextState extends ConsumerState<LoadErrorText> {
  @override
  void initState() {
    super.initState();
    unawaited(
      ref
          .read(errorLogProvider)
          .record(widget.error, widget.stack, context: widget.failed),
    );
  }

  @override
  Widget build(BuildContext context) =>
      Center(child: Text('${widget.failed}.'));
}
