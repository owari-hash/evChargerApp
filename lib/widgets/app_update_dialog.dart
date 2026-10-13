import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_update.dart';
import '../services/app_update_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';

/// The update prompt.
///
/// Two shapes from one widget, driven by [AppUpdateInfo.forceUpdate]:
///
///  * **Optional** — dismissible. "Дараа" remembers the version so the driver is
///    not asked again until the next release.
///  * **Forced** — no barrier dismiss, no back button, no "later". The only way
///    out is the store, because this build is below the minimum the operator
///    still supports and the API may already refuse it.
class AppUpdateDialog extends StatelessWidget {
  const AppUpdateDialog({super.key, required this.info, this.service});

  final AppUpdateInfo info;
  final AppUpdateService? service;

  /// Raises the dialog. Returns once it is gone; a forced one never returns
  /// through dismissal, only through the driver leaving for the store.
  static Future<void> show(
    BuildContext context,
    AppUpdateInfo info, {
    AppUpdateService? service,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !info.forceUpdate,
      builder: (BuildContext dialogContext) =>
          AppUpdateDialog(info: info, service: service),
    );
  }

  AppUpdateService get _service => service ?? AppUpdateService.instance;

  String _text(String key) => AppStrings.get(key);

  String get _notes {
    final bool isMn = AppStrings.currentLanguage == AppLanguage.mn;
    final String preferred = isMn ? info.releaseNotesMn : info.releaseNotesEn;
    // Fall back to the other language rather than showing nothing: release
    // notes are usually written in one and left empty in the other.
    final String fallback = isMn ? info.releaseNotesEn : info.releaseNotesMn;
    return preferred.trim().isNotEmpty ? preferred.trim() : fallback.trim();
  }

  Future<void> _openStore(BuildContext context) async {
    final String? url = info.storeUrl;
    if (url == null || url.isEmpty) return;

    final Uri? uri = Uri.tryParse(url);
    bool opened = false;
    if (uri != null) {
      // The store app, not an in-app webview — an in-app browser cannot start
      // an install, which is the whole point of the button.
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_text('update_open_failed'))),
      );
    }
    // The dialog deliberately stays up on a forced update: the driver has not
    // updated yet, and dismissing here would let them back into a dead build.
  }

  Future<void> _later(BuildContext context) async {
    await _service.dismiss(info.latestVersion);
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool forced = info.forceUpdate;
    final String notes = _notes;

    return PopScope(
      // A forced update survives the Android back gesture.
      canPop: !forced,
      child: AlertDialog(
        // `card`, never `panel`: panel is the deliberately dark nav/hero surface
        // in both themes, and ink-on-panel disappeared in light mode.
        backgroundColor: palette.card,
        // Material 3 tints a dialog surface by elevation, which would pull the
        // colour away from the palette. Keep the token exact.
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: palette.border),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: forced
                    ? AppTheme.errorRed.withValues(alpha: 0.12)
                    : palette.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                forced
                    ? Icons.system_update_alt_rounded
                    : Icons.rocket_launch_rounded,
                color: forced ? AppTheme.errorRed : palette.accent,
                size: 24,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _text(forced ? 'update_title_force' : 'update_title'),
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: palette.ink,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              _text(
                forced ? 'update_body_force' : 'update_body',
              ).replaceFirst('{version}', info.latestVersion),
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: palette.inkMuted,
              ),
            ),
            if (notes.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: palette.border),
                ),
                child: Text(
                  notes,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: palette.ink,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              '${_text('update_current_version').replaceFirst('{version}', info.currentVersion)}'
              '${info.platform == 'ios' ? ' · ${_text('update_store_ios')}' : ''}'
              '${info.platform == 'android' ? ' · ${_text('update_store_android')}' : ''}',
              style: TextStyle(fontSize: 11.5, color: palette.inkMuted),
            ),
          ],
        ),
        actions: <Widget>[
          if (!forced)
            TextButton(
              onPressed: () => _later(context),
              style: TextButton.styleFrom(foregroundColor: palette.inkMuted),
              child: Text(_text('update_later')),
            ),
          FilledButton(
            onPressed: () => _openStore(context),
            style: FilledButton.styleFrom(
              backgroundColor: forced ? AppTheme.errorRed : palette.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _text('update_now'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
