import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/app_strings.dart';

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
    final int estimatedMinutes = ((targetLimitPct - 20) * 0.6).toInt().clamp(
      10,
      60,
    );
    final int estimatedRangeKm = (targetLimitPct * 6.0).toInt();
    final int estimatedCostMnt = (targetLimitPct * 160.0).toInt();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      color: context.palette.ink,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        AppStrings.get('set_charge_limit'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: context.palette.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: context.palette.accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      color: AppTheme.sageGreen,
                      size: 14,
                    ),
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
              inactiveTrackColor: context.palette.border,
              thumbColor: context.palette.ink,
              overlayColor: AppTheme.sageGreen.withValues(alpha: 0.2),
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
              Expanded(
                child: _buildEstimateItem(
                context,
                icon: Icons.timer_outlined,
                label: AppStrings.get('time_remaining'),
                value: '$estimatedMinutes мин',
              ),
              ),
              Container(width: 1, height: 28, color: context.palette.border),
              Expanded(
                child: _buildEstimateItem(
                context,
                icon: Icons.add_road_rounded,
                label: AppStrings.get('added_range'),
                value: '$estimatedRangeKm км',
              ),
              ),
              Container(width: 1, height: 28, color: context.palette.border),
              Expanded(
                child: _buildEstimateItem(
                context,
                icon: Icons.payments_outlined,
                label: AppStrings.get('estimated_total'),
                value: '₮$estimatedCostMnt',
              ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEstimateItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: context.palette.inkMuted),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: context.palette.inkMuted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: context.palette.ink,
            ),
          ),
        ),
      ],
    );
  }
}
