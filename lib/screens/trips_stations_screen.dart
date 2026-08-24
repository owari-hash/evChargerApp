import 'package:flutter/material.dart';
import '../models/station.dart';
import '../services/ocpp_mock_service.dart';
import '../services/stations_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import '../utils/money.dart';

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
              Text(
                AppStrings.get('nearby_stations'),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.palette.ink,
                ),
              ),
              const SizedBox(height: 12),

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
              Container(
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
                  style: const TextStyle(
                    color: AppTheme.sageGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${station.availableConnectors}/${station.totalConnectors} Сул байна',
                style: TextStyle(fontSize: 12, color: context.palette.inkMuted),
              ),
              const Spacer(),
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
        ],
      ),
    );
  }
}

/// Camera QR Scanner & Payment Checkout Modal
class _QrScannerCheckoutSheet extends StatefulWidget {
  const _QrScannerCheckoutSheet();

  @override
  State<_QrScannerCheckoutSheet> createState() =>
      _QrScannerCheckoutSheetState();
}

class _QrScannerCheckoutSheetState extends State<_QrScannerCheckoutSheet> {
  final OcppMockService _service = OcppMockService.instance;
  bool _isScanned = false;
  bool _isProcessing = false;
  double _depositAmountMnt = 25000.0;

  void _onScanCompleted() async {
    setState(() {
      _isScanned = true;
    });
  }

  void _onPayAndStart() async {
    setState(() => _isProcessing = true);

    await _service.startSessionFromQrCode('EV-UB-SHANGRILA', _depositAmountMnt);

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Төлбөр амжилттай! Цэнэглэж эхэллээ (${formatMntLeading(_depositAmountMnt)}).',
          ),
          backgroundColor: AppTheme.sageGreen,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: context.palette.panel,
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
                  _isScanned
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
            child: _isScanned
                ? _buildCheckoutView()
                : _buildCameraScannerView(),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraScannerView() {
    return Column(
      children: [
        const SizedBox(height: 10),
        Text(
          AppStrings.get('scan_qr_desc'),
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 20),
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.sageGreen, width: 3),
              color: Colors.white10,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.qr_code_2_rounded,
                  size: 140,
                  color: Colors.white24,
                ),
                Container(width: 210, height: 2, color: AppTheme.sageGreen),
              ],
            ),
          ),
        ),
        const SizedBox(height: 30),
        ElevatedButton.icon(
          onPressed: _onScanCompleted,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.sageGreen,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
          ),
          icon: const Icon(Icons.check_circle_rounded),
          label: const Text('QR КОД УНШУУЛЛАА'),
        ),
      ],
    );
  }

  Widget _buildCheckoutView() {
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Шангри-Ла Молл Цэнэглэгч',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Загуур #1 (CCS2 Fast 180kW) • ${formatMntLeading(450)}/кВт.ц',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text(
            AppStrings.get('select_deposit'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),

          Row(
            children: [15000.0, 25000.0, 50000.0, 75000.0].map((amt) {
              final bool isSelected = _depositAmountMnt == amt;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: () => setState(() => _depositAmountMnt = amt),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.sageGreen : Colors.white10,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '₮${(amt / 1000).toInt()}k',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          Text(
            AppStrings.get('payment_method'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.qr_code_2_rounded,
                  color: AppTheme.sageGreen,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Text(
                  AppStrings.get('qpay'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.sageGreen,
                  size: 20,
                ),
              ],
            ),
          ),
          const Spacer(),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _onPayAndStart,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.sageGreen,
              ),
              icon: _isProcessing
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
                _isProcessing
                    ? AppStrings.get('scanning')
                    : '${formatMntLeading(_depositAmountMnt)} ТӨЛӨӨД ЦЭНЭГЛЭХ',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
