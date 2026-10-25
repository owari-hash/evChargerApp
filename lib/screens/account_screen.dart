import 'package:flutter/material.dart';

import '../models/auth_user.dart';
import '../services/account_service.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import '../widgets/account_widgets.dart';
import '../widgets/guided_step.dart';
import 'login_register_screen.dart';
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

  late final TextEditingController _vehicleBrand = TextEditingController(
    text: _auth.currentUser.value?.vehicleBrand ?? '',
  );
  late final TextEditingController _vehicleModel = TextEditingController(
    text: _auth.currentUser.value?.vehicleModel ?? '',
  );

  bool _savingVehicle = false;

  @override
  void dispose() {
    _vehicleBrand.dispose();
    _vehicleModel.dispose();
    super.dispose();
  }

  Future<void> _saveVehicle() async {
    if (_savingVehicle) return;
    FocusScope.of(context).unfocus();
    setState(() => _savingVehicle = true);

    try {
      await _account.updateVehicle(
        brand: _vehicleBrand.text,
        model: _vehicleModel.text,
      );
      if (!mounted) return;
      setState(() => _savingVehicle = false);
      showSnack(context, AppStrings.get('acct_vehicle_saved'));
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _savingVehicle = false);
      showApiSnack(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return ValueListenableBuilder<AuthUser?>(
      valueListenable: _auth.currentUser,
      builder: (BuildContext context, AuthUser? user, Widget? _) {
        // The account tab is where a guest signs in, so it shows the sign-in
        // screen itself rather than an empty pane. Every other tab stays
        // reachable behind it — this is a tab, not a wall.
        if (user == null) {
          return LoginRegisterScreen(
            authService: widget.authService,
            onLoginSuccess: () {},
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 120),
          children: <Widget>[
            _identityHeader(palette, user),
            const SizedBox(height: 16),
            // Email and phone, and whether each is verified, live on the
            // security page with the actions for them; repeating them here
            // put the same address on screen twice.
            _navCard(palette),
            const SizedBox(height: 12),
            _vehicleCard(palette),
            // The charge tag is the system's own identifier for the driver;
            // it is issued with the account and drivers never need to see it.
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
                user.email ?? user.phone ?? '',
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
          Divider(color: palette.border, height: 1, indent: 60),
          // Replays the home-screen walkthrough. Never tells the server: a
          // replay is not the first run, and it is fine to watch it twice.
          _navRow(
            palette,
            Icons.tips_and_updates_outlined,
            AppStrings.get('guide_replay'),
            AppStrings.get('guide_replay_sub'),
            GuidedStep.trigger,
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

  Widget _vehicleCard(AppPalette palette) {
    return SectionCard(
      title: AppStrings.get('acct_vehicle_title'),
      subtitle: AppStrings.get('acct_vehicle_body'),
      child: Column(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: AccountField(
                  controller: _vehicleBrand,
                  label: AppStrings.get('acct_vehicle_brand'),
                  icon: Icons.directions_car_filled_rounded,
                  helper: AppStrings.get('acct_vehicle_brand_hint'),
                  enabled: !_savingVehicle,
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AccountField(
                  controller: _vehicleModel,
                  label: AppStrings.get('acct_vehicle_model'),
                  helper: AppStrings.get('acct_vehicle_model_hint'),
                  enabled: !_savingVehicle,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _saveVehicle(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          PrimaryAction(
            label: AppStrings.get('acct_vehicle_save'),
            busy: _savingVehicle,
            onPressed: _saveVehicle,
          ),
        ],
      ),
    );
  }
}
