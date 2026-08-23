import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/ocpp_models.dart';
import '../services/ocpp_mock_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';

/// Session activity, in plain language.
///
/// The underlying data is the OCPP frame log. Customers see readable events;
/// the raw JSON-RPC frame is one tap away for anyone who needs it.
class OcppJsonLoggerSheet extends StatefulWidget {
  const OcppJsonLoggerSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => const OcppJsonLoggerSheet(),
    );
  }

  @override
  State<OcppJsonLoggerSheet> createState() => _OcppJsonLoggerSheetState();
}

/// Plain-language label and icon for an OCPP action.
({String key, IconData icon}) _describe(String? action) {
  switch (action) {
    case 'Authorize':
      return (key: 'act_authorize', icon: Icons.verified_user_rounded);
    case 'StartTransaction':
      return (key: 'act_start', icon: Icons.play_circle_fill_rounded);
    case 'StopTransaction':
      return (key: 'act_stop', icon: Icons.check_circle_rounded);
    case 'MeterValues':
      return (key: 'act_meter', icon: Icons.speed_rounded);
    case 'StatusNotification':
      return (key: 'act_status', icon: Icons.info_rounded);
    case 'Heartbeat':
      return (key: 'act_heartbeat', icon: Icons.favorite_rounded);
    case 'BootNotification':
      return (key: 'act_boot', icon: Icons.power_rounded);
    case 'RemoteStartTransaction':
      return (key: 'act_remote_start', icon: Icons.wifi_tethering_rounded);
    case 'RemoteStopTransaction':
      return (key: 'act_remote_stop', icon: Icons.stop_circle_rounded);
    case 'ReserveNow':
      return (key: 'act_reserve', icon: Icons.event_available_rounded);
    default:
      return (key: 'act_other', icon: Icons.bolt_rounded);
  }
}

String _clock(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

class _OcppJsonLoggerSheetState extends State<OcppJsonLoggerSheet> {
  final OcppMockService _service = OcppMockService.instance;
  final Set<String> _expanded = <String>{};

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: <Widget>[
          _buildHandle(palette),
          _buildHeader(palette),
          Expanded(
            child: StreamBuilder<List<OcppFrame>>(
              stream: _service.logStream,
              initialData: _service.logs,
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<List<OcppFrame>> snapshot,
                  ) {
                    // Requests carry the meaning; results would double every row.
                    final List<OcppFrame> events =
                        (snapshot.data ?? <OcppFrame>[])
                            .where(
                              (OcppFrame f) =>
                                  f.messageTypeId == OcppMessageType.call,
                            )
                            .toList();

                    if (events.isEmpty) {
                      return Center(
                        child: Text(
                          AppStrings.get('activity_empty'),
                          style: TextStyle(
                            color: palette.inkMuted,
                            fontSize: 14,
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: events.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (BuildContext context, int index) =>
                          _buildEventTile(palette, events[index]),
                    );
                  },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle(AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: palette.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppStrings.get('activity_title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppStrings.get('activity_subtitle'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: palette.inkMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: AppStrings.get('clear_history'),
            icon: Icon(Icons.delete_outline_rounded, color: palette.inkMuted),
            onPressed: () {
              _service.clearLogs();
              setState(() => _expanded.clear());
            },
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close_rounded, color: palette.ink),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildEventTile(AppPalette palette, OcppFrame frame) {
    final ({String key, IconData icon}) info = _describe(frame.action);
    final bool open = _expanded.contains(frame.messageId);
    final String raw = const JsonEncoder.withIndent(
      '  ',
    ).convert(frame.payload);

    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: <Widget>[
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 4,
            ),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(info.icon, color: palette.accent, size: 20),
            ),
            title: Text(
              AppStrings.get(info.key),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.ink,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              _clock(frame.timestamp),
              style: TextStyle(color: palette.inkMuted, fontSize: 12),
            ),
            trailing: Icon(
              open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              color: palette.inkMuted,
            ),
            onTap: () => setState(() {
              if (!_expanded.remove(frame.messageId)) {
                _expanded.add(frame.messageId);
              }
            }),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '${AppStrings.get('activity_details')} · ${frame.action ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.inkMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Copy',
                        icon: Icon(
                          Icons.copy_rounded,
                          size: 16,
                          color: palette.inkMuted,
                        ),
                        onPressed: () =>
                            Clipboard.setData(ClipboardData(text: raw)),
                      ),
                    ],
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: palette.panel,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        raw,
                        style: TextStyle(
                          color: palette.onPanel.withValues(alpha: 0.85),
                          fontFamily: 'Menlo',
                          fontFamilyFallback: const <String>['monospace'],
                          fontSize: 11,
                          height: 1.45,
                        ),
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
}
