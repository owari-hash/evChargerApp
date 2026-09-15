import 'package:flutter/material.dart';

import '../models/auth_user.dart';
import '../services/account_service.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import '../widgets/account_widgets.dart';
import '../widgets/biometric_prompt.dart';
import '../widgets/pin_code_field.dart';

/// PIN, email confirmation and phone verification — the app's counterpart to
/// `/account/security` in the kiosk.
class SecurityScreen extends StatefulWidget {
  const SecurityScreen({
    super.key,
    this.authService,
    this.accountService,
    this.biometricService,
  });

  final AuthService? authService;
  final AccountService? accountService;
  final BiometricService? biometricService;

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  AuthService get _auth => widget.authService ?? AuthService.instance;
  AccountService get _account =>
      widget.accountService ?? AccountService.instance;
  BiometricService get _bio =>
      widget.biometricService ?? BiometricService.instance;

  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  final TextEditingController _code = TextEditingController();

  // Each complete PIN moves the cursor on; a matching repeat lands on the button.
  final FocusNode _nextFocus = FocusNode();
  final FocusNode _confirmFocus = FocusNode();
  final FocusNode _changeFocus = FocusNode();

  bool _changing = false;
  bool _resending = false;
  bool _sendingCode = false;
  bool _verifyingCode = false;
  bool _codeSent = false;
  bool _deletingAccount = false;
  String? _pinError;
  Map<String, String> _pinFields = const <String, String>{};
  String? _codeError;

  /// Null when the device has no Face ID / fingerprint, which hides the card.
  BiometricKind? _bioKind;
  bool _bioEnabled = false;
  bool _bioBusy = false;

  @override
  void initState() {
    super.initState();
    _loadBiometrics();
  }

  Future<void> _loadBiometrics() async {
    final BiometricKind? kind = await _bio.availableKind();
    final bool enabled = kind != null && await _bio.isEnabled();
    if (!mounted) return;
    setState(() {
      _bioKind = kind;
      _bioEnabled = enabled;
    });
  }

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    _code.dispose();
    _nextFocus.dispose();
    _confirmFocus.dispose();
    _changeFocus.dispose();
    super.dispose();
  }

  /// Runs when the repeat is complete: a typo is caught at once, a match moves
  /// focus to the button so saving stays one deliberate tap.
  void _checkConfirm(String value) {
    if (value == _next.text) {
      if (_pinFields.containsKey('confirmPin')) {
        setState(() => _pinFields = const <String, String>{});
      }
      _changeFocus.requestFocus();
      return;
    }
    _confirm.clear();
    setState(() {
      _pinFields = <String, String>{
        'confirmPin': AppStrings.get('auth_pin_mismatch'),
      };
    });
  }

  Future<void> _changePin(AuthUser user) async {
    if (_changing) return;
    FocusScope.of(context).unfocus();

    final Map<String, String> local = <String, String>{};
    if (user.hasPin && _current.text.length != 4) {
      local['currentPin'] = AppStrings.get('auth_bad_pin');
    }
    if (_next.text.length != 4) {
      local['pin'] = AppStrings.get('auth_bad_pin');
    } else if (_confirm.text != _next.text) {
      local['confirmPin'] = AppStrings.get('auth_pin_mismatch');
      _confirm.clear();
    }
    if (local.isNotEmpty) {
      setState(() {
        _pinError = null;
        _pinFields = local;
      });
      return;
    }

    setState(() {
      _changing = true;
      _pinError = null;
      _pinFields = const <String, String>{};
    });

    try {
      await _account.changePin(
        currentPin: user.hasPin ? _current.text : null,
        pin: _next.text,
        confirmPin: _confirm.text,
      );
      // Face ID / fingerprint sign-in would otherwise keep the old PIN.
      await _bio.refresh(phone: user.phone ?? '', pin: _next.text);
      if (!mounted) return;
      _current.clear();
      _next.clear();
      _confirm.clear();
      setState(() => _changing = false);
      showSnack(context, AppStrings.get('sec_pin_changed'));
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _changing = false;
        _pinError = error.message;
        _pinFields = error.fields;
      });
    }
  }

  Future<void> _resendEmail() async {
    if (_resending) return;
    setState(() => _resending = true);
    try {
      final String destination = await _account.resendEmailVerification();
      if (!mounted) return;
      setState(() => _resending = false);
      showSnack(
        context,
        AppStrings.get('sec_sent_to').replaceFirst('{dest}', destination),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _resending = false);
      showApiSnack(context, error);
    }
  }

  Future<void> _sendCode() async {
    if (_sendingCode) return;
    setState(() {
      _sendingCode = true;
      _codeError = null;
    });
    try {
      final String destination = await _account.sendPhoneCode();
      if (!mounted) return;
      setState(() {
        _sendingCode = false;
        _codeSent = true;
      });
      showSnack(
        context,
        AppStrings.get('sec_sent_to').replaceFirst('{dest}', destination),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _sendingCode = false;
        _codeError = error.message;
      });
    }
  }

  Future<void> _verifyCode() async {
    if (_verifyingCode) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _verifyingCode = true;
      _codeError = null;
    });
    try {
      await _account.verifyPhone(_code.text);
      if (!mounted) return;
      _code.clear();
      setState(() {
        _verifyingCode = false;
        _codeSent = false;
      });
      showSnack(context, AppStrings.get('sec_phone_done'));
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _verifyingCode = false;
        _codeError = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return Scaffold(
      backgroundColor: palette.bg,
      appBar: AppBar(title: Text(AppStrings.get('sec_title'))),
      body: ValueListenableBuilder<AuthUser?>(
        valueListenable: _auth.currentUser,
        builder: (BuildContext context, AuthUser? user, Widget? _) {
          if (user == null) return const SizedBox.shrink();

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 40),
            children: <Widget>[
              _pinCard(palette, user),
              if (_bioKind != null) ...<Widget>[
                const SizedBox(height: 12),
                _biometricCard(palette, user, _bioKind!),
              ],
              const SizedBox(height: 12),
              _phoneCard(palette, user),
              const SizedBox(height: 12),
              _emailCard(palette, user),
              const SizedBox(height: 12),
              _deleteAccountCard(palette),
            ],
          );
        },
      ),
    );
  }

  Widget _emailCard(AppPalette palette, AuthUser user) {
    final String? email = user.email;

    return SectionCard(
      title: AppStrings.get('sec_email_title'),
      trailing: email == null
          ? null
          : VerifiedChip(verified: user.emailVerified),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            email == null
                ? AppStrings.get('sec_email_none')
                : AppStrings.get(
                    user.emailVerified
                        ? 'sec_email_confirmed'
                        : 'sec_email_pending',
                  ).replaceFirst('{email}', email),
            style: TextStyle(
              color: palette.inkMuted,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          if (email != null && !user.emailVerified) ...<Widget>[
            const SizedBox(height: 14),
            PrimaryAction(
              label: AppStrings.get('sec_resend_email'),
              busy: _resending,
              onPressed: _resendEmail,
            ),
          ],
        ],
      ),
    );
  }

  Widget _phoneCard(AppPalette palette, AuthUser user) {
    final bool hasPhone = user.phone != null && user.phone!.isNotEmpty;

    return SectionCard(
      title: AppStrings.get('sec_phone_title'),
      trailing: VerifiedChip(verified: user.phoneVerified),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            user.phoneVerified
                ? AppStrings.get(
                    'sec_phone_confirmed',
                  ).replaceFirst('{phone}', user.phone ?? '')
                : hasPhone
                ? AppStrings.get('sec_phone_pending')
                : AppStrings.get('acct_no_number'),
            style: TextStyle(
              color: palette.inkMuted,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          if (!user.phoneVerified && hasPhone) ...<Widget>[
            const SizedBox(height: 14),
            if (_codeSent) ...<Widget>[
              PinCodeField(
                controller: _code,
                length: 6,
                obscure: false,
                enabled: !_verifyingCode,
                label: AppStrings.get('sec_code_label'),
                error: _codeError,
                autofillHints: const <String>[AutofillHints.oneTimeCode],
                onCompleted: (_) => _verifyCode(),
              ),
              const SizedBox(height: 12),
              PrimaryAction(
                label: AppStrings.get('sec_verify'),
                busy: _verifyingCode,
                onPressed: _verifyCode,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _sendingCode ? null : _sendCode,
                child: Text(AppStrings.get('sec_send_code')),
              ),
            ] else ...<Widget>[
              if (_codeError != null) ...<Widget>[
                FormErrorBanner(message: _codeError!),
                const SizedBox(height: 12),
              ],
              PrimaryAction(
                label: AppStrings.get('sec_send_code'),
                busy: _sendingCode,
                onPressed: _sendCode,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _pinCard(AppPalette palette, AuthUser user) {
    return SectionCard(
      title: AppStrings.get('sec_pin_title'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            AppStrings.get(user.hasPin ? 'sec_pin_hint' : 'sec_pin_none'),
            style: TextStyle(
              color: palette.inkMuted,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          if (user.hasPin) ...<Widget>[
            PinCodeField(
              controller: _current,
              enabled: !_changing,
              label: AppStrings.get('sec_pin_current'),
              error: _pinFields['currentPin'],
              onCompleted: (_) => _nextFocus.requestFocus(),
            ),
            const SizedBox(height: 12),
          ],
          PinCodeField(
            controller: _next,
            focusNode: _nextFocus,
            enabled: !_changing,
            label: AppStrings.get('sec_pin_new'),
            error: _pinFields['pin'],
            onCompleted: (_) => _confirmFocus.requestFocus(),
          ),
          const SizedBox(height: 12),
          PinCodeField(
            controller: _confirm,
            focusNode: _confirmFocus,
            enabled: !_changing,
            label: AppStrings.get('sec_pin_confirm'),
            error: _pinFields['confirmPin'],
            onCompleted: _checkConfirm,
          ),
          if (_pinError != null) ...<Widget>[
            const SizedBox(height: 12),
            FormErrorBanner(message: _pinError!),
          ],
          const SizedBox(height: 14),
          PrimaryAction(
            label: AppStrings.get(
              user.hasPin ? 'sec_pin_change' : 'sec_pin_set',
            ),
            busy: _changing,
            icon: Icons.shield_rounded,
            focusNode: _changeFocus,
            onPressed: () => _changePin(user),
          ),
        ],
      ),
    );
  }

  /// Turning it on needs the PIN once — it is what gets remembered — checked
  /// against the server before it is stored.
  Future<void> _toggleBiometrics(bool on, AuthUser user) async {
    if (_bioBusy) return;

    if (!on) {
      setState(() => _bioBusy = true);
      await _bio.disable();
      if (!mounted) return;
      setState(() {
        _bioBusy = false;
        _bioEnabled = false;
      });
      showSnack(context, AppStrings.get('sec_bio_off'));
      return;
    }

    final String? phone = user.phone;
    if (phone == null) return;
    final String? pin = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext sheetContext) => const _PinPromptSheet(),
    );
    if (pin == null || !mounted) return;

    setState(() => _bioBusy = true);
    try {
      await _auth.signIn(phone: phone, pin: pin);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _bioBusy = false);
      showApiSnack(context, error);
      return;
    }

    final bool enabled = await _bio.enable(
      phone: phone,
      pin: pin,
      reason: AppStrings.get('bio_reason'),
    );
    if (!mounted) return;
    setState(() {
      _bioBusy = false;
      _bioEnabled = enabled;
    });
    if (enabled) showSnack(context, AppStrings.get('sec_bio_on'));
  }

  Widget _biometricCard(AppPalette palette, AuthUser user, BiometricKind kind) {
    return SectionCard(
      title: AppStrings.get(
        kind == BiometricKind.face ? 'sec_bio_face' : 'sec_bio_finger',
      ),
      trailing: Switch.adaptive(
        value: _bioEnabled,
        activeTrackColor: palette.accent,
        onChanged: _bioBusy || !user.hasPin
            ? null
            : (bool on) => _toggleBiometrics(on, user),
      ),
      child: Row(
        children: <Widget>[
          BiometricGlyph(kind: kind, color: palette.accent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppStrings.get('sec_bio_body'),
              style: TextStyle(
                color: palette.inkMuted,
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _deleteAccountCard(AppPalette palette) {
    return SectionCard(
      title: AppStrings.get('sec_delete_title'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            AppStrings.get('sec_delete_body'),
            style: TextStyle(
              color: palette.inkMuted,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _deletingAccount ? null : _confirmDeleteAccount,
            icon: _deletingAccount
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.delete_forever_rounded, size: 18),
            label: Text(AppStrings.get('sec_delete_btn')),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(AppStrings.get('sec_delete_confirm_title')),
        content: Text(AppStrings.get('sec_delete_confirm_body')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppStrings.get('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
            child: Text(AppStrings.get('sec_delete_btn')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deletingAccount = true);
    try {
      await _bio.disable();
      await _account.deleteAccount();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      showSnack(context, AppStrings.get('sec_delete_success'));
    } catch (_) {
      if (!mounted) return;
      setState(() => _deletingAccount = false);
      showSnack(context, AppStrings.get('sec_delete_success'));
    }
  }
}

/// Asks for the PIN once, to turn on Face ID / fingerprint sign-in. Pops the
/// PIN as soon as the fourth digit goes in.
class _PinPromptSheet extends StatefulWidget {
  const _PinPromptSheet();

  @override
  State<_PinPromptSheet> createState() => _PinPromptSheetState();
}

class _PinPromptSheetState extends State<_PinPromptSheet> {
  final TextEditingController _pin = TextEditingController();

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        22,
        20,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            AppStrings.get('sec_bio_enter_pin'),
            style: TextStyle(
              color: palette.ink,
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 18),
          PinCodeField(
            controller: _pin,
            autofocus: true,
            onCompleted: (String pin) => Navigator.pop(context, pin),
          ),
        ],
      ),
    );
  }
}
