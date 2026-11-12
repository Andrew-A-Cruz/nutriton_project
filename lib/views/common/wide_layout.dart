import 'package:flutter/widgets.dart';

/// The narrowest screen that gets the two-pane layouts: an iPad, or a large
/// phone on its side.
const double defaultWideLayoutMinWidth = 700;

/// The width in use. Only tests change it: Flutter's test window is 800
/// wide, so `test/flutter_test_config.dart` turns the two-pane layouts off
/// and the tests of those layouts turn them back on.
double wideLayoutMinWidth = defaultWideLayoutMinWidth;

/// Whether the screen is wide enough to show two panes side by side.
bool isWideLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= wideLayoutMinWidth;
