import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:evchargerapp/screens/mongolia_map_screen.dart';
import 'package:evchargerapp/services/route_service.dart';
import 'package:evchargerapp/utils/app_strings.dart';

void main() {
  setUp(() => LanguageController.set(AppLanguage.mn));

  group('Driving route parsing', () {
    // Trimmed shape of a real OSRM /route/v1/driving response.
    final Map<String, dynamic> ok = <String, dynamic>{
      'code': 'Ok',
      'routes': <dynamic>[
        <String, dynamic>{
          'distance': 4200.5,
          'duration': 540.0,
          'geometry': <String, dynamic>{
            'coordinates': <dynamic>[
              <dynamic>[106.9140, 47.9130],
              <dynamic>[106.9200, 47.9180],
              <dynamic>[106.9640, 47.9530],
            ],
          },
        },
      ],
    };

    test('reads geometry, distance and duration', () {
      final DrivingRoute? route = DrivingRoute.fromOsrmJson(ok);
      expect(route, isNotNull);
      expect(route!.points.length, 3);
      expect(route.distanceMeters, closeTo(4200.5, 0.01));
      expect(route.duration, const Duration(seconds: 540));
    });

    test('GeoJSON lon/lat order is not swapped', () {
      // The classic routing bug: GeoJSON is [lon, lat], LatLng is (lat, lon).
      final DrivingRoute route = DrivingRoute.fromOsrmJson(ok)!;
      expect(route.points.first.latitude, closeTo(47.9130, 0.0001));
      expect(route.points.first.longitude, closeTo(106.9140, 0.0001));
      expect(route.points.last.latitude, closeTo(47.9530, 0.0001));
    });

    test(
      'the route has real intermediate points, not just a straight line',
      () {
        final DrivingRoute route = DrivingRoute.fromOsrmJson(ok)!;
        expect(route.points.length, greaterThan(2));
      },
    );

    test('rejects error and empty responses', () {
      expect(
        DrivingRoute.fromOsrmJson(<String, dynamic>{'code': 'NoRoute'}),
        isNull,
      );
      expect(
        DrivingRoute.fromOsrmJson(<String, dynamic>{
          'code': 'Ok',
          'routes': <dynamic>[],
        }),
        isNull,
      );
    });

    test('request URL puts longitude before latitude, as OSRM expects', () {
      final Uri uri = RouteService.buildOsrmUri(
        const LatLng(47.9130, 106.9140),
        const LatLng(47.9530, 106.9640),
      );
      expect(uri.path, contains('106.914,47.913;106.964,47.953'));
      expect(uri.queryParameters['geometries'], 'geojson');
      expect(uri.queryParameters['overview'], 'full');
    });
  });

  group('Turn-by-turn guidance', () {
    test('compass headings cover all eight sectors', () {
      expect(compassLabel(0), 'хойш');
      expect(compassLabel(90), 'зүүн');
      expect(compassLabel(180), 'урагш');
      expect(compassLabel(270), 'баруун');
      expect(compassLabel(359), 'хойш');
      expect(compassLabel(-90), 'баруун');
    });

    test('guidance text changes with remaining distance', () {
      final String far = navigationInstruction(4200, 90);
      final String mid = navigationInstruction(640, 90);
      final String near = navigationInstruction(120, 90);
      final String arrived = navigationInstruction(10, 90);

      expect(far, contains('км'));
      expect(near, contains('120'));
      expect(arrived, 'Та очих газартаа ирлээ');
      expect(<String>{far, mid, near, arrived}.length, 4);
    });

    test('guidance names the direction of travel', () {
      expect(navigationInstruction(500, 0), contains('хойш'));
      expect(navigationInstruction(500, 180), contains('урагш'));
    });
  });

  group('Route start/stop control', () {
    test('the action button label reflects the route state', () {
      expect(routeActionLabelKey(isNavigating: false), 'start_route');
      expect(routeActionLabelKey(isNavigating: true), 'stop_route');
    });
  });
}
