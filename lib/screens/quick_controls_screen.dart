import 'package:flutter/material.dart';
import '../services/ocpp_mock_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import '../widgets/ocpp_json_logger_sheet.dart';
import 'mongolia_map_screen.dart';

class QuickControlsScreen extends StatefulWidget {
  const QuickControlsScreen({super.key});

  @override
  State<QuickControlsScreen> createState() => _QuickControlsScreenState();
}

class _QuickControlsScreenState extends State<QuickControlsScreen> {
  final OcppMockService _service = OcppMockService.instance;
  double _climateTemp = 17.0;
  bool _isPlayingMedia = true;

  void _openInteractiveMap(BuildContext context) {
    // A pushed route rather than a modal sheet: sheets strip the top padding
    // (MediaQuery.removePadding), which slid the header and its back button
    // under the status bar where they could not be tapped.
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext pageContext) => Scaffold(
          backgroundColor: pageContext.palette.bg,
          appBar: AppBar(
            titleSpacing: 0,
            title: const Text(
              'Цэнэглэх станцын зураг',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              tooltip: 'Буцах',
              onPressed: () => Navigator.of(pageContext).pop(),
            ),
          ),
          body: MongoliaMapScreen(
            onOpenQrScanner: () => Navigator.of(pageContext).pop(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          AppStrings.get('quick_controls'),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: context.palette.ink,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.notes_rounded,
              color: context.palette.ink,
              size: 28,
            ),
            tooltip: AppStrings.get('ocpp_log'),
            onPressed: () => OcppJsonLoggerSheet.show(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          children: [
            // Row 1: Energy & Climate
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Energy Card
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.palette.card,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: context.palette.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.get('energy'),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: context.palette.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '11:44 цагт цэнэглэж эхэлсэн',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.palette.inkMuted,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            '${_service.targetLimitPct.toInt()}%',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: context.palette.ink,
                            ),
                          ),
                          Text(
                            AppStrings.get('charge_limit'),
                            style: TextStyle(
                              fontSize: 10,
                              color: context.palette.inkMuted,
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Limit slider badge
                          Container(
                            width: double.infinity,
                            height: 26,
                            decoration: BoxDecoration(
                              color: context.palette.accent.withValues(
                                alpha: 0.16,
                              ),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: _service.targetLimitPct / 100,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppTheme.sageGreen,
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                  ),
                                ),
                                Text(
                                  'Хязгаар ${_service.targetLimitPct.toInt()}%',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Climate Card
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.palette.card,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: context.palette.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  AppStrings.get('climate'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: context.palette.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${AppStrings.get('outside_temp')} 28°C',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.palette.inkMuted,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_climateTemp.toInt()}°C',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: context.palette.ink,
                                      ),
                                    ),
                                    Text(
                                      AppStrings.get('windows_locked'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: context.palette.inkMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.ac_unit_rounded,
                                color: context.palette.accent,
                                size: 26,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          // Temp range bar
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '08°C',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: context.palette.inkMuted,
                                ),
                              ),
                              Text(
                                '42°C',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: context.palette.inkMuted,
                                ),
                              ),
                            ],
                          ),
                          SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                              activeTrackColor: AppTheme.sageGreen,
                              inactiveTrackColor: context.palette.accent
                                  .withValues(alpha: 0.16),
                            ),
                            child: Slider(
                              value: _climateTemp,
                              min: 8,
                              max: 42,
                              onChanged: (val) =>
                                  setState(() => _climateTemp = val),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Row 2: Media & Tire Pressure
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Media Card
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.palette.card,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: context.palette.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.get('media'),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: context.palette.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppStrings.get('media_system'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.palette.inkMuted,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            AppStrings.get('media_track'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: context.palette.ink,
                            ),
                          ),
                          Text(
                            AppStrings.get('media_artist'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.palette.inkMuted,
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Media Controls
                          Row(
                            children: [
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: 0.45,
                                  color: AppTheme.sageGreen,
                                  backgroundColor: context.palette.accent
                                      .withValues(alpha: 0.16),
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () => setState(
                                  () => _isPlayingMedia = !_isPlayingMedia,
                                ),
                                child: Icon(
                                  _isPlayingMedia
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: context.palette.ink,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Tire Pressure Card
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.palette.card,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: context.palette.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.get('tire_pressure'),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: context.palette.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${AppStrings.get('last_measured')}: 12:15',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.palette.inkMuted,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      '49 psi',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: context.palette.ink,
                                      ),
                                    ),
                                    SizedBox(height: 18),
                                    Text(
                                      '47 psi',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: context.palette.ink,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: context.palette.accent.withValues(
                                    alpha: 0.16,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.tire_repair_rounded,
                                  color: context.palette.accent,
                                  size: 26,
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      '48 psi',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: context.palette.ink,
                                      ),
                                    ),
                                    SizedBox(height: 18),
                                    Text(
                                      '49 psi',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: context.palette.ink,
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
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Interactive Location Map Card
            InkWell(
              onTap: () => _openInteractiveMap(context),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.palette.card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: context.palette.border),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          AppStrings.get('location'),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: context.palette.ink,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(
                            Icons.open_in_full_rounded,
                            color: context.palette.ink,
                            size: 20,
                          ),
                          onPressed: () => _openInteractiveMap(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        height: 152,
                        decoration: BoxDecoration(
                          color: context.palette.accent.withValues(alpha: 0.09),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CustomPaint(
                              painter: _MapPreviewPainter(
                                routeColor: context.palette.accent,
                                gridColor: context.palette.accent.withValues(
                                  alpha: 0.22,
                                ),
                              ),
                            ),
                            // Address chip, floated so the map reads underneath.
                            Positioned(
                              left: 12,
                              right: 12,
                              bottom: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: context.palette.card.withValues(
                                    alpha: 0.94,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: context.palette.border,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.my_location_rounded,
                                      color: context.palette.accent,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        AppStrings.get('vehicle_location'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: context.palette.ink,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: context.palette.inkMuted,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

/// A small map-like preview: faint street grid, a route, and the car's pin.
/// The old painter drew a zig-zag line chart, which said nothing about place.
class _MapPreviewPainter extends CustomPainter {
  _MapPreviewPainter({required this.routeColor, required this.gridColor});

  final Color routeColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    // Streets: a few off-centre lines so it reads as a map, not graph paper.
    for (final double f in <double>[0.22, 0.55, 0.82]) {
      canvas.drawLine(
        Offset(0, size.height * f),
        Offset(size.width, size.height * f),
        grid,
      );
    }
    for (final double f in <double>[0.18, 0.46, 0.74]) {
      canvas.drawLine(
        Offset(size.width * f, 0),
        Offset(size.width * f, size.height),
        grid,
      );
    }

    // One wider avenue.
    final Paint avenue = Paint()
      ..color = gridColor
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(0, size.height * 0.68),
      Offset(size.width, size.height * 0.52),
      avenue,
    );

    // The travelled route.
    final Path route = Path()
      ..moveTo(size.width * 0.14, size.height * 0.82)
      ..cubicTo(
        size.width * 0.34,
        size.height * 0.74,
        size.width * 0.38,
        size.height * 0.40,
        size.width * 0.60,
        size.height * 0.38,
      )
      ..cubicTo(
        size.width * 0.74,
        size.height * 0.36,
        size.width * 0.76,
        size.height * 0.24,
        size.width * 0.86,
        size.height * 0.22,
      );
    canvas.drawPath(
      route,
      Paint()
        ..color = routeColor
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    // Origin dot.
    final Offset origin = Offset(size.width * 0.14, size.height * 0.82);
    canvas.drawCircle(origin, 4.5, Paint()..color = routeColor);
    canvas.drawCircle(
      origin,
      4.5,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );

    // Destination pin with a soft halo.
    final Offset pin = Offset(size.width * 0.86, size.height * 0.22);
    canvas.drawCircle(
      pin,
      13,
      Paint()..color = routeColor.withValues(alpha: 0.18),
    );
    canvas.drawCircle(pin, 6.5, Paint()..color = routeColor);
    canvas.drawCircle(pin, 2.4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _MapPreviewPainter oldDelegate) =>
      oldDelegate.routeColor != routeColor ||
      oldDelegate.gridColor != gridColor;
}
