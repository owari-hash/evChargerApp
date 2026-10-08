import 'package:flutter/material.dart';
import '../models/charging_session.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import '../utils/money.dart';
import 'ebarimt_sheet.dart';

/// Shown right after a charge stops. Every figure here is one the driver
/// watched tick up on the dashboard a moment ago, or — for [totalCostMnt] and
/// [transactionId] — one just read back from the charge point's own meter;
/// nothing is invented to fill the card out.
class ChargingSessionReceiptSheet extends StatelessWidget {
  final String stationName;
  final double totalEnergyKwh;
  final double activePowerKw;
  final double? totalCostMnt;

  /// Null when the session never reached the real backend (the dashboard's
  /// local simulation) — there is then nothing to request an e-Barimt for.
  final int? transactionId;

  const ChargingSessionReceiptSheet({
    super.key,
    required this.stationName,
    required this.totalEnergyKwh,
    required this.activePowerKw,
    required this.totalCostMnt,
    this.transactionId,
  });

  @override
  Widget build(BuildContext context) {
    final double? unitPrice = (totalCostMnt != null && totalEnergyKwh > 0)
        ? totalCostMnt! / totalEnergyKwh
        : null;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.palette.accent.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: AppTheme.sageGreen,
              size: 48,
            ),
          ),
          const SizedBox(height: 16),

          Text(
            AppStrings.get('charging_receipt'),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: context.palette.ink,
            ),
          ),
          const SizedBox(height: 20),

          // Total Cost Highlight Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: context.palette.bg,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Text(
                  AppStrings.get('total_paid'),
                  style: TextStyle(
                    fontSize: 12,
                    color: context.palette.inkMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  totalCostMnt == null ? '—' : formatMntLeading(totalCostMnt!),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: context.palette.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _buildReceiptRow(
            context,
            AppStrings.get('charging_station'),
            stationName,
          ),
          Divider(height: 20, color: context.palette.border),
          _buildReceiptRow(
            context,
            AppStrings.get('power'),
            '${activePowerKw.toInt()} кВт',
          ),
          Divider(height: 20, color: context.palette.border),
          _buildReceiptRow(
            context,
            AppStrings.get('energy_delivered'),
            '${totalEnergyKwh.toStringAsFixed(2)} кВт.ц',
          ),
          if (unitPrice != null) ...[
            Divider(height: 20, color: context.palette.border),
            _buildReceiptRow(
              context,
              AppStrings.get('unit_price'),
              '${formatMntLeading(unitPrice)} / кВт.ц',
            ),
          ],
          const SizedBox(height: 28),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: transactionId == null
                      ? null
                      : () {
                          Navigator.pop(context);
                          EbarimtSheet.show(
                            context,
                            ChargingSession(
                              transactionId: transactionId!,
                              chargePointId: '',
                              connectorId: 0,
                              idTag: '',
                              status: SessionStatus.completed,
                              energyKwh: totalEnergyKwh,
                              cost: totalCostMnt,
                              stationName: stationName,
                            ),
                          );
                        },
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  label: Text(
                    AppStrings.get('sess_ebarimt_get'),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    side: BorderSide(color: context.palette.panel, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.palette.panel,
                    foregroundColor: context.palette.onPanel,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                  child: Text(
                    AppStrings.get('done'),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: context.palette.inkMuted),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: context.palette.ink,
          ),
        ),
      ],
    );
  }
}
