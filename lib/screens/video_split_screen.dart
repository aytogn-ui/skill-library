import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';
import '../models/skill.dart';
import '../providers/skill_provider.dart';
import '../services/video_player_manager.dart';
import '../theme/app_theme.dart';

/// 動画分割スキル登録画面（開始/終了2ボタン方式）
/// - 動画を再生し「開始」でstartTime、「終了」でendTimeを記録
/// - バリデーション: 終了 > 開始、両方設定必須
/// - 保存: startTime〜endTimeのクリップをスキルとして登録
class VideoSplitScreen extends StatefulWidget {
  final String? sourceVideoPath;
  final String? sourceSkillId;

  const VideoSplitScreen({
    super.key,
    this.sourceVideoPath,
    this.sourceSkillId,
  });

  @override
  State<VideoSplitScreen> createState() => _VideoSplitScreenState();
}

class _VideoSplitScreenState extends State<VideoSplitScreen>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isFullscreen = false;
  String? _videoPath;

  // 開始・終了時刻（ミリ秒）
  int? _startTimeMs;
  int? _endTimeMs;

  // 保存済みスキルリスト
  final List<_SavedClipRecord> _savedClips = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.sourceVideoPath != null) {
      _loadVideoFromPath(widget.sourceVideoPath!);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _controller?.pause();
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.removeListener(_onProgress);
    VideoPlayerManager.instance.disposeCurrentController();
    _controller = null;
    // 縦向きに戻す
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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

    _controller?.removeListener(_onProgress);
    final ctrl = await VideoPlayerManager.instance.createController(path);

    if (ctrl == null || !mounted) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    await ctrl.setLooping(false);
    ctrl.addListener(_onProgress);

    setState(() {
      _controller = ctrl;
      _videoPath = path;
      _isInitialized = true;
      _isLoading = false;
      _isPlaying = false;
      _startTimeMs = null;
      _endTimeMs = null;
      _savedClips.clear();
    });
  }

  void _onProgress() {
    if (mounted) setState(() {});
  }

  // ─────────────────────────────────────────────
  // 再生コントロール
  // ─────────────────────────────────────────────
  Future<void> _togglePlayPause() async {
    if (_controller == null || !_isInitialized) return;
    if (_isPlaying) {
      await _controller!.pause();
      setState(() => _isPlaying = false);
    } else {
      await _controller!.play();
      setState(() => _isPlaying = true);
    }
  }

  // ─────────────────────────────────────────────
  // 開始・終了マーク
  // ─────────────────────────────────────────────

  /// 「開始」ボタン: 現在位置をstartTimeとして記録
  void _markStart() {
    if (_controller == null || !_isInitialized) return;
    final posMs = _controller!.value.position.inMilliseconds;
    setState(() {
      _startTimeMs = posMs;
      // 開始を変更した場合、終了をリセット
      if (_endTimeMs != null && _endTimeMs! <= posMs) {
        _endTimeMs = null;
      }
    });
    _showSnack('開始位置を設定: ${_formatMs(posMs)}', AppTheme.teal);
  }

  /// 「終了」ボタン: 現在位置をendTimeとして記録（バリデーション付き）
  void _markEnd() {
    if (_controller == null || !_isInitialized) return;

    // バリデーション①: 開始位置が未設定
    if (_startTimeMs == null) {
      _showSnack('先に開始位置を設定してください', AppTheme.errorRed);
      return;
    }

    final posMs = _controller!.value.position.inMilliseconds;

    // バリデーション②: 終了 ≤ 開始
    if (posMs <= _startTimeMs!) {
      _showSnack('終了位置は開始より後に設定してください', AppTheme.errorRed);
      return;
    }

    // バリデーション③: 開始 == 終了（差が200ms未満）
    if (posMs - _startTimeMs! < 200) {
      _showSnack('開始と終了の間隔を200ms以上にしてください', AppTheme.errorRed);
      return;
    }

    setState(() => _endTimeMs = posMs);
    _showSnack('終了位置を設定: ${_formatMs(posMs)}', AppTheme.primaryPurple);
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 保存（startTime〜endTimeをスキルとして登録）
  // ─────────────────────────────────────────────
  Future<void> _saveClip() async {
    if (_videoPath == null || _controller == null) return;

    // 最終バリデーション
    if (_startTimeMs == null) {
      _showSnack('開始位置を設定してください', AppTheme.errorRed);
      return;
    }
    if (_endTimeMs == null) {
      _showSnack('終了位置を設定してください', AppTheme.errorRed);
      return;
    }

    // タイトル入力ダイアログ
    final result = await showModalBottomSheet<Map<String, dynamic>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _SaveClipSheet(
        startMs: _startTimeMs!,
        endMs: _endTimeMs!,
      ),
    );

    if (result == null || result.isEmpty) return;
    if (!mounted) return;

    final title = result['title'] as String? ?? '';
    if (title.isEmpty) return;

    final provider = context.read<SkillProvider>();
    final skill = Skill(
      id: const Uuid().v4(),
      title: title,
      videoPath: _videoPath,
      category: result['category'] as String?,
      tags: (result['tags'] as List<String>?) ?? [],
      difficulty: result['difficulty'] as int? ?? 1,
      notes: result['notes'] as String?,
      startTimeMs: _startTimeMs,
      endTimeMs: _endTimeMs,
      sourceVideoId: widget.sourceSkillId,
      createdAt: DateTime.now(),
    );
    await provider.addSkill(skill);

    _savedClips.add(_SavedClipRecord(
      title: skill.title,
      startMs: _startTimeMs!,
      endMs: _endTimeMs!,
    ));

    setState(() {
      _startTimeMs = null;
      _endTimeMs = null;
    });

    if (mounted) {
      _showSnack('「$title」を登録しました', AppTheme.successGreen);
    }
  }

  // ─────────────────────────────────────────────
  // 全画面切替
  // ─────────────────────────────────────────────
  void _toggleFullscreen() {
    if (_isFullscreen) {
      _exitFullscreen();
    } else {
      _enterFullscreen();
    }
  }

  void _enterFullscreen() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    setState(() => _isFullscreen = true);
  }

  void _exitFullscreen() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    setState(() => _isFullscreen = false);
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isFullscreen) {
      return _buildFullscreenView();
    }
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
              : _buildEditorLayout(),
    );
  }

  // ─────────────────────────────────────────────
  // 全画面ビュー
  // ─────────────────────────────────────────────
  Widget _buildFullscreenView() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 動画（全画面）
          Center(
            child: _controller != null && _controller!.value.isInitialized
                ? AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: VideoPlayer(_controller!),
                  )
                : const SizedBox.shrink(),
          ),
          // 全画面コントロール（タップで表示）
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // シークバー
                if (_controller != null && _controller!.value.isInitialized)
                  _buildSeekBar(),
                // コントロール行
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(width: 16),
                    // 再生/停止
                    GestureDetector(
                      onTap: _togglePlayPause,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppTheme.primaryGradient,
                        ),
                        child: Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // 現在時刻
                    Text(
                      _formatMs(_controller?.value.position.inMilliseconds ?? 0),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    // 全画面終了ボタン
                    GestureDetector(
                      onTap: _exitFullscreen,
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        child: const Icon(Icons.fullscreen_exit,
                            color: Colors.white, size: 28),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 通常レイアウト（上70%:動画 / 下30%:コントロール）
  // ─────────────────────────────────────────────
  Widget _buildEditorLayout() {
    return Column(
      children: [
        // ─── 上部70%: 動画プレイヤー ───
        Expanded(
          flex: 7,
          child: _buildVideoArea(),
        ),
        // ─── 下部30%: コントロール ───
        Expanded(
          flex: 3,
          child: _buildControlArea(),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // 動画エリア
  // ─────────────────────────────────────────────
  Widget _buildVideoArea() {
    final ctrl = _controller;
    return Container(
      color: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 動画本体
          if (ctrl != null && ctrl.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: ctrl.value.aspectRatio,
                child: VideoPlayer(ctrl),
              ),
            )
          else
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_circle_outline,
                      color: AppTheme.textTertiary, size: 64),
                  const SizedBox(height: 8),
                  Text(
                    _videoPath != null ? '動画を読み込んでいます...' : '動画を選択してください',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
          // 全画面ボタン（右下）
          if (ctrl != null && ctrl.value.isInitialized)
            Positioned(
              bottom: 12,
              right: 12,
              child: GestureDetector(
                onTap: _toggleFullscreen,
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          // 開始・終了マーカー表示（左上）
          if (_startTimeMs != null || _endTimeMs != null)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_startTimeMs != null) ...[
                      const Icon(Icons.play_arrow, color: AppTheme.teal, size: 12),
                      Text(
                        _formatMs(_startTimeMs!),
                        style: const TextStyle(
                            color: AppTheme.teal,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                    if (_startTimeMs != null && _endTimeMs != null)
                      const Text(' → ',
                          style: TextStyle(color: Colors.white38, fontSize: 11)),
                    if (_endTimeMs != null) ...[
                      const Icon(Icons.stop, color: AppTheme.primaryPurple, size: 12),
                      Text(
                        _formatMs(_endTimeMs!),
                        style: const TextStyle(
                            color: AppTheme.primaryPurple,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // コントロールエリア（下30%）
  // ─────────────────────────────────────────────
  Widget _buildControlArea() {
    final ctrl = _controller;
    final posMs = ctrl?.value.position.inMilliseconds ?? 0;
    final totalMs = ctrl?.value.duration.inMilliseconds ?? 0;

    return Container(
      color: const Color(0xFF0A0A14),
      child: Column(
        children: [
          // シークバー
          if (ctrl != null && ctrl.value.isInitialized) _buildSeekBar(),

          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  children: [
                    // ── 再生コントロール行 ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // -5s
                        IconButton(
                          icon: const Icon(Icons.replay_5,
                              color: Colors.white70, size: 26),
                          onPressed: ctrl != null
                              ? () {
                                  final p = posMs - 5000;
                                  ctrl.seekTo(Duration(
                                      milliseconds: p.clamp(0, totalMs)));
                                  setState(() {});
                                }
                              : null,
                        ),
                        const SizedBox(width: 8),
                        // 再生/停止ボタン
                        GestureDetector(
                          onTap: _togglePlayPause,
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppTheme.primaryGradient,
                            ),
                            child: Icon(
                              _isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // +5s
                        IconButton(
                          icon: const Icon(Icons.forward_5,
                              color: Colors.white70, size: 26),
                          onPressed: ctrl != null
                              ? () {
                                  final p = posMs + 5000;
                                  ctrl.seekTo(Duration(
                                      milliseconds: p.clamp(0, totalMs)));
                                  setState(() {});
                                }
                              : null,
                        ),
                        const SizedBox(width: 16),
                        // 現在時刻表示
                        Text(
                          '${_formatMs(posMs)} / ${_formatMs(totalMs)}',
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // ── 開始・終了ボタン（横並び）──
                    Row(
                      children: [
                        // 開始ボタン
                        Expanded(
                          child: _buildMarkerButton(
                            label: '開始',
                            icon: Icons.play_arrow,
                            color: AppTheme.teal,
                            isSet: _startTimeMs != null,
                            timeMs: _startTimeMs,
                            onTap: ctrl != null ? _markStart : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // 終了ボタン
                        Expanded(
                          child: _buildMarkerButton(
                            label: '終了',
                            icon: Icons.stop,
                            color: AppTheme.primaryPurple,
                            isSet: _endTimeMs != null,
                            timeMs: _endTimeMs,
                            onTap: ctrl != null ? _markEnd : null,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // ── セグメント長 ──
                    if (_startTimeMs != null && _endTimeMs != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.successGreen.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppTheme.successGreen.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.timer,
                                    color: AppTheme.successGreen, size: 14),
                                const SizedBox(width: 4),
                                const Text('セグメント長',
                                    style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 11)),
                              ],
                            ),
                            Text(
                              _formatMs(_endTimeMs! - _startTimeMs!),
                              style: const TextStyle(
                                color: AppTheme.successGreen,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 8),

                    // ── 保存ボタン ──
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (_startTimeMs != null && _endTimeMs != null)
                            ? _saveClip
                            : null,
                        icon: const Icon(Icons.save_alt, size: 18),
                        label: Text(
                          (_startTimeMs != null && _endTimeMs != null)
                              ? 'スキルとして登録する'
                              : '開始・終了を設定してください',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              (_startTimeMs != null && _endTimeMs != null)
                                  ? AppTheme.successGreen
                                  : AppTheme.divider,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    // ── 保存済みクリップ ──
                    if (_savedClips.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _buildSavedClips(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 開始/終了マーカーボタン
  Widget _buildMarkerButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSet,
    required int? timeMs,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isSet
              ? color.withValues(alpha: 0.15)
              : AppTheme.cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSet
                ? color.withValues(alpha: 0.6)
                : AppTheme.divider,
            width: isSet ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSet ? color : AppTheme.textSecondary, size: 18),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isSet ? color : AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isSet && timeMs != null)
                  Text(
                    _formatMs(timeMs),
                    style: TextStyle(
                      color: color.withValues(alpha: 0.8),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else
                  Text(
                    '未設定',
                    style: const TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeekBar() {
    final ctrl = _controller!;
    final duration = ctrl.value.duration.inMilliseconds.toDouble();
    final position = ctrl.value.position.inMilliseconds
        .toDouble()
        .clamp(0.0, duration > 0 ? duration : 1.0);

    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        activeTrackColor: AppTheme.teal,
        inactiveTrackColor: Colors.white24,
        thumbColor: AppTheme.teal,
        overlayColor: AppTheme.teal.withValues(alpha: 0.2),
      ),
      child: Slider(
        value: position,
        min: 0,
        max: duration > 0 ? duration : 1.0,
        onChanged: (v) {
          ctrl.seekTo(Duration(milliseconds: v.toInt()));
          setState(() {});
        },
      ),
    );
  }

  Widget _buildSavedClips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '登録済みスキル',
          style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        ..._savedClips.map((c) => Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppTheme.successGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: AppTheme.successGreen, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      c.title,
                      style: const TextStyle(
                          color: AppTheme.textPrimary, fontSize: 12),
                    ),
                  ),
                  Text(
                    '${_formatMs(c.startMs)}～${_formatMs(c.endMs)}',
                    style: const TextStyle(
                        color: AppTheme.textTertiary, fontSize: 10),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // 動画未選択状態
  // ─────────────────────────────────────────────
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
            '動画分割 / スキル登録',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '動画を読み込み\n「開始」「終了」で区間を指定して\nスキルとして登録します',
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
              icon: const Icon(Icons.videocam_outlined, color: AppTheme.teal),
              label: const Text('カメラで撮影',
                  style: TextStyle(color: AppTheme.teal)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.teal),
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatMs(int ms) {
    if (ms < 0) ms = 0;
    final s = ms ~/ 1000;
    final m = s ~/ 60;
    final sec = s % 60;
    final cs = (ms % 1000) ~/ 10;
    return '${m.toString().padLeft(1, '0')}:${sec.toString().padLeft(2, '0')}.${cs.toString().padLeft(2, '0')}';
  }
}

// ────────────────────────────────────────────────
// 保存済みクリップ記録
// ────────────────────────────────────────────────
class _SavedClipRecord {
  final String title;
  final int startMs;
  final int endMs;
  _SavedClipRecord(
      {required this.title, required this.startMs, required this.endMs});
}

// ────────────────────────────────────────────────
// クリップ保存BottomSheet（タイトル入力）
// ────────────────────────────────────────────────
class _SaveClipSheet extends StatefulWidget {
  final int startMs;
  final int endMs;
  const _SaveClipSheet({required this.startMs, required this.endMs});

  @override
  State<_SaveClipSheet> createState() => _SaveClipSheetState();
}

class _SaveClipSheetState extends State<_SaveClipSheet> {
  final _titleController = TextEditingController(text: 'スキル 1');
  int _difficulty = 1;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  String _formatMs(int ms) {
    final s = ms ~/ 1000;
    final m = s ~/ 60;
    final sec = s % 60;
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final durationMs = widget.endMs - widget.startMs;
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ハンドル
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'スキルとして登録',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            // 区間情報
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.cardDark,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.divider),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer, color: AppTheme.teal, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    '${_formatMs(widget.startMs)} ～ ${_formatMs(widget.endMs)}',
                    style: const TextStyle(color: AppTheme.teal, fontSize: 13),
                  ),
                  const Spacer(),
                  Text(
                    _formatMs(durationMs),
                    style: const TextStyle(
                        color: AppTheme.textTertiary, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // タイトル入力
            TextField(
              controller: _titleController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'スキルタイトル',
                hintText: 'スキル名を入力',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),
            // 難易度
            Row(
              children: [
                const Text('難易度: ',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
                ...List.generate(5, (star) {
                  return GestureDetector(
                    onTap: () => setState(() => _difficulty = star + 1),
                    child: Icon(
                      (star + 1) <= _difficulty ? Icons.star : Icons.star_border,
                      color: (star + 1) <= _difficulty
                          ? AppTheme.accentGold
                          : AppTheme.textTertiary,
                      size: 22,
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 20),
            // 登録ボタン
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final title = _titleController.text.trim();
                  if (title.isEmpty) return;
                  Navigator.pop(context, {
                    'title': title,
                    'difficulty': _difficulty,
                    'category': null,
                    'tags': <String>[],
                    'notes': null,
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
                  'スキルを登録する',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('キャンセル',
                    style: TextStyle(color: AppTheme.textTertiary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
