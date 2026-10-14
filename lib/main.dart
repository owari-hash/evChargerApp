import 'dart:async';

import 'package:flutter/material.dart';
import 'models/app_update.dart';
import 'models/charging_session.dart';
import 'models/wallet.dart';
import 'screens/account_screen.dart';
import 'screens/home_dashboard_screen.dart';
import 'screens/mongolia_map_screen.dart';
import 'screens/quick_controls_screen.dart';
import 'screens/trips_stations_screen.dart';
import 'services/app_update_service.dart';
import 'services/auth_service.dart';
import 'services/sessions_service.dart';
import 'services/notifications_store.dart';
import 'services/wallet_watcher_service.dart';
import 'utils/money.dart';
import 'widgets/onboarding_tour.dart';
import 'theme/app_theme.dart';
import 'utils/app_info.dart';
import 'utils/app_strings.dart';
import 'widgets/app_update_dialog.dart';
import 'widgets/announcement_dialog.dart';
import 'widgets/assistant_sheet.dart';
import 'widgets/auth_gate.dart';
import 'widgets/notifications_sheet.dart';

void main() async {
  // The bundle version is read over a platform channel, so the binding has to
  // exist first. It is awaited rather than fired off, because the sign-in
  // footer renders the version on the very first frame.
  WidgetsFlutterBinding.ensureInitialized();
  await AppInfo.load();
  runApp(const EvChargerApp());
}

class EvChargerApp extends StatelessWidget {
  const EvChargerApp({super.key, this.authService});

  /// Injectable so tests can run the app against a stubbed driver API.
  final AuthService? authService;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (BuildContext context, ThemeMode mode, Widget? _) {
        return ValueListenableBuilder<AppLanguage>(
          valueListenable: LanguageController.language,
          builder: (BuildContext context, AppLanguage _, Widget? _) {
            return MaterialApp(
              title: 'Eplug',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: mode,
              home: MainAppFrame(authService: authService),
            );
          },
        );
      },
    );
  }
}

class MainAppFrame extends StatefulWidget {
  const MainAppFrame({super.key, this.authService});

  final AuthService? authService;

  @override
  State<MainAppFrame> createState() => _MainAppFrameState();
}

class _MainAppFrameState extends State<MainAppFrame> {
  AuthService get _auth => widget.authService ?? AuthService.instance;

  /// True until a session saved on a previous launch has been checked, so the
  /// app does not flash the sign-in screen at a driver who is already signed in.
  bool _bootstrapping = true;

  /// Guards the update prompt to one attempt per process.
  bool _updateChecked = false;
  /// 0: Home, 1: Map, 2: Quick Controls, 3: Stations, 4: Account.
  ///
  /// The map is where the app opens, for a guest and a signed-in driver alike:
  /// finding a charger is the reason the app gets opened, and it is the part
  /// that needs no account.
  int _activeTabIndex = _mapTab;

  static const int _mapTab = 1;
  static const int _accountTab = 4;

  bool get _isLoggedIn => _auth.isSignedIn;

  @override
  void initState() {
    super.initState();
    _auth.currentUser.addListener(_onAuthChanged);
    _restoreSession();
    if (_isLoggedIn) _startWalletWatcher();
  }

  @override
  void dispose() {
    _auth.currentUser.removeListener(_onAuthChanged);
    WalletWatcherService.instance.stop();
    super.dispose();
  }

  void _startWalletWatcher() {
    WalletWatcherService.instance.start(
      onNewEntry: (entry) {
        final String label = _walletEntryLabel(entry);
        final String amount =
            '${entry.isCredit ? '+' : ''}${formatMntLeading(entry.amount.toDouble())}';
        unawaited(
          NotificationsStore.instance.add(
            kind: NotificationKind.wallet,
            title: label,
            body: amount,
          ),
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label $amount'),
            backgroundColor: entry.isCredit ? AppTheme.sageGreen : null,
          ),
        );
      },
    );
  }

  String _walletEntryLabel(WalletEntry entry) {
    switch (entry.type) {
      case WalletEntryType.topUp:
        return AppStrings.get('wallet_entry_topup');
      case WalletEntryType.charge:
        return AppStrings.get('wallet_entry_charge');
      case WalletEntryType.refund:
        return AppStrings.get('wallet_entry_refund');
      case WalletEntryType.adjustment:
        return AppStrings.get('wallet_entry_adjustment');
      case WalletEntryType.bonus:
        return AppStrings.get('wallet_entry_bonus');
    }
  }

  Future<void> _maybeShowOnboarding() async {
    if (!mounted) return;
    await OnboardingTour.showIfFirstLaunch(context);
  }

  Future<void> _restoreSession() async {
    await _auth.restoreSession();
    if (mounted) {
      setState(() {
        _bootstrapping = false;
        _activeTabIndex = _mapTab;
      });
      // After the splash, never during it: a dialog raised over the boot screen
      // has no Scaffold to anchor its snackbar, and a forced update shown before
      // the app has drawn looks like a crash. Onboarding goes first — it is the
      // gentler prompt, and a brand new driver should see it before anything else.
      await _maybeShowOnboarding();
      if (_isLoggedIn && mounted) await maybeShowAnnouncement(context);
      unawaited(_checkForUpdate());
    }
  }

  /// Cold start only.
  ///
  /// There is deliberately no polling and no re-check when the app returns from
  /// the background. A driver who has the app open is usually in the middle of
  /// something — plugging in, paying, watching a charge — and a modal thrown
  /// over that, a forced one above all, can leave a session running that they
  /// can no longer stop. Being one launch late with an update is cheap; an
  /// interrupted charge is not.
  ///
  /// Failure is silent by design — see AppUpdateService.
  Future<void> _checkForUpdate() async {
    if (_updateChecked) return;
    _updateChecked = true;

    final AppUpdateInfo? pending = await AppUpdateService.instance
        .pendingPrompt();
    if (pending == null || !mounted) return;

    // Even on a cold start the driver may have left a charge running. Stay out
    // of the way and ask again next launch.
    if (await _hasLiveChargingSession()) return;
    if (!mounted) return;

    await AppUpdateDialog.show(context, pending);
  }

  /// True when a charge is running on this account right now.
  ///
  /// Errs towards "yes": if the answer cannot be established the prompt is
  /// skipped, because wrongly suppressing an update costs one launch while
  /// wrongly covering the stop button can cost a driver money.
  Future<bool> _hasLiveChargingSession() async {
    if (!_auth.isSignedIn) return false;
    try {
      final List<ChargingSession> recent = await SessionsService.instance.list(
        limit: 5,
      );
      return recent.any((ChargingSession session) => session.isActive);
    } catch (_) {
      return true;
    }
  }

  /// Signing in from a gated action swaps the tabs from their guest state to
  /// the real thing, so the frame rebuilds whenever the session changes.
  void _onAuthChanged() {
    if (!mounted) return;
    if (_isLoggedIn) {
      _startWalletWatcher();
    } else {
      WalletWatcherService.instance.stop();
    }
    setState(() {
      // Signing in on the account tab lands the driver back on the map rather
      // than leaving them looking at the profile form they just filled in.
      // A sign-in raised over a gated action is left alone: that one resumes
      // whatever the driver was already doing.
      if (_isLoggedIn && _activeTabIndex == _accountTab) {
        _activeTabIndex = _mapTab;
      }
    });
  }

  void _openQrScannerModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const TripsStationsScreen(),
    );
  }

  void _toggleTheme() {
    ThemeController.toggle();
    setState(() {});
  }

  /// Logging out throws away the session, so make the user mean it.
  Future<void> _confirmLogout() async {
    final AppPalette palette = context.palette;

    final bool? shouldLogOut = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(AppStrings.get('logout_title')),
          content: Text(AppStrings.get('logout_body')),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              style: TextButton.styleFrom(foregroundColor: palette.inkMuted),
              child: Text(AppStrings.get('cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.errorRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(AppStrings.get('logout')),
            ),
          ],
        );
      },
    );

    if (shouldLogOut != true) return;

    await _auth.signOut();
    if (mounted) setState(() => _activeTabIndex = _mapTab);
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    if (_bootstrapping) return const _BootSplash();

    // No sign-in wall. Every tab is reachable signed out; the ones that show a
    // driver's own vehicle, money or history say so and offer to sign them in.
    // App Store guideline 5.1.1(v): an app may not require an account to reach
    // features that are not account based, and finding a charger is not.
    final List<Widget> pages = [
      HomeDashboardScreen(
        authService: widget.authService,
        onNavigateToQuickControls: () {
          setState(() => _activeTabIndex = 2);
        },
        onFindCharger: () => setState(() => _activeTabIndex = _mapTab),
        onAddVehicle: () => setState(() => _activeTabIndex = _accountTab),
      ),
      MongoliaMapScreen(onOpenQrScanner: () => _openQrScannerModal(context)),
      QuickControlsScreen(authService: widget.authService),
      TripsStationsScreen(),
      AccountScreen(authService: widget.authService),
    ];

    return Scaffold(
      backgroundColor: palette.bg,

      // Clean Top Header App Bar
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          color: palette.bg,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 6,
            left: 20,
            right: 16,
            bottom: 6,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  'assets/images/ev logo.png',
                  width: 30,
                  height: 30,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Eplug',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: palette.ink,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Language, then theme, then logout.
              _LanguageAction(onChanged: () => setState(() {})),
              const SizedBox(width: 8),
              _AppBarAction(
                icon: ThemeController.isDark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                tooltip: ThemeController.isDark
                    ? AppStrings.get('light_mode')
                    : AppStrings.get('dark'),
                onPressed: _toggleTheme,
              ),
              if (_isLoggedIn) ...[
                const SizedBox(width: 8),
                _NotificationBellAction(onOpen: () => showNotificationsSheet(context)),
              ],
              const SizedBox(width: 10),
              // Guests get the way in; drivers get the way out.
              _isLoggedIn
                  ? _AppBarAction(
                      icon: Icons.logout_rounded,
                      tooltip: AppStrings.get('logout'),
                      onPressed: _confirmLogout,
                    )
                  : _AppBarAction(
                      icon: Icons.login_rounded,
                      tooltip: AppStrings.get('login'),
                      onPressed: () => AuthGate.require(
                        context,
                        reason: AppStrings.get('signin_required_account'),
                        authService: widget.authService,
                      ),
                    ),
            ],
          ),
        ),
      ),

      body: IndexedStack(index: _activeTabIndex, children: pages),

      floatingActionButton: FloatingActionButton(
        onPressed: () => showAssistantSheet(context, page: _currentTabLabel()),
        backgroundColor: palette.accent,
        tooltip: AppStrings.get('assistant_label'),
        child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
      ),

      // Floating Bottom Navigation Bar (Full rounded with space on all sides)
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: 16,
            top: 4,
          ),
          child: Container(
            height: 66,
            decoration: BoxDecoration(
              color: palette.panel,
              borderRadius: BorderRadius.circular(36),
              boxShadow: [
                BoxShadow(
                  color: palette.shadow,
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildBottomNavItem(
                  0,
                  Icons.home_rounded,
                  AppStrings.get('home'),
                ),
                _buildBottomNavItem(
                  1,
                  Icons.map_rounded,
                  AppStrings.get('map'),
                ),
                _buildBottomNavItem(
                  2,
                  Icons.tune_rounded,
                  AppStrings.get('control'),
                ),
                _buildBottomNavItem(
                  3,
                  Icons.ev_station_rounded,
                  AppStrings.get('nav_stations'),
                ),
                _buildBottomNavItem(
                  4,
                  Icons.person_rounded,
                  AppStrings.get('nav_account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The active tab's own label, so the assistant's system prompt can stay
  /// relevant to whatever the driver is actually looking at.
  String _currentTabLabel() {
    const keys = ['home', 'map', 'control', 'nav_stations', 'nav_account'];
    final key = keys[_activeTabIndex.clamp(0, keys.length - 1)];
    return AppStrings.get(key);
  }

  Widget _buildBottomNavItem(int index, IconData icon, String label) {
    final bool isSelected = _activeTabIndex == index;
    final AppPalette palette = context.palette;

    // The selected pill needs more room than the icon-only items so its
    // label is never clipped.
    return Expanded(
      flex: isSelected ? 2 : 1,
      // Keyed so tests can address a tab without matching an icon that also
      // appears inside the tab's own content.
      key: ValueKey<String>('nav-tab-$index'),
      child: GestureDetector(
        onTap: () => setState(() => _activeTabIndex = index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? palette.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(28),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: palette.accent.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? Colors.white
                    : palette.onPanel.withValues(alpha: 0.6),
              ),
              if (isSelected) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// MN | EN switch for the app bar.
class _LanguageAction extends StatelessWidget {
  const _LanguageAction({required this.onChanged});

  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final bool isMn = AppStrings.currentLanguage == AppLanguage.mn;

    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _segment(context, AppLanguage.mn, isMn),
          _segment(context, AppLanguage.en, !isMn),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, AppLanguage lang, bool active) {
    final AppPalette palette = context.palette;
    return Semantics(
      button: true,
      selected: active,
      label: lang.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          LanguageController.set(lang);
          onChanged();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: active ? palette.panel : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          // The inactive flag is dimmed rather than greyed out: an emoji
          // carries its own colour, so opacity is the only lever.
          child: Opacity(
            opacity: active ? 1.0 : 0.45,
            child: Text(lang.flag, style: const TextStyle(fontSize: 17)),
          ),
        ),
      ),
    );
  }
}

/// Circular action button used in the app bar.
class _AppBarAction extends StatelessWidget {
  const _AppBarAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        shape: BoxShape.circle,
        border: Border.all(color: palette.border),
      ),
      child: IconButton(
        icon: Icon(icon, color: palette.ink, size: 20),
        onPressed: onPressed,
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

/// The bell in the app bar: wallet changes and announcements the driver has
/// already seen once as a SnackBar or a modal, kept here so they can find
/// them again — same role as the kiosk website's bell.
class _NotificationBellAction extends StatelessWidget {
  const _NotificationBellAction({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    return ValueListenableBuilder<int>(
      valueListenable: NotificationsStore.instance.unread,
      builder: (context, unread, _) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                color: palette.card,
                shape: BoxShape.circle,
                border: Border.all(color: palette.border),
              ),
              child: IconButton(
                icon: Icon(Icons.notifications_rounded, color: palette.ink, size: 20),
                onPressed: onOpen,
                tooltip: AppStrings.get('notifications_label'),
                visualDensity: VisualDensity.compact,
              ),
            ),
            if (unread > 0)
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Shown for the moment it takes to check for a saved session.
class _BootSplash extends StatelessWidget {
  const _BootSplash();

  /// Matches the `backgroundColor` of `LaunchScreen.storyboard`, which is the
  /// cream the Eplug logo is drawn on. Handing over from the native launch
  /// screen to Flutter is meant to be invisible; using the theme palette here
  /// instead made the app blink from one splash to another.
  static const Color launchBackground = Color(0xFFFAF8F4);

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: launchBackground,
      child: Center(
        child: Image(
          image: AssetImage('assets/images/launch_badge.png'),
          width: 220,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}
