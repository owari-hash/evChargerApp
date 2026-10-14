import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/station.dart';
import '../services/api_client.dart';
import '../services/ocpp_mock_service.dart';
import '../services/sessions_service.dart';
import '../services/stations_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import '../utils/money.dart';
import '../widgets/account_widgets.dart';
import '../widgets/auth_gate.dart';
import 'wallet_screen.dart';

class TripsStationsScreen extends StatefulWidget {
  const TripsStationsScreen({super.key});

  @override
  State<TripsStationsScreen> createState() => _TripsStationsScreenState();
}

class _TripsStationsScreenState extends State<TripsStationsScreen> {
  final OcppMockService _service = OcppMockService.instance;
  final StationsService _stations = StationsService.instance;

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

  void _openQrScannerModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _QrScannerCheckoutSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.bg,
      appBar: AppBar(
        toolbarHeight: 76,
        automaticallyImplyLeading: false,
        title: Text(
          AppStrings.get('nearby_stations'),
          maxLines: 2,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: context.palette.ink,
            letterSpacing: -0.4,
            height: 1.15,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.qr_code_scanner_rounded,
              color: context.palette.ink,
              size: 28,
            ),
            onPressed: () => _openQrScannerModal(context),
            tooltip: AppStrings.get('scan_qr'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _stations.load(force: true),
        child: SingleChildScrollView(
          // Always scrollable, or pull-to-refresh does nothing on a short list.
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Say so when the list is the built-in fallback, rather than
              // letting stale stations pass for the live network.
              // TEMPORARY: suppressed during App Store capture. Remove.
              if (_stations.isFallback &&
                  !_stations.loading.value &&
                  !bool.fromEnvironment('SCREENSHOT_MODE'))
                _buildOfflineNotice(context),

              ..._service.nearbyStations.map(
                (station) => _buildStationCard(station, context),
              ),
            ],
          ),
        ),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.palette.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      station.address,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.palette.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.palette.bg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.ev_station_rounded,
                  color: context.palette.ink,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.palette.accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${station.kwSpeed.toInt()} кВт Супер',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.sageGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Takes the slack and ellipsises rather than pushing the price
              // off the card: a Spacer cannot shrink, so on a narrow phone the
              // Mongolian label used to overflow the row.
              Expanded(
                child: Text(
                  '${station.availableConnectors}/${station.totalConnectors} Сул байна',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.palette.inkMuted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${formatMntLeading(station.pricePerKwh)}/кВт.ц',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: context.palette.ink,
                ),
              ),
            ],
          ),
          if (station.feePercent > 0) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                AppStrings.get(
                  'service_fee_included',
                ).replaceFirst('{percent}', formatPercent(station.feePercent)),
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 11, color: context.palette.inkMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Which step the sheet is on, from camera to a started charge.
enum _ScanStage { scanning, resolving, confirming, starting }

/// Real camera QR Scanner → connector lookup → start-charging sheet.
///
/// It used to collect a made-up deposit on a hardcoded station. A QR sticker
/// only ever identifies a connector; the station's own Authorize decides
/// whether the scanning driver's tag can charge there, for free or otherwise
/// — this sheet has nothing to say about price.
class _QrScannerCheckoutSheet extends StatefulWidget {
  const _QrScannerCheckoutSheet();

  @override
  State<_QrScannerCheckoutSheet> createState() =>
      _QrScannerCheckoutSheetState();
}

class _QrScannerCheckoutSheetState extends State<_QrScannerCheckoutSheet> {
  final StationsService _stations = StationsService.instance;
  final SessionsService _sessions = SessionsService.instance;
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  _ScanStage _stage = _ScanStage.scanning;

  /// Set the moment a frame decodes, so the dozens of frames still in flight
  /// behind it do not each try to resolve the same code again.
  bool _handledDetection = false;

  ConnectorLookup? _lookup;
  ChargingStationLocation? _station;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
    unawaited(_controller.stop());
    _resolve(value);
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
      // The tariff and live connector status are worth showing before the
      // driver commits, but a station that fails to load a second time
      // should not block starting on what the code already resolved.
      ChargingStationLocation? station;
      try {
        station = await _stations.station(lookup.stationId);
      } on ApiException {
        station = null;
      }
      if (!mounted) return;
      setState(() {
        _lookup = lookup;
        _station = station;
        _stage = _ScanStage.confirming;
      });
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _errorMessage = err.message;
        _stage = _ScanStage.scanning;
      });
    }
  }

  void _rescan() {
    setState(() {
      _stage = _ScanStage.scanning;
      _lookup = null;
      _station = null;
      _errorMessage = null;
      _handledDetection = false;
    });
    unawaited(_controller.start());
  }

  Future<void> _startCharging() async {
    final ConnectorLookup? lookup = _lookup;
    if (lookup == null) return;

    // Starting a charge is the account-based half of the app, so this is
    // where an account is finally asked for. Signing in returns here and the
    // charge goes ahead — the driver taps once, not twice.
    final bool signedIn = await AuthGate.require(
      context,
      reason: AppStrings.get('signin_required_charge'),
    );
    if (!signedIn || !mounted) return;

    setState(() => _stage = _ScanStage.starting);

    try {
      await _stations.startCharging(
        lookup.stationId,
        connectorId: lookup.connectorId,
      );
      _sessions.notifySessionStarted();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.get('charge_started')),
          backgroundColor: AppTheme.sageGreen,
          duration: const Duration(seconds: 3),
        ),
      );
    } on ApiException catch (err) {
      if (!mounted) return;
      if (err.statusCode == 402) {
        setState(() => _stage = _ScanStage.confirming);
        await showStartBlockedDialog(
          context,
          message: err.message,
          onTopUp: () {
            Navigator.pop(context);
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) => const WalletScreen(),
              ),
            );
          },
        );
        return;
      }
      setState(() {
        _stage = _ScanStage.confirming;
        _errorMessage = err.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool confirming =
        _stage == _ScanStage.confirming || _stage == _ScanStage.starting;
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF0F1722),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: AppTheme.sageGreen,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Text(
                  confirming
                      ? AppStrings.get('confirm_payment')
                      : AppStrings.get('scan_qr'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          Expanded(
            child: confirming ? _buildConfirmView() : _buildScannerView(),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerView() {
    final bool resolving = _stage == _ScanStage.resolving;
    return Column(
      children: [
        const SizedBox(height: 10),
        Text(
          AppStrings.get('scan_qr_desc'),
          style: const TextStyle(color: Colors.white70, fontSize: 13),
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
              child: resolving
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.sageGreen,
                      ),
                    )
                  : MobileScanner(controller: _controller, onDetect: _onDetect),
            ),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.warningOrange, fontSize: 13),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildConfirmView() {
    final ConnectorLookup? lookup = _lookup;
    final ChargingStationLocation? station = _station;
    final bool starting = _stage == _ScanStage.starting;
    final String title =
        station?.name ?? lookup?.stationName ?? AppStrings.get('station_unknown');
    final String? address = station?.address ?? lookup?.address;
    final String connectorLabel = lookup?.connectorId != null
        ? (lookup!.label?.trim().isNotEmpty == true
              ? lookup.label!
              : '${AppStrings.get('connector_label')} ${lookup.connectorId}')
        : AppStrings.get('connector_any');
    final String? tariff = station != null
        ? '${formatMntLeading(station.pricePerKwh)}/кВт.ц'
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.ev_station_rounded,
                  color: AppTheme.sageGreen,
                  size: 32,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (address != null && address.isNotEmpty)
                        Text(
                          address,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      Text(
                        tariff != null ? '$connectorLabel • $tariff' : connectorLabel,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            Text(
              _errorMessage!,
              style: const TextStyle(color: AppTheme.warningOrange, fontSize: 13),
            ),
          ],
          const Spacer(),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: starting ? null : _startCharging,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.sageGreen,
              ),
              icon: starting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.bolt_rounded, size: 22),
              label: Text(
                starting
                    ? AppStrings.get('scanning')
                    : AppStrings.get('start_charging_cta'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: starting ? null : _rescan,
            child: Text(
              AppStrings.get('scan_again'),
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
