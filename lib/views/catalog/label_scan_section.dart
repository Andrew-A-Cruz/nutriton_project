import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/label_scan.dart';
import '../../providers/label_scan_providers.dart';
import '../common/error_feedback.dart';

/// "Scan a nutrition label" block for the new-food form, for products Open
/// Food Facts does not know: take or choose a photo of the label, and the
/// values read from it go to [onFill] so the form can prefill. The text is
/// read on the device. Nothing is saved here. Hidden where the device cannot
/// read text from a photo.
class LabelScanSection extends ConsumerStatefulWidget {
  const LabelScanSection({super.key, required this.onFill});

  final ValueChanged<LabelFill> onFill;

  @override
  ConsumerState<LabelScanSection> createState() => _LabelScanSectionState();
}

class _LabelScanSectionState extends ConsumerState<LabelScanSection> {
  bool _busy = false;
  String? _message;

  Future<void> _scan(LabelPhotoSource source) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    String? message;
    try {
      final lines = await ref.read(labelScannerProvider).scan(source);
      if (lines != null) {
        final fill = labelFill(parseNutritionLabel(rowsFromLines(lines)));
        if (fill == null) {
          message =
              'No nutrition values could be read from that photo. Try '
              'again with the whole table in view, flat and well lit.';
        } else {
          widget.onFill(fill);
        }
      }
    } catch (e, stack) {
      message = reportError(ref, e, stack, 'Could not read the label');
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(labelScannerProvider).isSupported) {
      return const SizedBox.shrink();
    }
    return CupertinoFormSection.insetGrouped(
      header: const Text('SCAN A NUTRITION LABEL'),
      footer: const Text(
        'Fills the form below from a photo of the nutrition table. The photo '
        'is read on this device and is not saved or sent anywhere. Check '
        'the values and edit before saving.',
      ),
      children: [
        CupertinoListTile(
          key: const Key('label-scan-camera'),
          leading: const Icon(CupertinoIcons.camera),
          title: const Text('Take a photo'),
          trailing: _busy ? const CupertinoActivityIndicator() : null,
          onTap: _busy ? null : () => _scan(LabelPhotoSource.camera),
        ),
        CupertinoListTile(
          key: const Key('label-scan-library'),
          leading: const Icon(CupertinoIcons.photo),
          title: const Text('Choose a photo'),
          onTap: _busy ? null : () => _scan(LabelPhotoSource.library),
        ),
        if (_message case final message?)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              message,
              key: const Key('label-scan-message'),
              style: const TextStyle(color: CupertinoColors.systemRed),
            ),
          ),
      ],
    );
  }
}
