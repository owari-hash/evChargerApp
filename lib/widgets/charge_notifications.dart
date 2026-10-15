import 'package:flutter/material.dart';

import '../models/charging_session.dart';
import '../services/notifications_store.dart';
import '../services/session_watcher_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import '../utils/money.dart';

/// Title and body for a charge starting or finishing, in the current
/// language — the same text goes in the pop-up and in the bell's history.
({String title, String body}) chargeNotificationText(SessionEvent event) {
  final ChargingSession session = event.session;
  final String station = session.displayLocation;

  if (event.type == SessionEventType.started) {
    final DateTime at = (session.startTimestamp ?? DateTime.now()).toLocal();
    final String time =
        '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    return (
      title: AppStrings.get('notif_charge_started_title'),
      body: AppStrings.get('notif_charge_started_body')
          .replaceFirst('{station}', station)
          .replaceFirst('{time}', time),
    );
  }

  final List<String> details = <String>[
    if (session.energyKwh > 0)
      '${session.energyKwh.toStringAsFixed(2)} ${AppStrings.get('unit_kwh')}',
    if (session.cost != null) formatMnt(session.cost!),
  ];
  return (
    title: AppStrings.get('notif_charge_stopped_title'),
    body: details.isEmpty
        ? station
        : AppStrings.get('notif_charge_stopped_body')
              .replaceFirst('{station}', station)
              .replaceFirst('{details}', details.join(' · ')),
  );
}

NotificationKind chargeNotificationKind(SessionEvent event) =>
    event.type == SessionEventType.started
    ? NotificationKind.chargeStarted
    : NotificationKind.chargeStopped;

/// The bell's icon for each kind; null keeps the plain dot.
IconData? notificationIcon(NotificationKind kind) {
  switch (kind) {
    case NotificationKind.chargeStarted:
      return Icons.bolt_rounded;
    case NotificationKind.chargeStopped:
      return Icons.check_circle_rounded;
    case NotificationKind.wallet:
    case NotificationKind.announcement:
      return null;
  }
}

/// The pop-up: a SnackBar like the wallet watcher's, with the bolt or the
/// tick in front and a «Харах» that opens the charge.
SnackBar chargeSnackBar(
  BuildContext context,
  SessionEvent event, {
  required VoidCallback onView,
}) {
  final AppPalette palette = context.palette;
  final ({String title, String body}) text = chargeNotificationText(event);
  final bool started = event.type == SessionEventType.started;
  final Color foreground = started ? Colors.white : palette.onPanel;
  // The SnackBar theme's text style carries only a colour; start from the
  // app's own body style so the title and details are in Geist.
  final TextStyle base = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();

  return SnackBar(
    backgroundColor: started ? AppTheme.sageGreen : null,
    duration: const Duration(seconds: 5),
    content: Row(
      children: <Widget>[
        Icon(
          started ? Icons.bolt_rounded : Icons.check_circle_rounded,
          color: started ? Colors.white : AppTheme.sageGreen,
          size: 22,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                text.title,
                style: base.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                text.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: base.copyWith(
                  color: foreground.withValues(alpha: 0.85),
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    action: SnackBarAction(
      label: AppStrings.get('notif_view'),
      textColor: started ? Colors.white : AppTheme.sageGreen,
      onPressed: onView,
    ),
  );
}
