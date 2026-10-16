import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/station.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/sessions_service.dart';
import '../services/stations_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import '../utils/money.dart';
import 'charge_start_panel.dart';

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
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(AppStrings.get('charge_started')),
        backgroundColor: AppTheme.sageGreen,
      ),
    );
  }

  void _closeThen(VoidCallback? action) {
    Navigator.of(context).pop();
    action?.call();
  }

  void _externalMaps() {
    final VoidCallback? custom = widget.onExternalMaps;
    if (custom != null) {
      _closeThen(custom);
      return;
    }
    final Uri url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination='
      '${_station.latitude},${_station.longitude}&travelmode=driving',
    );
    unawaited(
      launchUrl(url, mode: LaunchMode.externalApplication).catchError(
        (Object _) => false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final ChargingStationLocation s = _station;
    final int free = _connectors.isEmpty
        ? s.availableConnectors
        : _connectors.where((StationConnector c) => c.isStartable).length;
    final int total = _connectors.isEmpty ? s.totalConnectors : _connectors.length;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      s.name,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                        color: palette.ink,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: AppStrings.get('close'),
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.close_rounded, color: palette.inkMuted),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _StatusLine(station: s, free: free, total: total),
              if (s.address.trim().isNotEmpty || s.distance.isNotEmpty) ...<
                Widget
              >[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.place_outlined,
                      size: 16,
                      color: palette.inkMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        <String>[
                          if (s.address.trim().isNotEmpty) s.address.trim(),
                          if (s.distance.isNotEmpty) s.distance,
                        ].join(' · '),
                        style: TextStyle(
                          fontSize: 13,
                          color: palette.inkMuted,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              _FactsRow(station: s),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onRoute == null
                          ? _externalMaps
                          : () => _closeThen(widget.onRoute),
                      icon: const Icon(Icons.navigation_rounded, size: 18),
                      label: Text(AppStrings.get('directions')),
                    ),
                  ),
                  if (widget.onRoute != null) ...<Widget>[
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: _externalMaps,
                      child: Tooltip(
                        message: AppStrings.get('open_in_maps'),
                        child: const Icon(Icons.map_outlined, size: 20),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              ChargeStartPanel(
                stationId: s.id,
                connectors: _connectors,
                stationOnline: s.isOnline,
                onStarted: _onStarted,
                stationsService: widget.stationsService,
                sessionsService: widget.sessionsService,
                authService: widget.authService,
              ),
            ],
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

/// Max power and the price the driver pays, side by side.
class _FactsRow extends StatelessWidget {
  const _FactsRow({required this.station});

  final ChargingStationLocation station;

  @override
  Widget build(BuildContext context) {
    final String notPublished = AppStrings.get('not_published');
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: _Fact(
              icon: Icons.bolt_rounded,
              label: AppStrings.get('max_power'),
              value: station.kwSpeed > 0
                  ? '${station.kwSpeed.toStringAsFixed(0)} ${AppStrings.get('unit_kw')}'
                  : notPublished,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Fact(
              icon: Icons.payments_outlined,
              label: AppStrings.get('price'),
              value: station.pricePerKwh > 0
                  ? '${formatMntLeading(station.pricePerKwh)}/${AppStrings.get('unit_kwh')}'
                  : notPublished,
              note: station.pricePerKwh > 0 && station.feePercent > 0
                  ? AppStrings.get('service_fee_included').replaceFirst(
                      '{percent}',
                      formatPercent(station.feePercent),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({
    required this.icon,
    required this.label,
    required this.value,
    this.note,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 15, color: palette.accent),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: palette.inkMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: palette.ink,
              ),
            ),
          ),
          if (note != null)
            Text(
              note!,
              style: TextStyle(fontSize: 10.5, color: palette.inkMuted),
            ),
        ],
      ),
    );
  }
}
