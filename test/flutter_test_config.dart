import 'dart:async';

import 'package:nutriton_project/views/common/wide_layout.dart';

/// Runs before every test file. Flutter's test window is 800 x 600, which
/// counts as a wide screen, so the two-pane layouts are off unless a test
/// asks for them (see `wide_layout_test.dart`); the screens are tested as
/// they look on a phone.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  wideLayoutMinWidth = double.infinity;
  await testMain();
}
