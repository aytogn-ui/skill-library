import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MasterySlider extends StatelessWidget {
  final int mastery;
  final ValueChanged<int> onChanged;
  final bool compact;

  const MasterySlider({
    super.key,
    required this.mastery,
    required this.onChanged,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = _getMasteryColor(mastery);

    if (compact) {
      return Row(
        children: [
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: color,
                thumbColor: color,
                overlayColor: color.withValues(alpha: 0.2),
                trackHeight: 4,
              ),
              child: Slider(
                value: mastery.toDouble(),
                min: 0,
                max: 100,
                divisions: 100,
                onChanged: (v) => onChanged(v.round()),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 48,
            alignment: Alignment.center,
            child: Text(
              '$mastery%',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '習得度',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.5)),
              ),
              child: Text(
                '$mastery%',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            inactiveTrackColor: AppTheme.divider,
            thumbColor: color,
            overlayColor: color.withValues(alpha: 0.2),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            trackHeight: 6,
            valueIndicatorColor: color,
            showValueIndicator: ShowValueIndicator.onDrag,
            valueIndicatorTextStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          child: Slider(
            value: mastery.toDouble(),
            min: 0,
            max: 100,
            divisions: 100,
            label: '$mastery%',
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('0%', style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
              _buildStageLabel(mastery),
              const Text('100%', style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStageLabel(int mastery) {
    String label;
    Color color;
    if (mastery >= 90) {
      label = '完全習得';
      color = AppTheme.teal;
    } else if (mastery >= 70) {
      label = '上達中';
      color = AppTheme.tealLight;
    } else if (mastery >= 50) {
      label = '練習中';
      color = AppTheme.primaryPurple;
    } else if (mastery >= 20) {
      label = '初期段階';
      color = const Color(0xFFFF9800);
    } else {
      label = '未習得';
      color = AppTheme.textTertiary;
    }

    return Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Color _getMasteryColor(int mastery) {
    if (mastery >= 80) return AppTheme.teal;
    if (mastery >= 50) return AppTheme.primaryPurple;
    if (mastery >= 30) return const Color(0xFFFF9800);
    return AppTheme.errorRed.withValues(alpha: 0.8);
  }
}
