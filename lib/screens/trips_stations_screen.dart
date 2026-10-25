import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/station.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/sessions_service.dart';
import '../services/stations_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import '../utils/money.dart';
import '../widgets/charge_start_panel.dart';
import '../widgets/station_sheet.dart';
import '../widgets/app_toast.dart';

/// Opens the camera QR scanner — the quickest way to start a charge when the
/// driver is standing at the charger.
Future<void> showQrScannerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) => const QrScannerSheet(),
  );
}

/// The stations tab: the live network as a list. Tapping one opens the same
/// station sheet as the map.
class TripsStationsScreen extends StatefulWidget {
  const TripsStationsScreen({super.key});

  @override
  State<TripsStationsScreen> createState() => _TripsStationsScreenState();
}

/// Which stations the list shows.
enum _StationShow { all, active, inactive }

class _TripsStationsScreenState extends State<TripsStationsScreen> {
  final StationsService _stations = StationsService.instance;
  _StationShow _show = _StationShow.all;

  static bool _isActive(ChargingStationLocation s) =>
      s.availability != StationAvailability.offline;

  @override
  void initState() {
    super.initState();
    _stations.stations.addListener(_onStationsChanged);
    _stations.loading.addListener(_onStationsChanged);
    _stations.load();
  }

  @override
  void dispose() {
    _stations.stations.removeListener(_onStationsChanged);
    _stations.loading.removeListener(_onStationsChanged);
    super.dispose();
  }

  void _onStationsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final List<ChargingStationLocation> all = _stations.stations.value;
    final bool loading = _stations.loading.value;
    final String? error = _stations.error.value;

    return Scaffold(
      backgroundColor: context.palette.bg,
      appBar: AppBar(
        toolbarHeight: 64,
        automaticallyImplyLeading: false,
        title: Text(
          AppStrings.get('stations'),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: context.palette.ink,
            letterSpacing: -0.4,
          ),
        ),
        actions: const [SizedBox(width: 16)],
      ),
      body: RefreshIndicator(
        onRefresh: () => _stations.load(force: true),
        child: ListView(
          // Always scrollable, or pull-to-refresh does nothing on a short list.
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          children: [
            if (all.isEmpty && loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            else if (all.isEmpty)
              _buildEmpty(context, error)
            else ...[
              // The list is the last one that loaded; say so when it could not
              // be refreshed rather than passing it off as live.
              if (error != null && !loading) _buildOfflineNotice(context),
              _buildShowFilter(context, all),
              const SizedBox(height: 14),
              ...all
                  .where(
                    (ChargingStationLocation s) => switch (_show) {
                      _StationShow.all => true,
                      _StationShow.active => _isActive(s),
                      _StationShow.inactive => !_isActive(s),
                    },
                  )
                  .map((station) => _buildStationCard(station, context)),
            ],
          ],
        ),
      ),
    );
  }

  /// Бүгд / Идэвхтэй / Идэвхгүй, each with how many stations it holds.
  Widget _buildShowFilter(
    BuildContext context,
    List<ChargingStationLocation> all,
  ) {
    final AppPalette palette = context.palette;
    final int active = all.where(_isActive).length;
    final List<(_StationShow, String, int, Color?)> options =
        <(_StationShow, String, int, Color?)>[
          (_StationShow.all, AppStrings.get('stations_show_all'), all.length, null),
          (
            _StationShow.active,
            AppStrings.get('stations_show_active'),
            active,
            StationAvailability.available.tone,
          ),
          (
            _StationShow.inactive,
            AppStrings.get('stations_show_inactive'),
            all.length - active,
            StationAvailability.offline.tone,
          ),
        ];

    return Row(
      children: <Widget>[
        for (final (_StationShow value, String label, int count, Color? dot)
            in options) ...<Widget>[
          if (value != _StationShow.all) const SizedBox(width: 8),
          Expanded(
            child: Material(
              color: _show == value
                  ? palette.ink
                  : palette.ink.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => setState(() => _show = value),
                child: SizedBox(
                  height: 38,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      if (dot != null) ...<Widget>[
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: dot,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(
                          '$label $count',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _show == value ? palette.bg : palette.ink,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmpty(BuildContext context, String? error) {
    final AppPalette palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 12),
      child: Column(
        children: <Widget>[
          Icon(Icons.cloud_off_rounded, size: 44, color: palette.inkMuted),
          const SizedBox(height: 12),
          Text(
            AppStrings.get('stations_empty_title'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            error ?? AppStrings.get('stations_empty_body'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: palette.inkMuted),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => _stations.load(force: true),
            child: Text(AppStrings.get('retry')),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineNotice(BuildContext context) {
    final AppPalette palette = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.warningOrange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.warningOrange.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.cloud_off_rounded,
            size: 18,
            color: AppTheme.warningOrange,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppStrings.get('stations_offline_notice'),
              style: TextStyle(fontSize: 12.5, color: palette.ink, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStationCard(
    ChargingStationLocation station,
    BuildContext context,
  ) {
    final AppPalette palette = context.palette;
    final StationAvailability availability = station.availability;
    final String status = availability == StationAvailability.offline
        ? AppStrings.get('station_status_offline')
        : AppStrings.get('plugs_free')
              .replaceFirst('{free}', '${station.availableConnectors}')
              .replaceFirst('{total}', '${station.totalConnectors}');

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: palette.card,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => showStationSheet(context, station: station),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        station.name,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: palette.ink,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: palette.inkMuted),
                  ],
                ),
                if (station.address.trim().isNotEmpty ||
                    station.distance.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    <String>[
                      if (station.address.trim().isNotEmpty)
                        station.address.trim(),
                      if (station.distance.isNotEmpty) station.distance,
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: palette.inkMuted),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: availability.tone,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Takes the slack and ellipsises rather than pushing the
                    // price off the card on a narrow phone.
                    Expanded(
                      child: Text(
                        <String>[
                          status,
                          if (station.kwSpeed > 0)
                            '${station.kwSpeed.toStringAsFixed(0)} ${AppStrings.get('unit_kw')}',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: palette.inkMuted),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (station.basePricePerKwh > 0)
                      Text(
                        '${formatMntLeading(station.basePricePerKwh)}/${AppStrings.get('unit_kwh')}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: palette.ink,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Which step the sheet is on, from camera to a started charge.
enum _ScanStage { scanning, resolving, confirming }

/// Builds the camera view. Injectable so tests can feed codes without one.
typedef QrScannerViewBuilder =
    Widget Function(
      BuildContext context,
      MobileScannerController controller,
      void Function(BarcodeCapture capture) onDetect,
    );

/// Camera QR scanner → sticker lookup → the shared [ChargeStartPanel].
///
/// A QR sticker only ever identifies a gun; the station's own Authorize
/// decides whether the scanning driver's tag can charge there.
class QrScannerSheet extends StatefulWidget {
  const QrScannerSheet({
    super.key,
    this.controller,
    this.scannerBuilder,
    this.stationsService,
    this.sessionsService,
    this.authService,
  });

  final MobileScannerController? controller;
  final QrScannerViewBuilder? scannerBuilder;
  final StationsService? stationsService;
  final SessionsService? sessionsService;
  final AuthService? authService;

  @override
  State<QrScannerSheet> createState() => _QrScannerSheetState();
}

class _QrScannerSheetState extends State<QrScannerSheet> {
  StationsService get _stations =>
      widget.stationsService ?? StationsService.instance;

  late final MobileScannerController _controller =
      widget.controller ??
      MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);

  _ScanStage _stage = _ScanStage.scanning;

  /// Set the moment a frame decodes, so the dozens of frames still in flight
  /// behind it do not each try to resolve the same code again. Cleared again
  /// whenever the sheet goes back to scanning.
  bool _handledDetection = false;

  ConnectorLookup? _lookup;
  ChargingStationLocation? _station;
  String? _errorMessage;

  /// The station's guns as `/live` last reported them — the only read that
  /// says whether another driver has the scanned gun.
  List<StationConnector>? _live;

  /// Keeps the scanned gun held for this driver and its state fresh while the
  /// confirm view is open.
  Timer? _poll;
  static const Duration _pollEvery = Duration(seconds: 5);

  bool get _signedIn =>
      (widget.authService ?? AuthService.instance).currentUser.value != null;

  @override
  void dispose() {
    _poll?.cancel();
    _releaseHold();
    _controller.dispose();
    super.dispose();
  }

  /// Holds the scanned gun (when signed in) and re-reads every gun's state.
  /// Failures are quiet: the next tick tries again, and the server still
  /// refuses a start on a gun someone else has.
  Future<void> _syncLive(ConnectorLookup lookup) async {
    final int? connectorId = lookup.connectorId;
    if (connectorId != null && _signedIn) {
      try {
        await _stations.holdConnector(lookup.stationId, connectorId);
      } catch (_) {}
    }
    try {
      final List<StationConnector> live = await _stations.liveConnectors(
        lookup.stationId,
      );
      if (!mounted || _lookup?.stationId != lookup.stationId) return;
      if (live.isNotEmpty) setState(() => _live = live);
    } catch (_) {}
  }

  void _startPolling(ConnectorLookup lookup) {
    _poll?.cancel();
    _poll = Timer.periodic(_pollEvery, (_) => unawaited(_syncLive(lookup)));
  }

  void _releaseHold() {
    final ConnectorLookup? lookup = _lookup;
    final int? connectorId = lookup?.connectorId;
    if (lookup == null || connectorId == null || !_signedIn) return;
    unawaited(
      _stations
          .releaseConnector(lookup.stationId, connectorId)
          .catchError((Object _) {}),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handledDetection) return;
    String? value;
    for (final Barcode barcode in capture.barcodes) {
      if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
        value = barcode.rawValue;
        break;
      }
    }
    if (value == null || value.isEmpty) return;
    _handledDetection = true;
    unawaited(_safely(_controller.stop));
    _resolve(value);
  }

  Future<void> _safely(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // A camera that is already stopped or started is not a problem here.
    }
  }

  Future<void> _resolve(String scanned) async {
    setState(() {
      _stage = _ScanStage.resolving;
      _errorMessage = null;
    });
    try {
      final ConnectorLookup lookup = await _stations.resolveConnectorCode(
        scanned,
      );
      // The guns' live states are worth showing before the driver commits,
      // but a station that fails to load should not block starting on what
      // the code already resolved.
      ChargingStationLocation? station;
      try {
        station = await _stations.station(lookup.stationId);
      } on ApiException {
        station = null;
      }
      if (!mounted) return;
      _lookup = lookup;
      _live = null;
      // Ask who has the gun before showing it, so a taken gun is never
      // offered for a moment and then pulled away.
      await _syncLive(lookup);
      if (!mounted) return;
      setState(() {
        _station = station;
        _stage = _ScanStage.confirming;
      });
      _startPolling(lookup);
    } on ApiException catch (err) {
      if (!mounted) return;
      // Back to the camera, ready for the next code: it used to stay stopped
      // with the detection latch still set, so one unrecognised sticker left
      // the scanner dead until the sheet was closed.
      _backToScanning(error: err.message);
    }
  }

  void _backToScanning({String? error}) {
    _poll?.cancel();
    _releaseHold();
    setState(() {
      _live = null;
      _stage = _ScanStage.scanning;
      _lookup = null;
      _station = null;
      _errorMessage = error;
      _handledDetection = false;
    });
    unawaited(_safely(_controller.start));
  }

  void _onStarted() {
    _poll?.cancel();
    // The toast lives on the root overlay, so it outlasts the sheet closing.
    AppToast.show(context, AppStrings.get('charge_started'));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // The camera reads best on dark, and the confirm view stays in the same
    // sheet, so the whole sheet uses the dark palette.
    return Theme(
      data: AppTheme.darkTheme,
      child: Builder(
        builder: (BuildContext context) {
          final AppPalette palette = context.palette;
          final bool confirming = _stage == _ScanStage.confirming;
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                  child: Row(
                    children: [
                      Icon(
                        confirming
                            ? Icons.ev_station_rounded
                            : Icons.qr_code_scanner_rounded,
                        color: palette.accent,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          AppStrings.get(
                            confirming ? 'confirm_start_title' : 'scan_qr',
                          ),
                          style: TextStyle(
                            color: palette.ink,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: palette.ink),
                        tooltip: AppStrings.get('close'),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: confirming
                      ? _buildConfirmView(context)
                      : _buildScannerView(context),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildScannerView(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool resolving = _stage == _ScanStage.resolving;
    final QrScannerViewBuilder builder =
        widget.scannerBuilder ??
        (
          BuildContext context,
          MobileScannerController controller,
          void Function(BarcodeCapture) onDetect,
        ) => MobileScanner(controller: controller, onDetect: onDetect);
    return Column(
      children: [
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            AppStrings.get('scan_qr_desc'),
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.inkMuted, fontSize: 13),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.sageGreen, width: 3),
                color: Colors.black,
              ),
              // The camera stays mounted while a code resolves, so going back
              // to scanning only has to restart it, not rebuild it.
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  builder(context, _controller, _onDetect),
                  if (resolving)
                    const ColoredBox(
                      color: Colors.black54,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.sageGreen,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _errorMessage!,
              key: const ValueKey<String>('scan-error'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.warningOrange,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildConfirmView(BuildContext context) {
    final AppPalette palette = context.palette;
    final ConnectorLookup lookup = _lookup!;
    final ChargingStationLocation? station = _station;
    final String title = station?.name ?? lookup.stationName;
    final String? address = station?.address ?? lookup.address;
    final String? tariff = station != null && station.basePricePerKwh > 0
        ? '${formatMntLeading(station.basePricePerKwh)}/${AppStrings.get('unit_kwh')}'
        : null;

    // Without the station detail, the gun the sticker named is all there is
    // to show; its live state is then unknown, and the station decides.
    final List<StationConnector> all = _live?.isNotEmpty == true
        ? _live!
        : station?.connectors.isNotEmpty == true
        ? station!.connectors
        : (lookup.connectorId == null
              ? const <StationConnector>[]
              : <StationConnector>[
                  StationConnector(
                    connectorId: lookup.connectorId!,
                    status: 'Available',
                    type: lookup.connectorType,
                    powerKw: lookup.powerKw,
                    label: lookup.label,
                  ),
                ]);

    StationConnector? scanned;
    for (final StationConnector c in all) {
      if (c.connectorId == lookup.connectorId) scanned = c;
    }
    final bool online = station?.isOnline ?? true;
    // An offline station reports every gun unavailable; the panel already
    // says the station is offline, which is the truer reason.
    final bool scannedTaken = scanned != null && online && !scanned.isStartable;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.bg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title.isEmpty ? AppStrings.get('station_unknown') : title,
                  style: TextStyle(
                    color: palette.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (address != null && address.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      address,
                      style: TextStyle(color: palette.inkMuted, fontSize: 12.5),
                    ),
                  ),
                if (tariff != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      tariff,
                      style: TextStyle(
                        color: palette.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (scannedTaken)
            _buildInUseView(context, scanned, all)
          else
            ChargeStartPanel(
              stationId: lookup.stationId,
              // The sticker names one gun; that is the only one on offer.
              connectors: scanned != null ? <StationConnector>[scanned] : all,
              initialConnectorId: lookup.connectorId,
              stationOnline: station?.isOnline ?? true,
              onStarted: _onStarted,
              stationsService: widget.stationsService,
              sessionsService: widget.sessionsService,
              authService: widget.authService,
              footer: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: TextButton(
                  onPressed: _backToScanning,
                  child: Text(
                    AppStrings.get('scan_again'),
                    style: TextStyle(color: palette.inkMuted, fontSize: 13),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The scanned gun is someone else's: say so, and list the guns that are
  /// free so the driver can walk over and scan one of those instead.
  Widget _buildInUseView(
    BuildContext context,
    StationConnector scanned,
    List<StationConnector> all,
  ) {
    final AppPalette palette = context.palette;
    final List<StationConnector> free = all
        .where(
          (StationConnector c) =>
              c.connectorId != scanned.connectorId && c.isStartable,
        )
        .toList();

    return Column(
      key: const ValueKey<String>('scanned-in-use'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.warningOrange.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.warningOrange.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(
                Icons.do_not_disturb_on_rounded,
                color: AppTheme.warningOrange,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      AppStrings.get('scanned_in_use_title').replaceFirst(
                        '{id}',
                        connectorLetter(scanned.connectorId),
                      ),
                      style: TextStyle(
                        color: palette.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppStrings.get('scanned_in_use_body'),
                      style: TextStyle(
                        color: palette.inkMuted,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ConnectorOptionTile(connector: scanned),
        const SizedBox(height: 10),
        Text(
          AppStrings.get('free_to_scan_title'),
          style: TextStyle(
            color: palette.ink,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        if (free.isEmpty)
          Text(
            AppStrings.get('none_free_to_scan'),
            style: TextStyle(color: palette.inkMuted, fontSize: 13),
          )
        else
          ...free.map(
            (StationConnector c) => ConnectorOptionTile(connector: c),
          ),
        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            key: const ValueKey<String>('scan-another-button'),
            onPressed: _backToScanning,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.sageGreen,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
            label: Text(
              AppStrings.get('scan_again'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}
