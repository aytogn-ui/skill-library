import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/skill_attempt_provider.dart';
import '../theme/app_theme.dart';

/// スキル習得度ウィジェット
/// 直近 100 / 50 / 30 回の成功率を表示
/// - 試技数不足の場合は「データ不足（あとX回）」を表示
/// - 色分け: >90% 緑 / 70-89% 黄 / ≤69% 赤
class SkillSuccessRateWidget extends StatelessWidget {
  final String skillId;

  const SkillSuccessRateWidget({super.key, required this.skillId});

  @override
  Widget build(BuildContext context) {
    return Consumer<SkillAttemptProvider>(
      builder: (context, provider, _) {
        final rates = provider.getSuccessRates(skillId);
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
              // ヘッダー行
              Row(
                children: [
                  const Icon(Icons.trending_up,
                      color: AppTheme.teal, size: 18),
                  const SizedBox(width: 6),
                  const Text(
                    '直近成功率',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '総試技数: ${rates.totalAttempts}回',
                    style: const TextStyle(
                        color: AppTheme.textTertiary, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 3ウィンドウの成功率カード
              Row(
                children: [
                  Expanded(
                    child: _RateCard(
                      label: '直近30回',
                      result: rates.rate30,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _RateCard(
                      label: '直近50回',
                      result: rates.rate50,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _RateCard(
                      label: '直近100回',
                      result: rates.rate100,
                    ),
                  ),
                ],
              ),

              // 試技履歴に記録を追加するためのボタン
              const SizedBox(height: 12),
              _AttemptButtons(skillId: skillId),
            ],
          ),
        );
      },
    );
  }
}

/// 単一ウィンドウの成功率カード
class _RateCard extends StatelessWidget {
  final String label;
  final SuccessRateResult result;

  const _RateCard({required this.label, required this.result});

  @override
  Widget build(BuildContext context) {
    final hasData = result.hasData;
    final rate = result.rate;
    final color = hasData
        ? SuccessRateResult.rateColor(rate!)
        : AppTheme.textTertiary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: hasData ? 0.08 : 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: hasData ? 0.3 : 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ラベル
          Text(
            label,
            style: TextStyle(
              color: hasData ? color : AppTheme.textTertiary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),

          // 成功率または不足メッセージ
          if (hasData) ...[
            Text(
              '${rate!.toStringAsFixed(1)}%',
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            // カラーバー
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (rate / 100).clamp(0.0, 1.0),
                backgroundColor: color.withValues(alpha: 0.15),
                color: color,
                minHeight: 4,
              ),
            ),
          ] else ...[
            const Icon(Icons.hourglass_empty,
                color: AppTheme.textTertiary, size: 18),
            const SizedBox(height: 2),
            Text(
              result.totalAttempts == 0
                  ? 'データなし'
                  : 'あと${result.neededMore}回',
              style: const TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// 試技記録ボタン（成功/失敗）
class _AttemptButtons extends StatelessWidget {
  final String skillId;

  const _AttemptButtons({required this.skillId});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildButton(
            context: context,
            label: '✓ 成功',
            isSuccess: true,
            color: const Color(0xFF4CAF50),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildButton(
            context: context,
            label: '✕ 失敗',
            isSuccess: false,
            color: const Color(0xFFFF5252),
          ),
        ),
      ],
    );
  }

  Widget _buildButton({
    required BuildContext context,
    required String label,
    required bool isSuccess,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () async {
        await context.read<SkillAttemptProvider>().addAttempt(
              skillId: skillId,
              isSuccess: isSuccess,
            );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isSuccess ? '成功を記録しました ✓' : '失敗を記録しました'),
              backgroundColor:
                  isSuccess ? const Color(0xFF4CAF50) : const Color(0xFFFF5252),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(milliseconds: 1000),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
