import 'package:flutter/material.dart';
import 'screens/home_dashboard_screen.dart';
import 'screens/login_register_screen.dart';
import 'screens/mongolia_map_screen.dart';
import 'screens/quick_controls_screen.dart';
import 'screens/trips_stations_screen.dart';
import 'theme/app_theme.dart';
import 'utils/app_strings.dart';

void main() {
  runApp(const EvChargerApp());
}

class EvChargerApp extends StatelessWidget {
  const EvChargerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.mode,
      builder: (BuildContext context, ThemeMode mode, Widget? _) {
        return ValueListenableBuilder<AppLanguage>(
          valueListenable: LanguageController.language,
          builder: (BuildContext context, AppLanguage _, Widget? __) {
            return MaterialApp(
              title: 'Zev Charger',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: mode,
              home: const MainAppFrame(),
            );
          },
        );
      },
    );
  }
}

class MainAppFrame extends StatefulWidget {
  const MainAppFrame({super.key});

  @override
  State<MainAppFrame> createState() => _MainAppFrameState();
}

class _MainAppFrameState extends State<MainAppFrame> {
  bool _isLoggedIn = false;
  int _activeTabIndex =
      0; // 0: Home, 1: Mongolia Map, 2: Quick Controls, 3: Stations

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

    if (shouldLogOut == true && mounted) {
      setState(() {
        _isLoggedIn = false;
        _activeTabIndex = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;

    if (!_isLoggedIn) {
      return LoginRegisterScreen(
        onLoginSuccess: () {
          setState(() {
            _isLoggedIn = true;
          });
        },
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
              Expanded(
                child: Text(
                  'ZEV CHARGER',
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
          _segment(context, 'MN', isMn, AppLanguage.mn),
          _segment(context, 'EN', !isMn, AppLanguage.en),
        ],
      ),
    );
  }

  Widget _segment(
    BuildContext context,
    String label,
    bool active,
    AppLanguage lang,
  ) {
    final AppPalette palette = context.palette;
    return Semantics(
      button: true,
      selected: active,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          LanguageController.set(lang);
          onChanged();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: active ? palette.panel : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: active ? palette.onPanel : palette.inkMuted,
            ),
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
