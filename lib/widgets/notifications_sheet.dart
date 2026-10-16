import 'dart:async';

import 'package:flutter/material.dart';

import '../services/notifications_store.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import 'charge_notifications.dart';

/// The bell's dropdown-equivalent: every wallet change, announcement and
/// charge start or finish the driver has already seen once, newest first.
///
/// [onOpen] is called, after the sheet closes, for a tapped entry that has
/// somewhere to go — a charge opens the dashboard or the history.
void showNotificationsSheet(
  BuildContext context, {
  void Function(AppNotification item)? onOpen,
}) {
  unawaited(NotificationsStore.instance.markAllRead());
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => NotificationsSheet(onOpen: onOpen),
  );
}

/// Whether tapping [item] in the list leads anywhere. An announcement opens
/// in full: the list cuts its body at two lines.
bool notificationOpens(AppNotification item) =>
    item.kind == NotificationKind.chargeStarted ||
    item.kind == NotificationKind.chargeStopped ||
    item.kind == NotificationKind.announcement;

/// When [at] happened, as a driver reads it: "Өнөөдөр 14:05",
/// "Өчигдөр 09:12", or the date for anything older.
String notificationTime(DateTime at, {DateTime? now}) {
  final DateTime local = at.toLocal();
  final DateTime today = DateUtils.dateOnly(now ?? DateTime.now());
  final DateTime day = DateUtils.dateOnly(local);
  String two(int v) => v.toString().padLeft(2, '0');
  final String clock = '${two(local.hour)}:${two(local.minute)}';
  if (day == today) return '${AppStrings.get('notif_today')} $clock';
  if (day == today.subtract(const Duration(days: 1))) {
    return '${AppStrings.get('notif_yesterday')} $clock';
  }
  return '${local.year}.${two(local.month)}.${two(local.day)} $clock';
}

class NotificationsSheet extends StatelessWidget {
  const NotificationsSheet({super.key, this.onOpen});

  final void Function(AppNotification item)? onOpen;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        // Follows the theme: light card in light mode, dark in dark mode.
        color: palette.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      AppStrings.get('notifications_label'),
                      style: TextStyle(color: palette.ink, fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: palette.ink),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<List<AppNotification>>(
                valueListenable: NotificationsStore.instance.items,
                builder: (context, items, _) {
                  if (items.isEmpty) {
                    return Center(
                      child: Text(
                        AppStrings.get('notifications_empty'),
                        style: TextStyle(color: palette.inkMuted, fontSize: 13),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => Divider(color: palette.border, height: 1),
                    itemBuilder: (context, i) {
                      final AppNotification item = items[i];
                      final bool opens = onOpen != null && notificationOpens(item);
                      final IconData? icon = notificationIcon(item.kind);
                      final Widget row = Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.imageUrl != null)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  item.imageUrl!,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => _Dot(item: item, palette: palette),
                                ),
                              )
                            else if (icon != null)
                              _KindIcon(item: item, icon: icon, palette: palette)
                            else
                              _Dot(item: item, palette: palette),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: TextStyle(
                                      color: palette.ink,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.body,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: palette.inkMuted, fontSize: 12.5),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    notificationTime(item.at),
                                    style: TextStyle(
                                      color: palette.inkMuted.withValues(alpha: 0.75),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (opens)
                              Padding(
                                padding: const EdgeInsets.only(left: 8, top: 2),
                                child: Icon(Icons.chevron_right_rounded, color: palette.inkMuted, size: 20),
                              ),
                          ],
                        ),
                      );
                      if (!opens) return row;
                      return InkWell(
                        onTap: () {
                          Navigator.of(context).pop();
                          onOpen!(item);
                        },
                        child: row,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.item, required this.palette});

  final AppNotification item;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: item.kind == NotificationKind.announcement ? palette.accent : palette.inkMuted,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// A charge's bolt or tick, in a tinted disc where the other kinds have a dot.
class _KindIcon extends StatelessWidget {
  const _KindIcon({required this.item, required this.icon, required this.palette});

  final AppNotification item;
  final IconData icon;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    // A charge in progress gets the solid brand disc; a finished one the
    // quieter outline, so the two read apart at a glance.
    final bool started = item.kind == NotificationKind.chargeStarted;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: started ? palette.accent : palette.ink.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: started ? Colors.white : palette.ink, size: 18),
    );
  }
}
