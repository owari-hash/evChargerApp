import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../theme/app_theme.dart';
import '../utils/app_strings.dart';

class _Step {
  const _Step(this.icon, this.titleKey, this.bodyKey);
  final IconData icon;
  final String titleKey;
  final String bodyKey;
}

const List<_Step> _steps = [
  _Step(Icons.location_on_rounded, 'onboarding_step1_title', 'onboarding_step1_body'),
  _Step(Icons.qr_code_scanner_rounded, 'onboarding_step2_title', 'onboarding_step2_body'),
  _Step(Icons.account_balance_wallet_rounded, 'onboarding_step3_title', 'onboarding_step3_body'),
  _Step(Icons.receipt_long_rounded, 'onboarding_step4_title', 'onboarding_step4_body'),
];

/// A one-time, four-step walkthrough shown the first time the app is opened:
/// find a station, scan its QR, top up the wallet, get an e-Barimt. Mirrors
/// the kiosk website's onboarding — same steps, same one-time storage idea,
/// just the native sheet instead of a web modal.
class OnboardingTour {
  static const String _seenKey = 'onboarding_seen';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  /// Shows the tour if this install has never dismissed it before. Safe to
  /// call on every cold start — it is a no-op after the first time.
  static Future<void> showIfFirstLaunch(BuildContext context) async {
    final String? seen = await _storage.read(key: _seenKey).catchError((_) => null);
    if (seen == '1' || !context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _OnboardingSheet(),
    );
    await _storage.write(key: _seenKey, value: '1').catchError((_) {});
  }
}

class _OnboardingSheet extends StatefulWidget {
  const _OnboardingSheet();

  @override
  State<_OnboardingSheet> createState() => _OnboardingSheetState();
}

class _OnboardingSheetState extends State<_OnboardingSheet> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == _steps.length - 1) {
      Navigator.of(context).pop();
      return;
    }
    _controller.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool last = _page == _steps.length - 1;

    return Container(
      height: MediaQuery.of(context).size.height * 0.62,
      decoration: BoxDecoration(
        color: palette.panel,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded, color: palette.onPanel.withValues(alpha: 0.7)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _steps.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final step = _steps[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: palette.accent.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(step.icon, color: palette.accent, size: 32),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          AppStrings.get(step.titleKey),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: palette.onPanel,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          AppStrings.get(step.bodyKey),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: palette.inkMuted, fontSize: 14, height: 1.4),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < _steps.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _page ? palette.accent : palette.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.accent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    last ? AppStrings.get('onboarding_done') : AppStrings.get('onboarding_next'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
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
