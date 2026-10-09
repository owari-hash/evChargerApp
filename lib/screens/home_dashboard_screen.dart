import 'dart:async';

import 'package:flutter/material.dart';
import '../models/auth_user.dart';
import '../models/charging_session.dart';
import '../models/ocpp_models.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/ocpp_mock_service.dart';
import '../services/sessions_service.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import '../widgets/account_widgets.dart';
import '../widgets/signed_out_panel.dart';
import '../widgets/charging_power_ring_gauge.dart';
import '../widgets/charging_session_receipt_sheet.dart';
import '../widgets/swipe_to_slide_button.dart';
import '../widgets/vehicle_charging_matrix.dart';
import '../widgets/vehicle_silhouette.dart';
import 'wallet_screen.dart';

class HomeDashboardScreen extends StatefulWidget {
  final VoidCallback onNavigateToQuickControls;

  const HomeDashboardScreen({
    super.key,
    required this.onNavigateToQuickControls,
    this.onFindCharger,
    this.onAddVehicle,
    this.authService,
  });

  /// Opens the station map, where a real charger is picked to start on.
  final VoidCallback? onFindCharger;

  /// Opens the account page, where the driver saves their car.
  final VoidCallback? onAddVehicle;

  /// Injectable so tests can drive the screen without the real session.
  final AuthService? authService;

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  final OcppMockService _service = OcppMockService.instance;

  AuthService get _auth => widget.authService ?? AuthService.instance;
  final SessionsService _sessions = SessionsService.instance;

  /// The transaction id of a real session, when the API reports one running.
  /// Null means anything on screen is local demo state.
  int? _remoteTransactionId;

  /// When the real session now charging actually started, for the hero label.
  DateTime? _sessionStart;

  /// Re-reads the running session so energy, power, charge and cost follow
  /// the charge point's own meter rather than a local estimate.
  Timer? _liveRefresh;

  @override
  void initState() {
    super.initState();
    _auth.currentUser.addListener(_onUserChanged);
    _syncWithDriverApi();
  }

  @override
  void dispose() {
    _auth.currentUser.removeListener(_onUserChanged);
    _liveRefresh?.cancel();
    super.dispose();
  }

  /// Saving a car on the account page updates the hero straight away.
  void _onUserChanged() {
    if (mounted) setState(() {});
  }

  void _scheduleLiveRefresh() {
    if (_remoteTransactionId == null) {
      _liveRefresh?.cancel();
      _liveRefresh = null;
      return;
    }
    _liveRefresh ??= Timer.periodic(
      const Duration(seconds: 10),
      (_) => _syncWithDriverApi(),
    );
  }

  /// Asks the driver API what is actually charging right now.
  ///
  /// Without this the dashboard showed whatever the local mock service held,
  /// which greeted every driver with a charge in progress they had not started.
  Future<void> _syncWithDriverApi() async {
    if (!_auth.isSignedIn) return;
    try {
      final List<ChargingSession> sessions = await _sessions.list(limit: 20);
      ChargingSession? active;
      for (final ChargingSession session in sessions) {
        if (session.isActive) {
          active = session;
          break;
        }
      }

      if (!mounted) return;
      setState(() {
        if (active == null) {
          _remoteTransactionId = null;
          _sessionStart = null;
          _service.clearRemoteSession();
          return;
        }
        _remoteTransactionId = active.transactionId;
        _sessionStart = active.startTimestamp;
        _service.adoptRemoteSession(
          transactionId: active.transactionId,
          stationName: active.displayLocation,
          energyKwh: active.energyKwh.toDouble(),
          powerKw: (active.lastPowerW ?? 0) / 1000.0,
          socPercent: active.lastSocPercent?.toDouble(),
          costMnt: active.cost?.toDouble(),
        );
      });
      _scheduleLiveRefresh();
    } on ApiException {
      // Offline, or the session list is unavailable. Showing nothing is right;
      // inventing a charge is not.
      if (!mounted) return;
      setState(() {
        _remoteTransactionId = null;
        _sessionStart = null;
        _service.clearRemoteSession();
      });
      _scheduleLiveRefresh();
    }
  }

  /// Returns whether a charge went ahead, so the slider can spring back when
  /// it did not.
  ///
  /// A charge is started on a particular charger, so once the wallet can pay
  /// for one this hands over to the map. It used to start a pretend session
  /// on a hard-coded station with a made-up ₮25,000 deposit.
  Future<bool> _handleStartChargingSession() async {
    // A prepaid network has nothing to bill the session to on an empty
    // wallet, so this is checked before the swipe does anything rather than
    // letting the driver find out at the station.
    try {
      final String? reason = WalletService.startBlockReason(
        await WalletService.instance.load(),
      );
      if (reason != null) {
        if (!mounted) return false;
        await showStartBlockedDialog(
          context,
          message: reason,
          onTopUp: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => const WalletScreen(),
            ),
          ),
        );
        return false;
      }
    } on ApiException {
      // Offline, or the wallet is unavailable. The station's own OCPP
      // authorize is the real gate, so a charge is not blocked on this.
    }

    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.get('pick_charger_hint'))),
    );
    widget.onFindCharger?.call();
    return false;
  }

  /// The driver's own car, as they named it in their account — never invented.
  String get _vehicleLabel =>
      _auth.currentUser.value?.vehicleDisplayName ??
      AppStrings.get('vehicle_not_set');

  String _formatClock(DateTime time) {
    final DateTime local = time.toLocal();
    final String hh = local.hour.toString().padLeft(2, '0');
    final String mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  void _handleStopChargingSession() async {
    double energy = _service.totalEnergyKwh;
    final double power = _service.activePowerKw;
    double? cost;
    String station =
        _service.activeStationName ?? AppStrings.get('station_unknown');

    final int? remote = _remoteTransactionId;
    int? finishedTransactionId;
    if (remote != null) {
      try {
        await _sessions.stop(remote);
      } on ApiException catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
        return;
      }
      _remoteTransactionId = null;
      finishedTransactionId = remote;

      // The charge point's own meter is the real number; local telemetry was
      // only ever an estimate while the session was still running.
      try {
        final List<ChargingSession> sessions = await _sessions.list(limit: 5);
        ChargingSession? finished;
        for (final ChargingSession s in sessions) {
          if (s.transactionId == remote) {
            finished = s;
            break;
          }
        }
        if (finished != null) {
          energy = finished.energyKwh.toDouble();
          cost = finished.cost?.toDouble();
          station = finished.displayLocation;
        }
      } on ApiException {
        // The stop already succeeded; a receipt with the locally-tracked
        // estimate beats no receipt at all.
      }
    }

    await _service.stopUserChargingSession();
    _service.clearRemoteSession();
    _scheduleLiveRefresh();

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
          transactionId: finishedTransactionId,
        ),
      );
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // The dashboard is the driver's own car — battery, lock, charge in
    // progress. There is nothing to show a guest, so offer the way in instead.
    if (!_auth.isSignedIn) {
      return Scaffold(
        backgroundColor: context.palette.bg,
        body: SignedOutPanel(
          icon: Icons.electric_car_rounded,
          title: AppStrings.get('guest_vehicle_title'),
          body: AppStrings.get('guest_vehicle_body'),
          reason: AppStrings.get('signin_required_vehicle'),
          onSignedIn: _syncWithDriverApi,
        ),
      );
    }

    return StreamBuilder<Map<String, dynamic>>(
      stream: _service.telemetryStream,
      builder: (context, snapshot) {
        final bool isCharging =
            _service.connectorStatuses[1] == ConnectorStatus.charging;

        return Scaffold(
          backgroundColor: context.palette.bg,
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero View: Hero Car Banner with Particle Matrix FX during Charging
                VehicleChargingMatrix(
                  isCharging: isCharging,
                  child: Container(
                    width: double.infinity,
                    height: 214,
                    decoration: BoxDecoration(
                      color: context.palette.panel,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: context.palette.shadow,
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Stack(
                        children: [
                          Positioned.fill(child: _buildVehicleHero(isCharging)),
                          Positioned(
                            bottom: 16,
                            left: 16,
                            right: 16,
                            // Bounded so a long status line can ellipsize
                            // instead of overflowing the hero card.
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isCharging
                                              ? Icons.bolt_rounded
                                              : Icons.electric_car_rounded,
                                          color: AppTheme.sageGreen,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            isCharging
                                                ? '${AppStrings.get('charging').toUpperCase()} • ${_service.activePowerKw.toInt()} кВт'
                                                : AppStrings.get('idle'),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Who is plugged in where, and since when —
                                    // the detail a shared station needs so the
                                    // driver can tell their own session apart.
                                    if (isCharging) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        [
                                          _vehicleLabel,
                                          if (_service.activeStationName !=
                                              null)
                                            _service.activeStationName!,
                                          if (_sessionStart != null)
                                            AppStrings.get(
                                              'charging_since',
                                            ).replaceFirst(
                                              '{time}',
                                              _formatClock(_sessionStart!),
                                            ),
                                        ].join(' • '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.75,
                                          ),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
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
                    costMnt: _service.sessionCostMnt,
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
                      label: Text(
                        AppStrings.get('stop_charging'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // Swipe to Start Action Slider (Dribbble Seamless EV Flow)
                  SwipeToSlideButton(
                    onSwipeCompleted: _handleStartChargingSession,
                    text: AppStrings.get('slide_to_start'),
                  ),
                ],
                const SizedBox(height: 22),

                // Quick Action Controls Row
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _buildQuickActionBtn(
                          icon: _service.isPlugLocked
                              ? Icons.lock_outline_rounded
                              : Icons.lock_open_rounded,
                          label: _service.isPlugLocked
                              ? AppStrings.get('locked')
                              : AppStrings.get('unlocked'),
                          isActive: _service.isPlugLocked,
                          onTap: () => setState(() => _service.toggleLock()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildQuickActionBtn(
                          icon: Icons.tune_rounded,
                          label: AppStrings.get('control'),
                          isActive: false,
                          onTap: widget.onNavigateToQuickControls,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricCard(
                          title: AppStrings.get('battery'),
                          // Only the car knows its charge, and it only tells
                          // the charger — so there is a number while charging
                          // and an honest dash the rest of the time.
                          value: _service.batteryLevel == null
                              ? '—'
                              : '${_service.batteryLevel!.toStringAsFixed(0)}%',
                          subtitle: isCharging
                              ? AppStrings.get('charging')
                              : AppStrings.get('battery_while_charging'),
                          icon: Icons.battery_charging_full_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The driver's own car: its name as a wordmark over a drawn side profile
  /// shaped like it. Without a saved car, an invitation to add one.
  Widget _buildVehicleHero(bool isCharging) {
    final AuthUser? user = _auth.currentUser.value;
    final String brand = user?.vehicleBrand?.trim() ?? '';
    final String model = user?.vehicleModel?.trim() ?? '';
    final bool hasVehicle = brand.isNotEmpty || model.isNotEmpty;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.0, 0.35),
          radius: 1.1,
          colors: <Color>[
            Color(0xFF1C4A35),
            AppTheme.darkForest,
            Color(0xFF07140D),
          ],
          stops: <double>[0.0, 0.62, 1.0],
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: 16,
            left: 18,
            right: 18,
            child: hasVehicle
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (brand.isNotEmpty)
                        Text(
                          brand.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.lightSage,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.6,
                          ),
                        ),
                      if (model.isNotEmpty)
                        Text(
                          model,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                            height: 1.15,
                          ),
                        ),
                    ],
                  )
                : Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          AppStrings.get('vehicle_add_title'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (widget.onAddVehicle != null)
                        TextButton.icon(
                          onPressed: widget.onAddVehicle,
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.darkForest,
                            backgroundColor: AppTheme.lightSage,
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: Text(
                            AppStrings.get('vehicle_add_cta'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          Positioned(
            left: 20,
            right: 20,
            top: 58,
            bottom: 52,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(end: isCharging ? 1.0 : 0.0),
              duration: const Duration(milliseconds: 600),
              builder: (BuildContext context, double glow, Widget? _) {
                return VehicleSilhouette(
                  style: bodyStyleFor(brand, model),
                  accent: const Color(0xFF34D399),
                  glow: glow,
                  muted: !hasVehicle,
                );
              },
            ),
          ),
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
    final AppPalette palette = context.palette;
    final Color foreground = isActive ? palette.onPanel : palette.ink;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? palette.panel : palette.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: foreground, size: 20),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: foreground,
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
  }) {
    final AppPalette palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: palette.accent, size: 16),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: palette.inkMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: palette.ink,
                letterSpacing: -0.5,
              ),
            ),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: palette.accent,
            ),
          ),
        ],
      ),
    );
  }
}
