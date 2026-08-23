import 'package:evchargerapp/models/connector_types.dart';
import 'package:evchargerapp/models/ocpp_models.dart';
import 'package:evchargerapp/services/ocpp_mock_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StationFilter', () {
    test('an empty filter matches every station', () {
      expect(StationFilter.none.matches(<String>['CCS2']), isTrue);
      expect(StationFilter.none.matches(<String>[]), isTrue);
      expect(StationFilter.none.isActive, isFalse);
    });

    test('matches a station offering any one of the wanted plugs', () {
      const StationFilter filter = StationFilter(
        connectorTypes: <String>{'CHAdeMO', 'Type1'},
      );

      expect(filter.matches(<String>['CCS2', 'CHAdeMO']), isTrue);
      expect(filter.matches(<String>['CCS2', 'GBT']), isFalse);
    });

    test('plug codes compare case-insensitively', () {
      const StationFilter filter = StationFilter(
        connectorTypes: <String>{'ccs2'},
      );
      expect(filter.matches(<String>['CCS2']), isTrue);
    });

    test('a station with no plugs listed is excluded by a plug filter', () {
      const StationFilter filter = StationFilter(
        connectorTypes: <String>{'CCS2'},
      );
      expect(filter.matches(<String>[]), isFalse);
    });
  });

  group('CarBrand', () {
    test('every brand names plugs that exist', () {
      for (final CarBrand brand in CarBrand.all) {
        expect(brand.connectorTypes, isNotEmpty, reason: brand.name);
        for (final ConnectorType type in brand.connectorTypes) {
          expect(ConnectorType.fromCode(type.code), isNotNull);
        }
      }
    });

    test('picking a Japanese import selects CHAdeMO, not CCS2', () {
      // The JDM hybrids common in Ulaanbaatar charge on CHAdeMO.
      final CarBrand toyota = CarBrand.byName('Toyota')!;
      expect(toyota.connectorTypes, contains(ConnectorType.chademo));
      expect(toyota.connectorTypes, isNot(contains(ConnectorType.ccs2)));
    });

    test('picking a Chinese make selects GB/T', () {
      expect(
        CarBrand.byName('BYD')!.connectorTypes,
        contains(ConnectorType.gbt),
      );
    });
  });

  group('station data', () {
    test('every station lists at least one recognised plug', () {
      final service = OcppMockService.instance;
      expect(service.nearbyStations, isNotEmpty);

      for (final station in service.nearbyStations) {
        expect(station.connectorTypes, isNotEmpty, reason: station.name);
        for (final String code in station.connectorTypes) {
          expect(
            ConnectorType.fromCode(code),
            isNotNull,
            reason: '${station.name} lists unknown plug $code',
          );
        }
      }
    });

    test('a Toyota driver still has somewhere to charge', () {
      final service = OcppMockService.instance;
      final CarBrand toyota = CarBrand.byName('Toyota')!;
      final StationFilter filter = StationFilter(
        brand: toyota.name,
        connectorTypes: toyota.connectorTypes
            .map((ConnectorType t) => t.code)
            .toSet(),
      );

      final matches = service.nearbyStations
          .where((s) => filter.matches(s.connectorTypes))
          .toList();

      expect(matches, isNotEmpty);
    });
  });

  group('idle state after sign-in', () {
    test('nothing is charging until a session actually starts', () {
      final service = OcppMockService.instance;
      service.clearRemoteSession();

      // Regression: these held demo values, so every driver was greeted with a
      // charge in progress they had not started.
      expect(service.connectorStatuses[1], ConnectorStatus.available);
      expect(service.activePowerKw, 0.0);
      expect(service.totalEnergyKwh, 0.0);
      expect(service.activeStationName, isNull);
    });

    test('adopting a real session lights the dashboard up again', () {
      final service = OcppMockService.instance;
      service.adoptRemoteSession(
        transactionId: 42,
        stationName: 'Сүхбаатарын Талбай Станц',
        energyKwh: 18.4,
        powerKw: 120.0,
        socPercent: 71,
      );

      expect(service.connectorStatuses[1], ConnectorStatus.charging);
      expect(service.totalEnergyKwh, 18.4);
      expect(service.activePowerKw, 120.0);
      expect(service.batteryLevel, 71);
      expect(service.activeStationName, 'Сүхбаатарын Талбай Станц');

      service.clearRemoteSession();
    });
  });
}
