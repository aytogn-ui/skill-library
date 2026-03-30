import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/skill.dart';
import '../theme/app_theme.dart';

class SkillCard extends StatelessWidget {
  final Skill skill;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const SkillCard({
    super.key,
    required this.skill,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: AppTheme.cardGradient,
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryPurple.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildThumbnail(),
              _buildInfo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildThumbnailImage(),
          Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.thumbnailOverlay,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: _buildMasteryBadge(),
          ),
          const Center(
            child: Icon(
              Icons.play_circle_outline,
              color: Colors.white54,
              size: 36,
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            child: _buildDifficultyStars(),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailImage() {
    // 1. ネットワークURL（サンプルデータ用）
    if (skill.thumbnailUrl != null && skill.thumbnailUrl!.isNotEmpty) {
      return Image.network(
        skill.thumbnailUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return _buildPlaceholder(loading: true);
        },
        errorBuilder: (_, __, ___) => _buildPlaceholder(),
      );
    }
    // 2. ローカルファイル（モバイル撮影）
    if (!kIsWeb && skill.thumbnailPath != null && skill.thumbnailPath!.isNotEmpty) {
      final file = File(skill.thumbnailPath!);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(),
        );
      }
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder({bool loading = false}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryPurple.withValues(alpha: 0.3),
            AppTheme.teal.withValues(alpha: 0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white38,
                ),
              )
            : const Icon(
                Icons.videocam_outlined,
                color: Colors.white30,
                size: 40,
              ),
      ),
    );
  }

  Widget _buildMasteryBadge() {
    final color = _getMasteryColor(skill.mastery);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6),
        ],
      ),
      child: Text(
        '${skill.mastery}%',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDifficultyStars() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          return Icon(
            i < skill.difficulty ? Icons.star : Icons.star_border,
            color: AppTheme.accentGold,
            size: 10,
          );
        }),
      ),
    );
  }

  Widget _buildInfo() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            skill.title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (skill.tags.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                ...skill.tags.take(2).map((tag) => Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPurple.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppTheme.primaryPurple.withValues(alpha: 0.5),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            color: AppTheme.tealLight,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    )),
                if (skill.tags.length > 2)
                  Text(
                    '+${skill.tags.length - 2}',
                    style: const TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: skill.mastery / 100,
              backgroundColor: AppTheme.divider,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getMasteryColor(skill.mastery),
              ),
              minHeight: 3,
            ),
          ),
        ],
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
