import 'package:flutter/material.dart';
import '../services/ocpp_mock_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';

class TripsStationsScreen extends StatefulWidget {
  const TripsStationsScreen({super.key});

  @override
  State<TripsStationsScreen> createState() => _TripsStationsScreenState();
}

class _TripsStationsScreenState extends State<TripsStationsScreen> {
  final OcppMockService _service = OcppMockService.instance;

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
      backgroundColor: AppTheme.softBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          AppStrings.get('nearby_stations'),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: AppTheme.darkForest,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.darkForest, size: 28),
            onPressed: () => _openQrScannerModal(context),
            tooltip: AppStrings.get('scan_qr'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Scan QR Banner Action Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.darkForest,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.sageGreen, size: 36),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.get('ready_to_charge'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppStrings.get('scan_qr_desc'),
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => _openQrScannerModal(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.sageGreen,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.camera_alt_rounded, size: 20),
                      label: Text(
                        AppStrings.get('scan_button'),
                        style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(
              AppStrings.get('nearby_stations'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.darkForest,
              ),
            ),
            const SizedBox(height: 12),

            ..._service.nearbyStations.map((station) => _buildStationCard(station, context)),
          ],
        ),
      ),
    );
  }

  Widget _buildStationCard(ChargingStationLocation station, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.borderSubtle),
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkForest,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      station.address,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppTheme.softBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.ev_station_rounded, color: AppTheme.darkForest, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.lightSage,
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
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const Spacer(),
              Text(
                '₮${station.pricePerKwh.toInt()}/кВт.ц',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.darkForest,
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
  State<_QrScannerCheckoutSheet> createState() => _QrScannerCheckoutSheetState();
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
          content: Text('Төлбөр амжилттай! Цэнэглэж эхэллээ (₮${_depositAmountMnt.toInt()}).'),
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
      decoration: const BoxDecoration(
        color: AppTheme.darkForest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.sageGreen, size: 24),
                const SizedBox(width: 10),
                Text(
                  _isScanned ? 'Төлбөр баталгаажуулах' : AppStrings.get('scan_qr'),
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
                const Icon(Icons.qr_code_2_rounded, size: 140, color: Colors.white24),
                Container(
                  width: 210,
                  height: 2,
                  color: AppTheme.sageGreen,
                ),
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
            child: const Row(
              children: [
                Icon(Icons.ev_station_rounded, color: AppTheme.sageGreen, size: 32),
                SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Шангри-Ла Молл Цэнэглэгч',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Загуур #1 (CCS2 Fast 180kW) • ₮450/кВт.ц',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text(
            AppStrings.get('select_deposit'),
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
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
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
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
                const Icon(Icons.qr_code_2_rounded, color: AppTheme.sageGreen, size: 24),
                const SizedBox(width: 10),
                Text(
                  AppStrings.get('qpay'),
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                const Icon(Icons.check_circle_rounded, color: AppTheme.sageGreen, size: 20),
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
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.bolt_rounded, size: 22),
              label: Text(
                _isProcessing ? 'УНШИЖ БАЙНА...' : '₮${_depositAmountMnt.toInt()} ТӨЛӨӨД ЦЭНЭГЛЭХ',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
