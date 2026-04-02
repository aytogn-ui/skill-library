import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// アプリ全体で同時再生を1つに制限するシングルトン管理クラス
class VideoPlayerManager {
  VideoPlayerManager._();
  static final VideoPlayerManager instance = VideoPlayerManager._();

  VideoPlayerController? _currentController;
  String? _currentPath;

  String? get currentPath => _currentPath;

  /// 新しい動画コントローラを生成して返す。
  /// 既存のコントローラは必ず停止・破棄してから生成する。
  Future<VideoPlayerController?> createController(String path) async {
    await disposeCurrentController();

    VideoPlayerController ctrl;
    try {
      if (kIsWeb || path.startsWith('http')) {
        ctrl = VideoPlayerController.networkUrl(Uri.parse(path));
      } else {
        ctrl = VideoPlayerController.file(File(path));
      }
      await ctrl.initialize();
      _currentController = ctrl;
      _currentPath = path;
      return ctrl;
    } catch (e) {
      if (kDebugMode) debugPrint('[VideoPlayerManager] init error: $e');
      return null;
    }
  }

  /// 現在再生中のコントローラを停止・破棄する
  Future<void> disposeCurrentController() async {
    final ctrl = _currentController;
    if (ctrl != null) {
      try {
        await ctrl.pause();
        await ctrl.dispose();
      } catch (_) {}
    }
    _currentController = null;
    _currentPath = null;
  }

  /// 現在再生中かどうか
  bool get isPlaying => _currentController?.value.isPlaying ?? false;

  /// 現在のコントローラを返す（nullの場合あり）
  VideoPlayerController? get currentController => _currentController;
}
