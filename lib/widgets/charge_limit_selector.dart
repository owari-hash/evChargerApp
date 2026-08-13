import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ChargeLimitSelector extends StatelessWidget {
  final double targetLimitPct;
  final ValueChanged<double> onLimitChanged;

  const ChargeLimitSelector({
    super.key,
    required this.targetLimitPct,
    required this.onLimitChanged,
  });

  @override
  Widget build(BuildContext context) {
    final int estimatedMinutes = ((targetLimitPct - 20) * 0.6).toInt().clamp(10, 60);
    final int estimatedRangeKm = (targetLimitPct * 6.0).toInt();
    final int estimatedCostMnt = (targetLimitPct * 160.0).toInt();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.tune_rounded, color: AppTheme.darkForest, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Цэнэглэх Хязгаар Тохируулах',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.darkForest,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.lightSage,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt_rounded, color: AppTheme.sageGreen, size: 14),
                    const SizedBox(width: 2),
                    Text(
                      '${targetLimitPct.toInt()}%',
                      style: const TextStyle(
                        color: AppTheme.sageGreen,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Target Limit Slider Track
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.sageGreen,
              inactiveTrackColor: AppTheme.borderSubtle,
              thumbColor: AppTheme.darkForest,
              overlayColor: AppTheme.sageGreen.withOpacity(0.2),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: targetLimitPct,
              min: 50.0,
              max: 100.0,
              divisions: 10,
              onChanged: onLimitChanged,
            ),
          ),
          const SizedBox(height: 12),

          // Dynamic Metric Estimate Chips Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildEstimateItem(
                icon: Icons.timer_outlined,
                label: 'Үлдсэн хугацаа',
                value: '$estimatedMinutes мин',
              ),
              Container(width: 1, height: 28, color: AppTheme.borderSubtle),
              _buildEstimateItem(
                icon: Icons.add_road_rounded,
                label: 'Нэмэгдэх зай',
                value: '$estimatedRangeKm км',
              ),
              Container(width: 1, height: 28, color: AppTheme.borderSubtle),
              _buildEstimateItem(
                icon: Icons.payments_outlined,
                label: 'Тооцоолсон дүн',
                value: '₮$estimatedCostMnt',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEstimateItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: AppTheme.textMuted),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppTheme.darkForest,
          ),
        ),
      ],
    );
  }
}
