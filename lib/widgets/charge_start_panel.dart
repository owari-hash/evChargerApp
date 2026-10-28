import 'package:flutter/material.dart';

import '../models/charging_session.dart';
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
import 'ebarimt_choice_sheet.dart';
import 'idle_nudge.dart';

const Set<String> _knownConnectorStatuses = <String>{
  'Available',
  'Preparing',
  'Charging',
  'SuspendedEV',
  'SuspendedEVSE',
  'Finishing',
  'Reserved',
  'Unavailable',
  'Faulted',
};

/// What a driver reads for one gun's live state — the kiosk's wording, so a
/// gun reads the same in the app and on the website.
String connectorStatusLabel(StationConnector connector, {bool online = true}) {
  if (!online) return AppStrings.get('connector_offline');
  // Someone scanned this gun and is about to start: the station still reports
  // it free, but it is not. Same rule as the kiosk.
  if (connector.inUseByOther &&
      (connector.isAvailable || connector.status == 'Preparing')) {
    return AppStrings.get('cstatus_inUseByOther');
  }
  if (_knownConnectorStatuses.contains(connector.status)) {
    return AppStrings.get('cstatus_${connector.status}');
  }
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
    this.onScanQr,
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

  /// Optional QR scan callback: if provided, the CTA button prompts to scan QR to charge.
  final VoidCallback? onScanQr;

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

  /// The idle hint is showing: light up the next step in the step bar too.
  bool _nudging = false;

  /// Every failure is reported as a toast, the same as on the web.
  void _fail(String message) {
    if (mounted) AppToast.show(context, message, kind: ToastKind.error);
  }

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

    // Same step as the kiosk: confirm the start and pick personal or company
    // e-Barimt. Internal users charge free, so they have nothing to receipt.
    EbarimtChoice? ebarimt;
    if (!_isInternal) {
      ebarimt = await EbarimtChoiceSheet.show(context);
      if (ebarimt == null || !mounted) return;
    }

    // No "is it plugged in?" guess from the gun's status here, as on the
    // website: after a stop with the cable still in, a charger can report
    // `Available`, and refusing on that blocked a restart the website let
    // through. The charger itself decides, and its answer is shown below.

    setState(() => _starting = true);
    try {
      await _stations.startCharging(
        widget.stationId,
        connectorId: _selected,
        ebarimt: ebarimt,
      );
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
      // Only a refusal about the cable is put as "check the plug"; every
      // other 409 (a charge still closing, the gun taken) says what it is.
      final String msg =
          (err.message.contains('хүлээж аваагүй') ||
              err.message.contains('залгасан'))
          ? AppStrings.get('plug_not_detected')
          : err.message;
      _fail(msg);
    }
  }

  bool get _isInternal =>
      widget.authService?.currentUser.value?.isInternal == true ||
      AuthService.instance.currentUser.value?.isInternal == true;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool isInternal = _isInternal;
    final bool signedIn =
        (widget.authService ?? AuthService.instance).isSignedIn;
    // From the map the driver still has to scan the gun (step 2); after a
    // scan they are on "plug in" (step 3) with Charge as step 4.
    final bool scanMode = widget.onScanQr != null;
    final int currentStep = scanMode ? 1 : 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ChargeStepBar(
          current: currentStep,
          signedIn: signedIn,
          pointTo: _nudging ? currentStep + 1 : null,
        ),
        const SizedBox(height: 12),
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
        const SizedBox(height: 16),
        IdleNudge(
          message: AppStrings.get(scanMode ? 'nudge_scan' : 'nudge_charge'),
          enabled: widget.stationOnline && !_starting,
          onChanged: (bool on) {
            if (mounted) setState(() => _nudging = on);
          },
          child: SizedBox(
          height: 54,
          child: widget.onScanQr != null
              ? ElevatedButton.icon(
                  key: const ValueKey<String>('charge-qr-button'),
                  onPressed: widget.stationOnline ? widget.onScanQr : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.sageGreen,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 22),
                  label: Text(
                    AppStrings.get('scan_to_charge'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              : ElevatedButton.icon(
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
                    AppStrings.get(
                      _starting ? 'starting' : 'start_charging_cta',
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
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

/// The kiosk's four steps — sign in, pick a gun, plug in, charge — so a
/// driver sees the whole path. [pointTo] bounces the next step when they have
/// been idle.
class ChargeStepBar extends StatefulWidget {
  const ChargeStepBar({
    super.key,
    required this.current,
    required this.signedIn,
    this.pointTo,
  });

  final int current;
  final bool signedIn;
  final int? pointTo;

  @override
  State<ChargeStepBar> createState() => _ChargeStepBarState();
}

class _ChargeStepBarState extends State<ChargeStepBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant ChargeStepBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pointTo != widget.pointTo) _sync();
  }

  /// Animates only while pointing, so idle screens settle in tests.
  void _sync() {
    if (widget.pointTo != null) {
      _bounce.repeat(reverse: true);
    } else {
      _bounce
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    const List<String> keys = <String>[
      'step_signin',
      'step_connector',
      'step_plug',
      'step_charge',
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List<Widget>.generate(keys.length, (int i) {
        // Sign-in is asked when Charge is pressed, so it is only "done" once
        // the driver is actually signed in.
        final bool done = i == 0 ? widget.signedIn : i < widget.current;
        final bool current = !done && i == widget.current;
        final bool pointed = !done && i == widget.pointTo;
        final Color fill = done || current
            ? AppTheme.sageGreen
            : pointed
            ? AppTheme.sageGreen.withValues(alpha: 0.18)
            : palette.bg;
        final Color text = done || current
            ? Colors.white
            : pointed
            ? AppTheme.sageGreen
            : palette.inkMuted;

        Widget circle = Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(
              color: done || current || pointed
                  ? AppTheme.sageGreen
                  : palette.border,
              width: pointed || current ? 2.5 : 1,
            ),
          ),
          child: Text(
            done ? '✓' : '${i + 1}',
            style: TextStyle(
              color: text,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        );
        if (pointed) {
          circle = AnimatedBuilder(
            animation: _bounce,
            builder: (BuildContext context, Widget? child) =>
                Transform.translate(
                  offset: Offset(0, -5 * _bounce.value),
                  child: child,
                ),
            child: circle,
          );
        }

        return Expanded(
          child: Column(
            children: <Widget>[
              circle,
              const SizedBox(height: 6),
              Text(
                AppStrings.get(keys[i]),
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.15,
                  fontWeight: current || pointed
                      ? FontWeight.w800
                      : FontWeight.w500,
                  color: current || pointed
                      ? AppTheme.sageGreen
                      : (done ? palette.ink : palette.inkMuted),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

/// One gun: name, plug type and power, live status, picked or not.
class ConnectorOptionTile extends StatelessWidget {
  const ConnectorOptionTile({
    super.key,
    required this.connector,
    this.online = true,
    this.selected = false,
    this.onTap,
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
                      if (chargeProgressLabel(connector) != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            chargeProgressLabel(connector)!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: palette.accent,
                            ),
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
