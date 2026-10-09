import 'package:flutter/material.dart';

import '../services/vehicle_photo_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import '../utils/money.dart';

/// One fact along the bottom of the hero, e.g. "Сүүлд цэнэглэсэн · 3 өдрийн өмнө".
class HeroFact {
  const HeroFact({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

/// The live session, as the charge point reports it. Null fields are things
/// it has not reported, shown as a dash rather than guessed.
class ChargeStatus {
  const ChargeStatus({
    this.socPercent,
    required this.powerKw,
    required this.energyKwh,
    this.costMnt,
    this.detail = '',
  });

  /// The car's own state of charge; many chargers never receive it.
  final double? socPercent;
  final double powerKw;
  final double energyKwh;
  final double? costMnt;

  /// "Сүхбаатарын талбай · 14:05-с".
  final String detail;
}

/// The driver's car as the dashboard's centrepiece: a real photo of their
/// model when one is found, otherwise the car drawn on a lit floor; its name
/// as a wordmark, a live status chip, and a strip of real facts underneath.
/// Every number shown comes from the caller — the card itself invents nothing.
class VehicleHeroCard extends StatefulWidget {
  const VehicleHeroCard({
    super.key,
    required this.brand,
    required this.model,
    required this.isCharging,
    required this.statusLabel,
    this.facts = const <HeroFact>[],
    this.charge,
    this.onAddVehicle,
    this.photo,
    this.photoImage,
  });

  final String brand;
  final String model;
  final bool isCharging;
  final String statusLabel;
  final List<HeroFact> facts;

  /// Set while charging: the battery panel replaces the fact strip.
  final ChargeStatus? charge;
  final VoidCallback? onAddVehicle;

  /// A photo of the saved model; null keeps the drawing.
  final VehiclePhoto? photo;

  /// Where the photo's pixels come from; defaults to [photo]'s URL. Lets a
  /// test or preview supply an image without the network.
  final ImageProvider? photoImage;

  @override
  State<VehicleHeroCard> createState() => _VehicleHeroCardState();
}

class _VehicleHeroCardState extends State<VehicleHeroCard> {
  /// The photo could not be loaded; the drawing takes its place.
  bool _photoFailed = false;

  @override
  void didUpdateWidget(VehicleHeroCard old) {
    super.didUpdateWidget(old);
    if (old.photo?.url != widget.photo?.url ||
        old.photoImage != widget.photoImage) {
      _photoFailed = false;
    }
  }

  void _onPhotoError() {
    if (_photoFailed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _photoFailed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final VehiclePhoto? photo = _photoFailed ? null : widget.photo;
    return _HeroCardBody(
      brand: widget.brand,
      model: widget.model,
      isCharging: widget.isCharging,
      statusLabel: widget.statusLabel,
      facts: widget.facts,
      charge: widget.isCharging ? widget.charge : null,
      onAddVehicle: widget.onAddVehicle,
      photoImage: photo == null
          ? null
          : widget.photoImage ??
                NetworkImage(photo.url, headers: _photoHeaders),
      credit: photo?.credit,
      onPhotoError: _onPhotoError,
    );
  }
}

const Map<String, String> _photoHeaders = <String, String>{
  'User-Agent': 'EplugApp/1.0 (contact@eplug.mn)',
};

class _HeroCardBody extends StatelessWidget {
  const _HeroCardBody({
    required this.brand,
    required this.model,
    required this.isCharging,
    required this.statusLabel,
    required this.facts,
    required this.charge,
    required this.onAddVehicle,
    required this.photoImage,
    required this.credit,
    required this.onPhotoError,
  });

  /// Height of the band between the wordmark and the fact strip.
  static const double stageHeight = 156;

  /// The car shown before a photo of the driver's own model is found.
  static const String defaultCarAsset = 'assets/images/ev_default.png';
  static const double _defaultCarAspect = 619 / 324;

  /// A larger stage on wide screens, where 156pt leaves the car tiny.
  static const double wideStageHeight = 230;

  /// Where the card switches from photo-on-top to photo-beside.
  static const double wideBreakpoint = 600;

  /// The model's photo; null draws the car instead.
  final ImageProvider? photoImage;
  final String? credit;
  final VoidCallback onPhotoError;

  final String brand;
  final String model;
  final bool isCharging;

  /// "Бэлэн", or "Цэнэглэж байна · 22 кВт" while a session runs.
  final String statusLabel;

  /// At most three; fewer are fine, none hides the strip.
  final List<HeroFact> facts;

  final ChargeStatus? charge;

  final VoidCallback? onAddVehicle;

  bool get _hasVehicle => brand.isNotEmpty || model.isNotEmpty;

  static const Color _accent = Color(0xFF34D399);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF0D2619).withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[_bgTop, _bgMid, _bgBottom],
              stops: <double>[0.0, 0.55, 1.0],
            ),
          ),
          child: photoImage == null
              ? _drawingLayout()
              : LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints box) {
                    final bool wide = box.maxWidth >= wideBreakpoint;
                    if (charge != null) {
                      return wide
                          ? _chargingWideLayout()
                          : _chargingPhoneLayout();
                    }
                    return _photoFullLayout(box.maxWidth, wide);
                  },
                ),
        ),
      ),
    );
  }

  static const Color _bgTop = Color(0xFF123526);
  static const Color _bgMid = Color(0xFF0A1F16);
  static const Color _bgBottom = Color(0xFF050E0A);

  Widget _drawingLayout() {
    return Stack(
      children: <Widget>[
        // Studio spotlight from above the car.
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.15, 0.1),
                radius: 0.9,
                colors: <Color>[Color(0x332FBF7E), Color(0x00000000)],
              ),
            ),
          ),
        ),
        // A faint diagonal sheen, like light across glass.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: const Alignment(-1.0, -1.0),
                  end: const Alignment(1.0, 1.0),
                  colors: <Color>[
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white.withValues(alpha: 0.045),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                  stops: const <double>[0.30, 0.42, 0.54],
                ),
              ),
            ),
          ),
        ),
        // Hairline rim, brighter along the top edge.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _header(),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints box) => SizedBox(
                  height: box.maxWidth >= wideBreakpoint
                      ? wideStageHeight
                      : stageHeight,
                  child: _stage(),
                ),
              ),
              if (charge != null) ...<Widget>[
                const SizedBox(height: 6),
                _chargePanel(compact: true),
              ] else if (facts.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                _factStrip(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Not charging: the photo is the whole card. Name and status sit on a
  /// shade at the top, the facts on a glass strip at the bottom.
  Widget _photoFullLayout(double width, bool wide) {
    if (!wide) return _photoPhoneIdleLayout();
    // Close to a photo's own shape, so the car is not cropped to a sliver,
    // never so tall it pushes everything else off screen.
    final double height = (width / 2.0).clamp(280.0, 560.0);
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _CarPhoto(image: photoImage!, onError: onPhotoError),
          const _Shade(
            begin: Alignment.topCenter,
            end: Alignment(0, -0.25),
            from: Color(0xB3000000),
          ),
          if (facts.isNotEmpty)
            const _Shade(
              begin: Alignment.bottomCenter,
              end: Alignment(0, 0.2),
              from: Color(0xCC000000),
            ),
          Positioned(
            top: wide ? 22 : 16,
            left: wide ? 26 : 18,
            right: wide ? 22 : 16,
            child: _header(),
          ),
          Positioned(
            left: wide ? 22 : 12,
            right: wide ? 22 : 12,
            bottom: wide ? 22 : 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _credit(),
                if (facts.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _factStrip(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Not charging, on a phone: the photo at its own shape across the top,
  /// so the whole car shows, and the facts just under it.
  Widget _photoPhoneIdleLayout() {
    return ColoredBox(
      color: _bgMid,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AspectRatio(
            aspectRatio: 3 / 2,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                _CarPhoto(image: photoImage!, onError: onPhotoError),
                const _Shade(
                  begin: Alignment.topCenter,
                  end: Alignment(0, -0.25),
                  from: Color(0xB3000000),
                ),
                if (facts.isNotEmpty)
                  const _Shade(
                    begin: Alignment.bottomCenter,
                    end: Alignment(0, 0.55),
                    from: _bgMid,
                  ),
                Positioned(top: 16, left: 18, right: 16, child: _header()),
                Positioned(right: 14, bottom: 6, child: _credit()),
              ],
            ),
          ),
          if (facts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 12),
              child: _factStrip(),
            ),
        ],
      ),
    );
  }

  /// Charging on a phone: the car on top, the battery panel under it.
  Widget _chargingPhoneLayout() {
    return ColoredBox(
      color: _bgMid,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                _CarPhoto(image: photoImage!, onError: onPhotoError),
                const _Shade(
                  begin: Alignment.topCenter,
                  end: Alignment(0, -0.2),
                  from: Color(0xB3000000),
                ),
                const _Shade(
                  begin: Alignment.bottomCenter,
                  end: Alignment(0, 0.35),
                  from: _bgMid,
                ),
                Positioned(top: 16, left: 18, right: 16, child: _header()),
                Positioned(right: 14, bottom: 6, child: _credit()),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: _chargePanel(compact: false),
          ),
        ],
      ),
    );
  }

  /// Charging on a wide screen: the car on the left, the battery beside it.
  /// The photo blends into the panel through an overlay gradient, which
  /// renders the same everywhere (a ShaderMask left a hard seam on the web).
  Widget _chargingWideLayout() {
    return SizedBox(
      height: 300,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            flex: 6,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                _CarPhoto(image: photoImage!, onError: onPhotoError),
                const _Shade(
                  begin: Alignment.topCenter,
                  end: Alignment(0, -0.2),
                  from: Color(0xB3000000),
                ),
                const _Shade(
                  begin: Alignment.centerRight,
                  end: Alignment(0.35, 0),
                  from: _bgMid,
                ),
                Positioned(top: 22, left: 26, right: 26, child: _header()),
                Positioned(left: 26, bottom: 12, child: _credit()),
              ],
            ),
          ),
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 24, 28, 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _chargePanel(compact: false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Battery and session: the car's charge large with a bar, then power,
  /// energy and cost. A dash wherever the charger has not reported a value.
  Widget _chargePanel({required bool compact}) {
    final ChargeStatus c = charge!;
    final double? soc = c.socPercent;

    Widget stat(IconData icon, String label, String value) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                icon,
                size: 12,
                color: AppTheme.lightSage.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            if (soc == null)
              Icon(Icons.bolt_rounded, color: _accent, size: compact ? 32 : 40)
            else
              Text(
                soc.toStringAsFixed(0),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: compact ? 34 : 46,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.5,
                  height: 1.0,
                ),
              ),
            if (soc != null)
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 4),
                child: Text(
                  '%',
                  style: TextStyle(
                    color: _accent,
                    fontSize: compact ? 16 : 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  soc == null
                      ? AppStrings.get('charge_soc_unknown')
                      : AppStrings.get('charge_battery'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _BatteryBar(fraction: soc == null ? null : (soc / 100).clamp(0.0, 1.0)),
        SizedBox(height: compact ? 12 : 16),
        Row(
          children: <Widget>[
            stat(
              Icons.bolt_rounded,
              AppStrings.get('hero_power'),
              '${c.powerKw.toStringAsFixed(0)} кВт',
            ),
            stat(
              Icons.battery_charging_full_rounded,
              AppStrings.get('hero_energy'),
              '${c.energyKwh.toStringAsFixed(1)} кВт·ц',
            ),
            stat(
              Icons.payments_outlined,
              AppStrings.get('charge_cost'),
              c.costMnt == null ? '—' : formatMnt(c.costMnt!),
            ),
          ],
        ),
        if (c.detail.isNotEmpty) ...<Widget>[
          SizedBox(height: compact ? 10 : 14),
          Row(
            children: <Widget>[
              Icon(
                Icons.ev_station_rounded,
                size: 13,
                color: AppTheme.lightSage.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  c.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// The photographer and licence, which Creative Commons asks us to show.
  Widget _credit() {
    if (credit == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        '${AppStrings.get('photo_credit')}: $credit',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.55),
          fontSize: 9,
          fontWeight: FontWeight.w500,
          shadows: const <Shadow>[Shadow(color: Colors.black54, blurRadius: 4)],
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: _hasVehicle
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (brand.isNotEmpty)
                      Text(
                        brand.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppTheme.lightSage.withValues(alpha: 0.75),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3.2,
                        ),
                      ),
                    if (model.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        model,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      AppStrings.get('vehicle_add_title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppStrings.get('vehicle_add_body'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(width: 12),
        _hasVehicle ? _statusChip() : _addButton(),
      ],
    );
  }

  Widget _statusChip() {
    final Color dot = isCharging
        ? _accent
        : AppTheme.lightSage.withValues(alpha: 0.7);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: dot,
              shape: BoxShape.circle,
              boxShadow: isCharging
                  ? <BoxShadow>[
                      BoxShadow(
                        color: _accent.withValues(alpha: 0.7),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              statusLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addButton() {
    if (onAddVehicle == null) return const SizedBox.shrink();
    return FilledButton.icon(
      onPressed: onAddVehicle,
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.lightSage,
        foregroundColor: AppTheme.darkForest,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: const StadiumBorder(),
      ),
      icon: const Icon(Icons.add_rounded, size: 16),
      label: Text(
        AppStrings.get('vehicle_add_cta'),
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
      ),
    );
  }

  /// The default car on a lit floor, with a soft shadow and a faint
  /// reflection — shown until a photo of the driver's own model is found.
  Widget _stage() {
    Widget car(double glow) => Image.asset(
      defaultCarAsset,
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      filterQuality: FilterQuality.medium,
    );

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: isCharging ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 600),
      builder: (BuildContext context, double glow, Widget? _) {
        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints box) {
            final double carHeight = box.maxHeight * 0.80;
            // The default image's own shape, capped by the stage width.
            final double carWidth = (carHeight * _defaultCarAspect).clamp(
              0.0,
              box.maxWidth,
            );
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: <Widget>[
                // Contact shadow, so the car sits on the floor, not above
                // it — as wide as the car itself, not the card.
                Positioned(
                  left: (box.maxWidth - carWidth * 0.9) / 2,
                  width: carWidth * 0.9,
                  top: carHeight * 0.86,
                  height: carHeight * 0.22,
                  child: CustomPaint(
                    painter: _ContactShadow(glow: glow, accent: _accent),
                  ),
                ),
                // Floor: a thin lit horizon the car stands on.
                Positioned(
                  left: box.maxWidth * 0.04,
                  right: box.maxWidth * 0.04,
                  top: carHeight * 0.965,
                  height: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          _accent.withValues(alpha: 0.0),
                          _accent.withValues(alpha: 0.35 + glow * 0.35),
                          _accent.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                // Reflection, fading out downwards.
                Positioned(
                  top: carHeight * 0.97,
                  left: 0,
                  right: 0,
                  height: carHeight * 0.32,
                  child: IgnorePointer(
                    child: ClipRect(
                      child: ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (Rect r) => LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            Colors.white.withValues(
                              alpha: _hasVehicle ? 0.20 : 0.08,
                            ),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ).createShader(r),
                        child: OverflowBox(
                          alignment: Alignment.topCenter,
                          maxHeight: carHeight,
                          child: Transform.flip(
                            flipY: true,
                            child: SizedBox(
                              height: carHeight,
                              child: car(glow),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: carHeight,
                  child: car(glow),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _factStrip() {
    final List<Widget> cells = <Widget>[];
    for (int i = 0; i < facts.length && i < 3; i++) {
      if (i > 0) {
        cells.add(
          Container(
            width: 1,
            height: 26,
            color: Colors.white.withValues(alpha: 0.10),
          ),
        );
      }
      final HeroFact f = facts[i];
      cells.add(
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      f.icon,
                      size: 12,
                      color: AppTheme.lightSage.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        f.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  f.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(children: cells),
    );
  }
}

/// The model's photo, cover-fitted, fading in over a shimmer while it loads.
class _CarPhoto extends StatelessWidget {
  const _CarPhoto({required this.image, required this.onError});

  final ImageProvider image;
  final VoidCallback onError;

  @override
  Widget build(BuildContext context) {
    return Image(
      image: image,
      fit: BoxFit.cover,
      alignment: const Alignment(0, 0.2),
      gaplessPlayback: true,
      frameBuilder:
          (BuildContext context, Widget child, int? frame, bool sync) {
            if (sync) return child;
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (frame == null) const _Shimmer(),
                AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOut,
                  child: child,
                ),
              ],
            );
          },
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
        onError();
        return const SizedBox.shrink();
      },
    );
  }
}

/// A gradient from [from] at [begin] to transparent at [end].
class _Shade extends StatelessWidget {
  const _Shade({required this.begin, required this.end, required this.from});

  final Alignment begin;
  final Alignment end;
  final Color from;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: begin,
            end: end,
            colors: <Color>[from, from.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

/// A slow light sweep, for the moment before the photo arrives.
class _Shimmer extends StatefulWidget {
  const _Shimmer();

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (BuildContext context, Widget? _) {
        final double x = -1.5 + _c.value * 3;
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(x - 0.6, -0.3),
              end: Alignment(x + 0.6, 0.3),
              colors: <Color>[
                Colors.white.withValues(alpha: 0.02),
                Colors.white.withValues(alpha: 0.08),
                Colors.white.withValues(alpha: 0.02),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The car's charge as a bar; without a reading, a slow sweep that says
/// "charging" without pretending to know how full it is.
class _BatteryBar extends StatelessWidget {
  const _BatteryBar({required this.fraction});

  final double? fraction;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: 8,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ColoredBox(color: Colors.white.withValues(alpha: 0.10)),
            if (fraction != null)
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: fraction,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[Color(0xFF1F8A56), Color(0xFF34D399)],
                    ),
                  ),
                ),
              )
            else
              const _Shimmer(),
          ],
        ),
      ),
    );
  }
}

/// A soft oval of shade under the car, with a hint of the accent while it
/// charges. Painted, not a BoxShadow, so it is the same soft shape everywhere.
class _ContactShadow extends CustomPainter {
  _ContactShadow({required this.glow, required this.accent});

  final double glow;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect r = Offset.zero & size;
    canvas.drawOval(
      r,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            Colors.black.withValues(alpha: 0.55),
            Colors.black.withValues(alpha: 0.0),
          ],
        ).createShader(r),
    );
    if (glow > 0) {
      canvas.drawOval(
        r.inflate(size.height * 0.4),
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              accent.withValues(alpha: 0.30 * glow),
              accent.withValues(alpha: 0.0),
            ],
          ).createShader(r.inflate(size.height * 0.4)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ContactShadow old) =>
      old.glow != glow || old.accent != accent;
}
