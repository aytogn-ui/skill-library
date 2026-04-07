import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_theme.dart';

/// 全画面動画再生ページ
/// - 再生中のプレイヤーを引き継ぎ（同一コントローラを使用）
/// - 全画面: 動画・再生ボタン・全画面終了ボタンのみ表示
/// - 回転: 動画アスペクト比に応じて自動判定
///   - 横動画(16:9等): ランドスケープ
///   - 縦動画(9:16等): ポートレート
/// - デバイス回転追従: 全画面中はAutoRotate許可
/// - 離脱時: 復帰して元の画面へ（再生位置保持）
class FullscreenVideoPage extends StatefulWidget {
  final VideoPlayerController controller;
  final bool isPlaying;
  final VoidCallback? onTogglePlay;
  final VoidCallback? onExit;

  const FullscreenVideoPage({
    super.key,
    required this.controller,
    this.isPlaying = false,
    this.onTogglePlay,
    this.onExit,
  });

  @override
  State<FullscreenVideoPage> createState() => _FullscreenVideoPageState();
}

class _FullscreenVideoPageState extends State<FullscreenVideoPage>
    with WidgetsBindingObserver {
  bool _showControls = true;

  /// 動画が縦向き(portrait)かどうか
  bool get _isPortraitVideo {
    final ar = widget.controller.value.aspectRatio;
    return ar < 1.0; // aspectRatio < 1 → 縦動画
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _applyFullscreenOrientation();
    widget.controller.addListener(_onProgress);

    // 3秒後にコントロールを非表示
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  /// 動画アスペクト比に応じた向きを設定
  void _applyFullscreenOrientation() {
    if (_isPortraitVideo) {
      // 縦動画: ポートレートのまま全画面
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } else {
      // 横動画: ランドスケープ全画面
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_onProgress);
    // ポートレートに戻す
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _onProgress() {
    if (mounted) setState(() {});
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && widget.controller.value.isPlaying) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  void _exitFullscreen() {
    widget.onExit?.call();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final isPlaying = ctrl.value.isPlaying;
    final duration = ctrl.value.duration.inMilliseconds.toDouble();
    final position = ctrl.value.position.inMilliseconds
        .toDouble()
        .clamp(0.0, duration > 0 ? duration : 1.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // 動画本体（中央・アスペクト比維持）
            Center(
              child: ctrl.value.isInitialized
                  ? AspectRatio(
                      aspectRatio: ctrl.value.aspectRatio,
                      child: VideoPlayer(ctrl),
                    )
                  : const CircularProgressIndicator(color: AppTheme.teal),
            ),

            // コントロールオーバーレイ
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_showControls,
                child: Stack(
                  children: [
                    // 暗幕
                    Container(color: Colors.black26),

                    // 中央: 再生/停止ボタン
                    Center(
                      child: GestureDetector(
                        onTap: widget.onTogglePlay,
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.5),
                            border: Border.all(color: Colors.white30, width: 2),
                          ),
                          child: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 38,
                          ),
                        ),
                      ),
                    ),

                    // 下部: シークバー + 全画面終了ボタン
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                        child: Column(
                          children: [
                            // シークバー
                            SliderTheme(
                              data: SliderThemeData(
                                trackHeight: 3,
                                thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 7),
                                overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 14),
                                activeTrackColor: AppTheme.teal,
                                inactiveTrackColor: Colors.white30,
                                thumbColor: AppTheme.teal,
                                overlayColor:
                                    AppTheme.teal.withValues(alpha: 0.2),
                              ),
                              child: Slider(
                                value: position,
                                min: 0,
                                max: duration > 0 ? duration : 1.0,
                                onChanged: (v) {
                                  ctrl.seekTo(
                                      Duration(milliseconds: v.toInt()));
                                  setState(() {});
                                },
                              ),
                            ),
                            // 時刻 + 全画面終了
                            Row(
                              children: [
                                Text(
                                  _formatMs(ctrl.value.position.inMilliseconds),
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 12),
                                ),
                                Text(
                                  ' / ${_formatMs(ctrl.value.duration.inMilliseconds)}',
                                  style: const TextStyle(
                                      color: Colors.white38, fontSize: 12),
                                ),
                                const Spacer(),
                                // 全画面終了ボタン（44×44以上）
                                GestureDetector(
                                  onTap: _exitFullscreen,
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.fullscreen_exit,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMs(int ms) {
    if (ms < 0) ms = 0;
    final s = ms ~/ 1000;
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(1, '0')}:${sec.toString().padLeft(2, '0')}';
  }
}

/// 全画面ボタンウィジェット（オーバーレイ用・右下配置）
/// 最小タップ領域 44×44px を保証
class FullscreenButton extends StatelessWidget {
  final bool isFullscreen;
  final VoidCallback onTap;

  const FullscreenButton({
    super.key,
    required this.isFullscreen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}

/// 全画面ページへのナビゲーションヘルパー
/// コントローラを共有してシームレスな切替を実現
Future<void> pushFullscreenVideo({
  required BuildContext context,
  required VideoPlayerController controller,
  bool isPlaying = false,
  VoidCallback? onTogglePlay,
  VoidCallback? onExit,
}) async {
  await Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      pageBuilder: (_, __, ___) => FullscreenVideoPage(
        controller: controller,
        isPlaying: isPlaying,
        onTogglePlay: onTogglePlay,
        onExit: onExit,
      ),
      transitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}
