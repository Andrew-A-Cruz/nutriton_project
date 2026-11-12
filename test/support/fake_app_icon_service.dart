import 'package:nutriton_project/data/app_icon/app_icon_service.dart';

/// An icon service that remembers the icon it was given. [failNext] makes
/// the next change fail, as the system does when it refuses.
class FakeAppIconService implements AppIconService {
  FakeAppIconService({this.icon});

  /// The alternate icon in use, or null for the primary icon.
  String? icon;
  bool failNext = false;
  final List<String?> changes = [];

  @override
  bool get isSupported => true;

  @override
  Future<String?> current() async => icon;

  @override
  Future<void> set(String? name) async {
    if (failNext) {
      failNext = false;
      throw StateError('refused');
    }
    icon = name;
    changes.add(name);
  }
}
