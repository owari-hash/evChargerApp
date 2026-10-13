/// The server's answer to "is this build still good?".
///
/// Built from `GET /app-api/app/version`. The decision is made on the server so
/// a threshold can be changed without shipping an app: the app only renders what
/// it is told.
class AppUpdateInfo {
  const AppUpdateInfo({
    required this.platform,
    required this.currentVersion,
    required this.latestVersion,
    required this.updateAvailable,
    required this.forceUpdate,
    this.currentBuild,
    this.latestBuild,
    this.storeUrl,
    this.releaseNotesMn = '',
    this.releaseNotesEn = '',
  });

  /// Nothing to do — used when the check fails, so a dead network never blocks
  /// the app on a forced update it could not actually confirm.
  const AppUpdateInfo.none()
    : platform = '',
      currentVersion = '',
      latestVersion = '',
      updateAvailable = false,
      forceUpdate = false,
      currentBuild = null,
      latestBuild = null,
      storeUrl = null,
      releaseNotesMn = '',
      releaseNotesEn = '';

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      platform: json['platform'] as String? ?? '',
      currentVersion: json['currentVersion'] as String? ?? '',
      currentBuild: _toInt(json['currentBuild']),
      latestVersion: json['latestVersion'] as String? ?? '',
      latestBuild: _toInt(json['latestBuild']),
      updateAvailable: json['updateAvailable'] == true,
      forceUpdate: json['forceUpdate'] == true,
      storeUrl: (json['storeUrl'] as String?)?.trim(),
      releaseNotesMn: json['releaseNotes'] as String? ?? '',
      releaseNotesEn: json['releaseNotesEn'] as String? ?? '',
    );
  }

  final String platform;
  final String currentVersion;
  final int? currentBuild;
  final String latestVersion;
  final int? latestBuild;

  /// A newer build exists. On its own this is a dismissible suggestion.
  final bool updateAvailable;

  /// This build is below the minimum the operator still supports. The dialog
  /// cannot be dismissed and the app must not continue behind it.
  final bool forceUpdate;

  /// Play Store or App Store link for this platform. Null when unconfigured.
  final String? storeUrl;

  final String releaseNotesMn;
  final String releaseNotesEn;

  /// Only worth showing a dialog when there is both something newer and
  /// somewhere to send the driver.
  bool get shouldPrompt =>
      updateAvailable && storeUrl != null && storeUrl!.isNotEmpty;

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
