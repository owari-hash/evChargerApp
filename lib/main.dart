import 'package:flutter/material.dart';
import 'screens/account_screen.dart';
import 'screens/home_dashboard_screen.dart';
import 'screens/login_register_screen.dart';
import 'screens/mongolia_map_screen.dart';
import 'screens/quick_controls_screen.dart';
import 'screens/trips_stations_screen.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';
import 'utils/app_strings.dart';

void main() {
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
  int _activeTabIndex =
      0; // 0: Home, 1: Map, 2: Quick Controls, 3: Stations, 4: Account

  bool get _isLoggedIn => _auth.isSignedIn;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    await _auth.restoreSession();
    await _screenshotSignIn();
    if (mounted) {
      setState(() {
        _bootstrapping = false;
        if (shotTab >= 0 && shotTab <= 4) _activeTabIndex = shotTab;
      });
    }
  }

  /// TEMPORARY screenshot scaffolding — remove before shipping.
  ///
  /// `Platform.environment` is empty on iOS, so these come in as compile-time
  /// defines instead: `--dart-define=SCREENSHOT_EMAIL=... SCREENSHOT_TAB=2`.
  static const String _shotEmail = String.fromEnvironment('SCREENSHOT_EMAIL');
  static const String _shotPassword = String.fromEnvironment(
    'SCREENSHOT_PASSWORD',
  );
  static const int shotTab = int.fromEnvironment('SCREENSHOT_TAB', defaultValue: -1);

  Future<void> _screenshotSignIn() async {
    if (_auth.isSignedIn) return;
    if (_shotEmail.isEmpty || _shotPassword.isEmpty) return;
    try {
      await _auth.signIn(identifier: _shotEmail, password: _shotPassword);
    } catch (e) {
      debugPrint('SCREENSHOT: sign-in failed: $e');
    }
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
    if (mounted) setState(() => _activeTabIndex = 0);
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    if (_bootstrapping) return const _BootSplash();

    if (!_isLoggedIn) {
      return LoginRegisterScreen(
        authService: widget.authService,
        onLoginSuccess: () => setState(() {}),
      );
    }

    final List<Widget> pages = [
      HomeDashboardScreen(
        onNavigateToQuickControls: () {
          setState(() => _activeTabIndex = 2);
        },
      ),
      MongoliaMapScreen(onOpenQrScanner: () => _openQrScannerModal(context)),
      const QuickControlsScreen(),
      const TripsStationsScreen(),
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
              const SizedBox(width: 10),
              _AppBarAction(
                icon: Icons.logout_rounded,
                tooltip: AppStrings.get('logout'),
                onPressed: _confirmLogout,
              ),
            ],
          ),
        ),
      ),

      body: IndexedStack(index: _activeTabIndex, children: pages),

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

  Widget _buildBottomNavItem(int index, IconData icon, String label) {
    final bool isSelected = _activeTabIndex == index;
    final AppPalette palette = context.palette;

    // The selected pill needs more room than the icon-only items so its
    // label is never clipped.
    return Expanded(
      flex: isSelected ? 2 : 1,
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

/// Shown for the moment it takes to check for a saved session.
class _BootSplash extends StatelessWidget {
  const _BootSplash();

  /// Matches the `backgroundColor` of `LaunchScreen.storyboard`, and the
  /// backdrop the badge artwork was feathered onto. Handing over from the
  /// native launch screen to Flutter is meant to be invisible; using the theme
  /// palette here instead made the app blink from one splash to another.
  static const Color launchBackground = Color(0xFF1A2028);

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: launchBackground,
      child: Center(
        child: Image(
          image: AssetImage('assets/images/logo_badge.png'),
          width: 180,
          height: 180,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}
