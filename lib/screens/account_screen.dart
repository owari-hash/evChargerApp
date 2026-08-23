import 'package:flutter/material.dart';

import '../models/auth_user.dart';
import '../services/account_service.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import '../widgets/account_widgets.dart';
import 'security_screen.dart';
import 'sessions_screen.dart';
import 'wallet_screen.dart';

/// The account hub, mirroring `/account` in the kiosk web app: who you are
/// signed in as, your details, your charge tags, and the way through to the
/// wallet, security and history pages.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, this.authService, this.accountService});

  final AuthService? authService;
  final AccountService? accountService;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  AuthService get _auth => widget.authService ?? AuthService.instance;
  AccountService get _account =>
      widget.accountService ?? AccountService.instance;

  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _newTag = TextEditingController();

  bool _savingProfile = false;
  bool _linkingTag = false;
  String? _profileError;
  Map<String, String> _profileFields = const <String, String>{};

  @override
  void initState() {
    super.initState();
    final AuthUser? user = _auth.currentUser.value;
    _name.text = user?.name ?? '';
    _phone.text = user?.phone ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _newTag.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_savingProfile) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _savingProfile = true;
      _profileError = null;
      _profileFields = const <String, String>{};
    });

    try {
      await _account.updateProfile(
        name: _name.text,
        phone: _phone.text,
        locale: AppStrings.currentLanguage == AppLanguage.mn ? 'mn' : 'en',
      );
      if (!mounted) return;
      setState(() => _savingProfile = false);
      showSnack(context, AppStrings.get('acct_saved'));
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _savingProfile = false;
        _profileError = error.message;
        _profileFields = error.fields;
      });
    }
  }

  Future<void> _linkTag() async {
    final String tag = _newTag.text.trim();
    if (tag.isEmpty || _linkingTag) return;
    FocusScope.of(context).unfocus();
    setState(() => _linkingTag = true);

    try {
      await _account.linkIdTag(tag);
      if (!mounted) return;
      _newTag.clear();
      setState(() => _linkingTag = false);
      showSnack(
        context,
        AppStrings.get('acct_idtags_linked').replaceFirst('{tag}', tag),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _linkingTag = false);
      showApiSnack(context, error);
    }
  }

  Future<void> _unlinkTag(String tag) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(AppStrings.get('acct_idtags_unlink_confirm')),
        content: Text(tag),
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
            child: Text(AppStrings.get('acct_idtags_unlink_yes')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _account.unlinkIdTag(tag);
      if (!mounted) return;
      showSnack(
        context,
        AppStrings.get('acct_idtags_unlinked').replaceFirst('{tag}', tag),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      showApiSnack(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return ValueListenableBuilder<AuthUser?>(
      valueListenable: _auth.currentUser,
      builder: (BuildContext context, AuthUser? user, Widget? _) {
        if (user == null) return const SizedBox.shrink();

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 120),
          children: <Widget>[
            _identityHeader(palette, user),
            const SizedBox(height: 16),
            _statusCard(palette, user),
            const SizedBox(height: 12),
            _navCard(palette),
            const SizedBox(height: 12),
            _profileCard(palette),
            const SizedBox(height: 12),
            _idTagsCard(palette, user),
          ],
        );
      },
    );
  }

  Widget _identityHeader(AppPalette palette, AuthUser user) {
    return Row(
      children: <Widget>[
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: palette.accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.accent.withValues(alpha: 0.35)),
          ),
          child: Text(
            user.displayName.characters.first.toUpperCase(),
            style: TextStyle(
              color: palette.accent,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                user.name.trim().isEmpty ? user.displayName : user.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                user.email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: palette.inkMuted, fontSize: 12.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusCard(AppPalette palette, AuthUser user) {
    return SectionCard(
      title: AppStrings.get('acct_status'),
      child: Column(
        children: <Widget>[
          _statusRow(
            palette,
            Icons.alternate_email_rounded,
            AppStrings.get('acct_email_label'),
            user.email,
            user.emailVerified,
          ),
          Divider(color: palette.border, height: 22),
          _statusRow(
            palette,
            Icons.phone_iphone_rounded,
            AppStrings.get('acct_mobile_label'),
            user.phone ?? AppStrings.get('acct_no_number'),
            user.phoneVerified,
          ),
        ],
      ),
    );
  }

  Widget _statusRow(
    AppPalette palette,
    IconData icon,
    String label,
    String value,
    bool verified,
  ) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: palette.inkMuted),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(color: palette.inkMuted, fontSize: 11),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: palette.ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        VerifiedChip(verified: verified),
      ],
    );
  }

  Widget _navCard(AppPalette palette) {
    return SectionCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: <Widget>[
          _navRow(
            palette,
            Icons.account_balance_wallet_rounded,
            AppStrings.get('acct_nav_wallet'),
            AppStrings.get('acct_nav_wallet_sub'),
            () => _open(const WalletScreen()),
          ),
          Divider(color: palette.border, height: 1, indent: 60),
          _navRow(
            palette,
            Icons.receipt_long_rounded,
            AppStrings.get('acct_nav_sessions'),
            AppStrings.get('acct_nav_sessions_sub'),
            () => _open(const SessionsScreen()),
          ),
          Divider(color: palette.border, height: 1, indent: 60),
          _navRow(
            palette,
            Icons.shield_rounded,
            AppStrings.get('acct_nav_security'),
            AppStrings.get('acct_nav_security_sub'),
            () => _open(const SecurityScreen()),
          ),
        ],
      ),
    );
  }

  void _open(Widget screen) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (BuildContext context) => screen));
  }

  Widget _navRow(
    AppPalette palette,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Row(
          children: <Widget>[
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 19, color: palette.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.ink,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: palette.inkMuted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: palette.inkMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileCard(AppPalette palette) {
    return SectionCard(
      title: AppStrings.get('acct_profile_title'),
      child: Column(
        children: <Widget>[
          AccountField(
            controller: _name,
            label: AppStrings.get('acct_name_label'),
            icon: Icons.badge_outlined,
            enabled: !_savingProfile,
            error: _profileFields['name'],
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          AccountField(
            controller: _phone,
            label: AppStrings.get('acct_mobile_label'),
            icon: Icons.phone_iphone_rounded,
            keyboardType: TextInputType.phone,
            enabled: !_savingProfile,
            error: _profileFields['phone'],
            helper: '+976 9911 2233',
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _saveProfile(),
          ),
          if (_profileError != null) ...<Widget>[
            const SizedBox(height: 12),
            FormErrorBanner(message: _profileError!),
          ],
          const SizedBox(height: 14),
          PrimaryAction(
            label: AppStrings.get('acct_save'),
            busy: _savingProfile,
            onPressed: _saveProfile,
          ),
        ],
      ),
    );
  }

  Widget _idTagsCard(AppPalette palette, AuthUser user) {
    return SectionCard(
      title: AppStrings.get('acct_idtags_title'),
      subtitle: AppStrings.get('acct_idtags_body'),
      child: Column(
        children: <Widget>[
          if (user.idTags.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                AppStrings.get('acct_idtags_none'),
                style: TextStyle(color: palette.inkMuted, fontSize: 12.5),
              ),
            )
          else
            ...user.idTags.map(
              (String tag) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.badge_rounded, size: 17, color: palette.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tag,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.ink,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _unlinkTag(tag),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.errorRed,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(
                        AppStrings.get('acct_idtags_unlink'),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          AccountField(
            controller: _newTag,
            label: AppStrings.get('acct_idtags_add'),
            icon: Icons.nfc_rounded,
            enabled: !_linkingTag,
            helper: AppStrings.get('acct_idtags_hint'),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _linkTag(),
          ),
          const SizedBox(height: 12),
          PrimaryAction(
            label: AppStrings.get('acct_idtags_submit'),
            busy: _linkingTag,
            onPressed: _linkTag,
          ),
        ],
      ),
    );
  }
}
