import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/contact_info.dart';
import '../services/contact_service.dart';
import '../theme/app_theme.dart';
import '../widgets/account_widgets.dart';
import '../widgets/feedback_card.dart';

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final ContactService _service = ContactService.instance;
  late ContactInfo _info;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _info = _service.current;
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final ContactInfo data = await _service.load();
    if (!mounted) return;
    setState(() {
      _info = data;
      _loading = false;
    });
  }

  Future<void> _launch(String urlString) async {
    try {
      final Uri uri = Uri.parse(urlString);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Ignored if device cannot open URL
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    // First phone number for direct dial
    final String dialPhone = _info.phone.split(',').first.trim().replaceAll(RegExp(r'\s+'), '');

    return Scaffold(
      backgroundColor: palette.bg,
      appBar: AppBar(
        title: const Text('Холбоо барих'),
        backgroundColor: palette.bg,
        foregroundColor: palette.ink,
        elevation: 0,
        actions: <Widget>[
          if (_loading)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: palette.accent,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: palette.accent,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 40),
          children: <Widget>[
            // Header card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: palette.border),
              ),
              child: Column(
                children: <Widget>[
                  Container(
                    width: 56,
                    height: 56,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/eplug-mark.png',
                      errorBuilder: (_, _, _) => Icon(
                        Icons.ev_station_rounded,
                        color: palette.accent,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Eplug Хэрэглэгчийн төв',
                    style: TextStyle(
                      color: palette.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Цэнэглэлт, төлбөр тооцоотой холбоотой лавлагаа болон тусламж авах сувгууд',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: palette.inkMuted,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Direct Contact Cards
            SectionCard(
              title: 'Шуурхай холбоо',
              child: Column(
                children: <Widget>[
                  // Phone Row
                  _contactRow(
                    palette: palette,
                    icon: Icons.phone_rounded,
                    title: 'Утас',
                    value: _info.phone,
                    hint: 'Залгах',
                    onTap: () => _launch('tel:$dialPhone'),
                  ),
                  Divider(color: palette.border, height: 1, indent: 56),

                  // Email Row
                  _contactRow(
                    palette: palette,
                    icon: Icons.email_rounded,
                    title: 'И-мэйл',
                    value: _info.email,
                    hint: 'Илгээх',
                    onTap: () => _launch('mailto:${_info.email}'),
                  ),
                  if (_info.address != null && _info.address!.isNotEmpty) ...<Widget>[
                    Divider(color: palette.border, height: 1, indent: 56),
                    _contactRow(
                      palette: palette,
                      icon: Icons.location_on_rounded,
                      title: 'Хаяг / Байршил',
                      value: _info.address!,
                      hint: '',
                      onTap: null,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Social Channels
            SectionCard(
              title: 'Сошиал сувгууд',
              child: Column(
                children: <Widget>[
                  if (_info.facebookUrl != null && _info.facebookUrl!.isNotEmpty)
                    _socialRow(
                      palette: palette,
                      icon: Icons.public_rounded,
                      title: 'Facebook',
                      name: _info.facebookName?.isNotEmpty == true ? _info.facebookName! : 'Eplug.mn',
                      onTap: () => _launch(_info.facebookUrl!),
                    ),
                  if (_info.instagramUrl != null && _info.instagramUrl!.isNotEmpty) ...<Widget>[
                    if (_info.facebookUrl != null && _info.facebookUrl!.isNotEmpty)
                      Divider(color: palette.border, height: 1, indent: 56),
                    _socialRow(
                      palette: palette,
                      icon: Icons.camera_alt_rounded,
                      title: 'Instagram',
                      name: _info.instagramName?.isNotEmpty == true ? _info.instagramName! : 'Eplug.mn',
                      onTap: () => _launch(_info.instagramUrl!),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Feedback Card
            const FeedbackCard(),
          ],
        ),
      ),
    );
  }

  Widget _contactRow({
    required AppPalette palette,
    required IconData icon,
    required String title,
    required String value,
    required String hint,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: palette.accent, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      color: palette.inkMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      color: palette.ink,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (hint.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  hint,
                  style: TextStyle(
                    color: palette.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _socialRow({
    required AppPalette palette,
    required IconData icon,
    required String title,
    required String name,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: palette.accent, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      color: palette.inkMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    style: TextStyle(
                      color: palette.ink,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.open_in_new_rounded, size: 18, color: palette.inkMuted),
          ],
        ),
      ),
    );
  }
}
