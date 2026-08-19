import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class VehicleChargingMatrix extends StatefulWidget {
  final Widget child;
  final bool isCharging;

  const VehicleChargingMatrix({
    super.key,
    required this.child,
    required this.isCharging,
  });

  @override
  State<VehicleChargingMatrix> createState() => _VehicleChargingMatrixState();
}

class _VehicleChargingMatrixState extends State<VehicleChargingMatrix>
    with SingleTickerProviderStateMixin {
  late AnimationController _matrixController;

  @override
  void initState() {
    super.initState();
    _matrixController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _matrixController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isCharging) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _matrixController,
      builder: (context, child) {
        return Stack(
          children: [
            widget.child,
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ParticleMatrixPainter(
                    progress: _matrixController.value,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ParticleMatrixPainter extends CustomPainter {
  final double progress;

  _ParticleMatrixPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final particlePaint = Paint()
      ..color = AppTheme.sageGreen
      ..style = PaintingStyle.fill;

    final glowPaint = Paint()
      ..color = const Color(0xFF6EE7B7).withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final random = Random(42);

    for (int i = 0; i < 35; i++) {
      final double baseX = random.nextDouble() * size.width;
      final double baseY = random.nextDouble() * size.height;

      final double currentX = (baseX + progress * size.width * 0.4) % size.width;
      final double currentY = (baseY + sin(progress * 2 * pi + i) * 8) % size.height;
      final double radius = 2.0 + (i % 3);

      canvas.drawCircle(Offset(currentX, currentY), radius + 2, glowPaint);
      canvas.drawCircle(Offset(currentX, currentY), radius, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticleMatrixPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
