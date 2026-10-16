import 'package:evchargerapp/models/connector_types.dart';
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
}
