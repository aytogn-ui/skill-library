import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/skill.dart';
import '../theme/app_theme.dart';

class RoutinePlayer extends StatefulWidget {
  final List<Skill> skills;
  final int initialIndex;
  final ValueChanged<int> onSkillChanged; // 現在再生中のindex通知

  const RoutinePlayer({
    super.key,
    required this.skills,
    required this.initialIndex,
    required this.onSkillChanged,
  });

  @override
  State<RoutinePlayer> createState() => RoutinePlayerState();
}

class RoutinePlayerState extends State<RoutinePlayer> {
  VideoPlayerController? _controller;
  int _currentIndex = 0;
  double _playbackSpeed = 1.0;
  bool _isInitialized = false;
  bool _isPlaying = false;

  static const List<double> _speeds = [0.5, 0.75, 1.0, 1.25, 1.5];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    if (!kIsWeb && widget.skills.isNotEmpty) {
      _initPlayer(_currentIndex);
    }
  }

  @override
  void didUpdateWidget(RoutinePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // スキルリストが変わった場合はリセット
    if (oldWidget.skills.length != widget.skills.length) {
      if (!kIsWeb && widget.skills.isNotEmpty) {
        _currentIndex = 0;
        _initPlayer(0);
      }
    }
  }

  Future<void> _initPlayer(int index) async {
    if (index >= widget.skills.length) return;
    final skill = widget.skills[index];

    await _controller?.dispose();
    _controller = null;
    setState(() {
      _isInitialized = false;
      _isPlaying = false;
    });

    final path = skill.videoPath;
    if (path == null || path.isEmpty) {
      widget.onSkillChanged(index);
      return;
    }

    _controller = VideoPlayerController.file(File(path));

    try {
      await _controller!.initialize();

      // クリップ範囲がある場合は開始位置にシーク
      if (skill.isClipped && skill.startTimeMs != null) {
        await _controller!.seekTo(Duration(milliseconds: skill.startTimeMs!));
      }

      _controller!.addListener(_onVideoProgress);
      await _controller!.setPlaybackSpeed(_playbackSpeed);
      await _controller!.play();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isPlaying = true;
        });
        widget.onSkillChanged(index);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Video init error: $e');
    }
  }

  void _onVideoProgress() {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final pos = _controller!.value.position;
    final skill = widget.skills[_currentIndex];

    // クリップ終端 or 動画終端に達したら次へ
    final endMs = skill.isClipped ? skill.endTimeMs! : _controller!.value.duration.inMilliseconds;
    if (pos.inMilliseconds >= endMs - 200) {
      _nextSkill();
    }

    if (mounted) setState(() {});
  }

  void _nextSkill() {
    final next = (_currentIndex + 1) % widget.skills.length;
    _currentIndex = next;
    _initPlayer(next);
  }

  void _prevSkill() {
    final prev = (_currentIndex - 1 + widget.skills.length) % widget.skills.length;
    _currentIndex = prev;
    _initPlayer(prev);
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

  void _changeSpeed(double speed) {
    _playbackSpeed = speed;
    _controller?.setPlaybackSpeed(speed);
    setState(() {});
  }

  Duration get _currentPosition =>
      _controller?.value.position ?? Duration.zero;

  Duration get _duration {
    if (_controller == null || !_isInitialized) return Duration.zero;
    final skill = widget.skills[_currentIndex];
    if (skill.isClipped) {
      return Duration(milliseconds: (skill.endTimeMs! - (skill.startTimeMs ?? 0)));
    }
    return _controller!.value.duration;
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoProgress);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return _buildWebPlaceholder();
    if (widget.skills.isEmpty) return _buildNoSkillPlaceholder();

    final skill = widget.skills[_currentIndex];
    return Container(
      color: Colors.black,
      child: Column(
        children: [
          // 動画エリア
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 動画 or サムネイル
                _buildVideoArea(skill),
                // スキル情報オーバーレイ
                Positioned(
                  top: 10,
                  left: 12,
                  right: 12,
                  child: _buildSkillInfo(skill),
                ),
                // 速度バッジ
                Positioned(
                  top: 10,
                  right: 12,
                  child: _buildSpeedBadge(),
                ),
              ],
            ),
          ),
          // シークバー＋コントロール
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildVideoArea(Skill skill) {
    if (!_isInitialized || _controller == null) {
      return _buildThumbnailOrPlaceholder(skill);
    }
    return GestureDetector(
      onTap: _togglePlay,
      child: AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: VideoPlayer(_controller!),
      ),
    );
  }

  Widget _buildThumbnailOrPlaceholder(Skill skill) {
    // サムネイルがあれば表示
    if (skill.thumbnailUrl != null) {
      return Image.network(skill.thumbnailUrl!, fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => _buildVideoPlaceholder(skill));
    }
    if (skill.thumbnailPath != null) {
      final f = File(skill.thumbnailPath!);
      if (f.existsSync()) return Image.file(f, fit: BoxFit.contain);
    }
    return _buildVideoPlaceholder(skill);
  }

  Widget _buildVideoPlaceholder(Skill skill) {
    return Container(
      color: AppTheme.cardDark,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_outlined, color: Colors.white24, size: 48),
            const SizedBox(height: 8),
            Text(
              skill.videoPath == null ? '動画なし' : '読み込み中...',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillInfo(Skill skill) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_currentIndex + 1} / ${widget.skills.length}',
                style: const TextStyle(
                    color: AppTheme.teal,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  skill.title,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSpeedBadge() {
    return GestureDetector(
      onTap: () => _showSpeedPicker(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primaryPurple.withValues(alpha: 0.6)),
        ),
        child: Text(
          '${_playbackSpeed}x',
          style: const TextStyle(
              color: AppTheme.primaryPurple, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildControls() {
    final pos = _currentPosition;
    final dur = _duration;
    final progress = dur.inMilliseconds > 0
        ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        children: [
          // シークバー
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.teal,
              inactiveTrackColor: Colors.white12,
              thumbColor: AppTheme.teal,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              trackHeight: 3,
            ),
            child: Slider(
              value: progress,
              onChanged: (v) {
                if (_controller == null || !_isInitialized) return;
                final skill = widget.skills[_currentIndex];
                final startMs = skill.startTimeMs ?? 0;
                final endMs = skill.isClipped
                    ? skill.endTimeMs!
                    : _controller!.value.duration.inMilliseconds;
                final seekMs = startMs + ((endMs - startMs) * v).round();
                _controller!.seekTo(Duration(milliseconds: seekMs));
              },
            ),
          ),
          // 時間表示＋コントロールボタン
          Row(
            children: [
              Text(
                _formatDuration(pos),
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
              const Spacer(),
              // 前スキル
              IconButton(
                icon: const Icon(Icons.skip_previous, color: Colors.white70),
                iconSize: 28,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                onPressed: widget.skills.length > 1 ? _prevSkill : null,
              ),
              // 再生/一時停止
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.teal.withValues(alpha: 0.2),
                    border: Border.all(color: AppTheme.teal, width: 1.5),
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    color: AppTheme.teal,
                    size: 24,
                  ),
                ),
              ),
              // 次スキル
              IconButton(
                icon: const Icon(Icons.skip_next, color: Colors.white70),
                iconSize: 28,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                onPressed: widget.skills.length > 1 ? _nextSkill : null,
              ),
              const Spacer(),
              Text(
                _formatDuration(dur),
                style: const TextStyle(color: Colors.white54, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWebPlaceholder() {
    return Container(
      color: AppTheme.cardDark,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.play_circle_outline, color: AppTheme.teal, size: 48),
          const SizedBox(height: 8),
          const Text(
            'ルーティン連続再生',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'モバイルアプリで動画を再生できます',
            style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
          ),
          if (widget.skills.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSkillQueue(),
          ],
        ],
      ),
    );
  }

  Widget _buildSkillQueue() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: widget.skills.asMap().entries.map((e) {
          final i = e.key;
          final skill = e.value;
          final isActive = i == _currentIndex;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive
                        ? AppTheme.teal
                        : AppTheme.primaryPurple.withValues(alpha: 0.3),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: isActive ? Colors.white : AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    skill.title,
                    style: TextStyle(
                      color: isActive ? AppTheme.teal : AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                Text(
                  skill.successRateText,
                  style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNoSkillPlaceholder() {
    return Container(
      color: AppTheme.cardDark,
      alignment: Alignment.center,
      child: const Text(
        'スキルを追加してください',
        style: TextStyle(color: AppTheme.textTertiary),
      ),
    );
  }

  void _showSpeedPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('再生速度',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              children: _speeds.map((s) {
                final isSelected = s == _playbackSpeed;
                return GestureDetector(
                  onTap: () {
                    _changeSpeed(s);
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryPurple
                          : AppTheme.cardDark,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.primaryPurple
                            : AppTheme.divider,
                      ),
                    ),
                    child: Text(
                      '${s}x',
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppTheme.textSecondary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
