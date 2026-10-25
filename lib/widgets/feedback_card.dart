import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import 'app_toast.dart';

/// «Санал хүсэлт» at the bottom of the home screen: a card with a slow green
/// glow that opens a short form. Lands in the console's Санал хүсэлт page,
/// the same as the kiosk footer's form.
class FeedbackCard extends StatefulWidget {
  const FeedbackCard({super.key});

  @override
  State<FeedbackCard> createState() => _FeedbackCardState();
}

class _FeedbackCardState extends State<FeedbackCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return AnimatedBuilder(
      animation: _glow,
      builder: (BuildContext context, Widget? child) {
        final double t = Curves.easeInOut.transform(_glow.value);
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: palette.accent.withValues(alpha: 0.18 + 0.22 * t),
                blurRadius: 18 + 14 * t,
                spreadRadius: -2,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => showFeedbackSheet(context),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  palette.accent.withValues(alpha: 0.22),
                  palette.card.withValues(alpha: 0.9),
                ],
              ),
              border: Border.all(color: palette.accent.withValues(alpha: 0.45)),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: palette.accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Transform.rotate(
                    angle: -math.pi / 40,
                    child: Icon(
                      Icons.forum_rounded,
                      color: palette.accent,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        AppStrings.get('feedback_title'),
                        style: TextStyle(
                          color: palette.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppStrings.get('feedback_subtitle'),
                        style: TextStyle(color: palette.inkMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: palette.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The form: a phone number only for a guest, then the message.
Future<void> showFeedbackSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) => const _FeedbackSheet(),
  );
}

class _FeedbackSheet extends StatefulWidget {
  const _FeedbackSheet();

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _message = TextEditingController();
  bool _sending = false;
  String? _error;

  bool get _signedIn => AuthService.instance.isSignedIn;

  @override
  void dispose() {
    _phone.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final String message = _message.text.trim();
    final String phone = _phone.text.trim();
    if (message.length < 3) {
      setState(() => _error = AppStrings.get('feedback_message_required'));
      return;
    }
    if (!_signedIn && phone.replaceAll(RegExp(r'\D'), '').length < 8) {
      setState(() => _error = AppStrings.get('feedback_phone_required'));
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ApiClient.shared.post(
        '/feedback',
        body: <String, dynamic>{
          'message': message,
          if (!_signedIn) 'phone': phone,
          'source': 'app',
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      AppToast.show(
        context,
        AppStrings.get('feedback_sent'),
        kind: ToastKind.success,
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final InputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: palette.border),
    );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: palette.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.get('feedback_title'),
                style: TextStyle(
                  color: palette.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppStrings.get('feedback_subtitle'),
                style: TextStyle(color: palette.inkMuted, fontSize: 12.5),
              ),
              const SizedBox(height: 16),
              if (!_signedIn) ...<Widget>[
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  enabled: !_sending,
                  decoration: InputDecoration(
                    labelText: AppStrings.get('feedback_phone'),
                    hintText: '9911 2233',
                    border: border,
                    enabledBorder: border,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _message,
                minLines: 4,
                maxLines: 8,
                maxLength: 2000,
                enabled: !_sending,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: AppStrings.get('feedback_title'),
                  hintText: AppStrings.get('feedback_placeholder'),
                  alignLabelWithHint: true,
                  border: border,
                  enabledBorder: border,
                ),
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: AppTheme.errorRed,
                    fontSize: 12.5,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: TextButton(
                        onPressed: _sending
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: AppTheme.cancelButtonStyle,
                        child: Text(AppStrings.get('cancel')),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: FilledButton(
                        onPressed: _sending ? null : _send,
                        style: FilledButton.styleFrom(
                          backgroundColor: palette.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _sending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(AppStrings.get('feedback_send')),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
