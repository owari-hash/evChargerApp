import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../services/biometric_service.dart';
import '../utils/app_strings.dart';

/// The Face ID mark on iPhone, a fingerprint elsewhere. Material has no Face ID
/// icon, so that one is drawn: four corner brackets around eyes, nose and smile.
class BiometricGlyph extends StatelessWidget {
  const BiometricGlyph({
    super.key,
    required this.kind,
    required this.color,
    this.size = 24,
  });

  final BiometricKind kind;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (kind == BiometricKind.fingerprint) {
      return Icon(Icons.fingerprint, color: color, size: size);
    }
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _FaceIdPainter(color)),
    );
  }
}

class _FaceIdPainter extends CustomPainter {
  const _FaceIdPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Drawn on a 24-unit grid, scaled to the box.
    final double u = size.width / 24;
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9 * u
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    Offset p(double x, double y) => Offset(x * u, y * u);
    final Radius r = Radius.circular(3.5 * u);

    final Path corners = Path()
      // Top left, top right, bottom right, bottom left.
      ..moveTo(p(1.5, 7.5).dx, p(1.5, 7.5).dy)
      ..lineTo(p(1.5, 5).dx, p(1.5, 5).dy)
      ..arcToPoint(p(5, 1.5), radius: r)
      ..lineTo(p(7.5, 1.5).dx, p(7.5, 1.5).dy)
      ..moveTo(p(16.5, 1.5).dx, p(16.5, 1.5).dy)
      ..lineTo(p(19, 1.5).dx, p(19, 1.5).dy)
      ..arcToPoint(p(22.5, 5), radius: r)
      ..lineTo(p(22.5, 7.5).dx, p(22.5, 7.5).dy)
      ..moveTo(p(22.5, 16.5).dx, p(22.5, 16.5).dy)
      ..lineTo(p(22.5, 19).dx, p(22.5, 19).dy)
      ..arcToPoint(p(19, 22.5), radius: r)
      ..lineTo(p(16.5, 22.5).dx, p(16.5, 22.5).dy)
      ..moveTo(p(7.5, 22.5).dx, p(7.5, 22.5).dy)
      ..lineTo(p(5, 22.5).dx, p(5, 22.5).dy)
      ..arcToPoint(p(1.5, 19), radius: r)
      ..lineTo(p(1.5, 16.5).dx, p(1.5, 16.5).dy);

    final Path face = Path()
      // Eyes.
      ..moveTo(p(8, 8.5).dx, p(8, 8.5).dy)
      ..lineTo(p(8, 10.5).dx, p(8, 10.5).dy)
      ..moveTo(p(16, 8.5).dx, p(16, 8.5).dy)
      ..lineTo(p(16, 10.5).dx, p(16, 10.5).dy)
      // Nose.
      ..moveTo(p(12, 8.5).dx, p(12, 8.5).dy)
      ..lineTo(p(12, 13.5).dx, p(12, 13.5).dy)
      ..lineTo(p(10.8, 13.5).dx, p(10.8, 13.5).dy)
      // Smile.
      ..moveTo(p(8.3, 16.2).dx, p(8.3, 16.2).dy)
      ..quadraticBezierTo(
        p(12, 19.2).dx,
        p(12, 19.2).dy,
        p(15.7, 16.2).dx,
        p(15.7, 16.2).dy,
      );

    canvas
      ..drawPath(corners, stroke)
      ..drawPath(face, stroke);
  }

  @override
  bool shouldRepaint(_FaceIdPainter oldDelegate) => oldDelegate.color != color;
}

/// "Sign in with Face ID" / "Sign in with fingerprint".
String biometricSignInLabel(BiometricKind kind) => AppStrings.get(
  kind == BiometricKind.face ? 'bio_sign_in_face' : 'bio_sign_in_finger',
);

/// Once a PIN has just proved itself, offers to remember it behind Face ID or
/// a fingerprint — unless the driver already said "not now". When biometric
/// sign-in is already on, the remembered PIN is simply brought up to date.
///
/// Takes the root navigator rather than a widget's context: signing in swaps
/// the account tab's sign-in screen out from under this call.
Future<void> offerBiometricSignIn(
  NavigatorState navigator,
  BiometricService biometrics, {
  required String phone,
  required String pin,
}) async {
  final BiometricKind? kind = await biometrics.availableKind();
  if (kind == null) return;

  if (await biometrics.isEnabled()) {
    await biometrics.refresh(phone: phone, pin: pin);
    return;
  }
  if (await biometrics.wasDeclined() || !navigator.mounted) return;

  final bool? accept = await showAdaptiveDialog<bool>(
    context: navigator.context,
    builder: (BuildContext dialogContext) {
      final bool ios = Theme.of(dialogContext).platform == TargetPlatform.iOS;
      Widget action(String label, bool value, {bool primary = false}) => ios
          ? CupertinoDialogAction(
              isDefaultAction: primary,
              onPressed: () => Navigator.pop(dialogContext, value),
              child: Text(label),
            )
          : TextButton(
              onPressed: () => Navigator.pop(dialogContext, value),
              child: Text(label),
            );

      return AlertDialog.adaptive(
        title: Text(
          AppStrings.get(
            kind == BiometricKind.face
                ? 'bio_offer_title_face'
                : 'bio_offer_title_finger',
          ),
        ),
        content: Text(AppStrings.get('bio_offer_body')),
        actions: <Widget>[
          action(AppStrings.get('bio_not_now'), false),
          action(AppStrings.get('bio_enable'), true, primary: true),
        ],
      );
    },
  );

  if (accept == true) {
    await biometrics.enable(
      phone: phone,
      pin: pin,
      reason: AppStrings.get('bio_reason'),
    );
  } else if (accept == false) {
    await biometrics.markDeclined();
  }
}
