import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import '../../core/shortcuts.dart';

/// A "log this" request from Siri: the item's id and when it was asked for.
typedef ShortcutRequest = ({String itemId, DateTime at});

/// The link to the Siri and Shortcuts intents. The app uses
/// [AppGroupShortcutsBridge] on iOS; tests pass a fake.
abstract class ShortcutsBridge {
  /// Stores what the intents read: today's sentence and the loggable items.
  Future<void> publish({
    required ShortcutsSummary summary,
    required List<ShortcutItem> items,
  });

  /// The waiting "log this" request, removed so it is handled once, or null.
  Future<ShortcutRequest?> takeRequest();

  /// Fires when an intent has just stored a request while the app runs.
  Stream<void> get requests;
}

/// For platforms without the intents, and the default until `main` installs
/// the real one.
class NoopShortcutsBridge implements ShortcutsBridge {
  const NoopShortcutsBridge();

  @override
  Future<void> publish({
    required ShortcutsSummary summary,
    required List<ShortcutItem> items,
  }) async {}

  @override
  Future<ShortcutRequest?> takeRequest() async => null;

  @override
  Stream<void> get requests => const Stream.empty();
}

/// The App Group defaults the widget also uses, through `home_widget`, and a
/// method channel the intent calls when it stores a request. Keys match
/// `ios/Runner/LogbiteShortcuts.swift`. Not covered by tests, which would
/// need a device.
class AppGroupShortcutsBridge implements ShortcutsBridge {
  AppGroupShortcutsBridge() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'request') _requests.add(null);
    });
  }

  static const appGroupId = 'group.com.andrewcruz.nutriton';
  static const _channel = MethodChannel('logbite/shortcuts');

  static const dateKeyKey = 'shortcut_date_key';
  static const sentenceKey = 'shortcut_sentence';
  static const emptySentenceKey = 'shortcut_empty_sentence';
  static const itemsKey = 'shortcut_items';
  static const requestItemKey = 'shortcut_request_item';
  static const requestAtKey = 'shortcut_request_at';

  /// Only iOS has the intents.
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  final _requests = StreamController<void>.broadcast();
  Future<void>? _init;

  Future<void> _ready() => _init ??= HomeWidget.setAppGroupId(appGroupId);

  @override
  Future<void> publish({
    required ShortcutsSummary summary,
    required List<ShortcutItem> items,
  }) async {
    await _ready();
    await HomeWidget.saveWidgetData<String>(dateKeyKey, summary.dateKey);
    await HomeWidget.saveWidgetData<String>(sentenceKey, summary.sentence);
    await HomeWidget.saveWidgetData<String>(
      emptySentenceKey,
      summary.emptySentence,
    );
    final encoded = encodeShortcutItems(items);
    await HomeWidget.saveWidgetData<String>(itemsKey, encoded);
    // Siri re-reads the names only when told.
    if (encoded != _lastItems) {
      _lastItems = encoded;
      await _channel.invokeMethod<void>('itemsChanged');
    }
  }

  String? _lastItems;

  @override
  Future<ShortcutRequest?> takeRequest() async {
    await _ready();
    final id = await HomeWidget.getWidgetData<String>(requestItemKey);
    final at = await HomeWidget.getWidgetData<double>(requestAtKey);
    if (id == null) return null;
    await HomeWidget.saveWidgetData<String>(requestItemKey, null);
    await HomeWidget.saveWidgetData<double>(requestAtKey, null);
    return (
      itemId: id,
      at: at == null
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.fromMillisecondsSinceEpoch((at * 1000).round()),
    );
  }

  @override
  Stream<void> get requests => _requests.stream;
}
