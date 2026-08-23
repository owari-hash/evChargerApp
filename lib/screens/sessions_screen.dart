import 'package:flutter/material.dart';

import '../models/charging_session.dart';
import '../models/wallet.dart' show formatMnt;
import '../services/api_client.dart';
import '../services/sessions_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import '../widgets/account_widgets.dart';

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
      final List<ChargingSession> list = await _sessions.list();
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
      if (!mounted) return;
      setState(() => _stopping = null);

      // "Accepted" means the charge point took the request, not that charging
      // has already stopped — say so rather than implying it is done.
      showSnack(
        context,
        status.toLowerCase() == 'accepted'
            ? AppStrings.get('sess_stop_accepted')
            : AppStrings.get(
                'sess_stop_replied',
              ).replaceFirst('{status}', status),
      );
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _stopping = null);
      showApiSnack(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final List<ChargingSession>? list = _list;

    return Scaffold(
      backgroundColor: palette.bg,
      appBar: AppBar(
        title: Text(AppStrings.get('sess_title')),
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

    final List<ChargingSession>? list = _list;
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
        padding: const EdgeInsets.fromLTRB(18, 40, 18, 40),
        children: <Widget>[
          Icon(
            Icons.receipt_long_rounded,
            size: 40,
            color: palette.inkMuted.withValues(alpha: 0.55),
          ),
          const SizedBox(height: 16),
          Text(
            AppStrings.get('sess_empty'),
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

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
      itemCount: list.length,
      separatorBuilder: (BuildContext context, int _) =>
          const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) =>
          _sessionCard(palette, list[index]),
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
                      ).replaceFirst('{id}', '${session.connectorId}'),
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
