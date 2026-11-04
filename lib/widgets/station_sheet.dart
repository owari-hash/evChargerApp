import 'dart:async';

import 'package:flutter/material.dart';

import '../models/station.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/sessions_service.dart';
import '../services/stations_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import '../utils/money.dart';
import '../screens/trips_stations_screen.dart';
import 'charge_start_panel.dart';
import 'app_toast.dart';
import 'glass.dart';

/// Opens [station]'s detail sheet — the app's version of the website's
/// station page: status, address, power and price, every gun with its live
/// state, directions, and starting a charge on a free gun.
///
/// [onRoute] starts the in-app route (the map passes one); [onExternalMaps]
/// overrides the Google Maps hand-off. Both close the sheet first. Without
/// [onRoute], «Чиглэл» goes straight to Google Maps.
Future<void> showStationSheet(
  BuildContext context, {
  required ChargingStationLocation station,
  VoidCallback? onRoute,
  VoidCallback? onExternalMaps,
  StationsService? stationsService,
  SessionsService? sessionsService,
  AuthService? authService,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) => StationSheet(
      station: station,
      onRoute: onRoute,
      onExternalMaps: onExternalMaps,
      stationsService: stationsService,
      sessionsService: sessionsService,
      authService: authService,
    ),
  );
}

class StationSheet extends StatefulWidget {
  const StationSheet({
    super.key,
    required this.station,
    this.onRoute,
    this.onExternalMaps,
    this.stationsService,
    this.sessionsService,
    this.authService,
    this.liveInterval = const Duration(seconds: 15),
  });

  final ChargingStationLocation station;
  final VoidCallback? onRoute;
  final VoidCallback? onExternalMaps;
  final StationsService? stationsService;
  final SessionsService? sessionsService;
  final AuthService? authService;

  /// How often the guns' states are re-read while the sheet is open.
  final Duration liveInterval;

  @override
  State<StationSheet> createState() => _StationSheetState();
}

class _StationSheetState extends State<StationSheet> {
  StationsService get _stations =>
      widget.stationsService ?? StationsService.instance;

  late ChargingStationLocation _station = widget.station;
  late List<StationConnector> _connectors = widget.station.connectors;
  Timer? _live;

  @override
  void initState() {
    super.initState();
    unawaited(_loadDetail());
    _live = Timer.periodic(widget.liveInterval, (_) => _refreshLive());
  }

  @override
  void dispose() {
    _live?.cancel();
    super.dispose();
  }

  /// The list entry may be minutes old; the detail is what the driver is
  /// about to commit to.
  Future<void> _loadDetail() async {
    try {
      final ChargingStationLocation fresh = await _stations.station(
        widget.station.id,
      );
      if (!mounted) return;
      setState(() {
        // The list carries the distance; the detail is fetched without one.
        _station = fresh.distance.isEmpty
            ? fresh.copyWith(distance: widget.station.distance)
            : fresh;
        _connectors = fresh.connectors;
      });
    } on ApiException {
      // Keep what the map already had.
    }
  }

  Future<void> _refreshLive() async {
    try {
      final List<StationConnector> live = await _stations.liveConnectors(
        widget.station.id,
      );
      if (mounted && live.isNotEmpty) setState(() => _connectors = live);
    } on ApiException {
      // The next tick tries again.
    }
  }

  void _onStarted() {
    // The toast lives on the root overlay, so it outlasts the sheet closing.
    AppToast.show(context, AppStrings.get('charge_started'));
    Navigator.of(context).pop();
  }

  void _navigateToMap() {
    Navigator.of(context).pop();
    if (widget.onRoute != null) {
      widget.onRoute!();
    } else {
      (widget.stationsService ?? StationsService.instance).routeToStation(_station);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final ChargingStationLocation s = _station;
    final int free = _connectors.isEmpty
        ? s.availableConnectors
        // Same rule as the server's count on the stations list: only
        // `Available` is free. A `Preparing` gun is usually still in a car.
        : _connectors
              .where((StationConnector c) => c.isAvailable && !c.inUseByOther)
              .length;
    final int total = _connectors.isEmpty ? s.totalConnectors : _connectors.length;

    final String notPublished = AppStrings.get('not_published');

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: GlassPanel(
        padding: EdgeInsets.zero,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.inkMuted.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                GlassEntrance(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              s.name,
                              style: TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: palette.ink,
                              ),
                            ),
                            if (s.address.trim().isNotEmpty ||
                                s.distance.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 4),
                              Text(
                                <String>[
                                  if (s.address.trim().isNotEmpty)
                                    s.address.trim(),
                                  if (s.distance.isNotEmpty) s.distance,
                                ].join(' · '),
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: palette.inkMuted,
                                  height: 1.35,
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            _StatusLine(station: s, free: free, total: total),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      GlassCircleButton(
                        icon: Icons.close_rounded,
                        tooltip: AppStrings.get('close'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Power, price and free guns, Waze's «14 min | 7.8 mi | 10:02».
                GlassEntrance(
                  delay: const Duration(milliseconds: 70),
                  child: GlassStatStrip(
                    leading: Icons.ev_station_rounded,
                    items: <(String, String)>[
                      (
                        s.kwSpeed > 0
                            ? '${s.kwSpeed.toStringAsFixed(0)} ${AppStrings.get('unit_kw')}'
                            : notPublished,
                        AppStrings.get('max_power'),
                      ),
                      (
                        s.basePricePerKwh > 0
                            ? formatMntLeading(s.basePricePerKwh)
                            : notPublished,
                        '${AppStrings.get('price')} / ${AppStrings.get('unit_kwh')}',
                      ),
                      (
                        s.isOnline && total > 0 ? '$free / $total' : '—',
                        AppStrings.get('station_guns_title'),
                      ),
                    ],
                  ),
                ),
                // Every gun with its live state — one someone has just scanned
                // reads as in use. Only the QR scanner narrows this to one gun.
                if (_connectors.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      AppStrings.get('station_guns_title'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: palette.ink,
                      ),
                    ),
                  ),
                  GlassEntrance(
                    delay: const Duration(milliseconds: 140),
                    child: Column(
                      children: _connectors
                          .map(
                            (StationConnector c) => ConnectorOptionTile(
                              connector: c,
                              online: s.isOnline,
                              // A gun is only picked by scanning its QR sticker,
                              // so the start names the gun the driver is at.
                              onTap: () => AppToast.show(
                                context,
                                AppStrings.get('qr_required_title'),
                                kind: ToastKind.info,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                ChargeStartPanel(
                  stationId: s.id,
                  connectors: _connectors,
                  stationOnline: s.isOnline,
                  onStarted: _onStarted,
                  onScanQr: () {
                    Navigator.of(context).pop();
                    showQrScannerSheet(context);
                  },
                  stationsService: widget.stationsService,
                  sessionsService: widget.sessionsService,
                  authService: widget.authService,
                ),
                const SizedBox(height: 10),
                // Waze's «Route options»: a glass outline pill under the main
                // action. Kept an OutlinedButton so it reads as one to tests
                // and screen readers.
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _navigateToMap,
                    icon: const Icon(Icons.navigation_rounded, size: 19),
                    label: Text(AppStrings.get('directions')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ThemeController.isDark
                          ? GlassTones.mint
                          : palette.accent,
                      backgroundColor: ThemeController.isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.white.withValues(alpha: 0.7),
                      side: BorderSide(
                        color: ThemeController.isDark
                            ? Colors.white.withValues(alpha: 0.13)
                            : palette.border,
                      ),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.station,
    required this.free,
    required this.total,
  });

  final ChargingStationLocation station;
  final int free;
  final int total;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final StationAvailability availability = !station.isOnline
        ? StationAvailability.offline
        : (free > 0 ? StationAvailability.available : StationAvailability.busy);
    final String label = switch (availability) {
      StationAvailability.available => AppStrings.get('station_status_free'),
      StationAvailability.busy => AppStrings.get('station_status_busy'),
      StationAvailability.offline => AppStrings.get('station_status_offline'),
    };
    return Row(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: availability.tone.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: availability.tone,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: palette.ink,
                ),
              ),
            ],
          ),
        ),
        if (station.isOnline && total > 0) ...<Widget>[
          const SizedBox(width: 8),
          Text(
            AppStrings.get('plugs_free')
                .replaceFirst('{free}', '$free')
                .replaceFirst('{total}', '$total'),
            style: TextStyle(fontSize: 12.5, color: palette.inkMuted),
          ),
        ],
      ],
    );
  }
}
