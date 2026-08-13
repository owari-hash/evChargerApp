import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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
    final String txRef = 'UB-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Success Icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppTheme.lightSage,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded, color: AppTheme.sageGreen, size: 48),
          ),
          const SizedBox(height: 16),

          const Text(
            'Цэнэглэлтийн Баримт',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppTheme.darkForest,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Гүйлгээний дугаар: #$txRef',
            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 20),

          // Total Cost Highlight Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.softBg,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                const Text(
                  'Нийт Төлөгдсөн Дүн',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 4),
                Text(
                  '₮${totalCostMnt.toInt()}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.darkForest,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Breakdown List
          _buildReceiptRow('Цэнэглэх станц', stationName),
          const Divider(height: 20, color: AppTheme.borderSubtle),
          _buildReceiptRow('Загуур / Хурд', '${activePowerKw.toInt()} кВт CCS2 Fast'),
          const Divider(height: 20, color: AppTheme.borderSubtle),
          _buildReceiptRow('Шилжүүлсэн эрчим хүч', '${totalEnergyKwh.toStringAsFixed(2)} кВт.ц'),
          const Divider(height: 20, color: AppTheme.borderSubtle),
          _buildReceiptRow('Нэгжийн үнэ', '₮450 / кВт.ц'),
          const Divider(height: 20, color: AppTheme.borderSubtle),
          _buildReceiptRow('Төлбөрийн хэрэгсэл', 'QPay (Амжилттай)'),
          const SizedBox(height: 28),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('И-мэйлээр баримт илгээгдлээ.'),
                        backgroundColor: AppTheme.darkForest,
                      ),
                    );
                  },
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('БАРИМТ ТАТАХ'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppTheme.darkForest),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.darkForest,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('БОЛСОН'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
          ),
        ),
      ],
    );
  }
}
