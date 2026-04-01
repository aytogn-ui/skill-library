import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import '../models/skill.dart';
import '../providers/skill_provider.dart';
import '../theme/app_theme.dart';

/// 動画分割スキル登録画面
/// - ソース動画のロード
/// - タイムライン上でstart/end マーカーを設定
/// - 範囲確認後「スキルとして登録」
/// - 複数回分割可能（ソース動画を保持したまま繰り返し）
class VideoSplitScreen extends StatefulWidget {
  /// 既存スキルのパスから起動する場合
  final String? sourceVideoPath;

  /// 既存スキルIDから起動する場合（分割元スキルとしてリンク）
  final String? sourceSkillId;

  const VideoSplitScreen({
    super.key,
    this.sourceVideoPath,
    this.sourceSkillId,
  });

  @override
  State<VideoSplitScreen> createState() => _VideoSplitScreenState();
}

class _VideoSplitScreenState extends State<VideoSplitScreen> {
  VideoPlayerController? _controller;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _videoPath;

  // マーカー（ミリ秒）
  int _startMs = 0;
  int _endMs = 0;
  bool _isSettingStart = true; // true = 次のセットはstart

  // 登録済みクリップのプレビュー用リスト
  final List<_ClipRecord> _registeredClips = [];

  @override
  void initState() {
    super.initState();
    if (widget.sourceVideoPath != null) {
      _loadVideoFromPath(widget.sourceVideoPath!);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // 動画ロード
  // ─────────────────────────────────────────────
  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final xFile = await picker.pickVideo(source: ImageSource.gallery);
    if (xFile == null) return;
    await _loadVideoFromPath(xFile.path);
  }

  Future<void> _loadVideoFromPath(String path) async {
    setState(() => _isLoading = true);

    await _controller?.dispose();
    _controller = null;

    VideoPlayerController ctrl;
    if (kIsWeb || path.startsWith('http')) {
      ctrl = VideoPlayerController.networkUrl(Uri.parse(path));
    } else {
      ctrl = VideoPlayerController.file(File(path));
    }

    try {
      await ctrl.initialize();
      await ctrl.setLooping(false);
      ctrl.addListener(_onProgress);

      final durationMs = ctrl.value.duration.inMilliseconds;
      setState(() {
        _controller = ctrl;
        _videoPath = path;
        _isInitialized = true;
        _isLoading = false;
        _startMs = 0;
        _endMs = durationMs > 0 ? durationMs : 0;
        _isSettingStart = true;
      });
    } catch (e) {
      await ctrl.dispose();
      setState(() {
        _isLoading = false;
        _isInitialized = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('動画の読み込みに失敗しました: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  void _onProgress() {
    if (mounted) setState(() {});
  }

  // ─────────────────────────────────────────────
  // マーカー操作
  // ─────────────────────────────────────────────
  void _setStart() {
    final pos = _controller?.value.position.inMilliseconds ?? 0;
    setState(() {
      _startMs = pos;
      if (_endMs <= _startMs) {
        _endMs = (_startMs + 1000).clamp(
            0, _controller?.value.duration.inMilliseconds ?? 0);
      }
      _isSettingStart = false;
    });
  }

  void _setEnd() {
    final pos = _controller?.value.position.inMilliseconds ?? 0;
    if (pos <= _startMs) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('終了位置は開始位置より後にしてください'),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() {
      _endMs = pos;
      _isSettingStart = true;
    });
  }

  Future<void> _seekToStart() async {
    await _controller?.seekTo(Duration(milliseconds: _startMs));
    setState(() {});
  }

  Future<void> _seekToEnd() async {
    await _controller?.seekTo(Duration(milliseconds: _endMs));
    setState(() {});
  }

  Future<void> _previewClip() async {
    await _controller?.seekTo(Duration(milliseconds: _startMs));
    await _controller?.play();
    setState(() {});
  }

  // ─────────────────────────────────────────────
  // スキル登録
  // ─────────────────────────────────────────────
  Future<void> _registerAsSkill() async {
    if (_videoPath == null) return;
    final duration = _endMs - _startMs;
    if (duration <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('有効な範囲を設定してください'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    // スキル作成ダイアログ
    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _SkillCreateSheet(
        startMs: _startMs,
        endMs: _endMs,
      ),
    );

    if (result == null) return;
    if (!mounted) return;

    // スキル保存
    final provider = context.read<SkillProvider>();
    final skillId = const Uuid().v4();
    final skill = Skill(
      id: skillId,
      title: result['title'] as String,
      videoPath: _videoPath,
      category: result['category'] as String?,
      tags: (result['tags'] as List<String>?) ?? [],
      difficulty: result['difficulty'] as int? ?? 1,
      notes: result['notes'] as String?,
      startTimeMs: _startMs,
      endTimeMs: _endMs,
      sourceVideoId: widget.sourceSkillId,
      createdAt: DateTime.now(),
    );
    await provider.addSkill(skill);

    // 登録済みリストに追加
    setState(() {
      _registeredClips.add(_ClipRecord(
        title: skill.title,
        startMs: _startMs,
        endMs: _endMs,
      ));
      // マーカーをリセット（次の分割のため）
      _isSettingStart = true;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('「${skill.title}」を登録しました'),
          backgroundColor: AppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: const Text('動画分割 / スキル登録'),
        backgroundColor: AppTheme.backgroundDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isInitialized)
            TextButton.icon(
              onPressed: _pickVideo,
              icon: const Icon(Icons.video_library_outlined,
                  color: AppTheme.teal, size: 18),
              label: const Text('変更',
                  style: TextStyle(color: AppTheme.teal, fontSize: 13)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.teal))
          : !_isInitialized
              ? _buildPickerState()
              : _buildEditorState(),
    );
  }

  Widget _buildPickerState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryPurple.withValues(alpha: 0.2),
                  AppTheme.teal.withValues(alpha: 0.2),
                ],
              ),
              border: Border.all(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.4),
                  width: 2),
            ),
            child: const Icon(Icons.content_cut,
                color: AppTheme.primaryPurple, size: 48),
          ),
          const SizedBox(height: 24),
          const Text(
            '動画分割スキル登録',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '動画を選択して\nStart/End マーカーで範囲を指定し\nスキルとして登録します',
            textAlign: TextAlign.center,
            style:
                TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.6),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _pickVideo,
            icon: const Icon(Icons.video_library_outlined),
            label: const Text('動画を選択'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            ),
          ),
          if (!kIsWeb) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final picker = ImagePicker();
                final xFile = await picker.pickVideo(
                    source: ImageSource.camera,
                    maxDuration: const Duration(seconds: 60));
                if (xFile != null) await _loadVideoFromPath(xFile.path);
              },
              icon: const Icon(Icons.videocam_outlined,
                  color: AppTheme.teal),
              label: const Text('カメラで撮影',
                  style: TextStyle(color: AppTheme.teal)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.teal),
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditorState() {
    final ctrl = _controller!;
    final totalMs = ctrl.value.duration.inMilliseconds;
    final posMs = ctrl.value.position.inMilliseconds;

    return Column(
      children: [
        // 動画プレイヤー
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            color: Colors.black,
            child: ctrl.value.isInitialized
                ? VideoPlayer(ctrl)
                : const Center(
                    child: CircularProgressIndicator(color: AppTheme.teal)),
          ),
        ),

        // シークバー（マーカー付き）
        _buildTimeline(posMs, totalMs),

        // 主操作エリア（スクロール可能）
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // マーカー情報カード
                _buildMarkerCard(totalMs),
                const SizedBox(height: 16),

                // 再生コントロール
                _buildPlayControls(ctrl),
                const SizedBox(height: 16),

                // マーカー設定ボタン
                _buildMarkerButtons(),
                const SizedBox(height: 20),

                // 登録ボタン
                _buildRegisterButton(),
                const SizedBox(height: 16),

                // 登録済みクリップ
                if (_registeredClips.isNotEmpty)
                  _buildRegisteredClips(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeline(int posMs, int totalMs) {
    final total = totalMs > 0 ? totalMs.toDouble() : 1.0;
    final startFrac = (_startMs / total).clamp(0.0, 1.0);
    final endFrac = (_endMs / total).clamp(0.0, 1.0);

    return Container(
      color: const Color(0xFF0A0A14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // カスタムタイムラインバー
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              return GestureDetector(
                onTapDown: (d) {
                  final frac = (d.localPosition.dx / w).clamp(0.0, 1.0);
                  final seekMs = (frac * total).toInt();
                  _controller?.seekTo(Duration(milliseconds: seekMs));
                },
                child: SizedBox(
                  height: 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // トラック
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // 選択範囲ハイライト
                      Positioned(
                        left: w * startFrac,
                        width: (w * (endFrac - startFrac)).clamp(0.0, w),
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.primaryPurple, AppTheme.teal],
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      // 現在位置インジケーター
                      Positioned(
                        left: (w * (posMs / total).clamp(0.0, 1.0)) - 1,
                        child: Container(
                          width: 3,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                        ),
                      ),
                      // Start マーカー
                      Positioned(
                        left: (w * startFrac) - 8,
                        top: 0,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryPurple,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('S',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold)),
                            ),
                            Container(
                              width: 2,
                              height: 24,
                              color: AppTheme.primaryPurple,
                            ),
                          ],
                        ),
                      ),
                      // End マーカー
                      Positioned(
                        left: (w * endFrac) - 8,
                        top: 0,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppTheme.teal,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('E',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold)),
                            ),
                            Container(
                              width: 2,
                              height: 24,
                              color: AppTheme.teal,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          // 時刻表示
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatMs(posMs),
                style: const TextStyle(
                    color: Colors.white60, fontSize: 10),
              ),
              Text(
                _formatMs(totalMs),
                style: const TextStyle(
                    color: Colors.white60, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMarkerCard(int totalMs) {
    final duration = _endMs - _startMs;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.content_cut,
                  color: AppTheme.primaryPurple, size: 18),
              const SizedBox(width: 6),
              const Text(
                '分割範囲',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryPurple, AppTheme.teal],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _formatMs(duration),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _markerInfo(
                  label: 'START',
                  timeMs: _startMs,
                  color: AppTheme.primaryPurple,
                  onSeek: _seekToStart,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _markerInfo(
                  label: 'END',
                  timeMs: _endMs,
                  color: AppTheme.teal,
                  onSeek: _seekToEnd,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _markerInfo({
    required String label,
    required int timeMs,
    required Color color,
    required VoidCallback onSeek,
  }) {
    return GestureDetector(
      onTap: onSeek,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              _formatMs(timeMs),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.touch_app, color: color, size: 10),
                const SizedBox(width: 2),
                Text('タップしてシーク',
                    style: TextStyle(color: color, fontSize: 9)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayControls(VideoPlayerController ctrl) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // -5s
        IconButton(
          icon: const Icon(Icons.replay_5, color: Colors.white70),
          onPressed: () {
            final pos = ctrl.value.position.inMilliseconds - 5000;
            ctrl.seekTo(Duration(milliseconds: pos.clamp(0, 999999)));
            setState(() {});
          },
        ),
        // 再生/停止
        GestureDetector(
          onTap: () async {
            if (ctrl.value.isPlaying) {
              await ctrl.pause();
            } else {
              await ctrl.play();
            }
            setState(() {});
          },
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.primaryGradient,
            ),
            child: Icon(
              ctrl.value.isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
        // +5s
        IconButton(
          icon: const Icon(Icons.forward_5, color: Colors.white70),
          onPressed: () {
            final pos = ctrl.value.position.inMilliseconds + 5000;
            ctrl.seekTo(Duration(
                milliseconds:
                    pos.clamp(0, ctrl.value.duration.inMilliseconds)));
            setState(() {});
          },
        ),
        const SizedBox(width: 16),
        // クリッププレビュー
        OutlinedButton.icon(
          onPressed: _previewClip,
          icon: const Icon(Icons.preview, size: 16),
          label: const Text('範囲確認', style: TextStyle(fontSize: 12)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.teal,
            side: const BorderSide(color: AppTheme.teal),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
        ),
      ],
    );
  }

  Widget _buildMarkerButtons() {
    return Row(
      children: [
        // START セット
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isSettingStart ? _setStart : null,
            icon: const Icon(Icons.flag, size: 16),
            label: const Text('START をセット'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isSettingStart
                  ? AppTheme.primaryPurple
                  : AppTheme.primaryPurple.withValues(alpha: 0.3),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // END セット
        Expanded(
          child: ElevatedButton.icon(
            onPressed: !_isSettingStart ? _setEnd : null,
            icon: const Icon(Icons.flag_outlined, size: 16),
            label: const Text('END をセット'),
            style: ElevatedButton.styleFrom(
              backgroundColor: !_isSettingStart
                  ? AppTheme.teal
                  : AppTheme.teal.withValues(alpha: 0.3),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterButton() {
    final duration = _endMs - _startMs;
    final isValid = duration > 0 && _videoPath != null;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isValid ? _registerAsSkill : null,
        icon: const Icon(Icons.add_circle_outline, size: 20),
        label: Text(
          isValid
              ? 'スキルとして登録 (${_formatMs(duration)})'
              : '範囲を設定してください',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isValid ? AppTheme.successGreen : AppTheme.divider,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildRegisteredClips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '登録済みクリップ',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ..._registeredClips.asMap().entries.map((e) {
          final clip = e.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppTheme.successGreen.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle,
                    color: AppTheme.successGreen, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${e.key + 1}. ${clip.title}',
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 13),
                  ),
                ),
                Text(
                  '${_formatMs(clip.startMs)} – ${_formatMs(clip.endMs)}',
                  style: const TextStyle(
                      color: AppTheme.textTertiary, fontSize: 11),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  String _formatMs(int ms) {
    if (ms < 0) ms = 0;
    final s = ms ~/ 1000;
    final m = s ~/ 60;
    final sec = s % 60;
    final centisec = (ms % 1000) ~/ 10;
    return '${m.toString().padLeft(1, '0')}:${sec.toString().padLeft(2, '0')}.${centisec.toString().padLeft(2, '0')}';
  }
}

// ────────────────────────────────────────────────
// 登録済みクリップ記録
// ────────────────────────────────────────────────
class _ClipRecord {
  final String title;
  final int startMs;
  final int endMs;
  _ClipRecord({required this.title, required this.startMs, required this.endMs});
}

// ────────────────────────────────────────────────
// スキル作成BottomSheet
// ────────────────────────────────────────────────
class _SkillCreateSheet extends StatefulWidget {
  final int startMs;
  final int endMs;

  const _SkillCreateSheet({required this.startMs, required this.endMs});

  @override
  State<_SkillCreateSheet> createState() => _SkillCreateSheetState();
}

class _SkillCreateSheetState extends State<_SkillCreateSheet> {
  final _titleController = TextEditingController();
  final _categoryController = TextEditingController();
  final _notesController = TextEditingController();
  final _tagsController = TextEditingController();
  int _difficulty = 1;
  final List<String> _tags = [];

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _notesController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _addTag() {
    final tag = _tagsController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagsController.clear();
      });
    }
  }

  String _formatMs(int ms) {
    final s = ms ~/ 1000;
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                  const SizedBox(height: 12),
                  const Text(
                    'スキルとして登録',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_formatMs(widget.startMs)} ～ ${_formatMs(widget.endMs)}',
                    style: const TextStyle(
                        color: AppTheme.teal, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Divider(color: AppTheme.divider),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  // タイトル（必須）
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'タイトル *',
                      hintText: '例: バックフリップ',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // カテゴリ
                  TextField(
                    controller: _categoryController,
                    decoration: const InputDecoration(
                      labelText: 'カテゴリ',
                      hintText: '例: アクロバット',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 難易度
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('難易度',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13)),
                      const SizedBox(height: 8),
                      Row(
                        children: List.generate(5, (i) {
                          final star = i + 1;
                          return GestureDetector(
                            onTap: () => setState(() => _difficulty = star),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Icon(
                                star <= _difficulty
                                    ? Icons.star
                                    : Icons.star_border,
                                color: star <= _difficulty
                                    ? AppTheme.accentGold
                                    : AppTheme.textTertiary,
                                size: 28,
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // タグ
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _tagsController,
                          decoration: const InputDecoration(
                            labelText: 'タグ',
                            hintText: 'タグを入力してEnter',
                          ),
                          onSubmitted: (_) => _addTag(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _addTag,
                        icon:
                            const Icon(Icons.add_circle, color: AppTheme.teal),
                      ),
                    ],
                  ),
                  if (_tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: _tags.map((tag) {
                        return Chip(
                          label: Text(tag),
                          deleteIconColor: AppTheme.textTertiary,
                          onDeleted: () =>
                              setState(() => _tags.remove(tag)),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // メモ
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'メモ',
                      hintText: 'メモや練習ポイント...',
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 登録ボタン
                  ElevatedButton(
                    onPressed: () {
                      final title = _titleController.text.trim();
                      if (title.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('タイトルを入力してください'),
                            backgroundColor: AppTheme.errorRed,
                          ),
                        );
                        return;
                      }
                      Navigator.pop(context, {
                        'title': title,
                        'category': _categoryController.text.trim().isEmpty
                            ? null
                            : _categoryController.text.trim(),
                        'tags': List<String>.from(_tags),
                        'difficulty': _difficulty,
                        'notes': _notesController.text.trim().isEmpty
                            ? null
                            : _notesController.text.trim(),
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '登録する',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text('キャンセル',
                        style: TextStyle(color: AppTheme.textTertiary)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
