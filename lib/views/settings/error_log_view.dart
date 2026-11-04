import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/diagnostics/error_log.dart';
import '../../providers/infrastructure_providers.dart';

/// Shares plain text through the system share sheet. Tests override it.
final textSharerProvider = Provider<Future<void> Function(String, Rect?)>(
  (ref) =>
      (text, origin) => SharePlus.instance.share(
        ShareParams(text: text, sharePositionOrigin: origin),
      ),
);

/// The failures recorded on this device, newest first, from Settings. They
/// never leave the phone unless the user shares them.
class ErrorLogView extends ConsumerStatefulWidget {
  const ErrorLogView({super.key});

  @override
  ConsumerState<ErrorLogView> createState() => _ErrorLogViewState();
}

class _ErrorLogViewState extends ConsumerState<ErrorLogView> {
  final _shareKey = GlobalKey();

  Future<void> _share(ErrorLog log) async {
    final box = _shareKey.currentContext?.findRenderObject();
    final origin = box is RenderBox
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    await ref.read(textSharerProvider)(log.exportText(), origin);
  }

  Future<void> _clear(ErrorLog log) async {
    await log.clear();
    if (mounted) setState(() {});
  }

  void _showDetail(ErrorLogEntry entry) {
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(entry.context),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.5,
          ),
          child: SingleChildScrollView(
            child: Text(
              [entry.message, ?entry.stack].join('\n\n'),
              textAlign: TextAlign.start,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final log = ref.watch(errorLogProvider);
    final entries = log.entries;
    final when = DateFormat.yMMMd().add_jm();
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Error log'),
        trailing: entries.isEmpty
            ? null
            : CupertinoButton(
                key: _shareKey,
                padding: EdgeInsets.zero,
                onPressed: () => _share(log),
                child: const Text('Share'),
              ),
      ),
      child: SafeArea(
        child: entries.isEmpty
            ? const Center(child: Text('No errors recorded.'))
            : ListView(
                children: [
                  CupertinoListSection.insetGrouped(
                    footer: const Text(
                      'Kept only on this device. Share it to report a '
                      'problem.',
                    ),
                    children: [
                      for (final e in entries)
                        CupertinoListTile(
                          title: Text(e.context),
                          subtitle: Text(
                            '${when.format(e.at)} · ${e.message}',
                            maxLines: 2,
                          ),
                          onTap: () => _showDetail(e),
                        ),
                    ],
                  ),
                  CupertinoButton(
                    key: const Key('clear-error-log'),
                    onPressed: () => _clear(log),
                    child: const Text(
                      'Clear log',
                      style: TextStyle(color: CupertinoColors.destructiveRed),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
