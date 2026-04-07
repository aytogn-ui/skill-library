import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/skill_provider.dart';
import '../models/skill.dart';
import '../theme/app_theme.dart';

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen>
    with SingleTickerProviderStateMixin {
  // ─── 状態変数 ───────────────────────────────────────
  bool _isCounting = false;
  int _totalCount = 0;
  int _successCount = 0;
  int _failCount = 0;

  // アニメーションコントローラー（ボタンタップ時のフラッシュ）
  late AnimationController _flashController;
  Color? _flashColor;

  @override
  void initState() {
    super.initState();
    _flashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _flashController.dispose();
    super.dispose();
  }

  // ─── ロジック ────────────────────────────────────────

  void _onStart() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isCounting = true;
      _totalCount = 0;
      _successCount = 0;
      _failCount = 0;
    });
  }

  void _onSuccess() {
    if (!_isCounting) return;
    HapticFeedback.lightImpact();
    _triggerFlash(AppTheme.successGreen);
    setState(() {
      _successCount++;
      _totalCount++;
    });
  }

  void _onFail() {
    if (!_isCounting) return;
    HapticFeedback.lightImpact();
    _triggerFlash(AppTheme.errorRed);
    setState(() {
      _failCount++;
      _totalCount++;
    });
  }

  void _onEnd() {
    if (!_isCounting) return;
    HapticFeedback.mediumImpact();
    setState(() => _isCounting = false);
    _showResultModal();
  }

  void _triggerFlash(Color color) {
    setState(() => _flashColor = color);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _flashColor = null);
    });
  }

  void _resetCounter() {
    setState(() {
      _isCounting = false;
      _totalCount = 0;
      _successCount = 0;
      _failCount = 0;
      _flashColor = null;
    });
  }

  double get _successRate {
    if (_totalCount == 0) return 0;
    return _successCount / _totalCount;
  }

  // ─── モーダル ─────────────────────────────────────────

  void _showResultModal() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ResultModal(
        totalCount: _totalCount,
        successCount: _successCount,
        failCount: _failCount,
        successRate: _successRate,
        onAddToSkill: () {
          Navigator.pop(context);
          _showSkillSelectModal();
        },
        onDiscard: () {
          Navigator.pop(context);
          _resetCounter();
        },
      ),
    );
  }

  void _showSkillSelectModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SkillSelectModal(
        successCount: _successCount,
        failCount: _failCount,
        onSelected: (skill) {
          Navigator.pop(context);
          _applyToSkill(skill);
        },
        onCancel: () {
          Navigator.pop(context);
          _resetCounter();
        },
      ),
    );
  }

  Future<void> _applyToSkill(Skill skill) async {
    final provider = context.read<SkillProvider>();
    final updated = skill.copyWith(
      successCount: skill.successCount + _successCount,
      failCount: skill.failCount + _failCount,
    );
    await provider.updateSkill(updated);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '「${skill.title}」に加算しました\n'
                  '成功 +$_successCount  失敗 +$_failCount',
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.successGreen,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    _resetCounter();
  }

  // ─── UI ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _flashColor != null
          ? _flashColor!.withValues(alpha: 0.08)
          : AppTheme.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildCounterBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          const Text(
            'Practice Counter',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          // 状態インジケーター
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: _isCounting
                  ? AppTheme.successGreen.withValues(alpha: 0.15)
                  : AppTheme.cardDark,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _isCounting
                    ? AppTheme.successGreen.withValues(alpha: 0.6)
                    : AppTheme.divider,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isCounting
                        ? AppTheme.successGreen
                        : AppTheme.textTertiary,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isCounting ? '計測中' : '待機中',
                  style: TextStyle(
                    color: _isCounting
                        ? AppTheme.successGreen
                        : AppTheme.textTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCounterBody() {
    return Column(
      children: [
        const SizedBox(height: 12),
        // Startボタン
        _buildStartButton(),
        const SizedBox(height: 16),
        // 数値表示エリア
        _buildStatsDisplay(),
        const Spacer(),
        // ○ × ボタン
        _buildActionButtons(),
        const SizedBox(height: 28),
        // Endボタン
        _buildEndButton(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildStartButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _isCounting ? 0.35 : 1.0,
          child: ElevatedButton.icon(
            onPressed: _isCounting ? null : _onStart,
            icon: const Icon(Icons.play_arrow_rounded, size: 22),
            label: const Text(
              'Start',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPurple,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.3),
              disabledForegroundColor: Colors.white38,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: _isCounting ? 0 : 4,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsDisplay() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isCounting
              ? AppTheme.primaryPurple.withValues(alpha: 0.4)
              : AppTheme.divider,
        ),
        boxShadow: _isCounting
            ? [
                BoxShadow(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.12),
                  blurRadius: 16,
                  spreadRadius: 2,
                )
              ]
            : [],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              label: 'Total',
              value: _totalCount,
              color: AppTheme.textPrimary,
              large: true,
            ),
          ),
          Container(width: 1, height: 60, color: AppTheme.divider),
          Expanded(
            child: _buildStatItem(
              label: 'Success',
              value: _successCount,
              color: AppTheme.successGreen,
            ),
          ),
          Container(width: 1, height: 60, color: AppTheme.divider),
          Expanded(
            child: _buildStatItem(
              label: 'Fail',
              value: _failCount,
              color: AppTheme.errorRed,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required int value,
    required Color color,
    bool large = false,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textTertiary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: anim,
            child: child,
          ),
          child: Text(
            value.toString(),
            key: ValueKey('${label}_$value'),
            style: TextStyle(
              color: color,
              fontSize: large ? 48 : 36,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 失敗ボタン（×）
          _buildCountButton(
            label: '×',
            color: AppTheme.errorRed,
            onTap: _isCounting ? _onFail : null,
          ),
          const SizedBox(width: 24),
          // 成功ボタン（○）
          _buildCountButton(
            label: '○',
            color: AppTheme.successGreen,
            onTap: _isCounting ? _onSuccess : null,
          ),
        ],
      ),
    );
  }

  Widget _buildCountButton({
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    final isEnabled = onTap != null;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isEnabled
              ? color.withValues(alpha: 0.12)
              : AppTheme.cardDark,
          border: Border.all(
            color: isEnabled
                ? color.withValues(alpha: 0.7)
                : AppTheme.divider,
            width: isEnabled ? 2.5 : 1.5,
          ),
          boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 20,
                    spreadRadius: 2,
                  )
                ]
              : [],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 52,
              fontWeight: FontWeight.w300,
              color: isEnabled ? color : AppTheme.textTertiary,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEndButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: _isCounting ? 1.0 : 0.35,
          child: OutlinedButton.icon(
            onPressed: _isCounting ? _onEnd : null,
            icon: const Icon(Icons.stop_rounded, size: 20),
            label: const Text(
              'End',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.errorRed,
              disabledForegroundColor: AppTheme.textTertiary,
              side: BorderSide(
                color: _isCounting
                    ? AppTheme.errorRed.withValues(alpha: 0.7)
                    : AppTheme.divider,
                width: 1.5,
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── 結果確認モーダル ──────────────────────────────────────

class _ResultModal extends StatelessWidget {
  final int totalCount;
  final int successCount;
  final int failCount;
  final double successRate;
  final VoidCallback onAddToSkill;
  final VoidCallback onDiscard;

  const _ResultModal({
    required this.totalCount,
    required this.successCount,
    required this.failCount,
    required this.successRate,
    required this.onAddToSkill,
    required this.onDiscard,
  });

  Color get _rateColor {
    if (successRate >= 0.8) return AppTheme.teal;
    if (successRate >= 0.6) return AppTheme.primaryPurple;
    if (successRate >= 0.4) return const Color(0xFFFF9800);
    return AppTheme.errorRed;
  }

  @override
  Widget build(BuildContext context) {
    final ratePercent = (successRate * 100).toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ハンドルバー
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // タイトル
            const Text(
              'セッション結果',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // 成功率メーター（大きく表示）
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _rateColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _rateColor.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    '$ratePercent%',
                    style: TextStyle(
                      color: _rateColor,
                      fontSize: 44,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    'Success Rate',
                    style: TextStyle(
                      color: _rateColor.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 数値詳細
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildResultItem(
                      'Total',
                      totalCount.toString(),
                      AppTheme.textPrimary,
                    ),
                  ),
                  Container(width: 1, height: 40, color: AppTheme.divider),
                  Expanded(
                    child: _buildResultItem(
                      'Success',
                      successCount.toString(),
                      AppTheme.successGreen,
                    ),
                  ),
                  Container(width: 1, height: 40, color: AppTheme.divider),
                  Expanded(
                    child: _buildResultItem(
                      'Fail',
                      failCount.toString(),
                      AppTheme.errorRed,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // アクションボタン
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onAddToSkill,
                icon: const Icon(Icons.add_chart, size: 20),
                label: const Text(
                  'スキルに加算する',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: onDiscard,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  '破棄する',
                  style: TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textTertiary,
            fontSize: 11,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ─── スキル選択モーダル ────────────────────────────────────

class _SkillSelectModal extends StatefulWidget {
  final int successCount;
  final int failCount;
  final ValueChanged<Skill> onSelected;
  final VoidCallback onCancel;

  const _SkillSelectModal({
    required this.successCount,
    required this.failCount,
    required this.onSelected,
    required this.onCancel,
  });

  @override
  State<_SkillSelectModal> createState() => _SkillSelectModalState();
}

class _SkillSelectModalState extends State<_SkillSelectModal> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ハンドル＋ヘッダー
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'スキルを選択',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '成功・失敗数を加算するスキルを選んでください',
                          style: TextStyle(
                            color: AppTheme.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // 加算プレビュー
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.cardDark,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('○ ',
                                  style: TextStyle(
                                      color: AppTheme.successGreen,
                                      fontSize: 11)),
                              Text('+${widget.successCount}',
                                  style: const TextStyle(
                                      color: AppTheme.successGreen,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('× ',
                                  style: TextStyle(
                                      color: AppTheme.errorRed,
                                      fontSize: 11)),
                              Text('+${widget.failCount}',
                                  style: const TextStyle(
                                      color: AppTheme.errorRed,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 検索バー
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'スキルを検索...',
                prefixIcon: const Icon(Icons.search,
                    color: AppTheme.textSecondary, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear,
                            color: AppTheme.textSecondary, size: 18),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          const SizedBox(height: 8),

          // スキルリスト
          Expanded(
            child: Consumer<SkillProvider>(
              builder: (context, provider, _) {
                final allSkills = provider.skills;
                final filtered = _searchQuery.isEmpty
                    ? allSkills
                    : allSkills
                        .where((s) => s.title
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase()))
                        .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off,
                            color: AppTheme.textTertiary, size: 40),
                        const SizedBox(height: 8),
                        Text(
                          allSkills.isEmpty
                              ? '登録済みのスキルがありません'
                              : '該当するスキルがありません',
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final skill = filtered[index];
                    return _buildSkillItem(skill);
                  },
                );
              },
            ),
          ),

          // キャンセルボタン
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 8, 16, MediaQuery.of(context).padding.bottom + 12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: widget.onCancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  side: const BorderSide(color: AppTheme.divider),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('キャンセル', style: TextStyle(fontSize: 15)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillItem(Skill skill) {
    final masteryColor = _getMasteryColor(skill.mastery);
    final newSuccess = skill.successCount + widget.successCount;
    final newFail = skill.failCount + widget.failCount;
    final newTotal = newSuccess + newFail;
    final newRate = newTotal > 0 ? newSuccess / newTotal : 0.0;

    return GestureDetector(
      onTap: () => widget.onSelected(skill),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            // 習得度インジケーター
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: masteryColor.withValues(alpha: 0.12),
                border: Border.all(
                    color: masteryColor.withValues(alpha: 0.5), width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                '${skill.mastery}%',
                style: TextStyle(
                  color: masteryColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // スキル情報
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    skill.title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      // 現在の成功数
                      _miniStat('○', skill.successCount.toString(),
                          AppTheme.successGreen),
                      const Text('  →  ',
                          style: TextStyle(
                              color: AppTheme.textTertiary, fontSize: 11)),
                      _miniStat('+${widget.successCount}',
                          newSuccess.toString(), AppTheme.successGreen),
                      const SizedBox(width: 10),
                      _miniStat('×', skill.failCount.toString(),
                          AppTheme.errorRed),
                      const Text('  →  ',
                          style: TextStyle(
                              color: AppTheme.textTertiary, fontSize: 11)),
                      _miniStat('+${widget.failCount}', newFail.toString(),
                          AppTheme.errorRed),
                    ],
                  ),
                ],
              ),
            ),

            // 加算後の成功率プレビュー
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${(newRate * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: _getMasteryColor((newRate * 100).round()),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text('加算後',
                    style:
                        TextStyle(color: AppTheme.textTertiary, fontSize: 10)),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                color: AppTheme.textTertiary, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(color: color, fontSize: 10)),
        const SizedBox(width: 2),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Color _getMasteryColor(int mastery) {
    if (mastery >= 80) return AppTheme.teal;
    if (mastery >= 50) return AppTheme.primaryPurple;
    if (mastery >= 30) return const Color(0xFFFF9800);
    return AppTheme.errorRed.withValues(alpha: 0.8);
  }
}
