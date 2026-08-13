import 'package:flutter/material.dart';
import 'screens/home_dashboard_screen.dart';
import 'screens/login_register_screen.dart';
import 'screens/mongolia_map_screen.dart';
import 'screens/quick_controls_screen.dart';
import 'screens/trips_stations_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const EvChargerApp());
}

class EvChargerApp extends StatelessWidget {
  const EvChargerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zev Charger',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const MainAppFrame(),
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
  int _activeTabIndex = 0; // 0: Home, 1: Mongolia Map, 2: Quick Controls, 3: Stations

  void _openQrScannerModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const TripsStationsScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
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
      MongoliaMapScreen(
        onOpenQrScanner: () => _openQrScannerModal(context),
      ),
      const QuickControlsScreen(),
      const TripsStationsScreen(),
    ];

    return Scaffold(
      backgroundColor: AppTheme.softBg,

      // Clean Top Header App Bar
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          color: AppTheme.softBg,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 6,
            left: 20,
            right: 20,
            bottom: 6,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Brand Title & Online Status
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.darkForest,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.darkForest.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.bolt_rounded, color: AppTheme.sageGreen, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'ZEV CHARGER',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.darkForest,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppTheme.sageGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Онлайн',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),

              // Logout Action Icon
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardWhite,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: IconButton(
                  icon: const Icon(Icons.logout_rounded, color: AppTheme.darkForest, size: 20),
                  onPressed: () {
                    setState(() => _isLoggedIn = false);
                  },
                  tooltip: 'Гарах',
                ),
              ),
            ],
          ),
        ),
      ),

      body: IndexedStack(
        index: _activeTabIndex,
        children: pages,
      ),

      // Floating Bottom Navigation Bar (Full rounded with space on all sides)
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 16, top: 4),
          child: Container(
            height: 66,
            decoration: BoxDecoration(
              color: AppTheme.darkForest,
              borderRadius: BorderRadius.circular(36),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.darkForest.withValues(alpha: 0.35),
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
                _buildBottomNavItem(0, Icons.home_rounded, 'Нүүр'),
                _buildBottomNavItem(1, Icons.map_rounded, 'Газрын зураг'),
                _buildBottomNavItem(2, Icons.tune_rounded, 'Удирдлага'),
                _buildBottomNavItem(3, Icons.ev_station_rounded, 'Станц'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem(int index, IconData icon, String label) {
    final bool isSelected = _activeTabIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTabIndex = index),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.sageGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(28),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.sageGreen.withValues(alpha: 0.4),
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
                color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6),
              ),
              if (isSelected) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
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
