import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/app_strings.dart';

/// Shows one Мэдээ: its image (if any), title and body.
///
/// The announcement watcher marks it seen and files it in the bell before
/// this opens, so the close button, a tap outside and the back button all
/// dismiss it the same way. The body scrolls: operators can write up to
/// 4000 characters, which used to run off the bottom of the screen.
Future<void> showAnnouncementDialog(
  BuildContext context, {
  required String title,
  required String body,
  String? imageUrl,
}) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) =>
        AnnouncementDialog(title: title, body: body, imageUrl: imageUrl),
  );
}

class AnnouncementDialog extends StatelessWidget {
  const AnnouncementDialog({
    super.key,
    required this.title,
    required this.body,
    this.imageUrl,
  });

  final String title;
  final String body;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final double maxHeight = MediaQuery.of(context).size.height * 0.8;

    return Dialog(
      backgroundColor: palette.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (imageUrl != null)
              Image.network(
                imageUrl!,
                height: 180,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppStrings.get('announcement_tag'),
                      style: TextStyle(
                        color: palette.accent,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      style: TextStyle(
                        color: palette.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      body,
                      style: TextStyle(
                        color: palette.inkMuted,
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: palette.accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(AppStrings.get('guide_done')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
