import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/app_update.dart';
import 'api_client.dart';

/// Checks whether this build is still the one the operator wants running.
///
/// The check is deliberately quiet about failure: a driver on a bad connection,
/// or an API that is down, must never be locked out by an update prompt the app
/// could not confirm. Any error answers [AppUpdateInfo.none].
class AppUpdateService {
  AppUpdateService({ApiClient? client, FlutterSecureStorage? storage})
    : _client = client ?? ApiClient.shared,
      _storage = storage ?? const FlutterSecureStorage();

  static final AppUpdateService instance = AppUpdateService();

  final ApiClient _client;
  final FlutterSecureStorage _storage;

  /// Remembers the version a driver chose to skip, so an optional update asks
  /// once rather than on every launch. A forced update ignores this entirely.
  static const String _dismissedKey = 'app_update_dismissed_version';

  PackageInfo? _packageInfo;

  Future<PackageInfo> _info() async =>
      _packageInfo ??= await PackageInfo.fromPlatform();

  /// `android` or `ios`. Empty elsewhere — the web build is served, not
  /// installed, so it has no store to send anyone to.
  String get platform {
    if (kIsWeb) return '';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return '';
  }

  /// The running marketing version, e.g. `1.0.13`. Read from the bundle rather
  /// than a constant, so it cannot drift from what was actually shipped.
  Future<String> currentVersion() async => (await _info()).version;

  /// The running build number, e.g. `68`.
  Future<int?> currentBuild() async => int.tryParse((await _info()).buildNumber);

  Future<AppUpdateInfo> check() async {
    final String target = platform;
    if (target.isEmpty) return const AppUpdateInfo.none();

    try {
      final PackageInfo info = await _info();
      final Map<String, dynamic> json = await _client.get(
        '/app/version',
        query: <String, String>{
          'platform': target,
          'version': info.version,
          if (info.buildNumber.isNotEmpty) 'build': info.buildNumber,
        },
      );
      return AppUpdateInfo.fromJson(json);
    } catch (error) {
      // Offline, 5xx, malformed payload — all the same answer: carry on.
      debugPrint('[app-update] check skipped: $error');
      return const AppUpdateInfo.none();
    }
  }

  /// True when the driver already said "later" to this exact version.
  Future<bool> wasDismissed(String version) async {
    if (version.isEmpty) return false;
    try {
      return await _storage.read(key: _dismissedKey) == version;
    } catch (_) {
      return false;
    }
  }

  Future<void> dismiss(String version) async {
    if (version.isEmpty) return;
    try {
      await _storage.write(key: _dismissedKey, value: version);
    } catch (_) {
      // Not being able to remember the choice only costs one extra prompt.
    }
  }

  /// The check plus the "asked already" rule, which is what the UI actually
  /// wants: should a dialog be raised right now?
  Future<AppUpdateInfo?> pendingPrompt() async {
    final AppUpdateInfo info = await check();
    if (!info.shouldPrompt) return null;
    if (info.forceUpdate) return info;
    if (await wasDismissed(info.latestVersion)) return null;
    return info;
  }
}
