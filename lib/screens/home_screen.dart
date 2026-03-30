import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/skill.dart';
import '../providers/skill_provider.dart';
import '../providers/routine_provider.dart';
import '../services/sample_data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/skill_card.dart';
import 'skill_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            _buildAppBar(context),
            _buildBody(context),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Row(
          children: [
            ShaderMask(
              shaderCallback: (bounds) =>
                  AppTheme.primaryGradient.createShader(bounds),
              child: const Text(
                'Skill Library',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const Spacer(),
            // サンプルデータボタン
            Consumer<SkillProvider>(
              builder: (context, skillProvider, _) {
                final hasSample = skillProvider.skills
                    .any((s) => s.id.startsWith('sample_'));
                return IconButton(
                  icon: Icon(
                    hasSample
                        ? Icons.dataset_outlined
                        : Icons.dataset,
                    color: hasSample
                        ? AppTheme.textTertiary
                        : AppTheme.teal,
                    size: 22,
                  ),
                  tooltip: hasSample ? 'サンプルデータを削除' : 'サンプルデータを読み込む',
                  onPressed: () => hasSample
                      ? _removeSampleData(context)
                      : _loadSampleData(context),
                );
              },
            ),
            const SizedBox(width: 4),
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.primaryGradient,
              ),
              child: const Icon(Icons.person_outline,
                  color: Colors.white, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Consumer<SkillProvider>(
      builder: (context, skillProvider, _) {
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // サマリーカード
                _buildSummaryCards(skillProvider),
                const SizedBox(height: 24),
                // 最近追加
                if (skillProvider.recentSkills.isNotEmpty) ...[
                  _buildSectionHeader(
                      '最近追加', Icons.access_time, context),
                  const SizedBox(height: 12),
                  _buildHorizontalSkillList(
                      skillProvider.recentSkills, context),
                  const SizedBox(height: 24),
                ],
                // 練習中（習得度50%以下）
                if (skillProvider.practicingSkills.isNotEmpty) ...[
                  _buildSectionHeader(
                      '練習中', Icons.fitness_center, context,
                      subtitle: '習得度 50% 以下'),
                  const SizedBox(height: 12),
                  _buildHorizontalSkillList(
                      skillProvider.practicingSkills, context),
                  const SizedBox(height: 24),
                ],
                // 高習得（80%以上）
                if (skillProvider.masteredSkills.isNotEmpty) ...[
                  _buildSectionHeader(
                      '高習得', Icons.emoji_events, context,
                      subtitle: '習得度 80% 以上',
                      iconColor: AppTheme.accentGold),
                  const SizedBox(height: 12),
                  _buildHorizontalSkillList(
                      skillProvider.masteredSkills, context),
                  const SizedBox(height: 24),
                ],
                // 技がない場合
                if (skillProvider.recentSkills.isEmpty)
                  _buildEmptyState(context),
                const SizedBox(height: 100),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryCards(SkillProvider provider) {
    final totalSkills = provider.skills.length;
    double avgMastery = 0;
    if (totalSkills > 0) {
      final allSkills = provider.skills;
      avgMastery =
          allSkills.fold(0, (sum, s) => sum + s.mastery) / allSkills.length;
    }

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.sports_martial_arts,
            value: totalSkills.toString(),
            label: '技の数',
            gradient: AppTheme.primaryGradient,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.trending_up,
            value: '${avgMastery.toStringAsFixed(0)}%',
            label: '平均習得度',
            gradient: const LinearGradient(
              colors: [AppTheme.teal, Color(0xFF00838F)],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.emoji_events,
            value: provider.masteredSkills.length.toString(),
            label: '高習得技',
            gradient: const LinearGradient(
              colors: [Color(0xFFFF9800), Color(0xFFE65100)],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required LinearGradient gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    IconData icon,
    BuildContext context, {
    String? subtitle,
    Color? iconColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor ?? AppTheme.primaryPurple, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(width: 8),
          Text(
            subtitle,
            style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildHorizontalSkillList(
      List<Skill> skills, BuildContext context) {
    return SizedBox(
      height: 210,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: skills.length,
        itemBuilder: (context, index) {
          final skill = skills[index];
          return Padding(
            padding: EdgeInsets.only(
              right: index < skills.length - 1 ? 12 : 0,
            ),
            child: SizedBox(
              width: 200,
              child: SkillCard(
                skill: skill,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SkillDetailScreen(skillId: skill.id),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShaderMask(
            shaderCallback: (bounds) =>
                AppTheme.primaryGradient.createShader(bounds),
            child: const Icon(
              Icons.sports_martial_arts,
              size: 80,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'まだ技がありません',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '右下の + ボタンから\n最初の技を登録しましょう！',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // サンプルデータ読み込みボタン（目立つ配置）
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _loadSampleData(context),
              icon: const Icon(Icons.dataset, color: AppTheme.teal),
              label: const Text(
                'サンプルデータを読み込む',
                style: TextStyle(color: AppTheme.teal, fontSize: 15),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.teal, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '8種類のパフォーマンス技のサンプルが入ります',
            style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.primaryPurple.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              children: [
                _buildTip(Icons.videocam, '動画で技を記録'),
                const SizedBox(height: 8),
                _buildTip(Icons.trending_up, '習得度をトラッキング'),
                const SizedBox(height: 8),
                _buildTip(Icons.playlist_play, 'ルーティンを作成'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTip(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.teal, size: 18),
        const SizedBox(width: 10),
        Text(
          text,
          style:
              const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
      ],
    );
  }

  // ─── サンプルデータ操作 ───────────────────────────

  Future<void> _loadSampleData(BuildContext context) async {
    final skillProvider = context.read<SkillProvider>();
    final routineProvider = context.read<RoutineProvider>();

    // 既に入っているサンプルを一旦消す（重複防止）
    final existingIds = skillProvider.skills
        .where((s) => s.id.startsWith('sample_'))
        .map((s) => s.id)
        .toList();
    for (final id in existingIds) {
      await skillProvider.deleteSkill(id);
    }

    // スキル追加
    final sampleSkills = SampleDataService.getSampleSkills();
    for (final skill in sampleSkills) {
      await skillProvider.addSkill(skill);
    }

    // ルーティン追加
    final existingRoutineIds = routineProvider.routines
        .where((r) => r.id.startsWith('routine_'))
        .map((r) => r.id)
        .toList();
    for (final id in existingRoutineIds) {
      await routineProvider.deleteRoutine(id);
    }
    final sampleRoutines = SampleDataService.getSampleRoutines();
    for (final routine in sampleRoutines) {
      await routineProvider.addRoutine(routine);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                  '${sampleSkills.length}件の技・${sampleRoutines.length}件のルーティンを読み込みました'),
            ],
          ),
          backgroundColor: AppTheme.successGreen,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _removeSampleData(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('サンプルデータを削除',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text('読み込んだサンプルデータをすべて削除しますか？',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除', style: TextStyle(color: AppTheme.errorRed)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final skillProvider = context.read<SkillProvider>();
    final routineProvider = context.read<RoutineProvider>();

    final sampleSkillIds = skillProvider.skills
        .where((s) => s.id.startsWith('sample_'))
        .map((s) => s.id)
        .toList();
    for (final id in sampleSkillIds) {
      await skillProvider.deleteSkill(id);
    }

    final sampleRoutineIds = routineProvider.routines
        .where((r) => r.id.startsWith('routine_'))
        .map((r) => r.id)
        .toList();
    for (final id in sampleRoutineIds) {
      await routineProvider.deleteRoutine(id);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('サンプルデータを削除しました'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }
}
