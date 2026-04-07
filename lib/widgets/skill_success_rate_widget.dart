import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/skill_attempt_provider.dart';
import '../theme/app_theme.dart';

/// スキル習得度ウィジェット（統合表示版）
/// - 習得度 = 選択した直近N回の成功率
/// - ウィンドウ切替: [100回] [50回] [30回]（デフォルト50回）
/// - 試技数不足の場合は「試技数不足」を表示
/// - 色分け: >90% 緑 / 70-89% 黄 / ≤69% 赤
class SkillSuccessRateWidget extends StatefulWidget {
  final String skillId;

  const SkillSuccessRateWidget({super.key, required this.skillId});

  @override
  State<SkillSuccessRateWidget> createState() => _SkillSuccessRateWidgetState();
}

class _SkillSuccessRateWidgetState extends State<SkillSuccessRateWidget> {
  // デフォルトは50回
  int _selectedWindow = 50;
  static const List<int> _windows = [100, 50, 30];

  @override
  Widget build(BuildContext context) {
    return Consumer<SkillAttemptProvider>(
      builder: (context, provider, _) {
        final result = provider.calculateRate(widget.skillId, _selectedWindow);
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ヘッダー行（タイトル + セグメントボタン）
              Row(
                children: [
                  const Icon(Icons.trending_up,
                      color: AppTheme.teal, size: 18),
                  const SizedBox(width: 6),
                  const Text(
                    '習得度',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  // セグメントボタン: [100回] [50回] [30回]
                  _buildWindowSelector(),
                ],
              ),
              const SizedBox(height: 14),

              // メイン表示エリア（閲覧専用）
              _buildRateDisplay(result),
            ],
          ),
        );
      },
    );
  }

  /// ウィンドウ選択セグメントボタン
  Widget _buildWindowSelector() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _windows.map((w) {
          final selected = w == _selectedWindow;
          return GestureDetector(
            onTap: () => setState(() => _selectedWindow = w),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.primaryPurple
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$w回',
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : AppTheme.textTertiary,
                  fontSize: 11,
                  fontWeight: selected
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 成功率メイン表示（閲覧専用）
  Widget _buildRateDisplay(SuccessRateResult result) {
    final hasData = result.hasData;
    final rate = result.rate;
    final color = hasData
        ? SuccessRateResult.rateColor(rate!)
        : AppTheme.textTertiary;

    return Row(
      children: [
        // 大きな成功率表示
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasData) ...[
                // 習得度 82%（直近50回）
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${rate!.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: color,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          height: 1.1,
                        ),
                      ),
                      TextSpan(
                        text: '  （直近$_selectedWindow回）',
                        style: const TextStyle(
                          color: AppTheme.textTertiary,
                          fontSize: 12,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // プログレスバー
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (rate / 100).clamp(0.0, 1.0),
                    backgroundColor: color.withValues(alpha: 0.15),
                    color: color,
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 6),
                // カラー判定ラベル
                _buildJudgeLabel(rate),
              ] else ...[
                // 試技数不足
                Row(
                  children: [
                    const Icon(Icons.hourglass_empty,
                        color: AppTheme.textTertiary, size: 20),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '試技数不足',
                          style: TextStyle(
                            color: AppTheme.textTertiary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          result.totalAttempts == 0
                              ? '試技を記録してください'
                              : 'あと${result.neededMore}回で集計開始',
                          style: const TextStyle(
                            color: AppTheme.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        // 右側: 総試技数バッジ
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.backgroundDark,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Column(
                children: [
                  Text(
                    '${result.totalAttempts}',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Text(
                    '総試技数',
                    style: TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 色判定ラベル（>90%: 上達 / 70-89%: 標準 / ≤69%: 要練習）
  Widget _buildJudgeLabel(double rate) {
    String label;
    Color color;
    IconData icon;

    if (rate >= 90) {
      label = '上達';
      color = const Color(0xFF4CAF50);
      icon = Icons.emoji_events;
    } else if (rate >= 70) {
      label = '標準';
      color = const Color(0xFFFFB300);
      icon = Icons.trending_up;
    } else {
      label = '要練習';
      color = const Color(0xFFFF5252);
      icon = Icons.fitness_center;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 12),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
