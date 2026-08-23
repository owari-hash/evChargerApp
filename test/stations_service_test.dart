import 'package:evchargerapp/models/station.dart';
import 'package:evchargerapp/services/stations_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChargingStationLocation.fromJson', () {
    Map<String, dynamic> station(Map<String, dynamic> overrides) =>
        <String, dynamic>{
          'id': 'CP-UB-001',
          'name': 'Шангри-Ла',
          'address': 'Сүхбаатар дүүрэг',
          'latitude': 47.915,
          'longitude': 106.9205,
          'tariffPerKwh': 450,
          'maxPowerKw': 180,
          'totalConnectors': 4,
          'availableConnectors': 3,
          'connectorTypes': <String>['CCS2', 'Type2'],
          'isOnline': true,
          ...overrides,
        };

    test('maps a live charge point onto what the widgets read', () {
      final ChargingStationLocation? parsed = ChargingStationLocation.fromJson(
        station(<String, dynamic>{'distanceKm': 2.4}),
      );

      expect(parsed, isNotNull);
      expect(parsed!.id, 'CP-UB-001');
      expect(parsed.name, 'Шангри-Ла');
      expect(parsed.kwSpeed, 180);
      expect(parsed.pricePerKwh, 450);
      expect(parsed.availableConnectors, 3);
      expect(parsed.totalConnectors, 4);
      expect(parsed.connectorTypes, <String>['CCS2', 'Type2']);
      expect(parsed.isOnline, isTrue);
      // The start endpoint is keyed by station id, so the QR must carry it.
      expect(parsed.qrCode, 'CP-UB-001');
      expect(parsed.distance, '2.4 км');
    });

    test('drops charge points that carry no coordinates', () {
      final ChargingStationLocation? parsed = ChargingStationLocation.fromJson(
        station(<String, dynamic>{'latitude': null, 'longitude': null}),
      );
      expect(parsed, isNull);
    });

    test('drops placeholder coordinates outside the service area', () {
      // The real CSMS record that prompted this guard: lat 1, lng 2, which is
      // open ocean off West Africa.
      expect(
        ChargingStationLocation.fromJson(
          station(<String, dynamic>{'latitude': 1, 'longitude': 2}),
        ),
        isNull,
      );
      expect(
        ChargingStationLocation.fromJson(
          station(<String, dynamic>{'latitude': 0, 'longitude': 0}),
        ),
        isNull,
      );
      expect(
        ChargingStationLocation.fromJson(
          station(<String, dynamic>{'latitude': 120, 'longitude': 500}),
        ),
        isNull,
      );
    });

    test('keeps stations across Mongolia, not just Ulaanbaatar', () {
      // Ölgii in the far west and Choibalsan in the east both have to survive.
      for (final List<double> point in <List<double>>[
        <double>[48.9683, 89.9628],
        <double>[48.0956, 114.5350],
      ]) {
        expect(
          ChargingStationLocation.fromJson(
            station(<String, dynamic>{
              'latitude': point[0],
              'longitude': point[1],
            }),
          ),
          isNotNull,
          reason: 'expected \$point to be inside the service area',
        );
      }
    });

    test('falls back to the id when the name is blank', () {
      final ChargingStationLocation? parsed = ChargingStationLocation.fromJson(
        station(<String, dynamic>{'name': '   '}),
      );
      expect(parsed!.name, 'CP-UB-001');
    });

    test('leaves distance empty when the listing had no origin', () {
      final ChargingStationLocation? parsed = ChargingStationLocation.fromJson(
        station(<String, dynamic>{}),
      );
      expect(parsed!.distance, '');
    });

    test('shows metres below a kilometre', () {
      expect(ChargingStationLocation.formatDistance(0.34), '340 м');
      expect(ChargingStationLocation.formatDistance(1.0), '1.0 км');
      expect(ChargingStationLocation.formatDistance(12.35), '12.3 км');
    });

    test('reads numbers that arrive as strings', () {
      final ChargingStationLocation? parsed = ChargingStationLocation.fromJson(
        station(<String, dynamic>{
          'latitude': '47.915',
          'longitude': '106.9205',
          'tariffPerKwh': '450',
          'totalConnectors': '4',
        }),
      );
      expect(parsed!.latitude, closeTo(47.915, 0.0001));
      expect(parsed.pricePerKwh, 450);
      expect(parsed.totalConnectors, 4);
    });
  });

  group('StationsService', () {
    test('starts on the built-in fallback so the map is never blank', () {
      final StationsService service = StationsService();
      expect(service.isFallback, isTrue);
      expect(service.stations.value, isNotEmpty);
      expect(service.stations.value, StationsService.fallbackStations);
    });

    test('every fallback station is plottable and priced', () {
      for (final ChargingStationLocation s
          in StationsService.fallbackStations) {
        expect(
          ChargingStationLocation.isInServiceArea(s.latitude, s.longitude),
          isTrue,
        );
        expect(s.pricePerKwh, greaterThan(0));
        expect(s.totalConnectors, greaterThanOrEqualTo(s.availableConnectors));
        expect(s.connectorTypes, isNotEmpty);
      }
    });

    test('haversine measures a known Ulaanbaatar hop', () {
      // Sükhbaatar Square to Zaisan, about 3.9 km apart.
      final double km = StationsService.haversineKm(
        47.9188,
        106.9176,
        47.8864,
        106.9058,
      );
      expect(km, closeTo(3.8, 0.6));
      expect(StationsService.haversineKm(47.9, 106.9, 47.9, 106.9), 0);
    });

    test('reprojecting rewrites distances against a new origin', () {
      final StationsService service = StationsService();
      service.reprojectDistances(latitude: 47.9188, longitude: 106.9176);

      // Sükhbaatar Square itself is in the fallback list, so measuring from it
      // must put that station within a few metres.
      final ChargingStationLocation square = service.stations.value.firstWhere(
        (ChargingStationLocation s) => s.id == 'UB-005',
      );
      expect(square.distance, endsWith('м'));
      expect(square.distance, isNot(contains('км')));
    });
  });
}
