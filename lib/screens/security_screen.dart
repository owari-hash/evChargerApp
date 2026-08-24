import 'package:flutter/material.dart';

import '../models/auth_user.dart';
import '../services/account_service.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import '../widgets/account_widgets.dart';

/// Password, email confirmation and phone verification — the app's counterpart
/// to `/account/security` in the kiosk.
class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key, this.authService, this.accountService});

  final AuthService? authService;
  final AccountService? accountService;

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  AuthService get _auth => widget.authService ?? AuthService.instance;
  AccountService get _account =>
      widget.accountService ?? AccountService.instance;

  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  final TextEditingController _code = TextEditingController();

  bool _changing = false;
  bool _resending = false;
  bool _sendingCode = false;
  bool _verifyingCode = false;
  bool _codeSent = false;
  bool _deletingAccount = false;
  String? _passwordError;
  Map<String, String> _passwordFields = const <String, String>{};
  String? _codeError;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (_changing) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _changing = true;
      _passwordError = null;
      _passwordFields = const <String, String>{};
    });

    try {
      await _account.changePassword(
        currentPassword: _current.text,
        password: _next.text,
        confirmPassword: _confirm.text,
      );
      if (!mounted) return;
      _current.clear();
      _next.clear();
      _confirm.clear();
      setState(() => _changing = false);
      showSnack(context, AppStrings.get('sec_changed'));
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _changing = false;
        _passwordError = error.message;
        _passwordFields = error.fields;
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
              _emailCard(palette, user),
              const SizedBox(height: 12),
              _phoneCard(palette, user),
              const SizedBox(height: 12),
              _passwordCard(palette),
              const SizedBox(height: 12),
              _deleteAccountCard(palette),
            ],
          );
        },
      ),
    );
  }

  Widget _emailCard(AppPalette palette, AuthUser user) {
    return SectionCard(
      title: AppStrings.get('sec_email_title'),
      trailing: VerifiedChip(verified: user.emailVerified),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            AppStrings.get(
              user.emailVerified ? 'sec_email_confirmed' : 'sec_email_pending',
            ).replaceFirst('{email}', user.email),
            style: TextStyle(
              color: palette.inkMuted,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          if (!user.emailVerified) ...<Widget>[
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
              AccountField(
                controller: _code,
                label: AppStrings.get('sec_code_label'),
                icon: Icons.sms_outlined,
                keyboardType: TextInputType.number,
                enabled: !_verifyingCode,
                error: _codeError,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _verifyCode(),
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

  Widget _passwordCard(AppPalette palette) {
    return SectionCard(
      title: AppStrings.get('sec_password_title'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AccountField(
            controller: _current,
            label: AppStrings.get('sec_current'),
            icon: Icons.lock_outline_rounded,
            obscure: true,
            enabled: !_changing,
            error: _passwordFields['currentPassword'],
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          AccountField(
            controller: _next,
            label: AppStrings.get('sec_new'),
            icon: Icons.lock_reset_rounded,
            obscure: true,
            enabled: !_changing,
            error: _passwordFields['password'],
            helper: AppStrings.get('auth_password_hint'),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          AccountField(
            controller: _confirm,
            label: AppStrings.get('sec_confirm'),
            icon: Icons.lock_reset_rounded,
            obscure: true,
            enabled: !_changing,
            error: _passwordFields['confirmPassword'],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _changePassword(),
          ),
          if (_passwordError != null) ...<Widget>[
            const SizedBox(height: 12),
            FormErrorBanner(message: _passwordError!),
          ],
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: palette.inkMuted,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  AppStrings.get('sec_changed'),
                  style: TextStyle(
                    color: palette.inkMuted,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          PrimaryAction(
            label: AppStrings.get('sec_change'),
            busy: _changing,
            icon: Icons.shield_rounded,
            onPressed: _changePassword,
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
