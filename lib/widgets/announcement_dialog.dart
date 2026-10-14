import 'package:flutter/material.dart';

import '../services/announcement_service.dart';
import '../services/notifications_store.dart';
import '../theme/app_theme.dart';

/// Shows the newest Мэдээ this device has not dismissed yet, as a modal with
/// its image (if any), title and body. Closing it files the announcement
/// into the notification bell's history instead of losing it outright —
/// mirrors the kiosk website's announcement modal.
Future<void> maybeShowAnnouncement(BuildContext context) async {
  Announcement? announcement;
  try {
    announcement = await AnnouncementService.instance.nextUnseen();
  } catch (_) {
    return;
  }
  if (announcement == null || !context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (context) => _AnnouncementDialog(announcement: announcement!),
  );
}

class _AnnouncementDialog extends StatelessWidget {
  const _AnnouncementDialog({required this.announcement});

  final Announcement announcement;

  Future<void> _close(BuildContext context) async {
    await AnnouncementService.instance.markSeen(announcement.id);
    await NotificationsStore.instance.add(
      kind: NotificationKind.announcement,
      title: announcement.title,
      body: announcement.body,
      imageUrl: announcement.imageUrl,
    );
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return Dialog(
      backgroundColor: palette.panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                if (announcement.imageUrl != null)
                  Image.network(
                    announcement.imageUrl!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: GestureDetector(
                    onTap: () => _close(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    announcement.title,
                    style: TextStyle(color: palette.onPanel, fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    announcement.body,
                    style: TextStyle(color: palette.inkMuted, fontSize: 14, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
