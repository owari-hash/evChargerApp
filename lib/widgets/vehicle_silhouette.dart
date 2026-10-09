import 'package:flutter/material.dart';

/// The rough shape of a car, enough to draw a recognisable side profile.
enum VehicleBodyStyle { sedan, suv, hatch }

/// Guesses the body style from what the driver typed on their account.
///
/// Drivers type freely ("tesla model y", "BYD Atto 3", "Leaf"), so this matches
/// well-known EV model names and falls back to a sedan for anything else.
VehicleBodyStyle bodyStyleFor(String? brand, String? model) {
  final String text = ' ${[brand, model].whereType<String>().join(' ')} '
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9.\s]'), ' ');

  bool any(List<String> names) => names.any(
    (String n) => RegExp('\\s${RegExp.escape(n)}\\s').hasMatch(text),
  );

  if (any(const <String>[
    'model y',
    'model x',
    'id.4',
    'id.5',
    'id.6',
    'ioniq 5',
    'ev6',
    'ev9',
    'ev5',
    'ev3',
    'enyaq',
    'ix',
    'ix1',
    'ix3',
    'x5',
    'x3',
    'eqa',
    'eqb',
    'eqc',
    'q4',
    'q6',
    'q8',
    'e tron',
    'e-tron',
    'atto',
    'atto 3',
    'tang',
    'song',
    'yuan',
    'sealion',
    'mach e',
    'mach-e',
    'bz4x',
    'kona',
    'niro',
    'xc40',
    'ex30',
    'ex90',
    'c40',
    'ariya',
    'zeekr x',
    'zeekr 7x',
    'li',
    'aito',
    'm5',
    'm7',
    'm9',
    'tank',
    'land cruiser',
    'range rover',
    'jeep',
    'lexus rz',
    'rz',
    'ux',
    'solterra',
    'macan',
    'cayenne',
    'polestar 3',
    'polestar 4',
    'deepal',
    'avatr',
    'voyah',
    'jetour',
    'haval',
    'ora',
    'xpeng g6',
    'g9',
  ])) {
    return VehicleBodyStyle.suv;
  }
  if (any(const <String>[
    'leaf',
    'bolt',
    'id.3',
    'dolphin',
    'seagull',
    'i3',
    'zoe',
    'e 208',
    'e-208',
    'mini',
    'honda e',
    '500e',
    'fiat',
    'corsa',
    'megane',
    'golf',
    'e golf',
    'e-golf',
    'spring',
    'wuling',
    'good cat',
    'ex3',
  ])) {
    return VehicleBodyStyle.hatch;
  }
  return VehicleBodyStyle.sedan;
}

/// A clean side profile of an electric car in a pearl finish, drawn rather
/// than pictured so it stays crisp at any size and in either theme.
///
/// [glow] lights the charge port and the light bar while a session runs.
class VehicleSilhouette extends StatelessWidget {
  const VehicleSilhouette({
    super.key,
    required this.style,
    required this.accent,
    this.glow = 0.0,
    this.muted = false,
  });

  final VehicleBodyStyle style;
  final Color accent;

  /// 0..1 — how brightly the charge port and light bar shine.
  final double glow;

  /// Drawn faded, for the "add your car" state.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _SilhouettePainter(
        style: style,
        accent: accent,
        glow: glow,
        muted: muted,
      ),
    );
  }
}

/// Body profiles in a unit box: x is 0 (rear) → 1 (nose), y is 0 (roof) → 1
/// (ground). Each is the outline, the glasshouse inside it and wheel centres.
class _Profile {
  const _Profile({
    required this.aspect,
    required this.body,
    required this.glass,
    required this.pillarX,
    required this.rearWheel,
    required this.frontWheel,
    required this.wheelR,
    required this.beltY,
  });

  /// Height / length of the whole car.
  final double aspect;
  final List<List<double>> body;
  final List<List<double>> glass;
  final double pillarX;
  final double rearWheel;
  final double frontWheel;
  final double wheelR;
  final double beltY;
}

// Each list is a move-to followed by quadratic segments [cx, cy, x, y].
const _Profile _sedan = _Profile(
  aspect: 0.29,
  body: <List<double>>[
    <double>[0.025, 0.80],
    <double>[0.005, 0.70, 0.02, 0.52],
    <double>[0.03, 0.44, 0.13, 0.40],
    <double>[0.26, 0.06, 0.47, 0.06],
    <double>[0.62, 0.06, 0.72, 0.36],
    <double>[0.86, 0.40, 0.95, 0.47],
    <double>[1.0, 0.52, 0.995, 0.66],
    <double>[0.99, 0.80, 0.96, 0.82],
    <double>[0.50, 0.84, 0.025, 0.80],
  ],
  glass: <List<double>>[
    <double>[0.18, 0.39],
    <double>[0.30, 0.13, 0.47, 0.125],
    <double>[0.59, 0.12, 0.675, 0.37],
    <double>[0.42, 0.40, 0.18, 0.39],
  ],
  pillarX: 0.455,
  rearWheel: 0.205,
  frontWheel: 0.795,
  wheelR: 0.235,
  beltY: 0.47,
);

const _Profile _suv = _Profile(
  aspect: 0.37,
  body: <List<double>>[
    <double>[0.02, 0.80],
    <double>[0.0, 0.62, 0.015, 0.40],
    <double>[0.025, 0.16, 0.10, 0.11],
    <double>[0.36, 0.06, 0.60, 0.08],
    <double>[0.66, 0.09, 0.75, 0.34],
    <double>[0.90, 0.38, 0.96, 0.44],
    <double>[1.0, 0.48, 0.995, 0.64],
    <double>[0.99, 0.80, 0.96, 0.82],
    <double>[0.50, 0.84, 0.02, 0.80],
  ],
  glass: <List<double>>[
    <double>[0.065, 0.36],
    <double>[0.07, 0.17, 0.13, 0.155],
    <double>[0.38, 0.12, 0.60, 0.135],
    <double>[0.64, 0.15, 0.71, 0.35],
    <double>[0.40, 0.37, 0.065, 0.36],
  ],
  pillarX: 0.40,
  rearWheel: 0.20,
  frontWheel: 0.80,
  wheelR: 0.245,
  beltY: 0.45,
);

const _Profile _hatch = _Profile(
  aspect: 0.36,
  body: <List<double>>[
    <double>[0.03, 0.80],
    <double>[0.01, 0.60, 0.025, 0.40],
    <double>[0.04, 0.16, 0.12, 0.10],
    <double>[0.34, 0.05, 0.53, 0.07],
    <double>[0.62, 0.08, 0.72, 0.36],
    <double>[0.88, 0.40, 0.95, 0.47],
    <double>[1.0, 0.52, 0.995, 0.66],
    <double>[0.99, 0.80, 0.96, 0.82],
    <double>[0.50, 0.84, 0.03, 0.80],
  ],
  glass: <List<double>>[
    <double>[0.075, 0.37],
    <double>[0.085, 0.17, 0.15, 0.15],
    <double>[0.36, 0.11, 0.53, 0.125],
    <double>[0.61, 0.14, 0.68, 0.37],
    <double>[0.40, 0.39, 0.075, 0.37],
  ],
  pillarX: 0.40,
  rearWheel: 0.21,
  frontWheel: 0.79,
  wheelR: 0.235,
  beltY: 0.47,
);

class _SilhouettePainter extends CustomPainter {
  _SilhouettePainter({
    required this.style,
    required this.accent,
    required this.glow,
    required this.muted,
  });

  final VehicleBodyStyle style;
  final Color accent;
  final double glow;
  final bool muted;

  _Profile get _profile => switch (style) {
    VehicleBodyStyle.sedan => _sedan,
    VehicleBodyStyle.suv => _suv,
    VehicleBodyStyle.hatch => _hatch,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final _Profile p = _profile;

    // Fit the car in the box, leaving room for the ground shadow.
    double length = size.width;
    double height = length * p.aspect;
    final double maxHeight = size.height * 0.86;
    if (height > maxHeight) {
      height = maxHeight;
      length = height / p.aspect;
    }
    final Offset origin = Offset(
      (size.width - length) / 2,
      size.height * 0.92 - height,
    );
    Offset at(double x, double y) => origin + Offset(x * length, y * height);

    Path trace(List<List<double>> pts) {
      final Offset start = at(pts[0][0], pts[0][1]);
      final Path path = Path()..moveTo(start.dx, start.dy);
      for (final List<double> seg in pts.skip(1)) {
        final Offset c = at(seg[0], seg[1]);
        final Offset e = at(seg[2], seg[3]);
        path.quadraticBezierTo(c.dx, c.dy, e.dx, e.dy);
      }
      return path..close();
    }

    final double alpha = muted ? 0.38 : 1.0;
    final Rect bounds = Rect.fromLTWH(origin.dx, origin.dy, length, height);
    final double groundY = origin.dy + height * 0.82 + p.wheelR * height * 0.6;

    // Ground shadow and a soft accent pool under the car.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(bounds.center.dx, groundY),
        width: length * 1.02,
        height: height * 0.14,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45 * alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(bounds.center.dx, groundY),
        width: length * 0.9,
        height: height * 0.08,
      ),
      Paint()
        ..color = accent.withValues(alpha: (0.18 + glow * 0.35) * alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );

    // Body: a pearl finish, bright along the shoulder, darker at the sills.
    final Path body = trace(p.body);
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            const Color(0xFFF4F7F5).withValues(alpha: alpha),
            const Color(0xFFD5DEDA).withValues(alpha: alpha),
            const Color(0xFF8E9C96).withValues(alpha: alpha),
            const Color(0xFF55625D).withValues(alpha: alpha),
          ],
          stops: const <double>[0.0, 0.42, 0.72, 1.0],
        ).createShader(bounds),
    );

    canvas.save();
    canvas.clipPath(body);

    // Shoulder reflection — the long highlight that makes paint read as paint.
    canvas.drawRect(
      Rect.fromLTRB(
        bounds.left,
        at(0, p.beltY - 0.05).dy,
        bounds.right,
        at(0, p.beltY + 0.02).dy,
      ),
      Paint()
        ..shader = LinearGradient(
          colors: <Color>[
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.75 * alpha),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(bounds),
    );

    // Lower body cladding.
    canvas.drawRect(
      Rect.fromLTRB(bounds.left, at(0, 0.70).dy, bounds.right, bounds.bottom),
      Paint()..color = const Color(0xFF26302C).withValues(alpha: 0.55 * alpha),
    );

    // Door shut lines.
    final Paint seam = Paint()
      ..color = Colors.black.withValues(alpha: 0.18 * alpha)
      ..strokeWidth = 1.0;
    final double doorTop = at(0, p.beltY - 0.06).dy;
    final double doorBottom = at(0, 0.74).dy;
    canvas.drawLine(
      Offset(at(p.pillarX, 0).dx, doorTop),
      Offset(at(p.pillarX + 0.01, 0).dx, doorBottom),
      seam,
    );
    canvas.drawLine(
      Offset(at(p.frontWheel - p.wheelR * p.aspect * 1.5, 0).dx, doorTop + 4),
      Offset(at(p.frontWheel - p.wheelR * p.aspect * 1.5, 0).dx, doorBottom),
      seam,
    );
    canvas.restore();

    // Glasshouse: tinted, with a cool reflection across the top.
    final Path glass = trace(p.glass);
    final Rect glassBounds = glass.getBounds();
    canvas.drawPath(
      glass,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            const Color(0xFF3A4A52).withValues(alpha: alpha),
            const Color(0xFF0E1518).withValues(alpha: alpha),
            const Color(0xFF1C2A30).withValues(alpha: alpha),
          ],
        ).createShader(glassBounds),
    );
    canvas.save();
    canvas.clipPath(glass);
    canvas.drawPath(
      Path()
        ..moveTo(glassBounds.left + glassBounds.width * 0.35, glassBounds.top)
        ..lineTo(glassBounds.left + glassBounds.width * 0.55, glassBounds.top)
        ..lineTo(
          glassBounds.left + glassBounds.width * 0.30,
          glassBounds.bottom,
        )
        ..lineTo(
          glassBounds.left + glassBounds.width * 0.18,
          glassBounds.bottom,
        )
        ..close(),
      Paint()..color = Colors.white.withValues(alpha: 0.10 * alpha),
    );
    // B-pillar.
    canvas.drawRect(
      Rect.fromLTWH(
        at(p.pillarX, 0).dx - 2,
        glassBounds.top,
        4,
        glassBounds.height,
      ),
      Paint()..color = const Color(0xFF0A0F11).withValues(alpha: alpha),
    );
    canvas.restore();

    // Full-width light bars, front and rear.
    final double lampY = at(0, p.beltY + 0.02).dy;
    final Paint frontLamp = Paint()
      ..color = Color.lerp(
        Colors.white,
        accent,
        0.25 + glow * 0.6,
      )!.withValues(alpha: alpha)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(bounds.right - length * 0.075, lampY),
      Offset(bounds.right - length * 0.012, lampY + height * 0.035),
      frontLamp,
    );
    if (glow > 0) {
      canvas.drawLine(
        Offset(bounds.right - length * 0.075, lampY),
        Offset(bounds.right - length * 0.012, lampY + height * 0.035),
        Paint()
          ..color = accent.withValues(alpha: 0.55 * glow)
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }
    canvas.drawLine(
      Offset(bounds.left + length * 0.012, at(0, 0.47).dy),
      Offset(bounds.left + length * 0.05, at(0, 0.46).dy),
      Paint()
        ..color = const Color(0xFFE5484D).withValues(alpha: 0.9 * alpha)
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );

    // Charge port on the rear quarter, lit while charging.
    final Offset port = at(0.10, p.beltY + 0.06);
    canvas.drawCircle(
      port,
      2.2,
      Paint()
        ..color = Color.lerp(
          const Color(0xFF2A3430),
          accent,
          glow,
        )!.withValues(alpha: alpha),
    );
    if (glow > 0) {
      canvas.drawCircle(
        port,
        7,
        Paint()
          ..color = accent.withValues(alpha: 0.6 * glow)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    // Wheels: dark arches, tyres, then a turbine-style aero rim.
    for (final double wx in <double>[p.rearWheel, p.frontWheel]) {
      final Offset c = Offset(at(wx, 0).dx, at(0, 0.80).dy);
      final double r = p.wheelR * height;
      canvas.drawCircle(
        c,
        r * 1.12,
        Paint()..color = const Color(0xFF0B100E).withValues(alpha: alpha),
      );
      canvas.drawCircle(
        c,
        r,
        Paint()..color = const Color(0xFF161B19).withValues(alpha: alpha),
      );
      canvas.drawCircle(
        c,
        r * 0.68,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              const Color(0xFFB9C3BF).withValues(alpha: alpha),
              const Color(0xFF5E6A65).withValues(alpha: alpha),
            ],
          ).createShader(Rect.fromCircle(center: c, radius: r * 0.68)),
      );
      final Paint spoke = Paint()
        ..color = const Color(0xFF2B3330).withValues(alpha: alpha)
        ..strokeWidth = r * 0.10
        ..strokeCap = StrokeCap.round;
      for (int i = 0; i < 5; i++) {
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(i * 2 * 3.141592653589793 / 5);
        canvas.drawLine(Offset(0, -r * 0.18), Offset(0, -r * 0.62), spoke);
        canvas.restore();
      }
      canvas.drawCircle(
        c,
        r * 0.14,
        Paint()..color = const Color(0xFF1E2522).withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SilhouettePainter old) =>
      old.style != style ||
      old.accent != accent ||
      old.glow != glow ||
      old.muted != muted;
}
