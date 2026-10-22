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
    final String name = <String>[brand, model]
        .where((String s) => s.isNotEmpty)
        .join(' ');

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
/// brand's picture, and the same on every phone.
class _CarMark extends StatelessWidget {
  const _CarMark({required this.charging});

  final bool charging;

  @override
  Widget build(BuildContext context) {
    final bool isDark = ThemeController.isDark;
    return Container(
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
            color: const Color(
              0xFF10B981,
            ).withValues(alpha: charging ? 0.6 : 0.35),
            blurRadius: charging ? 28 : 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(
        charging ? Icons.bolt_rounded : Icons.electric_car_rounded,
        color: Colors.white,
        size: 34,
      ),
    );
  }
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
                AppStrings.get(
                  soc == null ? 'charge_soc_unknown' : 'charge_battery',
                ),
                style: TextStyle(color: palette.inkMuted, fontSize: 12.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 10,
            child: Stack(
              children: <Widget>[
                Container(color: palette.inkMuted.withValues(alpha: 0.15)),
                FractionallySizedBox(
                  widthFactor: ((soc ?? 0) / 100).clamp(0.0, 1.0),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[Color(0xFF34D399), Color(0xFF22D3EE)],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
