import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';
import '../utils/money.dart';

class ChargingSessionReceiptSheet extends StatelessWidget {
  final String stationName;
  final double totalEnergyKwh;
  final double activePowerKw;
  final double totalCostMnt;

  const ChargingSessionReceiptSheet({
    super.key,
    required this.stationName,
    required this.totalEnergyKwh,
    required this.activePowerKw,
    required this.totalCostMnt,
  });

  @override
  Widget build(BuildContext context) {
    final String txRef =
        'UB-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Success Icon
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
          const SizedBox(height: 4),
          Text(
            'Гүйлгээний дугаар: #$txRef',
            style: TextStyle(fontSize: 12, color: context.palette.inkMuted),
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
                  formatMntLeading(totalCostMnt),
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

          // Breakdown List
          _buildReceiptRow(
            context,
            AppStrings.get('charging_station'),
            stationName,
          ),
          Divider(height: 20, color: context.palette.border),
          _buildReceiptRow(
            context,
            AppStrings.get('connector_speed'),
            '${activePowerKw.toInt()} кВт CCS2 Fast',
          ),
          Divider(height: 20, color: context.palette.border),
          _buildReceiptRow(
            context,
            AppStrings.get('energy_delivered'),
            '${totalEnergyKwh.toStringAsFixed(2)} кВт.ц',
          ),
          Divider(height: 20, color: context.palette.border),
          _buildReceiptRow(
            context,
            AppStrings.get('unit_price'),
            '${formatMntLeading(450)} / кВт.ц',
          ),
          Divider(height: 20, color: context.palette.border),
          _buildReceiptRow(context, 'Төлбөрийн хэрэгсэл', 'QPay (Амжилттай)'),
          const SizedBox(height: 28),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppStrings.get('receipt_emailed')),
                        backgroundColor: context.palette.panel,
                      ),
                    );
                  },
                  icon: const Icon(Icons.download_rounded, size: 18),
                  // Never wrap: label length varies by language.
                  label: Text(
                    AppStrings.get('download_receipt'),
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
