import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Opens the camera scanner and returns the scanned barcode, or null when the
/// user backs out. Tests override [barcodeScannerProvider] with a fake so no
/// camera is needed.
typedef BarcodeScanner = Future<String?> Function(BuildContext context);

final barcodeScannerProvider = Provider<BarcodeScanner>(
  (ref) =>
      (context) => Navigator.of(context, rootNavigator: true).push<String>(
        CupertinoPageRoute(
          fullscreenDialog: true,
          builder: (_) => const BarcodeScannerPage(),
        ),
      ),
);

/// Whether camera scanning is available. `mobile_scanner` does not support
/// Windows, Linux or the web, so the Scan button is hidden there. Tests
/// override this to exercise both cases.
final barcodeScanSupportedProvider = Provider<bool>(
  (ref) =>
      !kIsWeb &&
      switch (defaultTargetPlatform) {
        TargetPlatform.android ||
        TargetPlatform.iOS ||
        TargetPlatform.macOS => true,
        _ => false,
      },
);

/// Full-screen camera page. Pops with the first retail barcode it sees
/// (EAN-13, EAN-8, UPC-A, UPC-E), or with null when cancelled.
class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  final _controller = MobileScannerController(
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  /// Set on the first detection so a burst of frames cannot pop twice.
  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue;
      if (code != null && code.isNotEmpty) {
        _done = true;
        Navigator.of(context).pop(code);
        return;
      }
    }
  }

  void _cancel() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.black,
        middle: const Text(
          'Scan barcode',
          style: TextStyle(color: CupertinoColors.white),
        ),
        leading: CupertinoButton(
          key: const Key('scanner-cancel'),
          padding: EdgeInsets.zero,
          onPressed: _cancel,
          child: const Text('Cancel'),
        ),
        trailing: ValueListenableBuilder<MobileScannerState>(
          valueListenable: _controller,
          builder: (context, state, _) {
            final on = state.torchState == TorchState.on;
            return CupertinoButton(
              key: const Key('scanner-torch'),
              padding: EdgeInsets.zero,
              // Disabled when the device has no torch or the camera is down.
              onPressed: state.torchState == TorchState.unavailable
                  ? null
                  : _controller.toggleTorch,
              child: Icon(on ? CupertinoIcons.bolt_fill : CupertinoIcons.bolt),
            );
          },
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) =>
                _ScannerError(error: error, onBack: _cancel),
          ),
          const IgnorePointer(child: _FramingOverlay()),
        ],
      ),
    );
  }
}

/// A rounded frame in the middle of the preview with a hint underneath.
class _FramingOverlay extends StatelessWidget {
  const _FramingOverlay();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            key: const Key('scanner-frame'),
            width: 280,
            height: 160,
            decoration: BoxDecoration(
              border: Border.all(color: CupertinoColors.white, width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Point the camera at a barcode',
            style: TextStyle(color: CupertinoColors.white, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

/// Shown instead of the preview when the camera cannot start.
class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.error, required this.onBack});

  final MobileScannerException error;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    final message = denied
        ? 'Camera access is turned off. Allow it in Settings to scan, or '
              'type the barcode digits instead.'
        : error.errorCode == MobileScannerErrorCode.unsupported
        ? 'No camera is available on this device. Type the barcode digits '
              'instead.'
        : 'The camera could not start. Type the barcode digits instead.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              key: const Key('scanner-error'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: CupertinoColors.white),
            ),
            const SizedBox(height: 16),
            CupertinoButton.filled(
              key: const Key('scanner-error-back'),
              onPressed: onBack,
              child: const Text('Enter manually'),
            ),
          ],
        ),
      ),
    );
  }
}
