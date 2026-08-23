import 'package:flutter/material.dart';

import '../models/connector_types.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';

/// Narrows the map to stations a given car can actually use.
///
/// Brand and plug are not two independent filters: a brand is a shortcut that
/// selects the plugs that make charges on, which the driver can then adjust by
/// hand. Only the plug set is ever used to match a station.
class StationFilterSheet extends StatefulWidget {
  const StationFilterSheet({
    super.key,
    required this.initial,
    required this.matchCount,
    required this.onChanged,
  });

  final StationFilter initial;

  /// How many stations a candidate filter would leave, so the driver can see
  /// the effect before committing to it.
  final int Function(StationFilter) matchCount;

  /// Fired as the driver edits, so the map behind the sheet keeps up.
  final ValueChanged<StationFilter> onChanged;

  @override
  State<StationFilterSheet> createState() => _StationFilterSheetState();
}

class _StationFilterSheetState extends State<StationFilterSheet> {
  late StationFilter _filter = widget.initial;

  void _update(StationFilter next) {
    setState(() => _filter = next);
    widget.onChanged(next);
  }

  void _pickBrand(CarBrand brand) {
    if (_filter.brand == brand.name) {
      // Tapping the selected brand clears it and the plugs it brought with it.
      _update(const StationFilter());
      return;
    }
    _update(
      StationFilter(
        brand: brand.name,
        connectorTypes: brand.connectorTypes
            .map((ConnectorType type) => type.code)
            .toSet(),
      ),
    );
  }

  void _toggleConnector(ConnectorType type) {
    final Set<String> next = Set<String>.from(_filter.connectorTypes);
    if (!next.remove(type.code)) next.add(type.code);

    // Hand-editing the plugs means the brand no longer describes the selection.
    _update(
      StationFilter(
        brand: next.isEmpty ? null : _filter.brand,
        connectorTypes: next,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final int matches = widget.matchCount(_filter);

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      expand: false,
      builder: (BuildContext context, ScrollController controller) {
        return Container(
          decoration: BoxDecoration(
            color: palette.bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            children: <Widget>[
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                AppStrings.get('filter_title'),
                                style: TextStyle(
                                  color: palette.ink,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                AppStrings.get('filter_subtitle'),
                                style: TextStyle(
                                  color: palette.inkMuted,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_filter.isActive)
                          TextButton(
                            onPressed: () => _update(const StationFilter()),
                            style: TextButton.styleFrom(
                              foregroundColor: palette.inkMuted,
                              visualDensity: VisualDensity.compact,
                            ),
                            child: Text(AppStrings.get('filter_clear')),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    _label(palette, AppStrings.get('filter_brand')),
                    const SizedBox(height: 3),
                    Text(
                      AppStrings.get('filter_brand_hint'),
                      style: TextStyle(
                        color: palette.inkMuted,
                        fontSize: 11.5,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: CarBrand.all
                          .map(
                            (CarBrand brand) => _chip(
                              palette,
                              label: brand.name,
                              selected: _filter.brand == brand.name,
                              onTap: () => _pickBrand(brand),
                            ),
                          )
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 24),

                    _label(palette, AppStrings.get('filter_connector')),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ConnectorType.all
                          .map(
                            (ConnectorType type) => _chip(
                              palette,
                              label: type.label,
                              selected: _filter.connectorTypes.contains(
                                type.code,
                              ),
                              onTap: () => _toggleConnector(type),
                              icon: Icons.ev_station_rounded,
                            ),
                          )
                          .toList(growable: false),
                    ),
                    const SizedBox(height: 20),
                    if (matches == 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.warningOrange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.warningOrange.withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                        child: Text(
                          AppStrings.get('filter_none_match'),
                          style: const TextStyle(
                            color: AppTheme.warningOrange,
                            fontSize: 12.5,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Pinned so the action is reachable however long the chip lists get.
              Container(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  12 + MediaQuery.of(context).padding.bottom,
                ),
                decoration: BoxDecoration(
                  color: palette.card,
                  border: Border(top: BorderSide(color: palette.border)),
                ),
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: matches == 0
                        ? null
                        : () => Navigator.pop(context, _filter),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.panel,
                      foregroundColor: palette.onPanel,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    icon: const Icon(Icons.near_me_rounded, size: 19),
                    label: Text(
                      '${AppStrings.get('filter_nearest')} · $matches',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _label(AppPalette palette, String text) => Text(
    text,
    style: TextStyle(
      color: palette.ink,
      fontSize: 13.5,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.1,
    ),
  );

  Widget _chip(
    AppPalette palette, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? palette.accent : palette.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? palette.accent : palette.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(
                icon,
                size: 14,
                color: selected ? Colors.white : palette.inkMuted,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : palette.ink,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
