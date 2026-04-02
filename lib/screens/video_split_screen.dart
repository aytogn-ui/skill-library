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

/// 動画分割スキル登録画面
/// - 再生 → 一時停止した位置で「ここで分割」→ 保存
/// - 複数の分割ポイントを追加可能
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

  // 分割ポイントリスト（ミリ秒）
  final List<int> _splitPoints = [];

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
      _splitPoints.clear();
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
  // 分割ポイント追加
  // ─────────────────────────────────────────────
  void _addSplitPoint() {
    if (_controller == null || !_isInitialized) return;
    final posMs = _controller!.value.position.inMilliseconds;
    // 重複チェック（前後100ms以内は同一扱い）
    final isDuplicate = _splitPoints.any((p) => (p - posMs).abs() < 100);
    if (isDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('この位置には既に分割ポイントがあります'),
          backgroundColor: AppTheme.primaryPurple,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() {
      _splitPoints.add(posMs);
      _splitPoints.sort(); // 昇順ソート
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('分割ポイントを追加: ${_formatMs(posMs)}'),
        backgroundColor: AppTheme.teal,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1200),
      ),
    );
  }

  void _removeSplitPoint(int index) {
    setState(() => _splitPoints.removeAt(index));
  }

  Future<void> _seekToPoint(int ms) async {
    await _controller?.seekTo(Duration(milliseconds: ms));
    setState(() {});
  }

  // ─────────────────────────────────────────────
  // 保存（分割して各セクションをスキルとして登録）
  // ─────────────────────────────────────────────
  Future<void> _saveAll() async {
    if (_videoPath == null || _controller == null) return;
    if (_splitPoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('分割ポイントを追加してください'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    final totalMs = _controller!.value.duration.inMilliseconds;

    // セクションを生成（0→pt1, pt1→pt2, ..., ptN→end）
    final boundaries = [0, ..._splitPoints, totalMs];
    final sections = <Map<String, int>>[];
    for (int i = 0; i < boundaries.length - 1; i++) {
      final start = boundaries[i];
      final end = boundaries[i + 1];
      if (end - start > 200) {
        // 200ms以上のセクションのみ有効
        sections.add({'start': start, 'end': end});
      }
    }

    if (sections.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('有効なセクションがありません'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    // 一括登録ダイアログ
    final results = await showModalBottomSheet<List<Map<String, dynamic>>?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _BulkSaveSheet(sections: sections),
    );

    if (results == null || results.isEmpty) return;
    if (!mounted) return;

    final provider = context.read<SkillProvider>();
    int savedCount = 0;

    for (int i = 0; i < results.length; i++) {
      final r = results[i];
      final title = r['title'] as String?;
      if (title == null || title.isEmpty) continue;

      final section = sections[i];
      final skill = Skill(
        id: const Uuid().v4(),
        title: title,
        videoPath: _videoPath,
        category: r['category'] as String?,
        tags: (r['tags'] as List<String>?) ?? [],
        difficulty: r['difficulty'] as int? ?? 1,
        notes: r['notes'] as String?,
        startTimeMs: section['start'],
        endTimeMs: section['end'],
        sourceVideoId: widget.sourceSkillId,
        createdAt: DateTime.now(),
      );
      await provider.addSkill(skill);
      _savedClips.add(_SavedClipRecord(
        title: skill.title,
        startMs: section['start']!,
        endMs: section['end']!,
      ));
      savedCount++;
    }

    setState(() {
      _splitPoints.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$savedCount件のスキルを登録しました'),
          backgroundColor: AppTheme.successGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
  // 動画エリア（アスペクト比維持・縦中央・圧縮禁止）
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
            // アスペクト比を維持しつつ横幅にフィット・縦中央
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
          // 分割ポイント数バッジ（左上）
          if (_splitPoints.isNotEmpty)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.teal.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '分割ポイント: ${_splitPoints.length}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
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

                    // ── ここで分割ボタン ──
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: ctrl != null ? _addSplitPoint : null,
                        icon: const Icon(Icons.content_cut, size: 18),
                        label: const Text(
                          'ここで分割',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    // ── 分割ポイントリスト（最大3件を表示） ──
                    if (_splitPoints.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildSplitPointList(),
                    ],

                    const SizedBox(height: 8),

                    // ── 保存ボタン ──
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _splitPoints.isNotEmpty ? _saveAll : null,
                        icon: const Icon(Icons.save_alt, size: 18),
                        label: Text(
                          _splitPoints.isNotEmpty
                              ? '保存 (${_splitPoints.length + 1}セクション → スキル登録)'
                              : '分割ポイントを追加してください',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _splitPoints.isNotEmpty
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

  Widget _buildSplitPointList() {
    final showCount = _splitPoints.length > 3 ? 3 : _splitPoints.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.cut, color: AppTheme.textTertiary, size: 13),
            const SizedBox(width: 4),
            Text(
              '分割ポイント (${_splitPoints.length}件)',
              style: const TextStyle(
                  color: AppTheme.textTertiary, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...List.generate(showCount, (i) {
          final pt = _splitPoints[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primaryPurple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppTheme.primaryPurple.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.content_cut,
                    color: AppTheme.primaryPurple, size: 13),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _seekToPoint(pt),
                  child: Text(
                    _formatMs(pt),
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _removeSplitPoint(i),
                  child: const Icon(Icons.close,
                      color: AppTheme.textTertiary, size: 16),
                ),
              ],
            ),
          );
        }),
        if (_splitPoints.length > 3)
          Text(
            '  ...他${_splitPoints.length - 3}件',
            style: const TextStyle(
                color: AppTheme.textTertiary, fontSize: 10),
          ),
      ],
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
            '動画を再生し、分割したい位置で\n「ここで分割」をタップして\n自動的にスキルとして登録します',
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
// 一括保存BottomSheet
// ────────────────────────────────────────────────
class _BulkSaveSheet extends StatefulWidget {
  final List<Map<String, int>> sections;
  const _BulkSaveSheet({required this.sections});

  @override
  State<_BulkSaveSheet> createState() => _BulkSaveSheetState();
}

class _BulkSaveSheetState extends State<_BulkSaveSheet> {
  late List<TextEditingController> _titleControllers;
  late List<int> _difficulties;

  @override
  void initState() {
    super.initState();
    _titleControllers = List.generate(
      widget.sections.length,
      (i) => TextEditingController(text: 'スキル ${i + 1}'),
    );
    _difficulties = List.filled(widget.sections.length, 1);
  }

  @override
  void dispose() {
    for (final c in _titleControllers) {
      c.dispose();
    }
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
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scroll) => Column(
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
                  Text(
                    '${widget.sections.length}件のスキルとして登録',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '各セクションのタイトルを入力してください',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Divider(color: AppTheme.divider),
            Expanded(
              child: ListView.builder(
                controller: scroll,
                padding: const EdgeInsets.all(16),
                itemCount: widget.sections.length,
                itemBuilder: (context, i) {
                  final s = widget.sections[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.cardDark,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // セクション情報
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AppTheme.primaryPurple,
                                    AppTheme.teal
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${i + 1}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_formatMs(s['start']!)} ～ ${_formatMs(s['end']!)}',
                              style: const TextStyle(
                                  color: AppTheme.teal, fontSize: 13),
                            ),
                            const Spacer(),
                            Text(
                              _formatMs(s['end']! - s['start']!),
                              style: const TextStyle(
                                  color: AppTheme.textTertiary,
                                  fontSize: 11),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // タイトル入力
                        TextField(
                          controller: _titleControllers[i],
                          decoration: InputDecoration(
                            labelText: 'タイトル',
                            hintText: 'スキル ${i + 1}',
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // 難易度
                        Row(
                          children: [
                            const Text('難易度: ',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12)),
                            ...List.generate(5, (star) {
                              return GestureDetector(
                                onTap: () => setState(
                                    () => _difficulties[i] = star + 1),
                                child: Icon(
                                  (star + 1) <= _difficulties[i]
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: (star + 1) <= _difficulties[i]
                                      ? AppTheme.accentGold
                                      : AppTheme.textTertiary,
                                  size: 22,
                                ),
                              );
                            }),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final results = List.generate(
                          widget.sections.length,
                          (i) => {
                            'title': _titleControllers[i].text.trim(),
                            'difficulty': _difficulties[i],
                            'category': null,
                            'tags': <String>[],
                            'notes': null,
                          },
                        );
                        Navigator.pop(context, results);
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
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text('キャンセル',
                        style:
                            TextStyle(color: AppTheme.textTertiary)),
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
