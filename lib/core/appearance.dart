/// The Pro appearance choices: accent color themes and alternate app icons.
/// Pure Dart, so colors are plain ARGB ints.
library;

/// An accent color for buttons, links and switches. The system light and
/// dark appearance stays; only the accent changes.
enum AppTheme {
  blue('Blue', light: 0xFF007AFF, dark: 0xFF0A84FF),
  green('Green', light: 0xFF2E7D32, dark: 0xFF30D158),
  orange('Orange', light: 0xFFC85A00, dark: 0xFFFF9F0A),
  purple('Purple', light: 0xFF8944C8, dark: 0xFFBF5AF2),
  pink('Pink', light: 0xFFD81B60, dark: 0xFFFF375F),
  teal('Teal', light: 0xFF00796B, dark: 0xFF40C8E0);

  const AppTheme(this.label, {required this.light, required this.dark});

  final String label;

  /// ARGB in light mode, dark enough to read as text on white.
  final int light;

  /// ARGB in dark mode.
  final int dark;

  /// The theme everyone has, and the one used without Pro.
  static const standard = blue;

  /// The theme stored as [name]; unknown or missing text is [standard].
  static AppTheme fromName(String? name) =>
      values.asNameMap()[name] ?? standard;
}

/// The theme in use: the saved [choice] with Pro, otherwise the standard
/// one. The saved choice itself is kept, so it returns with Pro.
AppTheme effectiveTheme(AppTheme choice, {required bool pro}) =>
    pro ? choice : AppTheme.standard;

/// An app icon. [iosName] is the alternate icon set in the asset catalog
/// (null for the primary icon), made by `tool/make_alt_icons.py`.
enum AppIconChoice {
  standard('Green', null, 'assets/icon/alt/default.png'),
  midnight('Midnight', 'AppIcon-Midnight', 'assets/icon/alt/midnight.png'),
  light('Light', 'AppIcon-Light', 'assets/icon/alt/light.png'),
  ocean('Ocean', 'AppIcon-Ocean', 'assets/icon/alt/ocean.png');

  const AppIconChoice(this.label, this.iosName, this.preview);

  final String label;
  final String? iosName;

  /// A small picture of the icon, bundled with the app.
  final String preview;

  /// The choice the system reports as [iosName]; unknown names and null are
  /// the primary icon.
  static AppIconChoice fromIosName(String? iosName) {
    for (final c in values) {
      if (c.iosName == iosName) return c;
    }
    return standard;
  }
}
