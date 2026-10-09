import 'package:flutter/material.dart';
import '../models/station.dart';
import '../models/wallet.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/stations_service.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import '../widgets/ocpp_json_logger_sheet.dart';
import '../widgets/signed_out_panel.dart';
import 'mongolia_map_screen.dart';
import 'wallet_screen.dart';

/// Wallet balance and the nearby network, one tap from the dashboard.
///
/// This used to be a car's cockpit — climate, media, tyre pressure — none of
/// which the app has ever been connected to anything to read. What the app
/// actually knows is the wallet and the charging network, so that is what is
/// here now.
class QuickControlsScreen extends StatefulWidget {
  const QuickControlsScreen({super.key, this.authService});

  /// Injectable so tests can drive the screen without the real session.
  final AuthService? authService;

  @override
  State<QuickControlsScreen> createState() => _QuickControlsScreenState();
}

class _QuickControlsScreenState extends State<QuickControlsScreen> {
  AuthService get _auth => widget.authService ?? AuthService.instance;
  final StationsService _stations = StationsService.instance;

  WalletSnapshot? _wallet;
  bool _walletLoading = true;
  String? _walletError;

  @override
  void initState() {
    super.initState();
    _stations.stations.addListener(_onStationsChanged);
    _stations.load();
    _loadWallet();
  }

  @override
  void dispose() {
    _stations.stations.removeListener(_onStationsChanged);
    super.dispose();
  }

  void _onStationsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadWallet() async {
    setState(() {
      _walletLoading = true;
      _walletError = null;
    });
    try {
      final WalletSnapshot snapshot = await WalletService.instance.load(
        entryLimit: 1,
      );
      if (!mounted) return;
      setState(() {
        _wallet = snapshot;
        _walletLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _walletError = error.message;
        _walletLoading = false;
      });
    }
  }

  void _openInteractiveMap(BuildContext context) {
    // A pushed route rather than a modal sheet: sheets strip the top padding
    // (MediaQuery.removePadding), which slid the header and its back button
    // under the status bar where they could not be tapped.
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext pageContext) => Scaffold(
          backgroundColor: pageContext.palette.bg,
          appBar: AppBar(
            titleSpacing: 0,
            title: const Text(
              'Цэнэглэх станцын зураг',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              tooltip: 'Буцах',
              onPressed: () => Navigator.of(pageContext).pop(),
            ),
          ),
          body: MongoliaMapScreen(
            onOpenQrScanner: () => Navigator.of(pageContext).pop(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Both the wallet and the network are account-scoped reads here, so a
    // guest has nothing on this screen to look at.
    if (!_auth.isSignedIn) {
      return Scaffold(
        backgroundColor: context.palette.bg,
        body: SignedOutPanel(
          icon: Icons.tune_rounded,
          title: AppStrings.get('guest_controls_title'),
          body: AppStrings.get('guest_controls_body'),
          reason: AppStrings.get('signin_required_controls'),
          onSignedIn: () {
            _loadWallet();
            setState(() {});
          },
        ),
      );
    }

    final List<ChargingStationLocation> nearby = _stations.stations.value
        .take(3)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: context.palette.bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          AppStrings.get('quick_controls'),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: context.palette.ink,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.notes_rounded,
              color: context.palette.ink,
              size: 28,
            ),
            tooltip: AppStrings.get('ocpp_log'),
            onPressed: () => OcppJsonLoggerSheet.show(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait(<Future<void>>[
            _stations.load(force: true),
            _loadWallet(),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          children: [
            _buildWalletCard(context),
            const SizedBox(height: 16),
            _buildNearbyStationsCard(context, nearby),
            const SizedBox(height: 16),
            _buildMapCard(context),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletCard(BuildContext context) {
    final num? balance = _wallet?.wallet.balance;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.palette.panel,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.get('wallet_balance'),
                  style: TextStyle(
                    fontSize: 12,
                    color: context.palette.onPanel.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 4),
                if (_walletLoading)
                  SizedBox(
                    height: 26,
                    width: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: context.palette.onPanel,
                    ),
                  )
                else if (_walletError != null)
                  Text(
                    AppStrings.get('wallet_unavailable'),
                    style: TextStyle(
                      fontSize: 13,
                      color: context.palette.onPanel.withValues(alpha: 0.85),
                    ),
                  )
                else
                  Text(
                    formatMnt(balance ?? 0),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: context.palette.onPanel,
                    ),
                  ),
              ],
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.palette.onPanel,
              foregroundColor: context.palette.panel,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const WalletScreen()),
            ),
            child: Text(AppStrings.get('topup_title')),
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyStationsCard(
    BuildContext context,
    List<ChargingStationLocation> nearby,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
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
                child: Text(
                  AppStrings.get('nearby_stations'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: context.palette.ink,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _openInteractiveMap(context),
                child: Text(AppStrings.get('map')),
              ),
            ],
          ),
          if (_stations.loading.value && nearby.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
            )
          else if (nearby.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                _stations.error.value ?? AppStrings.get('route_unavailable'),
                style: TextStyle(fontSize: 12, color: context.palette.inkMuted),
              ),
            )
          else
            ...nearby.map(
              (ChargingStationLocation station) => InkWell(
                onTap: () => _openInteractiveMap(context),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: station.availableConnectors > 0
                              ? AppTheme.sageGreen
                              : context.palette.inkMuted,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              station.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: context.palette.ink,
                              ),
                            ),
                            Text(
                              station.distance.isNotEmpty
                                  ? '${station.distance} · ${station.availableConnectors}/${station.totalConnectors} ${AppStrings.get('available')}'
                                  : '${station.availableConnectors}/${station.totalConnectors} ${AppStrings.get('available')}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: context.palette.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '₮${station.pricePerKwh.toInt()}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: context.palette.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMapCard(BuildContext context) {
    return InkWell(
      onTap: () => _openInteractiveMap(context),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.palette.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.palette.border),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Text(
                  AppStrings.get('location'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.palette.ink,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.open_in_full_rounded,
                    color: context.palette.ink,
                    size: 20,
                  ),
                  onPressed: () => _openInteractiveMap(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                height: 152,
                decoration: BoxDecoration(
                  color: context.palette.accent.withValues(alpha: 0.09),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(
                      painter: _MapPreviewPainter(
                        routeColor: context.palette.accent,
                        gridColor: context.palette.accent.withValues(
                          alpha: 0.22,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: context.palette.card.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: context.palette.border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.map_rounded,
                              color: context.palette.accent,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                AppStrings.get('map_title'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: context.palette.ink,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: context.palette.inkMuted,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small map-like preview: faint street grid and a route. Decorative only —
/// it opens the real map on tap, it does not claim to be the driver's actual
/// location.
class _MapPreviewPainter extends CustomPainter {
  _MapPreviewPainter({required this.routeColor, required this.gridColor});

  final Color routeColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (final double f in <double>[0.22, 0.55, 0.82]) {
      canvas.drawLine(
        Offset(0, size.height * f),
        Offset(size.width, size.height * f),
        grid,
      );
    }
    for (final double f in <double>[0.18, 0.46, 0.74]) {
      canvas.drawLine(
        Offset(size.width * f, 0),
        Offset(size.width * f, size.height),
        grid,
      );
    }

    final Paint avenue = Paint()
      ..color = gridColor
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(0, size.height * 0.68),
      Offset(size.width, size.height * 0.52),
      avenue,
    );

    final Path route = Path()
      ..moveTo(size.width * 0.14, size.height * 0.82)
      ..cubicTo(
        size.width * 0.34,
        size.height * 0.74,
        size.width * 0.38,
        size.height * 0.40,
        size.width * 0.60,
        size.height * 0.38,
      )
      ..cubicTo(
        size.width * 0.74,
        size.height * 0.36,
        size.width * 0.76,
        size.height * 0.24,
        size.width * 0.86,
        size.height * 0.22,
      );
    canvas.drawPath(
      route,
      Paint()
        ..color = routeColor
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    final Offset origin = Offset(size.width * 0.14, size.height * 0.82);
    canvas.drawCircle(origin, 4.5, Paint()..color = routeColor);
    canvas.drawCircle(
      origin,
      4.5,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );

    final Offset pin = Offset(size.width * 0.86, size.height * 0.22);
    canvas.drawCircle(
      pin,
      13,
      Paint()..color = routeColor.withValues(alpha: 0.18),
    );
    canvas.drawCircle(pin, 6.5, Paint()..color = routeColor);
    canvas.drawCircle(pin, 2.4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _MapPreviewPainter oldDelegate) =>
      oldDelegate.routeColor != routeColor ||
      oldDelegate.gridColor != gridColor;
}
