import 'package:flutter/material.dart';

import '../models/station.dart';
import '../screens/wallet_screen.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/sessions_service.dart';
import '../services/stations_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import 'account_widgets.dart';
import 'auth_gate.dart';

/// What a driver reads for one gun's live state.
String connectorStatusLabel(StationConnector connector, {bool online = true}) {
  if (!online) return AppStrings.get('connector_offline');
  if (connector.isAvailable) return AppStrings.get('available');
  if (connector.status == 'Preparing') return AppStrings.get('connector_plugged');
  if (connector.isCharging) return AppStrings.get('charging');
  if (connector.isFaulted) return AppStrings.get('connector_faulted');
  return AppStrings.get('connector_busy');
}

/// Green free, amber in use, red broken, grey when the station is dark —
/// the same tones as the map pins.
Color connectorStatusTone(StationConnector connector, {bool online = true}) {
  if (!online) return StationAvailability.offline.tone;
  if (connector.isStartable) return StationAvailability.available.tone;
  if (connector.isFaulted) return AppTheme.errorRed;
  return StationAvailability.busy.tone;
}

/// Picks a gun and starts a charge on it — the one start flow in the app.
///
/// The QR scanner (after resolving a sticker) and the map's station sheet
/// both end here, so the sign-in gate, the empty-wallet dialog and the
/// station's own Accepted/Rejected answer are handled the same way in both.
///
/// [onStarted] runs only once the charge point has *accepted* the start; the
/// host closes itself and confirms. Any other answer stays on this panel with
/// the reason shown, so the driver can pick another gun or try again.
class ChargeStartPanel extends StatefulWidget {
  const ChargeStartPanel({
    super.key,
    required this.stationId,
    required this.connectors,
    required this.onStarted,
    this.initialConnectorId,
    this.stationOnline = true,
    this.footer,
    this.stationsService,
    this.sessionsService,
    this.authService,
  });

  final String stationId;

  /// Every gun on the station with its live status. Empty when the station's
  /// guns are not known — the station then picks a free one itself.
  final List<StationConnector> connectors;

  /// The gun to preselect, e.g. the one whose QR sticker was scanned.
  final int? initialConnectorId;

  final bool stationOnline;

  /// Called after an `Accepted` start.
  final VoidCallback onStarted;

  /// Shown under the start button (the scanner's «Дахин уншуулах»).
  final Widget? footer;

  /// Injectable for tests.
  final StationsService? stationsService;
  final SessionsService? sessionsService;
  final AuthService? authService;

  @override
  State<ChargeStartPanel> createState() => _ChargeStartPanelState();
}

class _ChargeStartPanelState extends State<ChargeStartPanel> {
  StationsService get _stations =>
      widget.stationsService ?? StationsService.instance;
  SessionsService get _sessions =>
      widget.sessionsService ?? SessionsService.instance;

  int? _selected;
  bool _starting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected = _defaultSelection();
  }

  @override
  void didUpdateWidget(covariant ChargeStartPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A live refresh can take the chosen gun away; fall back rather than
    // starting on one that is now busy.
    if (!_canPick(_selected)) _selected = _defaultSelection();
  }

  bool _canPick(int? connectorId) {
    if (connectorId == null) return widget.connectors.isEmpty;
    for (final StationConnector c in widget.connectors) {
      if (c.connectorId == connectorId) return c.isStartable;
    }
    return false;
  }

  int? _defaultSelection() {
    final int? wanted = widget.initialConnectorId;
    if (widget.connectors.isEmpty) return wanted;
    if (wanted != null && _canPick(wanted)) return wanted;
    for (final StationConnector c in widget.connectors) {
      if (c.isStartable) return c.connectorId;
    }
    return null;
  }

  bool get _canStart =>
      widget.stationOnline &&
      !_starting &&
      (widget.connectors.isEmpty || _canPick(_selected));

  Future<void> _start() async {
    // Starting a charge is the account-based half of the app, so this is
    // where an account is finally asked for. Signing in returns here and the
    // charge goes ahead — the driver taps once, not twice.
    final bool signedIn = await AuthGate.require(
      context,
      reason: AppStrings.get('signin_required_charge'),
      authService: widget.authService,
    );
    if (!signedIn || !mounted) return;

    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      await _stations.startCharging(widget.stationId, connectorId: _selected);
      _sessions.notifySessionStarted();
      if (!mounted) return;
      setState(() => _starting = false);
      widget.onStarted();
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() => _starting = false);
      if (err.statusCode == 402) {
        final NavigatorState navigator = Navigator.of(context);
        await showStartBlockedDialog(
          context,
          message: err.message,
          onTopUp: () {
            navigator.pop();
            navigator.push(
              MaterialPageRoute<void>(builder: (_) => const WalletScreen()),
            );
          },
        );
        return;
      }
      setState(() => _error = err.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool isInternal =
        widget.authService?.currentUser.value?.isInternal == true ||
        AuthService.instance.currentUser.value?.isInternal == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (isInternal) ...<Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppTheme.sageGreen.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.sageGreen.withValues(alpha: 0.4),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_rounded,
                  size: 16,
                  color: AppTheme.sageGreen,
                ),
                SizedBox(width: 6),
                Text(
                  'Дотоод хэрэглэгч · Үнэ төлбөргүй',
                  style: TextStyle(
                    color: AppTheme.sageGreen,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
        Text(
          AppStrings.get('pick_connector'),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: palette.ink,
          ),
        ),
        const SizedBox(height: 8),
        if (widget.connectors.isEmpty)
          Text(
            AppStrings.get('connector_any'),
            style: TextStyle(fontSize: 13, color: palette.inkMuted),
          )
        else
          for (final StationConnector c in widget.connectors)
            _ConnectorOption(
              connector: c,
              online: widget.stationOnline,
              selected: c.connectorId == _selected,
              onTap: widget.stationOnline && c.isStartable && !_starting
                  ? () => setState(() {
                      _selected = c.connectorId;
                      _error = null;
                    })
                  : null,
            ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Icon(
                Icons.error_outline_rounded,
                size: 18,
                color: AppTheme.warningOrange,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _error!,
                  key: const ValueKey<String>('charge-start-error'),
                  style: const TextStyle(
                    color: AppTheme.warningOrange,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          height: 54,
          child: ElevatedButton.icon(
            key: const ValueKey<String>('charge-start-button'),
            onPressed: _canStart ? _start : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.sageGreen,
              foregroundColor: Colors.white,
            ),
            icon: _starting
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
              AppStrings.get(_starting ? 'starting' : 'start_charging_cta'),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        if (!widget.stationOnline) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            AppStrings.get('station_offline_hint'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: palette.inkMuted),
          ),
        ],
        if (widget.footer != null) widget.footer!,
      ],
    );
  }
}

/// One gun: name, plug type and power, live status, picked or not.
class _ConnectorOption extends StatelessWidget {
  const _ConnectorOption({
    required this.connector,
    required this.online,
    required this.selected,
    required this.onTap,
  });

  final StationConnector connector;
  final bool online;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final Color tone = connectorStatusTone(connector, online: online);
    final bool enabled = onTap != null;
    final String spec = <String>[
      if (connector.type != null) connector.type!,
      if (connector.powerKw != null && connector.powerKw! > 0)
        '${connector.powerKw!.toStringAsFixed(0)} ${AppStrings.get('unit_kw')}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? palette.accent.withValues(alpha: 0.10) : palette.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: ValueKey<String>('connector-${connector.connectorId}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? palette.accent : palette.border,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 20,
                  color: enabled
                      ? (selected ? palette.accent : palette.inkMuted)
                      : palette.border,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        connector.displayName(
                          AppStrings.get('connector_label'),
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: enabled ? palette.ink : palette.inkMuted,
                        ),
                      ),
                      if (spec.isNotEmpty)
                        Text(
                          spec,
                          style: TextStyle(
                            fontSize: 12,
                            color: palette.inkMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: tone,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        connectorStatusLabel(connector, online: online),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: palette.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
