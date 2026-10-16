import 'dart:convert';

import 'package:evchargerapp/models/station.dart';
import 'package:evchargerapp/services/api_client.dart';
import 'package:evchargerapp/services/session_store.dart';
import 'package:evchargerapp/services/stations_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

ApiClient _client(http.Response Function(http.Request request) handler) =>
    ApiClient(
      sessionStore: InMemorySessionStore(),
      httpClient: MockClient((http.Request r) async => handler(r)),
    );

http.Response _json(Map<String, dynamic> body, [int status = 200]) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: <String, String>{'content-type': 'application/json'},
    );

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
    test('starts empty rather than on invented stations', () {
      final StationsService service = StationsService();
      expect(service.stations.value, isEmpty);
    });

    test('a failed fetch keeps the list empty and says why', () async {
      final StationsService service = StationsService(
        client: _client((http.Request r) => _json(<String, dynamic>{
          'error': 'Сервертэй холбогдож чадсангүй',
        }, 503)),
      );
      await service.load();
      expect(service.stations.value, isEmpty);
      expect(service.error.value, isNotNull);
    });

    test('startCharging succeeds only on Accepted', () async {
      String status = 'Accepted';
      final StationsService service = StationsService(
        client: _client((http.Request r) {
          expect(r.url.path, endsWith('/stations/cp1/start'));
          expect(jsonDecode(r.body), <String, dynamic>{'connectorId': 2});
          return _json(<String, dynamic>{'status': status});
        }),
      );
      await service.startCharging('cp1', connectorId: 2);

      status = 'Rejected';
      await expectLater(
        service.startCharging('cp1', connectorId: 2),
        throwsA(isA<ApiException>()),
      );
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
      service.stations.value = <ChargingStationLocation>[
        ChargingStationLocation.fromJson(<String, dynamic>{
          'id': 'UB-005',
          'latitude': 47.9188,
          'longitude': 106.9176,
        })!,
        ChargingStationLocation.fromJson(<String, dynamic>{
          'id': 'ZAISAN',
          'latitude': 47.8864,
          'longitude': 106.9058,
        })!,
      ];
      service.reprojectDistances(latitude: 47.9188, longitude: 106.9177);

      // Measured from the square itself, its station is a few metres away.
      final ChargingStationLocation square = service.stations.value.firstWhere(
        (ChargingStationLocation s) => s.id == 'UB-005',
      );
      expect(square.distance, endsWith('м'));
      expect(square.distance, isNot(contains('км')));
    });
  });
}
