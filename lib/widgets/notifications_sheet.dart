import 'dart:async';
import 'dart:ui' show ImageFilter;

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
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.32),
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
    final bool isDark = ThemeController.isDark;
    final BorderRadius radius = const BorderRadius.vertical(top: Radius.circular(28));

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.72,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? <Color>[
                      const Color(0xFF1C2A38).withValues(alpha: 0.80),
                      const Color(0xFF0F1722).withValues(alpha: 0.92),
                    ]
                  : <Color>[
                      Colors.white.withValues(alpha: 0.88),
                      Colors.white.withValues(alpha: 0.80),
                    ],
            ),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: palette.inkMuted.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppStrings.get('notifications_label'),
                          style: TextStyle(
                            color: palette.ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: IconButton.styleFrom(
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : const Color(0xFF0D1F17).withValues(alpha: 0.05),
                          shape: const CircleBorder(),
                        ),
                        icon: Icon(Icons.close_rounded, color: palette.ink, size: 20),
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
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: palette.accent.withValues(alpha: 0.10),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.notifications_none_rounded,
                                  color: palette.accent,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                AppStrings.get('notifications_empty'),
                                style: TextStyle(color: palette.inkMuted, fontSize: 13),
                              ),
                            ],
                          ),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 4),
                        itemBuilder: (context, i) {
                          final AppNotification item = items[i];
                          final bool opens = onOpen != null && notificationOpens(item);
                          final IconData? icon = notificationIcon(item.kind);
                          final Widget row = Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (item.imageUrl != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
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
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.1,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        item.body,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: palette.inkMuted,
                                          fontSize: 12.5,
                                          height: 1.35,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        notificationTime(item.at),
                                        style: TextStyle(
                                          color: palette.inkMuted.withValues(alpha: 0.7),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (opens)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4, top: 6),
                                    child: Icon(
                                      Icons.chevron_right_rounded,
                                      color: palette.inkMuted.withValues(alpha: 0.6),
                                      size: 19,
                                    ),
                                  ),
                              ],
                            ),
                          );
                          final Widget card = DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : const Color(0xFF0D1F17).withValues(alpha: 0.035),
                            ),
                            child: row,
                          );
                          if (!opens) return card;
                          return Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(18),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () {
                                Navigator.of(context).pop();
                                onOpen!(item);
                              },
                              child: card,
                            ),
                          );
                        },
                      );
                    },
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

class _Dot extends StatelessWidget {
  const _Dot({required this.item, required this.palette});

  final AppNotification item;
  final AppPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      margin: const EdgeInsets.only(top: 2),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: (item.kind == NotificationKind.announcement
                ? palette.accent
                : palette.inkMuted)
            .withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: item.kind == NotificationKind.announcement ? palette.accent : palette.inkMuted,
          shape: BoxShape.circle,
        ),
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
    // quieter glass-tinted outline, so the two read apart at a glance.
    final bool started = item.kind == NotificationKind.chargeStarted;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: started ? palette.accent : palette.accent.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        boxShadow: started
            ? [
                BoxShadow(
                  color: palette.accent.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Icon(icon, color: started ? Colors.white : palette.accent, size: 18),
    );
  }
}
