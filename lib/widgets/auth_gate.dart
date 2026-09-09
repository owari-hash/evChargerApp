import 'package:flutter/material.dart';

import '../screens/login_register_screen.dart';
import '../services/auth_service.dart';

/// The one place an account-only action asks for an account.
///
/// Browsing the network — the map, the station list, prices, connector states,
/// driving routes — needs no account and must never reach this. Charging a car
/// and paying for it does. Keeping the check here rather than in a wall around
/// the whole app is what lets a driver look before they sign up.
class AuthGate {
  const AuthGate._();

  /// True if the driver may proceed, prompting them if they were not signed in.
  ///
  /// Signed in, this returns immediately and shows nothing at all, so callers
  /// can front every gated action with it:
  ///
  /// ```dart
  /// if (!await AuthGate.require(context, reason: ...)) return;
  /// ```
  ///
  /// Signed out, it raises the sign-in sheet over whatever is on screen and
  /// answers whether they got through it. The caller then carries on with the
  /// action, so signing in resumes the tap that triggered it.
  static Future<bool> require(
    BuildContext context, {
    required String reason,
    AuthService? authService,
  }) async {
    final AuthService auth = authService ?? AuthService.instance;
    if (auth.isSignedIn) return true;

    final bool? signedIn = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) =>
          LoginRegisterScreen.sheet(reason: reason, authService: authService),
    );

    // A dismissed sheet pops null. Read the service rather than trusting the
    // result alone, so a sign-in that landed still counts if the sheet was
    // closed by something other than its own success path.
    return signedIn ?? auth.isSignedIn;
  }
}
