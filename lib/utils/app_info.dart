import 'package:flutter/foundation.dart' show debugPrint;
import 'package:package_info_plus/package_info_plus.dart';

/// What this build actually is, read from the bundle.
///
/// This used to be a hand-maintained constant and had drifted three releases
/// behind `pubspec.yaml`, which is exactly the kind of thing the driver sees in
/// a support ticket. It now comes from CFBundleShortVersionString / versionName,
/// so it cannot be wrong.
class AppInfo {
  const AppInfo._();

  /// Shown before [load] completes and if the platform channel ever fails.
  /// Keep in step with `version:` in pubspec.yaml.
  static const String fallbackVersion = '1.0.13';

  static String version = fallbackVersion;

  /// versionCode on Android, CFBundleVersion on iOS. Empty until loaded.
  static String build = '';

  /// `1.0.13 (68)`, or just the version when no build number is available.
  static String get display => build.isEmpty ? version : '$version ($build)';

  /// Call once during startup. Never throws: a missing version is a cosmetic
  /// problem, not a reason to fail a launch.
  static Future<void> load() async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      if (info.version.isNotEmpty) version = info.version;
      build = info.buildNumber;
    } catch (error) {
      debugPrint('[app-info] falling back to $fallbackVersion: $error');
    }
  }
}

/// Kept for the screens that already read it. Prefer [AppInfo.version].
@Deprecated('Use AppInfo.version, which reads the real bundle version')
String get kAppVersion => AppInfo.version;
