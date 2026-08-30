import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/connector_types.dart';
import '../models/station.dart';
import '../services/ocpp_mock_service.dart';
import '../services/stations_service.dart';
import '../services/route_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import '../utils/money.dart';
import '../widgets/station_filter_sheet.dart';

/// Whether an incoming GPS fix is allowed to write the driver's position.
///
/// A simulated route owns that position while it runs. Letting real GPS fixes
/// write it at the same time snaps the driver back to their true location once
/// a second, so the route never advances and turn-by-turn appears frozen.
@visibleForTesting
bool gpsFixOwnsPosition({required bool isNavigatingRoute}) =>
    !isNavigatingRoute;

/// One step of the simulated drive: closes [fraction] of the remaining gap
/// between [from] and [to].
@visibleForTesting
LatLng stepTowardsDestination(LatLng from, LatLng to, double fraction) {
  return LatLng(
    from.latitude + (to.latitude - from.latitude) * fraction,
    from.longitude + (to.longitude - from.longitude) * fraction,
  );
}

/// Which label the primary route button shows. Extracted so the start/stop
/// behaviour is verifiable without driving the map widget.
@visibleForTesting
String routeActionLabelKey({required bool isNavigating}) =>
    isNavigating ? 'stop_route' : 'start_route';

/// Compass heading for a bearing in degrees, in the active language.
@visibleForTesting
String compassLabel(double bearing) {
  const List<String> keys = <String>[
    'dir_n',
    'dir_ne',
    'dir_e',
    'dir_se',
    'dir_s',
    'dir_sw',
    'dir_w',
    'dir_nw',
  ];
  final double normalised = (bearing % 360 + 360) % 360;
  return AppStrings.get(keys[(((normalised + 22.5) % 360) ~/ 45).toInt()]);
}

/// Guidance line for the navigation HUD, from the remaining distance and the
/// real bearing to the target. Replaces what used to be a fixed string.
@visibleForTesting
String navigationInstruction(double metres, double bearing) {
  final String heading = compassLabel(bearing);
  final String toward = AppStrings.get('toward');
  final String km = AppStrings.get('unit_km');
  final String m = AppStrings.get('unit_m');
  if (metres < 30) {
    return AppStrings.get('arrived_short');
  }
  if (metres < 300) {
    return '${metres.round()} $m · $toward $heading';
  }
  if (metres < 1000) {
    return '${(metres / 50).round() * 50} $m · $toward $heading';
  }
  return '${(metres / 1000).toStringAsFixed(1)} $km · $toward $heading';
}

class MongoliaMapScreen extends StatefulWidget {
  final VoidCallback onOpenQrScanner;

  const MongoliaMapScreen({super.key, required this.onOpenQrScanner});

  @override
  State<MongoliaMapScreen> createState() => _MongoliaMapScreenState();
}

class _MongoliaMapScreenState extends State<MongoliaMapScreen> {
  final OcppMockService _service = OcppMockService.instance;
  final MapController _mapController = MapController();

  StreamSubscription<Position>? _positionStreamSub;
  LatLng _userPosition = const LatLng(
    47.9130,
    106.9140,
  ); // Ulaanbaatar default GPS
  double _userSpeedKmH = 0.0;
  bool _isGpsPermissionGranted = false;

  String _searchQuery = '';
  String? _selectedStationId;
  StationFilter _filter = StationFilter.none;

  /// Destination the running route is actually driving to.
  LatLng? _navDestination;
  bool _isNavigatingRoute = false;
  DrivingRoute? _route;
  bool _routeLoading = false;
  String? _routeError;

  final StationsService _stations = StationsService.instance;

  @override
  void initState() {
    super.initState();
    _stations.stations.addListener(_onStationsChanged);
    _stations.loading.addListener(_onStationsChanged);
    _initUserGpsLocation();
    // Draw the fallback immediately, then swap in the live network. Waiting for
    // the fetch would open the map on empty tiles.
    _stations.load();
  }

  void _onStationsChanged() {
    if (mounted) setState(() {});
  }

  /// Shown when the network could not be reached and there is nothing to map.
  Widget _buildEmptyState(BuildContext context) {
    final AppPalette palette = context.palette;
    return Container(
      color: palette.bg,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.ev_station_outlined,
                size: 56,
                color: palette.inkMuted,
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.get('stations_empty_title'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: palette.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _stations.error.value ?? AppStrings.get('stations_empty_body'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: palette.inkMuted),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _stations.loading.value
                    ? null
                    : () => _stations.load(force: true),
                child: Text(
                  _stations.loading.value
                      ? AppStrings.get('loading')
                      : AppStrings.get('retry'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _initUserGpsLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        setState(() => _isGpsPermissionGranted = true);

        // Get current initial GPS position
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        setState(() {
          _userPosition = LatLng(pos.latitude, pos.longitude);
        });

        // Refetch from where the driver actually is, so the list comes back
        // distance-sorted rather than in the server's default order.
        unawaited(
          _stations.load(
            latitude: _userPosition.latitude,
            longitude: _userPosition.longitude,
            force: true,
          ),
        );

        // Listen to live continuous real-time GPS updates
        _positionStreamSub =
            Geolocator.getPositionStream(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                distanceFilter: 5,
              ),
            ).listen((Position pos) {
              if (!mounted) return;
              setState(() {
                _userPosition = LatLng(pos.latitude, pos.longitude);
                _userSpeedKmH = (pos.speed * 3.6).clamp(0.0, 200.0);
              });
              _stations.reprojectDistances(
                latitude: _userPosition.latitude,
                longitude: _userPosition.longitude,
              );

              if (_isNavigatingRoute) {
                // Follow the driver rather than driving the map ourselves.
                _mapController.move(_userPosition, _mapController.camera.zoom);
                _checkArrival();
              }
            });
      }
    } catch (e) {
      debugPrint('GPS Location error: $e');
    }
  }

  /// Starts guidance to [destination]: fetches the real driving route and
  /// then follows the driver's own GPS along it.
  ///
  /// This used to animate the car towards the destination on a timer, which
  /// looked like navigation but ignored where the driver actually was.
  Future<void> _startNavigation(LatLng destination) async {
    setState(() {
      _isNavigatingRoute = true;
      _navDestination = destination;
      _route = null;
      _routeError = null;
      _routeLoading = true;
    });

    _mapController.move(_userPosition, 15.0);

    try {
      final DrivingRoute route = await RouteService.fetchDrivingRoute(
        _userPosition,
        destination,
      );
      if (!mounted || !_isNavigatingRoute) return;
      setState(() {
        _route = route;
        _routeLoading = false;
      });
      _fitRoute(route);
    } on RouteUnavailable catch (e) {
      debugPrint('Route lookup failed: $e');
      if (!mounted) return;
      // Guidance still works from bearing and distance; only the road
      // geometry is missing.
      setState(() {
        _routeLoading = false;
        _routeError = AppStrings.get('route_unavailable');
      });
    }
  }

  /// Frames the whole route so the driver can see where they are going.
  void _fitRoute(DrivingRoute route) {
    if (route.points.length < 2) return;
    try {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(route.points),
          padding: const EdgeInsets.fromLTRB(48, 120, 48, 260),
        ),
      );
    } catch (e) {
      debugPrint('Could not fit route bounds: $e');
    }
  }

  /// Ends guidance once the driver reaches the charger.
  void _checkArrival() {
    final LatLng? target = _navDestination;
    if (target == null) return;

    final double metres = Geolocator.distanceBetween(
      _userPosition.latitude,
      _userPosition.longitude,
      target.latitude,
      target.longitude,
    );
    if (metres > 30) return;

    _stopSimulatedNavigation();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings.get('arrived_full')),
        backgroundColor: AppTheme.sageGreen,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String _navigationInstruction(LatLng from, LatLng to) {
    final double metres = Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
    final double bearing = Geolocator.bearingBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );
    return navigationInstruction(metres, bearing);
  }

  /// Ends the running route and clears everything it owns.
  void _stopSimulatedNavigation() {
    if (!mounted) return;
    setState(() {
      _isNavigatingRoute = false;
      _navDestination = null;
      _route = null;
      _routeError = null;
      _routeLoading = false;
      _userSpeedKmH = 0.0;
    });
  }

  /// Stations matching the search box and [filter], in map order.
  List<ChargingStationLocation> _stationsMatching(StationFilter filter) {
    final String query = _searchQuery.trim().toLowerCase();
    return _service.nearbyStations.where((ChargingStationLocation st) {
      if (!filter.matches(st.connectorTypes)) return false;
      if (query.isEmpty) return true;
      return st.name.toLowerCase().contains(query) ||
          st.address.toLowerCase().contains(query);
    }).toList();
  }

  /// Straight-line kilometres from the driver to a station.
  double _distanceKmTo(ChargingStationLocation station) {
    return const Distance().as(
          LengthUnit.Meter,
          _userPosition,
          LatLng(station.latitude, station.longitude),
        ) /
        1000.0;
  }

  /// Opens the filter sheet, then jumps to the closest station that matches.
  Future<void> _openFilterSheet() async {
    final StationFilter before = _filter;
    final StationFilter? applied = await showModalBottomSheet<StationFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => StationFilterSheet(
        initial: _filter,
        matchCount: (StationFilter candidate) =>
            _stationsMatching(candidate).length,
        // Keep the map behind the sheet in step with what is being chosen.
        onChanged: (StationFilter live) => setState(() => _filter = live),
      ),
    );

    if (!mounted) return;
    if (applied == null) {
      // Dismissed rather than applied. The live preview is rolled back, so
      // backing out can never strand the driver on an empty map.
      setState(() => _filter = before);
      return;
    }
    setState(() => _filter = applied);
    _goToNearestMatch();
  }

  /// Selects and centres the nearest station passing the current filter.
  void _goToNearestMatch() {
    final List<ChargingStationLocation> matches = _stationsMatching(_filter);
    if (matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.get('filter_none_match'))),
      );
      return;
    }

    matches.sort(
      (ChargingStationLocation a, ChargingStationLocation b) =>
          _distanceKmTo(a).compareTo(_distanceKmTo(b)),
    );
    final ChargingStationLocation nearest = matches.first;
    final LatLng pos = LatLng(nearest.latitude, nearest.longitude);

    setState(() {
      _selectedStationId = nearest.id;
      if (_isNavigatingRoute) _navDestination = pos;
    });
    _mapController.move(pos, 14.5);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppStrings.get('filter_nearest_found')
              .replaceFirst('{name}', nearest.name)
              .replaceFirst(
                '{distance}',
                _distanceKmTo(nearest).toStringAsFixed(1),
              ),
        ),
      ),
    );
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
    final Uri googleMapsUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppStrings.get('getting_directions')}: $lat, $lng',
            ),
            backgroundColor: AppTheme.sageGreen,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    _stations.stations.removeListener(_onStationsChanged);
    _stations.loading.removeListener(_onStationsChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<ChargingStationLocation> all = _service.nearbyStations;

    // Nothing to centre on, select or navigate to. Every readout below reads
    // off a station, so bail out to an explicit empty state rather than
    // indexing into an empty list.
    if (all.isEmpty) return _buildEmptyState(context);

    final stations = _stationsMatching(_filter);

    final ChargingStationLocation activeStation = stations.firstWhere(
      (st) => st.id == _selectedStationId,
      orElse: () => stations.isNotEmpty ? stations.first : all.first,
    );

    final LatLng destinationPos = LatLng(
      activeStation.latitude,
      activeStation.longitude,
    );

    // While a route runs, every readout follows the route's own destination so
    // the HUD can't disagree with where the car is actually heading.
    final LatLng routeTarget = _isNavigatingRoute
        ? (_navDestination ?? destinationPos)
        : destinationPos;

    final double navDistanceMeters = Geolocator.distanceBetween(
      _userPosition.latitude,
      _userPosition.longitude,
      routeTarget.latitude,
      routeTarget.longitude,
    );
    final double navDistanceKm = navDistanceMeters / 1000.0;
    // While the road route is being fetched, say so; if routing failed, say
    // that too rather than pretending the bearing line is a road route.
    final String navInstruction = _routeLoading
        ? AppStrings.get('route_loading')
        : (_routeError ?? _navigationInstruction(_userPosition, routeTarget));

    return Scaffold(
      backgroundColor: context.palette.bg,
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
                  headers: {
                    'User-Agent': 'EplugApp/1.0 (contact@eplug.mn)',
                  },
                ),
              ),

              // Live Navigation Dynamic Route Polyline
              if (_isNavigatingRoute)
                PolylineLayer(
                  polylines: [
                    // Real road geometry when we have it; a direct line only
                    // as a fallback while it loads or if routing is down.
                    Polyline(
                      points:
                          _route?.points ??
                          <LatLng>[_userPosition, routeTarget],
                      strokeWidth: 6.0,
                      color: _route == null
                          ? AppTheme.sageGreen.withValues(alpha: 0.45)
                          : AppTheme.sageGreen,
                      borderStrokeWidth: _route == null ? 0 : 2,
                      borderColor: Colors.white,
                    ),
                  ],
                ),

              // Markers Layer (Live Driver Position & Ulaanbaatar Stations)
              MarkerLayer(
                markers: [
                  // Live driver position — drawn only once GPS has actually
                  // reported. Without permission `_userPosition` is just the
                  // Ulaanbaatar default, and pinning the driver to the city
                  // centre is worse than showing no pin at all.
                  if (_isGpsPermissionGranted)
                    Marker(
                      point: _userPosition,
                      width: 50,
                      height: 50,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: context.palette.panel,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.sageGreen.withValues(alpha: 0.6),
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
                  ...List.generate(stations.length, (index) {
                    final station = stations[index];
                    final LatLng pos = LatLng(
                      station.latitude,
                      station.longitude,
                    );
                    final bool isSelected = station.id == activeStation.id;

                    return Marker(
                      point: pos,
                      width: isSelected ? 130 : 92,
                      height: isSelected ? 74 : 58,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedStationId = station.id;
                            // Picking a new pin mid-route retargets the route
                            // rather than leaving it driving to the old one.
                            if (_isNavigatingRoute) {
                              _navDestination = pos;
                            }
                          });
                          _mapController.move(pos, 15.0);
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? context.palette.panel
                                    : context.palette.card,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Text(
                                station.name.split(' ').first,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? Colors.white
                                      : context.palette.ink,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: EdgeInsets.all(isSelected ? 8 : 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.sageGreen
                                    : context.palette.panel,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: isSelected
                                        ? AppTheme.sageGreen.withValues(
                                            alpha: 0.5,
                                          )
                                        : Colors.black26,
                                    blurRadius: isSelected ? 10 : 4,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.ev_station_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
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
                  color: context.palette.panel,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
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
                      child: const Icon(
                        Icons.turn_right_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            navInstruction,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${activeStation.name} • ${navDistanceKm.toStringAsFixed(1)} ${AppStrings.get('unit_km')} (${_userSpeedKmH.toInt()} ${AppStrings.get('unit_kmh')})',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                      tooltip: AppStrings.get('stop_route'),
                      onPressed: _stopSimulatedNavigation,
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
                        color: context.palette.card,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: InputDecoration(
                          hintText: AppStrings.get('search_stations'),
                          hintStyle: TextStyle(
                            color: context.palette.inkMuted,
                            fontSize: 13,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: context.palette.ink,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
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
                      decoration: BoxDecoration(
                        color: context.palette.card,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        AppStrings.currentLanguage == AppLanguage.mn
                            ? 'МН'
                            : 'EN',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: context.palette.ink,
                          letterSpacing: 0.5,
                        ),
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
                const SizedBox(height: 8),
                _buildMapControlBtn(
                  icon: Icons.tune_rounded,
                  tooltip: AppStrings.get('filter_title'),
                  onTap: _openFilterSheet,
                  badge: _filter.activeCount,
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
                    color: context.palette.card,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
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
                              color: context.palette.accent.withValues(
                                alpha: 0.16,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.ev_station_rounded,
                              color: AppTheme.sageGreen,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  activeStation.name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: context.palette.ink,
                                  ),
                                ),
                                Text(
                                  activeStation.address,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.palette.inkMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${navDistanceKm.toStringAsFixed(1)} ${AppStrings.get('unit_km')}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.sageGreen,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // A Wrap rather than a Row: the power badge and the price
                      // together already fill a 393pt card, and once the price
                      // carries decimals they no longer fit on one line. Every
                      // item here is information a driver is choosing on, so
                      // the line breaks rather than any of them ellipsising.
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: context.palette.panel,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${activeStation.kwSpeed.toInt()} ${AppStrings.get('kw_super')}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            '${activeStation.availableConnectors}/${activeStation.totalConnectors} ${AppStrings.get('available')}',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.palette.inkMuted,
                            ),
                          ),
                          Text(
                            '${formatMntLeading(activeStation.pricePerKwh)}/кВт.ц',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: context.palette.ink,
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
                          // Tapping this while a route ran used to restart it,
                          // and the only way out was a small X in the HUD.
                          onPressed: _isNavigatingRoute
                              ? _stopSimulatedNavigation
                              : () => _startNavigation(destinationPos),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isNavigatingRoute
                                ? AppTheme.errorRed
                                : AppTheme.sageGreen,
                            foregroundColor: Colors.white,
                            elevation: 4,
                          ),
                          icon: Icon(
                            _isNavigatingRoute
                                ? Icons.stop_rounded
                                : Icons.navigation_rounded,
                            size: 20,
                          ),
                          label: Text(
                            AppStrings.get(
                              routeActionLabelKey(
                                isNavigating: _isNavigatingRoute,
                              ),
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
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
                          backgroundColor: context.palette.panel,
                          foregroundColor: Colors.white,
                          elevation: 4,
                        ),
                        child: const Icon(
                          Icons.map_rounded,
                          size: 20,
                          color: AppTheme.sageGreen,
                        ),
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
    int badge = 0,
  }) {
    final AppPalette palette = context.palette;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: badge > 0 ? palette.panel : palette.card,
                shape: BoxShape.circle,
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: badge > 0 ? palette.onPanel : palette.ink,
                size: 20,
              ),
            ),
            // How many plugs the map is narrowed to, so an active filter is
            // obvious without opening the sheet.
            if (badge > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 17,
                  height: 17,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: palette.accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: palette.card, width: 1.5),
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
