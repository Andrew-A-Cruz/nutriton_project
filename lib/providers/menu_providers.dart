import 'dart:async';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/menus.dart';
import 'infrastructure_providers.dart';

/// Where the restaurant menus are bundled (made by `tool/make_menus.py`).
const menusAsset = 'assets/menus/menus.json';

/// The text of the bundled menus. Tests override it with a short file.
final menusSourceProvider = Provider<Future<String> Function()>(
  (ref) =>
      () => rootBundle.loadString(menusAsset),
);

/// The bundled restaurant menus, read once and kept for the session. A file
/// that cannot be read is recorded and gives no menus, which hides the
/// feature instead of breaking Add Food.
final menusProvider = FutureProvider<MenuCatalog>((ref) async {
  ref.keepAlive();
  try {
    return parseMenus(await ref.watch(menusSourceProvider)());
  } catch (e, stack) {
    unawaited(
      ref
          .read(errorLogProvider)
          .record(e, stack, context: 'Could not read the restaurant menus'),
    );
    return MenuCatalog.empty;
  }
});

/// Brings unedited restaurant foods up to the bundled menus once they are
/// read. Watched from the root, so it runs at every launch; it finds nothing
/// to do unless a new release raised the menus' version. A failure goes to
/// the error log and is retried at the next launch.
final menuRefreshPlanProvider = Provider<void>((ref) {
  final menus = ref.watch(menusProvider).value;
  if (menus == null || menus.chains.isEmpty) return;
  final errorLog = ref.read(errorLogProvider);
  unawaited(
    ref
        .read(catalogRepositoryProvider)
        .refreshMenuFoods(menus)
        .then<void>((_) {})
        .catchError(
          (Object e, StackTrace stack) => errorLog.record(
            e,
            stack,
            context: 'Could not refresh restaurant foods',
          ),
        ),
  );
});

/// Opens a link outside the app. Tests override it to see what was opened.
final linkOpenerProvider = Provider<Future<void> Function(Uri url)>(
  (ref) => (url) async {
    await launchUrl(url);
  },
);
