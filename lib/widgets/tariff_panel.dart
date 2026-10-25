import 'package:flutter/material.dart';

import '../models/station.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import '../utils/money.dart';
import 'account_widgets.dart';

/// While charging: the rate this driver is billed at right now, and the
/// station's whole price list with the zone in effect marked — the app's
/// counterpart to the kiosk's tariff panel.
class TariffPanel extends StatelessWidget {
  const TariffPanel({
    super.key,
    required this.yourRate,
    this.zoneName,
    this.isInternal = false,
    this.stationRate,
    this.defaultRate,
    this.zones = const <TariffZone>[],
  });

  /// Per kWh the running session is billed at.
  final num? yourRate;

  /// Name of the zone being billed now, if it has one.
  final String? zoneName;

  /// Internal users charge free.
  final bool isInternal;

  /// The station's current rate — shown when it has no time-of-day zones.
  final num? stationRate;

  /// The station's rate outside every zone.
  final num? defaultRate;
  final List<TariffZone> zones;

  /// Minutes since midnight in Mongolia (UTC+8, no DST) — the zones' clock.
  static int _mnMinuteNow() {
    final DateTime utc = DateTime.now().toUtc();
    return (utc.hour * 60 + utc.minute + 8 * 60) % 1440;
  }

  static String _clock(int minute) {
    final int h = (minute ~/ 60) % 24;
    final int m = minute % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  static String _rate(num? value) => value == null
      ? '—'
      : '${formatMnt(value)}/${AppStrings.get('tariff_kwh')}';

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = context.palette;
    final int now = _mnMinuteNow();
    TariffZone? inZone;
    for (final TariffZone z in zones) {
      if (z.covers(now)) {
        inZone = z;
        break;
      }
    }

    return SectionCard(
      glass: true,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // What this driver pays.
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: palette.accent.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.bolt_rounded, size: 18, color: palette.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        AppStrings.get('tariff_yours'),
                        style: TextStyle(
                          color: palette.inkMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (zoneName != null)
                        Text(
                          zoneName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: palette.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  isInternal ? AppStrings.get('tariff_free') : _rate(yourRate),
                  style: TextStyle(
                    color: palette.accent,
                    fontSize: isInternal ? 13 : 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
          // The station's price list.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  AppStrings.get('tariff_station'),
                  style: TextStyle(
                    color: palette.inkMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                if (zones.isEmpty)
                  Text(
                    _rate(stationRate ?? defaultRate),
                    style: TextStyle(
                      color: palette.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else ...<Widget>[
                  for (final TariffZone z in zones)
                    _zoneRow(
                      palette,
                      label:
                          '${_clock(z.startMinute)}–${_clock(z.endMinute)}'
                          '${z.name != null ? ' · ${z.name}' : ''}',
                      rate: z.tariffPerKwh,
                      current: identical(z, inZone),
                    ),
                  if (defaultRate != null)
                    _zoneRow(
                      palette,
                      label: AppStrings.get('tariff_other_hours'),
                      rate: defaultRate,
                      current: inZone == null,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _zoneRow(
    AppPalette palette, {
    required String label,
    required num? rate,
    required bool current,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: current
            ? palette.accent.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: current
              ? palette.accent.withValues(alpha: 0.35)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(text: label),
                  if (current)
                    TextSpan(
                      text: '  ● ${AppStrings.get('tariff_now')}',
                      style: TextStyle(color: palette.accent),
                    ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: current ? palette.ink : palette.inkMuted,
                fontSize: 12.5,
                fontWeight: current ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _rate(rate),
            style: TextStyle(
              color: current ? palette.ink : palette.inkMuted,
              fontSize: 12.5,
              fontWeight: current ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
