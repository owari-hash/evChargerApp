import 'dart:async';

import 'package:flutter/material.dart';
import '../models/auth_user.dart';
import '../models/charging_session.dart';
import '../models/wallet.dart';
import '../models/ocpp_models.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/ocpp_mock_service.dart';
import '../services/sessions_service.dart';
import '../services/vehicle_photo_service.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import '../widgets/account_widgets.dart';
import '../widgets/signed_out_panel.dart';
import '../widgets/charging_session_receipt_sheet.dart';
import '../widgets/swipe_to_slide_button.dart';
import '../widgets/vehicle_charging_matrix.dart';
import '../widgets/vehicle_hero_card.dart';
import 'sessions_screen.dart';
import 'wallet_screen.dart';

class HomeDashboardScreen extends StatefulWidget {
  final VoidCallback onNavigateToQuickControls;

  const HomeDashboardScreen({
    super.key,
    required this.onNavigateToQuickControls,
    this.onFindCharger,
    this.onAddVehicle,
    this.authService,
    this.sessionsService,
    this.walletService,
    this.photoService,
  });

  /// Opens the station map, where a real charger is picked to start on.
  final VoidCallback? onFindCharger;

  /// Opens the account page, where the driver saves their car.
  final VoidCallback? onAddVehicle;

  /// Injectable so tests can drive the screen without the real session.
  final AuthService? authService;
  final SessionsService? sessionsService;
  final WalletService? walletService;
  final VehiclePhotoService? photoService;

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  final OcppMockService _service = OcppMockService.instance;

  AuthService get _auth => widget.authService ?? AuthService.instance;
  SessionsService get _sessions =>
      widget.sessionsService ?? SessionsService.instance;
  WalletService get _walletService =>
      widget.walletService ?? WalletService.instance;

  /// The transaction id of a real session, when the API reports one running.
  /// Null means anything on screen is local demo state.
  int? _remoteTransactionId;

  /// When the real session now charging actually started, for the hero label.
  DateTime? _sessionStart;

  /// Re-reads the running session so energy, power, charge and cost follow
  /// the charge point's own meter rather than a local estimate.
  Timer? _liveRefresh;

  /// The driver's finished sessions, newest first, as the API returned them.
  List<ChargingSession> _history = const <ChargingSession>[];
  bool _historyLoaded = false;

  /// The last history read failed, so "no charges yet" would be a lie.
  bool _historyFailed = false;

  /// Null until loaded, or when the wallet is unavailable.
  WalletSnapshot? _wallet;

  /// A real photo of the saved model, and which car it was looked up for.
  VehiclePhoto? _photo;
  String? _photoFor;

  @override
  void initState() {
    super.initState();
    _auth.currentUser.addListener(_onUserChanged);
    _syncWithDriverApi();
    _loadWallet();
    _loadPhoto();
  }

  /// Looks up a photo of the saved model once per car, not on every rebuild.
  Future<void> _loadPhoto() async {
    final AuthUser? user = _auth.currentUser.value;
    final String key = VehiclePhotoService.searchQuery(
      user?.vehicleBrand,
      user?.vehicleModel,
    );
    if (key == _photoFor) return;
    _photoFor = key;
    if (key.isEmpty) {
      if (_photo != null) setState(() => _photo = null);
      return;
    }
    final VehiclePhoto? photo =
        await (widget.photoService ?? VehiclePhotoService.instance).photoFor(
          user?.vehicleBrand,
          user?.vehicleModel,
        );
    // The driver may have changed cars while this was in flight.
    if (!mounted || _photoFor != key) return;
    setState(() => _photo = photo);
  }

  Future<void> _loadWallet() async {
    if (!_auth.isSignedIn) return;
    try {
      final WalletSnapshot snapshot = await _walletService.load(entryLimit: 1);
      if (mounted) setState(() => _wallet = snapshot);
    } on ApiException {
      // The tile says the balance is unavailable rather than showing ₮0.
    }
  }

  @override
  void dispose() {
    _auth.currentUser.removeListener(_onUserChanged);
    _liveRefresh?.cancel();
    super.dispose();
  }

  /// Saving a car on the account page updates the hero straight away.
  void _onUserChanged() {
    if (!mounted) return;
    setState(() {});
    _loadPhoto();
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
      final List<ChargingSession> sessions = await _sessions.list(limit: 50);
      ChargingSession? active;
      for (final ChargingSession session in sessions) {
        if (session.isActive) {
          active = session;
          break;
        }
      }

      if (!mounted) return;
      setState(() {
        _history = sessions
            .where((ChargingSession s) => s.status == SessionStatus.completed)
            .toList(growable: false);
        _historyLoaded = true;
        _historyFailed = false;
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
        _historyLoaded = true;
        _historyFailed = true;
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
        await _walletService.load(),
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
          onSignedIn: () {
            _syncWithDriverApi();
            _loadWallet();
          },
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
                  child: _buildVehicleHero(isCharging),
                ),
                const SizedBox(height: 20),

                // Active Supercharging vs Setup State
                if (isCharging) ...[
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
                _buildSummaryRow(),
                const SizedBox(height: 22),
                _buildRecentSessions(),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The driver's own car, drawn to match the model they saved, with real
  /// facts underneath: the live session while charging, the last one when not.
  Widget _buildVehicleHero(bool isCharging) {
    final AuthUser? user = _auth.currentUser.value;
    final List<HeroFact> facts = <HeroFact>[];

    ChargeStatus? charge;
    if (isCharging) {
      // Only what the charge point reports: the car's own charge if it sent
      // one, and the meter's power, energy and bill.
      charge = ChargeStatus(
        socPercent: _service.batteryLevel,
        powerKw: _service.activePowerKw,
        energyKwh: _service.totalEnergyKwh,
        costMnt: _service.sessionCostMnt,
        detail: [
          if (_service.activeStationName != null) _service.activeStationName!,
          if (_sessionStart != null)
            AppStrings.get(
              'charging_since',
            ).replaceFirst('{time}', _formatClock(_sessionStart!)),
        ].join(' · '),
      );
    } else if (_history.isNotEmpty) {
      final ChargingSession last = _history.first;
      facts.add(
        HeroFact(
          icon: Icons.history_rounded,
          label: AppStrings.get('hero_last_charge'),
          value: _ago(last.stopTimestamp ?? last.startTimestamp),
        ),
      );
      facts.add(
        HeroFact(
          icon: Icons.battery_charging_full_rounded,
          label: AppStrings.get('hero_energy'),
          value: '${last.energyKwh.toStringAsFixed(1)} кВт·ц',
        ),
      );
      facts.add(
        HeroFact(
          icon: Icons.ev_station_rounded,
          label: AppStrings.get('hero_station'),
          value: last.displayLocation,
        ),
      );
    }

    return VehicleHeroCard(
      brand: user?.vehicleBrand?.trim() ?? '',
      model: user?.vehicleModel?.trim() ?? '',
      isCharging: isCharging,
      statusLabel: isCharging
          ? '${AppStrings.get('charging')} · ${_service.activePowerKw.toStringAsFixed(0)} кВт'
          : AppStrings.get('idle'),
      facts: facts,
      charge: charge,
      onAddVehicle: widget.onAddVehicle,
      photo: _photo,
    );
  }

  /// "5 мин өмнө", "3 өдрийн өмнө", or the date once it is over a month ago.
  String _ago(DateTime? at) {
    if (at == null) return '—';
    final Duration d = DateTime.now().difference(at.toLocal());
    if (d.inMinutes < 1) return AppStrings.get('ago_now');
    if (d.inHours < 1) {
      return AppStrings.get('ago_min').replaceFirst('{n}', '${d.inMinutes}');
    }
    if (d.inDays < 1) {
      return AppStrings.get('ago_hour').replaceFirst('{n}', '${d.inHours}');
    }
    if (d.inDays < 30) {
      return AppStrings.get('ago_day').replaceFirst('{n}', '${d.inDays}');
    }
    return _formatDate(at);
  }

  String _formatDate(DateTime at) {
    final DateTime l = at.toLocal();
    return '${l.year}.${l.month.toString().padLeft(2, '0')}.${l.day.toString().padLeft(2, '0')}';
  }

  void _open(Widget screen) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (BuildContext context) => screen));
  }

  /// Wallet balance and this month's charging, side by side.
  Widget _buildSummaryRow() {
    final DateTime now = DateTime.now();
    final List<ChargingSession> month = _history
        .where((ChargingSession s) {
          final DateTime? at = (s.stopTimestamp ?? s.startTimestamp)?.toLocal();
          return at != null && at.year == now.year && at.month == now.month;
        })
        .toList(growable: false);
    final double kwh = month.fold<double>(
      0,
      (double sum, ChargingSession s) => sum + s.energyKwh.toDouble(),
    );
    final num? spent = month.any((ChargingSession s) => s.cost != null)
        ? month.fold<num>(
            0,
            (num sum, ChargingSession s) => sum + (s.cost ?? 0),
          )
        : null;

    final num? balance = _wallet?.wallet.balance;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: _buildSummaryTile(
              icon: Icons.account_balance_wallet_rounded,
              title: AppStrings.get('wallet_balance'),
              value: balance == null ? '—' : formatMnt(balance),
              footer: AppStrings.get('topup_title'),
              footerIcon: Icons.add_rounded,
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => const WalletScreen(),
                  ),
                );
                _loadWallet();
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildSummaryTile(
              icon: Icons.calendar_month_rounded,
              title: AppStrings.get('home_month_title'),
              value: _historyLoaded && !_historyFailed
                  ? '${kwh.toStringAsFixed(1)} кВт·ц'
                  : '—',
              footer: _historyFailed
                  ? AppStrings.get('home_unavailable')
                  : _historyLoaded
                  ? [
                      AppStrings.get(
                        'home_month_sessions',
                      ).replaceFirst('{n}', '${month.length}'),
                      if (spent != null) formatMnt(spent),
                    ].join(' · ')
                  : AppStrings.get('loading'),
              onTap: () => _open(const SessionsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTile({
    required IconData icon,
    required String title,
    required String value,
    required String footer,
    IconData? footerIcon,
    required VoidCallback onTap,
  }) {
    final AppPalette palette = context.palette;
    return Material(
      color: palette.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: palette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: palette.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 16, color: palette.accent),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: palette.inkMuted,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: palette.inkMuted,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: palette.ink,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: <Widget>[
                  if (footerIcon != null) ...<Widget>[
                    Icon(footerIcon, size: 13, color: palette.accent),
                    const SizedBox(width: 2),
                  ],
                  Expanded(
                    child: Text(
                      footer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: footerIcon != null
                            ? palette.accent
                            : palette.inkMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The last three finished charges, straight from the driver API.
  Widget _buildRecentSessions() {
    final AppPalette palette = context.palette;
    final List<ChargingSession> recent = _history
        .take(3)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                AppStrings.get('home_recent_title'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: palette.ink,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            if (recent.isNotEmpty)
              TextButton(
                onPressed: () => _open(const SessionsScreen()),
                style: TextButton.styleFrom(
                  foregroundColor: palette.accent,
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(
                  AppStrings.get('home_see_all'),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: palette.border),
          ),
          child: !_historyLoaded
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                  ),
                )
              : recent.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 22,
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: palette.accent.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.ev_station_rounded,
                          color: palette.accent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              AppStrings.get(
                                _historyFailed
                                    ? 'home_unavailable'
                                    : 'home_no_sessions_title',
                              ),
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: palette.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppStrings.get(
                                _historyFailed
                                    ? 'home_unavailable_body'
                                    : 'home_no_sessions_body',
                              ),
                              style: TextStyle(
                                fontSize: 12,
                                color: palette.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: <Widget>[
                    for (int i = 0; i < recent.length; i++) ...<Widget>[
                      if (i > 0)
                        Divider(height: 1, indent: 64, color: palette.border),
                      _buildSessionRow(recent[i]),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildSessionRow(ChargingSession session) {
    final AppPalette palette = context.palette;
    return InkWell(
      onTap: () => _open(const SessionsScreen()),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.bolt_rounded, color: palette.accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    session.displayLocation,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: palette.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _ago(session.stopTimestamp ?? session.startTimestamp),
                    style: TextStyle(fontSize: 11.5, color: palette.inkMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  '${session.energyKwh.toStringAsFixed(1)} кВт·ц',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: palette.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  session.cost == null ? '—' : formatMnt(session.cost!),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: palette.inkMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
