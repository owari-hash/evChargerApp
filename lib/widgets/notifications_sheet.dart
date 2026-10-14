import 'dart:async';

import 'package:flutter/material.dart';

import '../services/notifications_store.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';

/// The bell's dropdown-equivalent: every wallet change and announcement the
/// driver has already dismissed once, newest first.
void showNotificationsSheet(BuildContext context) {
  unawaited(NotificationsStore.instance.markAllRead());
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _NotificationsSheet(),
  );
}

class _NotificationsSheet extends StatelessWidget {
  const _NotificationsSheet();

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: palette.panel,
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
                      style: TextStyle(color: palette.onPanel, fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: palette.onPanel),
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
                      return Padding(
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
                                      color: palette.onPanel,
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
                                ],
                              ),
                            ),
                          ],
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
