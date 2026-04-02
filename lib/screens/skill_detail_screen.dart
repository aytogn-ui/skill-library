import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../models/skill.dart';
import '../providers/skill_provider.dart';
import '../services/video_player_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/mastery_slider.dart';
import 'add_edit_skill_screen.dart';

class SkillDetailScreen extends StatefulWidget {
  final String skillId;
  const SkillDetailScreen({super.key, required this.skillId});

  @override
  State<SkillDetailScreen> createState() => _SkillDetailScreenState();
}

class _SkillDetailScreenState extends State<SkillDetailScreen>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 画面表示後に動画を自動ロード・再生
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoPlay();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // アプリがバックグラウンドに移行したら停止
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _controller?.pause();
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  Future<void> _autoPlay() async {
    final skill = context.read<SkillProvider>().getSkillById(widget.skillId);
    if (skill == null) return;
    final path = skill.videoPath;
    if (path == null || path.isEmpty) return;

    if (mounted) setState(() => _isLoading = true);

    // VideoPlayerManager 経由 → 同時再生禁止
    final ctrl = await VideoPlayerManager.instance.createController(path);
    if (ctrl == null || !mounted) return;

    _controller = ctrl;

    try {
      // クリップ開始位置へシーク
      if (skill.isClipped && skill.startTimeMs != null) {
        await ctrl.seekTo(Duration(milliseconds: skill.startTimeMs!));
      }
      await ctrl.setLooping(false);
      await ctrl.setPlaybackSpeed(1.0);
      ctrl.addListener(_onProgress);
      await ctrl.play();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isPlaying = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[SkillDetail] play error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onProgress() {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (mounted) setState(() {});
  }

  void _togglePlay() {
    if (_controller == null || !_isInitialized) return;
    if (_isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.removeListener(_onProgress);
    // 画面離脱時にプレイヤーを停止・破棄
    VideoPlayerManager.instance.disposeCurrentController();
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SkillProvider>(
      builder: (context, provider, _) {
        final skill = provider.getSkillById(widget.skillId);
        if (skill == null) {
          return const Scaffold(
            backgroundColor: AppTheme.backgroundDark,
            body: Center(
              child: Text('技が見つかりません',
                  style: TextStyle(color: AppTheme.textPrimary)),
            ),
          );
        }
        return _buildScaffold(context, skill, provider);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, Skill skill, SkillProvider provider) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context, skill, provider),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitleSection(skill),
                  const SizedBox(height: 16),
                  _buildMasterySection(skill, provider),
                  const SizedBox(height: 16),
                  _buildSuccessSection(skill, provider),
                  const SizedBox(height: 16),
                  if (skill.tags.isNotEmpty) ...[
                    _buildTagsSection(skill),
                    const SizedBox(height: 16),
                  ],
                  if (skill.category != null && skill.category!.isNotEmpty) ...[
                    _buildInfoRow(Icons.category, 'カテゴリー', skill.category!),
                    const SizedBox(height: 12),
                  ],
                  if (skill.notes != null && skill.notes!.isNotEmpty) ...[
                    _buildTextSection(Icons.notes, 'メモ', skill.notes!),
                    const SizedBox(height: 16),
                  ],
                  if (skill.tips != null && skill.tips!.isNotEmpty) ...[
                    _buildTextSection(Icons.lightbulb_outline, 'コツ', skill.tips!),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddEditSkillScreen(skillId: widget.skillId),
            ),
          );
        },
        icon: const Icon(Icons.edit),
        label: const Text('編集'),
        backgroundColor: AppTheme.primaryPurple,
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, Skill skill, SkillProvider provider) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: AppTheme.backgroundDark,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline, color: AppTheme.errorRed),
          onPressed: () => _confirmDelete(context, skill, provider),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          color: Colors.black,
          child: _buildVideoPlayer(skill),
        ),
      ),
    );
  }

  Widget _buildVideoPlayer(Skill skill) {
    // 動画がない場合はサムネイル表示
    if (skill.videoPath == null || skill.videoPath!.isEmpty) {
      return _buildThumbnailFallback(skill);
    }

    // ロード中
    if (_isLoading) {
      return Stack(
        alignment: Alignment.center,
        children: [
          _buildThumbnailFallback(skill),
          const CircularProgressIndicator(color: AppTheme.teal),
        ],
      );
    }

    // 動画初期化済み
    if (_isInitialized && _controller != null) {
      return GestureDetector(
        onTap: _togglePlay,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Aspect Fit: 黒背景＋アスペクト比維持
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            ),
            // 一時停止中のみ再生ボタンを表示
            if (!_isPlaying)
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.6),
                  border: Border.all(color: Colors.white30, width: 2),
                ),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
              ),
            // シークバー（下部）
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildProgressBar(),
            ),
          ],
        ),
      );
    }

    // フォールバック（初期化前）
    return GestureDetector(
      onTap: _autoPlay,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _buildThumbnailFallback(skill),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.6),
              border: Border.all(color: Colors.white30, width: 2),
            ),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    if (_controller == null || !_isInitialized) return const SizedBox.shrink();
    return VideoProgressIndicator(
      _controller!,
      allowScrubbing: true,
      colors: const VideoProgressColors(
        playedColor: AppTheme.teal,
        bufferedColor: Colors.white24,
        backgroundColor: Colors.white12,
      ),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
    );
  }

  Widget _buildThumbnailFallback(Skill skill) {
    if (skill.thumbnailUrl != null && skill.thumbnailUrl!.isNotEmpty) {
      return Image.network(
        skill.thumbnailUrl!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildThumbnailPlaceholder(),
      );
    }
    if (!kIsWeb && skill.thumbnailPath != null && skill.thumbnailPath!.isNotEmpty) {
      return Image.file(
        File(skill.thumbnailPath!),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildThumbnailPlaceholder(),
      );
    }
    return _buildThumbnailPlaceholder();
  }

  Widget _buildThumbnailPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryPurple.withValues(alpha: 0.4),
            AppTheme.teal.withValues(alpha: 0.4),
          ],
        ),
      ),
      child: const Center(
        child: Icon(Icons.videocam, color: Colors.white24, size: 64),
      ),
    );
  }

  Widget _buildTitleSection(Skill skill) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                skill.title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < skill.difficulty ? Icons.star : Icons.star_border,
                      color: AppTheme.accentGold,
                      size: 18,
                    ),
                  ),
                ),
                Text(
                  '難易度 ${skill.difficulty}',
                  style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _formatDate(skill.createdAt),
          style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildMasterySection(Skill skill, SkillProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: MasterySlider(
        mastery: skill.mastery,
        onChanged: (value) {
          provider.updateSkill(skill.copyWith(mastery: value));
        },
      ),
    );
  }

  Widget _buildSuccessSection(Skill skill, SkillProvider provider) {
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
          const Text(
            '成功・失敗カウント',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildCountCard(
                  label: '成功',
                  count: skill.successCount,
                  color: AppTheme.successGreen,
                  icon: Icons.check_circle_outline,
                  onIncrement: () => provider.updateSkill(
                      skill.copyWith(successCount: skill.successCount + 1)),
                  onDecrement: skill.successCount > 0
                      ? () => provider.updateSkill(
                          skill.copyWith(successCount: skill.successCount - 1))
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildCountCard(
                  label: '失敗',
                  count: skill.failCount,
                  color: AppTheme.errorRed,
                  icon: Icons.cancel_outlined,
                  onIncrement: () => provider.updateSkill(
                      skill.copyWith(failCount: skill.failCount + 1)),
                  onDecrement: skill.failCount > 0
                      ? () => provider.updateSkill(
                          skill.copyWith(failCount: skill.failCount - 1))
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.backgroundDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('成功率',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
                Text(
                  skill.successRateText,
                  style: TextStyle(
                    color: _getSuccessRateColor(skill.successRate),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountCard({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
    required VoidCallback onIncrement,
    VoidCallback? onDecrement,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: TextStyle(
                color: color, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              GestureDetector(
                onTap: onDecrement,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: onDecrement != null
                        ? color.withValues(alpha: 0.2)
                        : Colors.transparent,
                  ),
                  child: Icon(
                    Icons.remove,
                    color: onDecrement != null ? color : AppTheme.textTertiary,
                    size: 16,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onIncrement,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.2),
                  ),
                  child: Icon(Icons.add, color: color, size: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTagsSection(Skill skill) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: skill.tags
          .map((tag) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: AppTheme.primaryPurple.withValues(alpha: 0.4)),
                ),
                child: Text('#$tag',
                    style: const TextStyle(
                        color: AppTheme.tealLight, fontSize: 13)),
              ))
          .toList(),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.textTertiary, size: 18),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                color: AppTheme.textTertiary, fontSize: 13)),
        const SizedBox(width: 8),
        Text(value,
            style: const TextStyle(
                color: AppTheme.textPrimary, fontSize: 13)),
      ],
    );
  }

  Widget _buildTextSection(IconData icon, String title, String content) {
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
          Row(
            children: [
              Icon(icon, color: AppTheme.teal, size: 18),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          Text(content,
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontSize: 14, height: 1.6)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} 登録';
  }

  Color _getSuccessRateColor(double rate) {
    if (rate >= 0.8) return AppTheme.successGreen;
    if (rate >= 0.6) return AppTheme.teal;
    if (rate >= 0.4) return AppTheme.primaryPurple;
    if (rate > 0) return const Color(0xFFFF9800);
    return AppTheme.textTertiary;
  }

  void _confirmDelete(
      BuildContext context, Skill skill, SkillProvider provider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('削除確認',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('「${skill.title}」を削除しますか？',
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              provider.deleteSkill(skill.id);
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('削除',
                style: TextStyle(color: AppTheme.errorRed)),
          ),
        ],
      ),
    );
  }
}


