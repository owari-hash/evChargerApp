import 'package:flutter/material.dart';

import '../content/legal_content.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';

enum LegalTab { terms, privacy }

/// Shows the terms of service and the privacy notice in a sheet over the
/// current screen, so the driver reads them without leaving the app.
///
/// With [offerAccept] the sheet ends in an "accept" button, and the future
/// resolves true when the driver taps it.
Future<bool> showLegalSheet(
  BuildContext context, {
  LegalTab initialTab = LegalTab.terms,
  bool offerAccept = false,
}) async {
  final bool? accepted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.palette.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (BuildContext sheetContext) =>
        _LegalSheet(initialTab: initialTab, offerAccept: offerAccept),
  );
  return accepted ?? false;
}

class _LegalSheet extends StatelessWidget {
  const _LegalSheet({required this.initialTab, required this.offerAccept});

  final LegalTab initialTab;
  final bool offerAccept;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final AppLanguage language = AppStrings.currentLanguage;

    return FractionallySizedBox(
      heightFactor: 0.92,
      child: DefaultTabController(
        length: 2,
        initialIndex: initialTab.index,
        child: Column(
          children: <Widget>[
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: palette.border,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 4, 0),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TabBar(
                      labelColor: palette.ink,
                      unselectedLabelColor: palette.inkMuted,
                      indicatorColor: palette.accent,
                      dividerColor: Colors.transparent,
                      labelStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      tabs: <Widget>[
                        Tab(text: AppStrings.get('legal_terms_tab')),
                        Tab(text: AppStrings.get('legal_privacy_tab')),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: () => Navigator.pop(context, false),
                    icon: Icon(Icons.close_rounded, color: palette.inkMuted),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: palette.border),
            Expanded(
              child: TabBarView(
                children: <Widget>[
                  _DocumentView(document: LegalContent.terms(language)),
                  _DocumentView(document: LegalContent.privacy(language)),
                ],
              ),
            ),
            if (offerAccept)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.panel,
                        foregroundColor: palette.onPanel,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        AppStrings.get('legal_accept'),
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One document laid out like its page on the website: title, intro, the
/// stored fields (privacy only), then the numbered sections.
class _DocumentView extends StatelessWidget {
  const _DocumentView({required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final TextStyle body = TextStyle(
      color: palette.inkMuted,
      fontSize: 13.5,
      height: 1.55,
    );
    final TextStyle heading = TextStyle(
      color: palette.ink,
      fontSize: 16,
      fontWeight: FontWeight.w700,
      height: 1.3,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: <Widget>[
        if (document.draftTitle.isNotEmpty) ...<Widget>[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: palette.accent.withValues(alpha: 0.35)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(document.draftTitle, style: heading.copyWith(fontSize: 14)),
                if (document.draftBody.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    document.draftBody,
                    style: body.copyWith(fontSize: 12.5),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
        Text(
          document.title,
          style: TextStyle(
            color: palette.ink,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(document.intro, style: body.copyWith(fontSize: 14.5)),
        if (document.stored.isNotEmpty) ...<Widget>[
          const SizedBox(height: 22),
          Text(document.storedTitle, style: heading),
          for (final LegalItem item in document.stored)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(item.title, style: heading.copyWith(fontSize: 14)),
                  const SizedBox(height: 3),
                  Text(item.body, style: body),
                ],
              ),
            ),
        ],
        for (int i = 0; i < document.sections.length; i++) ...<Widget>[
          const SizedBox(height: 22),
          Text('${i + 1}. ${document.sections[i].heading}', style: heading),
          for (final String paragraph in document.sections[i].paragraphs)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(paragraph, style: body),
            ),
          for (final String bullet in document.sections[i].bullets)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('•  ', style: body),
                  Expanded(child: Text(bullet, style: body)),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
