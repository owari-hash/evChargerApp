import 'package:flutter/material.dart';
import '../models/station.dart';
import '../models/wallet.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/stations_service.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import '../utils/money.dart';
import '../widgets/signed_out_panel.dart';
import '../widgets/station_sheet.dart';
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
            title: Text(
              AppStrings.get('map_title'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              tooltip: AppStrings.get('back'),
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
                onTap: () => showStationSheet(context, station: station),
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
                          color: station.availability.tone,
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (station.basePricePerKwh > 0)
                            Text(
                              '${formatMntLeading(station.basePricePerKwh)}/${AppStrings.get('unit_kwh')}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: context.palette.ink,
                              ),
                            ),
                        ],
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
}
