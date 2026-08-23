import '../utils/app_strings.dart';

/// Plug standards a station can offer.
///
/// The codes match `CONNECTOR_TYPES` in evChargerKiosk's `src/lib/types.ts`, so
/// a station's types mean the same thing in the app, on the website and in the
/// CSMS.
class ConnectorType {
  const ConnectorType._(this.code, this.label);

  /// The wire value, e.g. `CCS2`.
  final String code;

  /// What a driver calls it. Plug standards are not translated — a CCS2 socket
  /// is labelled CCS2 in every language — so this is the code plus its common
  /// nickname where one exists.
  final String label;

  static const ConnectorType ccs2 = ConnectorType._('CCS2', 'CCS2');
  static const ConnectorType type2 = ConnectorType._('Type2', 'Type 2');
  static const ConnectorType chademo = ConnectorType._('CHAdeMO', 'CHAdeMO');
  static const ConnectorType gbt = ConnectorType._('GBT', 'GB/T');
  static const ConnectorType type1 = ConnectorType._('Type1', 'Type 1');
  static const ConnectorType schuko = ConnectorType._('Schuko', 'Schuko');

  /// Ordered by how common they are on the Mongolian network.
  static const List<ConnectorType> all = <ConnectorType>[
    ccs2,
    gbt,
    chademo,
    type2,
    type1,
    schuko,
  ];

  static ConnectorType? fromCode(String code) {
    for (final ConnectorType type in all) {
      if (type.code.toLowerCase() == code.toLowerCase()) return type;
    }
    return null;
  }

  @override
  String toString() => code;
}

/// A car make, and the plugs its EVs actually charge on.
///
/// Picking a brand is a shortcut, not a separate filter: it selects the plugs
/// that brand uses, which the driver can then adjust. A driver who knows their
/// car has a GB/T socket can skip straight to the plug.
class CarBrand {
  const CarBrand(this.name, this.connectorTypes);

  final String name;
  final List<ConnectorType> connectorTypes;

  /// The makes actually on the road in Ulaanbaatar, commonest first: imported
  /// JDM hybrids on CHAdeMO, Chinese EVs on GB/T, European and Korean on CCS2.
  static const List<CarBrand> all = <CarBrand>[
    CarBrand('Toyota', <ConnectorType>[
      ConnectorType.chademo,
      ConnectorType.type1,
    ]),
    CarBrand('Lexus', <ConnectorType>[
      ConnectorType.chademo,
      ConnectorType.type1,
    ]),
    CarBrand('Nissan', <ConnectorType>[
      ConnectorType.chademo,
      ConnectorType.type1,
    ]),
    CarBrand('BYD', <ConnectorType>[ConnectorType.gbt, ConnectorType.ccs2]),
    CarBrand('Chery', <ConnectorType>[ConnectorType.gbt]),
    CarBrand('Changan', <ConnectorType>[ConnectorType.gbt]),
    CarBrand('Great Wall', <ConnectorType>[ConnectorType.gbt]),
    CarBrand('Tesla', <ConnectorType>[ConnectorType.ccs2, ConnectorType.type2]),
    CarBrand('Hyundai', <ConnectorType>[
      ConnectorType.ccs2,
      ConnectorType.type2,
    ]),
    CarBrand('Kia', <ConnectorType>[ConnectorType.ccs2, ConnectorType.type2]),
    CarBrand('BMW', <ConnectorType>[ConnectorType.ccs2, ConnectorType.type2]),
    CarBrand('Volkswagen', <ConnectorType>[
      ConnectorType.ccs2,
      ConnectorType.type2,
    ]),
    CarBrand('Mercedes-Benz', <ConnectorType>[
      ConnectorType.ccs2,
      ConnectorType.type2,
    ]),
    CarBrand('Chevrolet', <ConnectorType>[
      ConnectorType.ccs2,
      ConnectorType.type1,
    ]),
  ];

  static CarBrand? byName(String name) {
    for (final CarBrand brand in all) {
      if (brand.name == name) return brand;
    }
    return null;
  }
}

/// What the map is currently filtered down to.
class StationFilter {
  const StationFilter({this.brand, this.connectorTypes = const <String>{}});

  /// The make the driver picked, purely so the sheet can show it selected.
  final String? brand;

  /// Connector codes a station must offer at least one of. Empty means "any".
  final Set<String> connectorTypes;

  bool get isActive => connectorTypes.isNotEmpty || brand != null;

  /// How many things the driver has narrowed by, for the badge on the button.
  int get activeCount => connectorTypes.length;

  static const StationFilter none = StationFilter();

  StationFilter copyWith({
    String? brand,
    Set<String>? connectorTypes,
    bool clearBrand = false,
  }) {
    return StationFilter(
      brand: clearBrand ? null : (brand ?? this.brand),
      connectorTypes: connectorTypes ?? this.connectorTypes,
    );
  }

  /// True when [stationTypes] satisfies this filter.
  bool matches(List<String> stationTypes) {
    if (connectorTypes.isEmpty) return true;
    return stationTypes.any(
      (String type) => connectorTypes.any(
        (String wanted) => wanted.toLowerCase() == type.toLowerCase(),
      ),
    );
  }

  /// Short summary for the map, e.g. "CCS2, GB/T".
  String get summary {
    if (connectorTypes.isEmpty) return AppStrings.get('filter_any_connector');
    return connectorTypes
        .map((String code) => ConnectorType.fromCode(code)?.label ?? code)
        .join(', ');
  }
}
