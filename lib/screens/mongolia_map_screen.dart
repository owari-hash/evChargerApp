import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/ocpp_mock_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';

class MongoliaMapScreen extends StatefulWidget {
  final VoidCallback onOpenQrScanner;

  const MongoliaMapScreen({
    super.key,
    required this.onOpenQrScanner,
  });

  @override
  State<MongoliaMapScreen> createState() => _MongoliaMapScreenState();
}

class _MongoliaMapScreenState extends State<MongoliaMapScreen> {
  final OcppMockService _service = OcppMockService.instance;
  final MapController _mapController = MapController();

  StreamSubscription<Position>? _positionStreamSub;
  LatLng _userPosition = const LatLng(47.9130, 106.9140); // Ulaanbaatar default GPS
  double _userSpeedKmH = 0.0;
  bool _isGpsPermissionGranted = false;

  String _searchQuery = '';
  int _selectedStationIndex = 0;
  bool _isNavigatingRoute = false;
  Timer? _simulatedNavTimer;

  @override
  void initState() {
    super.initState();
    _initUserGpsLocation();
  }

  Future<void> _initUserGpsLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        setState(() => _isGpsPermissionGranted = true);

        // Get current initial GPS position
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        setState(() {
          _userPosition = LatLng(pos.latitude, pos.longitude);
        });

        // Listen to live continuous real-time GPS updates
        _positionStreamSub = Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((Position pos) {
          setState(() {
            _userPosition = LatLng(pos.latitude, pos.longitude);
            _userSpeedKmH = (pos.speed * 3.6).clamp(0.0, 120.0);
          });

          if (_isNavigatingRoute) {
            _mapController.move(_userPosition, 16.0);
          }
        });
      }
    } catch (e) {
      debugPrint('GPS Location error: $e');
    }
  }

  void _startSimulatedNavigation(LatLng destination) {
    _simulatedNavTimer?.cancel();
    setState(() {
      _isNavigatingRoute = true;
    });

    _mapController.move(_userPosition, 16.0);

    // Dynamic animated movement towards charging station for testing navigation
    _simulatedNavTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isNavigatingRoute) {
        timer.cancel();
        return;
      }

      final double newLat = _userPosition.latitude + (destination.latitude - _userPosition.latitude) * 0.08;
      final double newLng = _userPosition.longitude + (destination.longitude - _userPosition.longitude) * 0.08;

      setState(() {
        _userPosition = LatLng(newLat, newLng);
        _userSpeedKmH = 42.0;
      });

      _mapController.move(_userPosition, 16.0);

      final double distanceMeters = Geolocator.distanceBetween(
        _userPosition.latitude,
        _userPosition.longitude,
        destination.latitude,
        destination.longitude,
      );

      if (distanceMeters < 20) {
        timer.cancel();
        setState(() {
          _isNavigatingRoute = false;
          _userSpeedKmH = 0.0;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Цэнэглэх станцад хүрч ирлээ! QR кодыг уншуулна уу.'),
              backgroundColor: AppTheme.sageGreen,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    });
  }

  void _zoomIn() {
    final double currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom + 0.5);
  }

  void _zoomOut() {
    final double currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom - 0.5);
  }

  void _centerDriverLocation() {
    _mapController.move(_userPosition, 15.5);
  }

  Future<void> _launchExternalGpsNavigation(double lat, double lng) async {
    final Uri googleMapsUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Чиглэл авч байна: $lat, $lng'),
            backgroundColor: AppTheme.sageGreen,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    _simulatedNavTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stations = _service.nearbyStations.where((st) {
      if (_searchQuery.isEmpty) return true;
      return st.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          st.address.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    final activeStation = stations.isNotEmpty
        ? stations[_selectedStationIndex % stations.length]
        : _service.nearbyStations.first;

    final LatLng destinationPos = LatLng(activeStation.latitude, activeStation.longitude);

    final double navDistanceKm = (Geolocator.distanceBetween(
      _userPosition.latitude,
      _userPosition.longitude,
      destinationPos.latitude,
      destinationPos.longitude,
    ) / 1000.0);

    return Scaffold(
      backgroundColor: AppTheme.softBg,
      body: Stack(
        children: [
          // 1. Real Interactive OpenStreetMap Layer with Real-Time User Position & Polyline
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: destinationPos,
              initialZoom: 14.0,
              minZoom: 5.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                tileProvider: NetworkTileProvider(
                  headers: {'User-Agent': 'ZevChargerApp/1.0 (contact@zevcharger.mn)'},
                ),
              ),

              // Live Navigation Dynamic Route Polyline
              if (_isNavigatingRoute)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [
                        _userPosition,
                        LatLng(
                          (_userPosition.latitude + destinationPos.latitude) / 2,
                          _userPosition.longitude,
                        ),
                        destinationPos,
                      ],
                      strokeWidth: 6.0,
                      color: AppTheme.sageGreen,
                    ),
                  ],
                ),

              // Markers Layer (Live Driver Position & Ulaanbaatar Stations)
              MarkerLayer(
                markers: [
                  // Live User Real GPS Vehicle Position Marker
                  Marker(
                    point: _userPosition,
                    width: 50,
                    height: 50,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.darkForest,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.sageGreen.withOpacity(0.6),
                            blurRadius: 12,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.navigation_rounded,
                        color: AppTheme.sageGreen,
                        size: 26,
                      ),
                    ),
                  ),

                  // Real Station Pin Markers in Ulaanbaatar
                  ...List.generate(_service.nearbyStations.length, (index) {
                    final station = _service.nearbyStations[index];
                    final LatLng pos = LatLng(station.latitude, station.longitude);
                    final bool isSelected = (_selectedStationIndex % _service.nearbyStations.length) == index;

                    return Marker(
                      point: pos,
                      width: isSelected ? 120 : 80,
                      height: isSelected ? 70 : 50,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedStationIndex = index;
                          });
                          _mapController.move(pos, 15.0);
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.darkForest : AppTheme.cardWhite,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black26, blurRadius: 4),
                                ],
                              ),
                              child: Text(
                                station.name.split(' ').first,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Colors.white : AppTheme.darkForest,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: EdgeInsets.all(isSelected ? 8 : 6),
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.sageGreen : AppTheme.darkForest,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: isSelected ? AppTheme.sageGreen.withOpacity(0.5) : Colors.black26,
                                    blurRadius: isSelected ? 10 : 4,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.ev_station_rounded, color: Colors.white, size: 16),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),

          // 2. Real-Time Turn-by-Turn Navigation Live HUD Bar (When Active)
          if (_isNavigatingRoute)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.darkForest,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: AppTheme.sageGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.turn_right_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '500 м дараа баруун тийш эргэнэ үү',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${activeStation.name} • ${navDistanceKm.toStringAsFixed(1)} км (${_userSpeedKmH.toInt()} км/ц)',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () {
                        setState(() {
                          _isNavigatingRoute = false;
                        });
                        _simulatedNavTimer?.cancel();
                      },
                    ),
                  ],
                ),
              ),
            )
          else
            // Standard Header & Search Bar Overlay
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.cardWhite,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
                        ],
                      ),
                      child: TextField(
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: 'Улаанбаатар дахь цэнэглэгч хайх...',
                          hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                          prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.darkForest),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: () {
                      setState(() {
                        AppStrings.currentLanguage =
                            AppStrings.currentLanguage == AppLanguage.mn
                                ? AppLanguage.en
                                : AppLanguage.mn;
                      });
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: AppTheme.cardWhite,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
                        ],
                      ),
                      child: Text(
                        AppStrings.currentLanguage == AppLanguage.mn ? '🇲🇳' : '🇬🇧',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 3. Floating Map Controls Bar (Right Side)
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 80,
            child: Column(
              children: [
                _buildMapControlBtn(
                  icon: Icons.add_rounded,
                  tooltip: 'Zoom In',
                  onTap: _zoomIn,
                ),
                const SizedBox(height: 8),
                _buildMapControlBtn(
                  icon: Icons.remove_rounded,
                  tooltip: 'Zoom Out',
                  onTap: _zoomOut,
                ),
                const SizedBox(height: 8),
                _buildMapControlBtn(
                  icon: Icons.my_location_rounded,
                  tooltip: 'My Location',
                  onTap: _centerDriverLocation,
                ),
              ],
            ),
          ),

          // 4. Bottom Active Station Card & Navigation Actions
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Active Station Preview Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardWhite,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.lightSage,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.ev_station_rounded, color: AppTheme.sageGreen, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  activeStation.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.darkForest,
                                  ),
                                ),
                                Text(
                                  activeStation.address,
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${navDistanceKm.toStringAsFixed(1)} км',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.sageGreen,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.darkForest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${activeStation.kwSpeed.toInt()} кВт Супер',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${activeStation.availableConnectors}/${activeStation.totalConnectors} Сул байна',
                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                          const Spacer(),
                          Text(
                            '₮${activeStation.pricePerKwh.toInt()}/кВт.ц',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.darkForest,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Navigation & Launch Options Dual Action Buttons
                Row(
                  children: [
                    // Start Real-Time Turn-by-Turn Route Guidance
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _startSimulatedNavigation(destinationPos);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.sageGreen,
                            foregroundColor: Colors.white,
                            elevation: 4,
                          ),
                          icon: const Icon(Icons.navigation_rounded, size: 20),
                          label: Text(
                            _isNavigatingRoute ? 'НАВИГАЦИ ЯВАГДАЖ БАЙНА' : 'ЧИГЛЭЛ ЭХЛҮҮЛЭХ',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Launch External Google / Apple Maps GPS
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          _launchExternalGpsNavigation(
                            activeStation.latitude,
                            activeStation.longitude,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.darkForest,
                          foregroundColor: Colors.white,
                          elevation: 4,
                        ),
                        child: const Icon(Icons.map_rounded, size: 20, color: AppTheme.sageGreen),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapControlBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(
          color: AppTheme.cardWhite,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
          ],
        ),
        child: Icon(icon, color: AppTheme.darkForest, size: 20),
      ),
    );
  }
}
