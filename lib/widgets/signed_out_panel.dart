import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import 'auth_gate.dart';

/// What an account-based tab shows a guest, in place of their own data.
///
/// Deliberately not a wall: it names what signing in adds and points out that
/// the map and the station list are already open, so a driver who only wants
/// to find a charger knows they can stop here.
class SignedOutPanel extends StatelessWidget {
  const SignedOutPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.reason,
    this.onSignedIn,
  });

  final IconData icon;
  final String title;
  final String body;

  /// Headline for the sign-in sheet this panel raises.
  final String reason;

  /// Called once the driver signs in, so the host tab can load its data.
  final VoidCallback? onSignedIn;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: palette.accent),
            ),
            const SizedBox(height: 22),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: palette.ink,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: palette.inkMuted,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 220,
              child: FilledButton(
                onPressed: () async {
                  final bool signedIn = await AuthGate.require(
                    context,
                    reason: reason,
                  );
                  if (signedIn) onSignedIn?.call();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: palette.accent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  AppStrings.get('login'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              AppStrings.get('guest_browse_hint'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: palette.inkMuted.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
