import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import '../utils/money.dart';
import 'glass.dart';
import 'vehicle_hero_card.dart' show ChargeStatus, HeroFact;

/// The dashboard's car card as frosted glass: the car's name, a live status
/// pill and a glowing car mark — no brand photo — then either the live
/// charge (battery bar and meter readings) or the last charge's facts.
/// Every number comes from the caller; the card invents nothing.
class GlassVehicleCard extends StatelessWidget {
  const GlassVehicleCard({
    super.key,
    required this.brand,
    required this.model,
    required this.isCharging,
    required this.statusLabel,
    this.facts = const <HeroFact>[],
    this.charge,
    this.onAddVehicle,
  });

  final String brand;
  final String model;
  final bool isCharging;
  final String statusLabel;
  final List<HeroFact> facts;
  final ChargeStatus? charge;
  final VoidCallback? onAddVehicle;

  bool get _hasCar => brand.isNotEmpty || model.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final String name = <String>[
      brand,
      model,
    ].where((String s) => s.isNotEmpty).join(' ');

    return GlassCard(
      borderRadius: 28,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _StatusPill(label: statusLabel, live: isCharging),
                    const SizedBox(height: 12),
                    Text(
                      _hasCar ? name : AppStrings.get('vehicle_add_title'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.ink,
                        fontSize: 24,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                      ),
                    ),
                    if (isCharging &&
                        charge != null &&
                        charge!.detail.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        charge!.detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.inkMuted,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _CarMark(charging: isCharging),
            ],
          ),
          const SizedBox(height: 18),
          if (!_hasCar)
            _AddVehicle(onAddVehicle: onAddVehicle)
          else if (isCharging && charge != null)
            _LiveCharge(charge: charge!)
          else if (facts.isNotEmpty)
            _Facts(facts: facts),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.live});

  final String label;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final Color tone = live ? palette.accent : palette.inkMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tone.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: tone,
              shape: BoxShape.circle,
              boxShadow: live
                  ? <BoxShadow>[
                      BoxShadow(
                        color: tone.withValues(alpha: 0.7),
                        blurRadius: 8,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: tone,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// A glowing car mark in place of a photo: the brand's look without the
/// brand's picture, and the same on every phone. While charging, a ring of
/// light circles it and the bolt breathes, so "charging" is visible at a
/// glance.
class _CarMark extends StatefulWidget {
  const _CarMark({required this.charging});

  final bool charging;

  @override
  State<_CarMark> createState() => _CarMarkState();
}

class _CarMarkState extends State<_CarMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant _CarMark old) {
    super.didUpdateWidget(old);
    _sync();
  }

  /// Runs only while charging, and never when the phone asks for less motion.
  void _sync() {
    final bool reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.charging && !reduce) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = ThemeController.isDark;
    final bool charging = widget.charging;

    return SizedBox(
      width: 84,
      height: 84,
      child: AnimatedBuilder(
        animation: _c,
        builder: (BuildContext context, Widget? _) {
          final double t = _c.value;
          // Two breaths per ring turn.
          final double pulse = charging
              ? (math.sin(t * math.pi * 4) + 1) / 2
              : 0;
          return Stack(
            alignment: Alignment.center,
            children: <Widget>[
              if (charging)
                Transform.rotate(
                  angle: t * math.pi * 2,
                  child: CustomPaint(
                    size: const Size(84, 84),
                    painter: _RingPainter(),
                  ),
                ),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[Color(0xFF34D399), Color(0xFF0EA5A4)],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: isDark ? 0.25 : 0.7),
                    width: 1.5,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(
                        alpha: charging ? 0.45 + 0.30 * pulse : 0.35,
                      ),
                      blurRadius: charging ? 22 + 14 * pulse : 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Transform.scale(
                  scale: 1 + 0.10 * pulse,
                  child: Icon(
                    charging ? Icons.bolt_rounded : Icons.electric_car_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A comet of light on a faint track, rotated by [_CarMark].
class _RingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Rect r = (Offset.zero & size).deflate(3);
    canvas.drawCircle(
      r.center,
      r.width / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF34D399).withValues(alpha: 0.18),
    );
    canvas.drawArc(
      r,
      0,
      math.pi * 1.4,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          endAngle: math.pi * 1.4,
          colors: <Color>[
            const Color(0xFF34D399).withValues(alpha: 0),
            const Color(0xFF34D399),
            const Color(0xFF22D3EE),
          ],
        ).createShader(r),
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => false;
}

class _AddVehicle extends StatelessWidget {
  const _AddVehicle({required this.onAddVehicle});

  final VoidCallback? onAddVehicle;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          AppStrings.get('vehicle_add_body'),
          style: TextStyle(color: palette.inkMuted, fontSize: 13, height: 1.4),
        ),
        if (onAddVehicle != null) ...<Widget>[
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onAddVehicle,
            style: FilledButton.styleFrom(
              backgroundColor: palette.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(AppStrings.get('vehicle_add_cta')),
          ),
        ],
      ],
    );
  }
}

/// The running session: the car's charge as a bar, then the meter's power,
/// energy and cost as three glass tiles.
class _LiveCharge extends StatelessWidget {
  const _LiveCharge({required this.charge});

  final ChargeStatus charge;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final double? soc = charge.socPercent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(
              soc == null ? '—' : '${soc.round()}%',
              style: TextStyle(
                color: palette.ink,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                charge.batteryCaption,
                style: TextStyle(
                  color: charge.hasEstimate ? palette.accent : palette.inkMuted,
                  fontSize: 12.5,
                  fontWeight: charge.hasEstimate
                      ? FontWeight.w800
                      : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _ChargeBar(
          fraction: ((soc ?? 0) / 100).clamp(0.0, 1.0),
          track: palette.inkMuted.withValues(alpha: 0.15),
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            Expanded(
              child: _Tile(
                icon: Icons.speed_rounded,
                label: AppStrings.get('hero_power'),
                value: '${charge.powerKw.toStringAsFixed(1)} кВт',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Tile(
                icon: Icons.battery_charging_full_rounded,
                label: AppStrings.get('hero_energy'),
                value: '${charge.energyKwh.toStringAsFixed(1)} кВт·ц',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Tile(
                icon: Icons.payments_rounded,
                label: AppStrings.get('charge_cost'),
                value: charge.costMnt == null
                    ? '—'
                    : formatMnt(charge.costMnt!),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Not charging: the last charge's facts as small glass tiles.
class _Facts extends StatelessWidget {
  const _Facts({required this.facts});

  final List<HeroFact> facts;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (int i = 0; i < facts.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _Tile(
              icon: facts[i].icon,
              label: facts[i].label,
              value: facts[i].value,
            ),
          ),
        ],
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool isDark = ThemeController.isDark;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 11),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.9),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 16, color: palette.accent),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.ink,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: palette.inkMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// The battery bar with a light sweeping through the filled part, left to
/// right, like current flowing in — the "it is charging" motion.
class _ChargeBar extends StatefulWidget {
  const _ChargeBar({required this.fraction, required this.track});

  final double fraction;
  final Color track;

  @override
  State<_ChargeBar> createState() => _ChargeBarState();
}

class _ChargeBarState extends State<_ChargeBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 10,
        child: Stack(
          children: <Widget>[
            Container(color: widget.track),
            FractionallySizedBox(
              widthFactor: widget.fraction,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[Color(0xFF34D399), Color(0xFF22D3EE)],
                      ),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _c,
                    builder: (BuildContext context, Widget? _) {
                      if (!_c.isAnimating) return const SizedBox.shrink();
                      // From fully left of the fill to fully right of it.
                      final double x = -1.6 + _c.value * 3.2;
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(x - 0.5, 0),
                            end: Alignment(x + 0.5, 0),
                            colors: <Color>[
                              Colors.white.withValues(alpha: 0),
                              Colors.white.withValues(alpha: 0.65),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
