import 'dart:async';

import 'package:flutter/material.dart';
import '../models/auth_user.dart';
import '../models/charging_session.dart';
import '../models/wallet.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/active_session_state.dart';
import '../services/session_watcher_service.dart';
import '../services/sessions_service.dart';
import '../services/stations_service.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import '../widgets/account_widgets.dart';
import '../widgets/signed_out_panel.dart';
import '../widgets/charging_session_receipt_sheet.dart';
import '../widgets/glass.dart';
import '../widgets/guided_step.dart';
import '../widgets/vehicle_charging_matrix.dart';
import '../widgets/glass_vehicle_card.dart';
import '../widgets/vehicle_hero_card.dart' show ChargeStatus;
import 'sessions_screen.dart';
import 'wallet_screen.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({
    super.key,
    this.onScanQr,
    this.onFindCharger,
    this.onAddVehicle,
    this.authService,
    this.sessionsService,
    this.walletService,
    this.guide,
  });

  /// The app guide, owned by the app frame. Its first four steps are the
  /// sections of this screen; the frame's bottom bar is the fifth.
  final AppGuideController? guide;

  /// Opens the camera QR scanner, where a charge is actually started.
  final VoidCallback? onScanQr;

  /// Opens the station map.
  final VoidCallback? onFindCharger;

  /// Opens the account page, where the driver saves their car.
  final VoidCallback? onAddVehicle;

  /// Injectable so tests can drive the screen without the real session.
  final AuthService? authService;
  final SessionsService? sessionsService;
  final WalletService? walletService;

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  final ActiveSessionState _session = ActiveSessionState.instance;

  AuthService get _auth => widget.authService ?? AuthService.instance;
  SessionsService get _sessions =>
      widget.sessionsService ?? SessionsService.instance;
  WalletService get _walletService =>
      widget.walletService ?? WalletService.instance;

  /// The transaction id of a real session, when the API reports one running.
  /// Null means nothing is charging.
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

  /// The wallet read has come back, whether or not it worked.
  bool _walletLoaded = false;

  bool _wasSignedIn = false;

  final ScrollController _scroll = ScrollController();

  /// Waits out the pause before the guide's first step.
  Timer? _guideStartTimer;

  /// Starts the guide anyway if the first load never finishes.
  Timer? _guideFallbackTimer;

  /// sukhApp's pause, so the screen has settled before the guide starts.
  static const Duration _guideDelay = Duration(milliseconds: 1400);
  static const Duration _guideReplayDelay = Duration(milliseconds: 350);
  static const Duration _guideLoadCap = Duration(seconds: 6);

  /// The guide points at real numbers, not spinners.
  bool get _firstLoadDone => _historyLoaded && _walletLoaded;

  @override
  void initState() {
    super.initState();
    _wasSignedIn = _auth.isSignedIn;
    _auth.currentUser.addListener(_onUserChanged);
    _sessions.sessionStarted.addListener(_onSessionStartedElsewhere);
    StationsService.instance.stations.addListener(_onStationsChanged);
    widget.guide?.addListener(_onGuideChanged);
    StationsService.instance.load();
    _syncWithDriverApi();
    _loadWallet();
    // The frame can ask for the guide in the same frame that first builds
    // this screen, before it was listening.
    if (widget.guide?.requested == true) _scheduleGuideStart();
  }

  void _onStationsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant HomeDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.guide != widget.guide) {
      oldWidget.guide?.removeListener(_onGuideChanged);
      widget.guide?.addListener(_onGuideChanged);
      _cancelGuideTimers();
      if (widget.guide?.requested == true) _scheduleGuideStart();
    }
  }

  void _onGuideChanged() {
    if (!mounted) return;
    setState(() {});
    if (widget.guide?.requested == true) {
      _scheduleGuideStart();
    } else {
      _cancelGuideTimers();
    }
  }

  void _cancelGuideTimers() {
    _guideStartTimer?.cancel();
    _guideStartTimer = null;
    _guideFallbackTimer?.cancel();
    _guideFallbackTimer = null;
  }

  /// Starts the guide once the first load is in (or has taken too long),
  /// after a short pause. A replay waits less: the data is already there.
  void _scheduleGuideStart() {
    final AppGuideController? guide = widget.guide;
    if (guide == null || !guide.requested || _guideStartTimer != null) return;
    if (_firstLoadDone || guide.isReplay) {
      _armGuideStart();
    } else {
      _guideFallbackTimer ??= Timer(_guideLoadCap, () {
        _guideFallbackTimer = null;
        _armGuideStart();
      });
    }
  }

  void _armGuideStart() {
    final AppGuideController? guide = widget.guide;
    if (guide == null || !guide.requested || _guideStartTimer != null) return;
    _guideFallbackTimer?.cancel();
    _guideFallbackTimer = null;
    _guideStartTimer = Timer(
      guide.isReplay ? _guideReplayDelay : _guideDelay,
      _beginGuide,
    );
  }

  void _beginGuide() {
    _guideStartTimer = null;
    final AppGuideController? guide = widget.guide;
    if (!mounted || guide == null || !guide.requested) return;
    if (!_auth.isSignedIn) {
      guide.cancel();
      return;
    }
    // Never underneath a dialog, the QR scanner sheet or a pushed page: wait
    // for it to close, then start.
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      _guideStartTimer = Timer(const Duration(milliseconds: 500), _beginGuide);
      return;
    }
    if (_scroll.hasClients && _scroll.offset > 0) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
    guide.begin();
  }

  /// A charge was just requested from another screen (the QR scanner). The
  /// charge point does not report the new transaction instantly, so this
  /// polls a few more times over the next moments rather than only once.
  void _onSessionStartedElsewhere() {
    _syncWithDriverApi();
    int attempts = 0;
    Timer.periodic(const Duration(seconds: 4), (Timer timer) {
      attempts++;
      if (!mounted || _remoteTransactionId != null || attempts >= 5) {
        timer.cancel();
        return;
      }
      _syncWithDriverApi();
    });
  }

  Future<void> _loadWallet() async {
    if (!_auth.isSignedIn) return;
    try {
      final WalletSnapshot snapshot = await _walletService.load(entryLimit: 1);
      if (mounted) setState(() => _wallet = snapshot);
    } on ApiException {
      // The tile says the balance is unavailable rather than showing ₮0.
    } finally {
      _walletLoaded = true;
      if (mounted && widget.guide?.requested == true) _scheduleGuideStart();
    }
  }

  @override
  void dispose() {
    _auth.currentUser.removeListener(_onUserChanged);
    _sessions.sessionStarted.removeListener(_onSessionStartedElsewhere);
    StationsService.instance.stations.removeListener(_onStationsChanged);
    widget.guide?.removeListener(_onGuideChanged);
    _cancelGuideTimers();
    _scroll.dispose();
    _liveRefresh?.cancel();
    super.dispose();
  }

  /// Saving a car on the account page updates the hero straight away.
  ///
  /// A sign-in from another tab loads the driver's data here too; it used to
  /// leave the recent-charges card on a spinner until the app restarted.
  void _onUserChanged() {
    if (!mounted) return;
    final bool justSignedIn = _auth.isSignedIn && !_wasSignedIn;
    _wasSignedIn = _auth.isSignedIn;
    setState(() {});
    if (justSignedIn) {
      _syncWithDriverApi();
      _loadWallet();
    }
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
  /// Nothing on the dashboard comes from anywhere else: it once showed a
  /// simulated charge to every driver who signed in.
  Future<void> _syncWithDriverApi() async {
    if (!_auth.isSignedIn) return;
    try {
      final List<ChargingSession> sessions = await _sessions.list(limit: 50);
      // The charge-started/finished pop-ups share this poll rather than
      // waiting up to 15 s for their own.
      SessionWatcherService.instance.ingest(sessions);
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
          _session.clear();
          return;
        }
        _remoteTransactionId = active.transactionId;
        _sessionStart = active.startTimestamp;
        _session.adoptRemoteSession(
          transactionId: active.transactionId,
          stationName: active.displayLocation,
          energyKwh: active.energyKwh.toDouble(),
          powerKw: (active.lastPowerW ?? 0) / 1000.0,
          socPercent: active.lastSocPercent?.toDouble(),
          minutesToFull: active.minutesToFull,
          costMnt: active.cost?.toDouble(),
        );
      });
      _scheduleLiveRefresh();
      if (widget.guide?.requested == true) _scheduleGuideStart();
    } on ApiException {
      // Offline, or the session list is unavailable. Showing nothing is right;
      // inventing a charge is not.
      if (!mounted) return;
      setState(() {
        _historyLoaded = true;
        _historyFailed = true;
        _remoteTransactionId = null;
        _sessionStart = null;
        _session.clear();
      });
      _scheduleLiveRefresh();
      if (widget.guide?.requested == true) _scheduleGuideStart();
    }
  }

  /// «QR уншуулж цэнэглэх»: checks the wallet, then opens the camera.
  ///
  /// A prepaid network has nothing to bill the session to on an empty
  /// wallet, so the driver hears about it here rather than at the station.
  Future<void> _handleScanToCharge() async {
    try {
      final String? reason = WalletService.startBlockReason(
        await _walletService.load(),
      );
      if (reason != null) {
        if (!mounted) return;
        await showStartBlockedDialog(
          context,
          message: reason,
          onTopUp: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => const WalletScreen(),
            ),
          ),
        );
        return;
      }
    } on ApiException {
      // Offline, or the wallet is unavailable. The station's own OCPP
      // authorize is the real gate, so a charge is not blocked on this.
    }
    if (!mounted) return;
    widget.onScanQr?.call();
  }

  String _formatClock(DateTime time) {
    final DateTime local = time.toLocal();
    final String hh = local.hour.toString().padLeft(2, '0');
    final String mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  void _handleStopChargingSession() async {
    double energy = _session.energyKwh;
    double? cost;
    double? energyCost;
    double? feeAmount;
    double? feePercent;
    String station = _session.stationName ?? AppStrings.get('station_unknown');

    final int? remote = _remoteTransactionId;
    int? finishedTransactionId;
    if (remote != null) {
      try {
        await _sessions.stop(remote);
      } on ApiException catch (error) {
        if (!mounted) return;
        showApiSnack(context, error);
        return;
      }
      _remoteTransactionId = null;
      finishedTransactionId = remote;
      // The receipt below is this stop's confirmation; the watcher only
      // files it in the bell.
      SessionWatcherService.instance.noteLocalStop(
        remote,
        confirmedInApp: true,
      );

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
          energyCost = finished.energyCost?.toDouble();
          feeAmount = finished.feeAmount?.toDouble();
          feePercent = finished.feePercent?.toDouble();
          station = finished.displayLocation;
        }
      } on ApiException {
        // The stop already succeeded; a receipt with the locally-tracked
        // estimate beats no receipt at all.
      }
    }

    _session.clear();
    _scheduleLiveRefresh();

    if (mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => ChargingSessionReceiptSheet(
          stationName: station,
          totalEnergyKwh: energy,
          totalCostMnt: cost,
          energyCostMnt: energyCost,
          feeAmountMnt: feeAmount,
          feePercent: feePercent,
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

    // Rebuilt by every sync with the driver API (every 10 s while charging).
    final bool isCharging = _session.isCharging;
    return Scaffold(
      backgroundColor: context.palette.bg,
      body: GlassBackground(
        child: SingleChildScrollView(
          controller: _scroll,
          // The bottom gap lets the last card scroll clear of the assistant
          // button resting in the bottom-right corner.
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 84),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero View: Hero Car Banner with Particle Matrix FX during Charging
              _guided(
                stepIndex: 0,
                key: 'hero',
                icon: Icons.electric_car_rounded,
                borderRadius: 28,
                child: VehicleChargingMatrix(
                  isCharging: isCharging,
                  child: _buildVehicleHero(isCharging),
                ),
              ),
              const SizedBox(height: 20),

              // Start a charge, or stop the one running.
              _guided(
                stepIndex: 1,
                key: 'start',
                icon: Icons.qr_code_scanner_rounded,
                borderRadius: 20,
                child: isCharging
                    // Stop Charging Button
                    ? SizedBox(
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
                      )
                    : _buildStartActions(),
              ),
              const SizedBox(height: 22),
              _guided(
                stepIndex: 2,
                key: 'wallet',
                icon: Icons.account_balance_wallet_rounded,
                borderRadius: 20,
                child: _buildSummaryRow(),
              ),
              const SizedBox(height: 22),
              _guided(
                stepIndex: 3,
                key: 'recent',
                icon: Icons.history_rounded,
                borderRadius: 20,
                tipBelow: false,
                // The heading sits on the bare page, not in a card.
                contentPadding: const EdgeInsets.all(10),
                child: _buildRecentSessions(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// The main way in: scan the charger's QR code. Finding a station is the
  /// quieter second choice.
  Widget _buildStartActions() {
    final AppPalette palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: 56,
          child: ElevatedButton.icon(
            key: const ValueKey<String>('home-scan-qr'),
            onPressed: _handleScanToCharge,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.sageGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 24),
            label: Text(
              AppStrings.get('scan_to_charge'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            key: const ValueKey<String>('home-find-station'),
            onPressed: widget.onFindCharger,
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.ink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: Icon(Icons.map_outlined, size: 20, color: palette.accent),
            label: Text(
              AppStrings.get('find_station'),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  /// One section of the app guide, or the section alone when there is no
  /// guide to show it in (tests that build the screen on its own).
  Widget _guided({
    required int stepIndex,
    required String key,
    required IconData icon,
    required Widget child,
    double borderRadius = 24,
    bool tipBelow = true,
    EdgeInsets contentPadding = EdgeInsets.zero,
  }) {
    final AppGuideController? guide = widget.guide;
    if (guide == null) return child;
    return GuidedStep.of(
      key: ValueKey<String>('guide-step-$key'),
      guide: guide,
      stepIndex: stepIndex,
      tag: AppStrings.get('guide_${key}_tag'),
      title: AppStrings.get('guide_${key}_title'),
      description: AppStrings.get('guide_${key}_body'),
      icon: icon,
      tipBelow: tipBelow,
      borderRadius: borderRadius,
      contentPadding: contentPadding,
      child: child,
    );
  }

  /// The driver's own car as a glass card: whether it is charging, and while
  /// it is, the battery and the live meter readings — nothing else.
  Widget _buildVehicleHero(bool isCharging) {
    final AuthUser? user = _auth.currentUser.value;

    ChargeStatus? charge;
    if (isCharging) {
      // Only what the charge point reports: the car's own charge if it sent
      // one, and the meter's power, energy and bill.
      charge = ChargeStatus(
        socPercent: _session.socPercent,
        minutesToFull: _session.minutesToFull,
        powerKw: _session.powerKw,
        energyKwh: _session.energyKwh,
        costMnt: _session.costMnt,
        detail: [
          if (_session.stationName != null) _session.stationName!,
          if (_sessionStart != null)
            AppStrings.get(
              'charging_since',
            ).replaceFirst('{time}', _formatClock(_sessionStart!)),
        ].join(' · '),
      );
    }

    return GlassVehicleCard(
      brand: user?.vehicleBrand?.trim() ?? '',
      model: user?.vehicleModel?.trim() ?? '',
      isCharging: isCharging,
      statusLabel: AppStrings.get(isCharging ? 'charging' : 'idle'),
      // Only the live charge belongs on the car; history has its own card.
      charge: charge,
      onAddVehicle: widget.onAddVehicle,
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

    final bool isInternal =
        _wallet?.wallet.isInternal == true ||
        _auth.currentUser.value?.isInternal == true;
    final num? balance = _wallet?.wallet.balance;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: _buildWalletCard(
              isInternal: isInternal,
              balance: balance,
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
          const SizedBox(width: 12),
          Expanded(
            child: _buildMonthCard(
              kwh: kwh,
              monthSessionsCount: month.length,
              spent: spent,
              onTap: () => _open(const SessionsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletCard({
    required bool isInternal,
    required num? balance,
    required VoidCallback onTap,
  }) {
    final AppPalette palette = context.palette;

    return GlassCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          palette.accent.withValues(alpha: 0.22),
                          palette.accent.withValues(alpha: 0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 17,
                      color: palette.accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppStrings.get('wallet_balance'),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: palette.inkMuted,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: palette.inkMuted.withValues(alpha: 0.7),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              isInternal
                  ? 'Үнэ төлбөргүй'
                  : (balance == null ? '—' : formatMnt(balance)),
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
                color: palette.ink,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: isInternal
                  ? AppTheme.sageGreen.withValues(alpha: 0.14)
                  : palette.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isInternal
                    ? AppTheme.sageGreen.withValues(alpha: 0.3)
                    : palette.accent.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  isInternal ? Icons.verified_rounded : Icons.add_rounded,
                  size: 14,
                  color: isInternal ? AppTheme.sageGreen : palette.accent,
                ),
                const SizedBox(width: 4),
                Text(
                  isInternal
                      ? 'Дотоод хэрэглэгч'
                      : AppStrings.get('topup_title'),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: isInternal
                        ? AppTheme.sageGreen
                        : palette.accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthCard({
    required double kwh,
    required int monthSessionsCount,
    required num? spent,
    required VoidCallback onTap,
  }) {
    final AppPalette palette = context.palette;
    final bool isDark = ThemeController.isDark;

    return GlassCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.teal.withValues(alpha: 0.22),
                          Colors.teal.withValues(alpha: 0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      size: 17,
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppStrings.get('home_month_title'),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: palette.inkMuted,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: palette.inkMuted.withValues(alpha: 0.7),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _historyLoaded && !_historyFailed
                  ? '${kwh.toStringAsFixed(1)} кВт·ц'
                  : '—',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
                color: palette.ink,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : palette.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : palette.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.bolt_rounded,
                  size: 14,
                  color: palette.accent,
                ),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    _historyFailed
                        ? AppStrings.get('home_unavailable')
                        : _historyLoaded
                        ? [
                            AppStrings.get(
                              'home_month_sessions',
                            ).replaceFirst('{n}', '$monthSessionsCount'),
                            if (spent != null) formatMnt(spent),
                          ].join(' · ')
                        : AppStrings.get('loading'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: palette.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
        GlassCard(
          padding: EdgeInsets.zero,
          borderRadius: 20,
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
