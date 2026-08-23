import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import '../utils/money.dart';

class ChargingPowerRingGauge extends StatefulWidget {
  final double batteryLevel;
  final double activePowerKw;
  final double totalEnergyKwh;
  final double targetLimitPct;

  const ChargingPowerRingGauge({
    super.key,
    required this.batteryLevel,
    required this.activePowerKw,
    required this.totalEnergyKwh,
    required this.targetLimitPct,
  });

  @override
  State<ChargingPowerRingGauge> createState() => _ChargingPowerRingGaugeState();
}

class _ChargingPowerRingGaugeState extends State<ChargingPowerRingGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double costMnt = widget.totalEnergyKwh * 450.0;

    return AnimatedBuilder(
      animation: _rotationController,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: context.palette.panel,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Circular Glowing Power Ring Gauge
              SizedBox(
                width: 200,
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer Radial Glow Shadow
                    Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.sageGreen.withValues(alpha: 0.35),
                            blurRadius: 30,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                    ),

                    // Custom Painted Rotating Ring
                    CustomPaint(
                      size: const Size(190, 190),
                      painter: _GlowingRingPainter(
                        progressPct: widget.batteryLevel / 100,
                        rotationValue: _rotationController.value,
                      ),
                    ),

                    // Inner Metrics Display
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              widget.batteryLevel.toStringAsFixed(0),
                              style: const TextStyle(
                                fontSize: 44,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.0,
                              ),
                            ),
                            const Text(
                              '%',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.sageGreen,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.sageGreen.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppTheme.sageGreen,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.bolt_rounded,
                                color: AppTheme.sageGreen,
                                size: 14,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${widget.activePowerKw.toInt()} кВт ХУРДТАЙ',
                                style: const TextStyle(
                                  color: AppTheme.sageGreen,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Live Session Metrics Row (kWh & MNT Cost)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          AppStrings.get('energy_delivered'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: Colors.white60),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${widget.totalEnergyKwh.toStringAsFixed(2)} кВт.ц',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 30, color: Colors.white24),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          AppStrings.get('total_cost'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: Colors.white60),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            formatMntLeading(costMnt),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.sageGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GlowingRingPainter extends CustomPainter {
  final double progressPct;
  final double rotationValue;

  _GlowingRingPainter({required this.progressPct, required this.rotationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 24) / 2;

    // Track Paint
    final trackPaint = Paint()
      ..color = Colors.white12
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Glowing Active Sweep Arc
    final sweepAngle = 2 * pi * progressPct;
    final startAngle = -pi / 2 + (rotationValue * 2 * pi);

    final activeGradient = SweepGradient(
      center: Alignment.center,
      startAngle: 0,
      endAngle: 2 * pi,
      colors: const [
        Color(0xFF10B981),
        Color(0xFF34D399),
        Color(0xFF6EE7B7),
        Color(0xFF10B981),
      ],
    );

    final activePaint = Paint()
      ..shader = activeGradient.createShader(
        Rect.fromCircle(center: center, radius: radius),
      )
      ..strokeWidth = 12
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GlowingRingPainter oldDelegate) {
    return oldDelegate.progressPct != progressPct ||
        oldDelegate.rotationValue != rotationValue;
  }
}
