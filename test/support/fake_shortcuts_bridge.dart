import 'dart:async';

import 'package:nutriton_project/core/shortcuts.dart';
import 'package:nutriton_project/data/shortcuts/shortcuts_bridge.dart';

/// Records what is published and hands out [pending] once.
class FakeShortcutsBridge implements ShortcutsBridge {
  final published = <({ShortcutsSummary summary, List<ShortcutItem> items})>[];
  ShortcutRequest? pending;
  final _requests = StreamController<void>.broadcast();

  /// As the intent does while the app runs.
  void signal() => _requests.add(null);

  @override
  Future<void> publish({
    required ShortcutsSummary summary,
    required List<ShortcutItem> items,
  }) async {
    published.add((summary: summary, items: items));
  }

  @override
  Future<ShortcutRequest?> takeRequest() async {
    final request = pending;
    pending = null;
    return request;
  }

  @override
  Stream<void> get requests => _requests.stream;
}
