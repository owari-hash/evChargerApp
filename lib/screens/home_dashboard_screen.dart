import 'package:flutter/material.dart';
import '../models/ocpp_models.dart';
import '../services/ocpp_mock_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import '../widgets/charge_limit_selector.dart';
import '../widgets/charging_power_ring_gauge.dart';
import '../widgets/charging_session_receipt_sheet.dart';
import '../widgets/swipe_to_slide_button.dart';
import '../widgets/vehicle_charging_matrix.dart';

class HomeDashboardScreen extends StatefulWidget {
  final VoidCallback onNavigateToQuickControls;

  const HomeDashboardScreen({
    super.key,
    required this.onNavigateToQuickControls,
  });

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  final OcppMockService _service = OcppMockService.instance;

  void _handleStartChargingSession() async {
    await _service.startSessionFromQrCode('EV-UB-SHANGRILA', 25000.0);
    if (mounted) setState(() {});
  }

  void _handleStopChargingSession() async {
    final double energy = _service.totalEnergyKwh;
    final double power = _service.activePowerKw;
    final double cost = energy * 450.0;
    final String station = _service.activeStationName ?? 'Шангри-Ла Молл Цэнэглэгч';

    await _service.stopUserChargingSession();

    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => ChargingSessionReceiptSheet(
          stationName: station,
          totalEnergyKwh: energy,
          activePowerKw: power,
          totalCostMnt: cost,
        ),
      );
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: _service.telemetryStream,
      builder: (context, snapshot) {
        final bool isCharging = _service.connectorStatuses[1] == ConnectorStatus.charging;

        return Scaffold(
          backgroundColor: AppTheme.softBg,
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Spec Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSpecChip(AppStrings.get('power'), '${_service.activePowerKw.toInt()} кВт'),
                    _buildSpecChip(AppStrings.get('vmax'), '190 км/ц'),
                    _buildSpecChip(AppStrings.get('range'), '${_service.remainingKm.toInt()} км'),
                  ],
                ),
                const SizedBox(height: 18),

                // Hero View: Hero Car Banner with Particle Matrix FX during Charging
                VehicleChargingMatrix(
                  isCharging: isCharging,
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: AppTheme.darkForest,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Image.asset(
                              'assets/images/bmw_x5.jpg',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: AppTheme.darkForest,
                                child: const Icon(Icons.directions_car_rounded, size: 80, color: AppTheme.sageGreen),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 16,
                            left: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isCharging ? Icons.bolt_rounded : Icons.electric_car_rounded,
                                    color: AppTheme.sageGreen,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isCharging ? 'SUPERCHARGING ACTIVE • 180 кВт' : 'BMW X5 xDrive50e • ₮0/кВт.ц',
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Active Supercharging vs Setup State
                if (isCharging) ...[
                  // Animated Glowing Power Ring Gauge
                  ChargingPowerRingGauge(
                    batteryLevel: _service.batteryLevel,
                    activePowerKw: _service.activePowerKw,
                    totalEnergyKwh: _service.totalEnergyKwh,
                    targetLimitPct: _service.targetLimitPct,
                  ),
                  const SizedBox(height: 16),

                  // Stop Charging Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _handleStopChargingSession,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.stop_circle_rounded, size: 22),
                      label: const Text(
                        'ЦЭНЭГЛЭЛТИЙГ ЗОГСООХ',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ),
                  ),
                ] else ...[
                  // Pre-charging Charge Limit & Estimation Selector
                  ChargeLimitSelector(
                    targetLimitPct: _service.targetLimitPct,
                    onLimitChanged: (val) {
                      setState(() => _service.targetLimitPct = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Swipe to Start Action Slider (Dribbble Seamless EV Flow)
                  SwipeToSlideButton(
                    onSwipeCompleted: _handleStartChargingSession,
                    text: 'Цэнэглэж эхлэхийн тулд гулсуулна уу',
                  ),
                ],
                const SizedBox(height: 22),

                // Quick Action Controls Row
                Row(
                  children: [
                    _buildQuickActionBtn(
                      icon: _service.isPlugLocked ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
                      label: _service.isPlugLocked ? AppStrings.get('locked') : AppStrings.get('unlocked'),
                      isActive: _service.isPlugLocked,
                      onTap: () => setState(() => _service.toggleLock()),
                    ),
                    const SizedBox(width: 10),
                    _buildQuickActionBtn(
                      icon: Icons.tune_rounded,
                      label: AppStrings.get('control'),
                      isActive: false,
                      onTap: widget.onNavigateToQuickControls,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetricCard(
                        title: AppStrings.get('battery'),
                        value: '${_service.batteryLevel.toStringAsFixed(0)}%',
                        subtitle: isCharging ? AppStrings.get('charging') : AppStrings.get('idle'),
                        icon: Icons.battery_charging_full_rounded,
                        accentColor: AppTheme.sageGreen,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSpecChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.darkForest)),
        ],
      ),
    );
  }

  Widget _buildQuickActionBtn({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.darkForest : AppTheme.cardWhite,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: Column(
          children: [
            Icon(icon, color: isActive ? Colors.white : AppTheme.darkForest, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.white : AppTheme.darkForest,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        children: [
          Icon(icon, color: accentColor, size: 24),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
              Text(
                value,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.darkForest),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
