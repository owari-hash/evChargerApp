import 'package:flutter/material.dart';

import '../models/charging_session.dart';
import '../models/station.dart' show connectorLetter;
import '../models/wallet.dart' show formatMnt;
import '../services/api_client.dart';
import '../services/session_watcher_service.dart';
import '../services/sessions_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import '../widgets/account_widgets.dart';
import '../widgets/ebarimt_sheet.dart';
import '../widgets/wallet_filter_sheet.dart';

/// Charging history, and the way to stop a session that is still running —
/// the app's counterpart to `/account/sessions` in the kiosk.
class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key, this.sessionsService});

  final SessionsService? sessionsService;

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  SessionsService get _sessions =>
      widget.sessionsService ?? SessionsService.instance;

  List<ChargingSession>? _list;
  String? _loadError;
  bool _loading = true;
  int? _stopping;

  /// Date filter from the same sheet as the wallet's, without its type row.
  WalletFilter _filter = WalletFilter.none;

  Future<void> _openFilter() async {
    final WalletFilter? picked = await showWalletFilterSheet(
      context,
      _filter,
      showFlow: false,
    );
    if (picked != null && mounted) setState(() => _filter = picked);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      // The API's maximum, so a 30- or 90-day filter has the history to show.
      final List<ChargingSession> list = await _sessions.list(limit: 200);
      SessionWatcherService.instance.ingest(list);
      if (!mounted) return;
      setState(() {
        _list = list;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = error.message;
      });
    }
  }

  Future<void> _stop(ChargingSession session) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(AppStrings.get('sess_stop_confirm')),
        content: Text(session.displayLocation),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppStrings.get('sess_keep')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
            child: Text(AppStrings.get('sess_stop_yes')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _stopping = session.transactionId);
    try {
      final String status = await _sessions.stop(session.transactionId);
      // This screen only says the charger took the request, so the
      // watcher's «Цэнэглэлт дууслаа» still pops up once it has stopped.
      SessionWatcherService.instance.noteLocalStop(session.transactionId);
      if (!mounted) return;
      setState(() => _stopping = null);

      // "Accepted" means the charge point took the request, not that charging
      // has already stopped — say so rather than implying it is done.
      showSnack(
        context,
        // Anything else is the charger's raw OCPP word, which tells a
        // driver nothing; say plainly that it did not stop.
        AppStrings.get(
          status.toLowerCase() == 'accepted'
              ? 'sess_stop_accepted'
              : 'sess_stop_refused',
        ),
      );
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _stopping = null);
      showApiSnack(context, error);
    }
  }

  Future<void> _openEbarimt(ChargingSession session) async {
    await EbarimtSheet.show(context, session);
    // The sheet mutates its own copy; re-reading the list is the simplest way
    // to pick up a receipt it just created without threading state back out.
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final List<ChargingSession>? all = _list;
    final List<ChargingSession>? list = all
        ?.where((ChargingSession s) => _filter.includesDate(s.startTimestamp))
        .toList();

    return Scaffold(
      backgroundColor: palette.bg,
      appBar: AppBar(
        title: Text(AppStrings.get('sess_title')),
        actions: <Widget>[
          if (all != null && all.isNotEmpty)
            IconButton(
              tooltip: AppStrings.get('wallet_filter'),
              onPressed: _openFilter,
              icon: Badge(
                isLabelVisible: _filter.hasDate,
                label: const Text('1'),
                backgroundColor: palette.accent,
                child: const Icon(Icons.tune_rounded),
              ),
            ),
          const SizedBox(width: 4),
        ],
        bottom: list == null || list.isEmpty
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(22),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Text(
                      AppStrings.get(
                        'sess_count',
                      ).replaceFirst('{count}', '${list.length}'),
                      style: TextStyle(
                        color: palette.inkMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
      ),
      body: RefreshIndicator(onRefresh: _load, child: _body(palette)),
    );
  }

  Widget _body(AppPalette palette) {
    if (_loading && _list == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final List<ChargingSession>? list = _list
        ?.where((ChargingSession s) => _filter.includesDate(s.startTimestamp))
        .toList();
    if (list == null) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 40),
        children: <Widget>[
          ErrorNotice(
            message: _loadError ?? AppStrings.get('sess_unavailable'),
            onRetry: _load,
          ),
        ],
      );
    }

    if (list.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
        children: <Widget>[
          if (_filter.hasDate) ...<Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: _filterPill(palette),
            ),
            const SizedBox(height: 24),
          ] else
            const SizedBox(height: 24),
          Icon(
            Icons.receipt_long_rounded,
            size: 40,
            color: palette.inkMuted.withValues(alpha: 0.55),
          ),
          const SizedBox(height: 16),
          Text(
            AppStrings.get(
              _filter.hasDate ? 'sess_filter_empty' : 'sess_empty',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.inkMuted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      );
    }

    final bool pill = _filter.hasDate;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
      itemCount: list.length + (pill ? 1 : 0),
      separatorBuilder: (BuildContext context, int _) =>
          const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        if (pill && index == 0) {
          return Align(
            alignment: Alignment.centerLeft,
            child: _filterPill(palette),
          );
        }
        return _sessionCard(palette, list[index - (pill ? 1 : 0)]);
      },
    );
  }

  /// The active date range, with an ✕ to clear it.
  Widget _filterPill(AppPalette palette) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
      decoration: BoxDecoration(
        color: palette.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.calendar_today_rounded, size: 13, color: palette.accent),
          const SizedBox(width: 6),
          Text(
            _filter.dateLabel,
            style: TextStyle(
              color: palette.accent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 2),
          InkWell(
            customBorder: const CircleBorder(),
            onTap: () => setState(() => _filter = WalletFilter.none),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close_rounded, size: 14, color: palette.accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sessionCard(AppPalette palette, ChargingSession session) {
    final bool active = session.isActive;
    final bool busy = _stopping == session.transactionId;

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      session.displayLocation,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      AppStrings.get(
                        'sess_connector',
                      ).replaceFirst('{id}', connectorLetter(session.connectorId)),
                      style: TextStyle(color: palette.inkMuted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _statusChip(palette, session),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: LabelledValue(
                  label: AppStrings.get('sess_energy'),
                  value: '${session.energyKwh.toStringAsFixed(2)} кВт·ц',
                  emphasis: true,
                ),
              ),
              Expanded(
                child: LabelledValue(
                  label: AppStrings.get('sess_duration'),
                  value: _formatDuration(session.duration),
                ),
              ),
              Expanded(
                child: LabelledValue(
                  label: AppStrings.get('sess_cost'),
                  value: session.cost == null ? '—' : formatMnt(session.cost!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${AppStrings.get('sess_started')}: ${_formatMoment(session.startTimestamp)}',
            style: TextStyle(color: palette.inkMuted, fontSize: 11.5),
          ),
          if (active) ...<Widget>[
            const SizedBox(height: 14),
            SizedBox(
              height: 42,
              child: OutlinedButton.icon(
                onPressed: busy ? null : () => _stop(session),
                icon: busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.stop_circle_outlined, size: 18),
                label: Text(
                  busy
                      ? AppStrings.get('sess_stopping')
                      : AppStrings.get('sess_stop'),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.errorRed,
                  side: BorderSide(
                    color: AppTheme.errorRed.withValues(alpha: 0.5),
                    width: 1.4,
                  ),
                ),
              ),
            ),
          ],
          if (session.status == SessionStatus.completed) ...<Widget>[
            const SizedBox(height: 14),
            SizedBox(
              height: 42,
              child: OutlinedButton.icon(
                onPressed: () => _openEbarimt(session),
                icon: Icon(
                  session.ebarimt?.status == EBarimtStatus.success
                      ? Icons.check_circle_outline_rounded
                      : Icons.receipt_long_outlined,
                  size: 18,
                ),
                label: Text(
                  session.ebarimt?.status == EBarimtStatus.success
                      ? AppStrings.get('sess_ebarimt_view')
                      : AppStrings.get('sess_ebarimt_get'),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.accent,
                  side: BorderSide(
                    color: palette.accent.withValues(alpha: 0.5),
                    width: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusChip(AppPalette palette, ChargingSession session) {
    final (String label, Color tone) = switch (session.status) {
      SessionStatus.active => (
        AppStrings.get('sess_in_progress'),
        palette.accent,
      ),
      SessionStatus.rejected => (
        AppStrings.get('sess_rejected'),
        AppTheme.errorRed,
      ),
      SessionStatus.completed => (
        AppStrings.get('sess_completed'),
        palette.inkMuted,
      ),
      SessionStatus.refunded => (
        AppStrings.get('sess_refunded'),
        const Color(0xFFB7791F),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tone.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: tone,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _formatDuration(Duration? span) {
    if (span == null) return '—';
    final int hours = span.inHours;
    final int minutes = span.inMinutes.remainder(60);
    if (hours > 0) return '$hoursц $minutesм';
    return '$minutesм';
  }

  String _formatMoment(DateTime? at) {
    if (at == null) return '—';
    final DateTime local = at.toLocal();
    return '${local.year}-${_two(local.month)}-${_two(local.day)} '
        '${_two(local.hour)}:${_two(local.minute)}';
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}
