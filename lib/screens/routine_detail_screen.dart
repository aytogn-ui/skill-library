import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/routine.dart';
import '../models/skill.dart';
import '../providers/routine_provider.dart';
import '../providers/skill_provider.dart';
import '../services/video_player_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/fullscreen_video_player.dart';

class RoutineDetailScreen extends StatefulWidget {
  final String routineId;
  const RoutineDetailScreen({super.key, required this.routineId});

  @override
  State<RoutineDetailScreen> createState() => _RoutineDetailScreenState();
}

class _RoutineDetailScreenState extends State<RoutineDetailScreen> {
  // ──── プレイヤー関連 ────
  VideoPlayerController? _videoController;
  int _currentSkillIndex = 0;
  bool _isPlaying = false;
  bool _isPlayerLoading = false;
  bool _isFullscreen = false;
  double _playbackSpeed = 1.0;
  final List<double> _speedOptions = [0.5, 0.75, 1.0, 1.25, 1.5];

  // ──── タイトル・メモ編集 ────
  bool _isEditingTitle = false;
  late TextEditingController _titleController;
  late TextEditingController _notesController;

  // ──── スキル追加検索 ────
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final routine =
        context.read<RoutineProvider>().getRoutineById(widget.routineId);
    _titleController = TextEditingController(text: routine?.title ?? '');
    _notesController = TextEditingController(text: routine?.notes ?? '');
  }

  @override
  void dispose() {
    _videoController?.removeListener(_onVideoProgress);
    VideoPlayerManager.instance.disposeCurrentController();
    _videoController = null;
    _titleController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // 動画ローダ
  // ─────────────────────────────────────────────
  Future<void> _loadVideo(Skill skill) async {
    // VideoPlayerManager経由で既存プレイヤーを停止・破棄（同時再生禁止）
    _videoController?.removeListener(_onVideoProgress);
    await VideoPlayerManager.instance.disposeCurrentController();
    _videoController = null;

    final path = skill.videoPath;
    if (path == null || path.isEmpty) {
      setState(() {
        _isPlayerLoading = false;
        _isPlaying = false;
      });
      return;
    }

    setState(() => _isPlayerLoading = true);

    // VideoPlayerManager経由で新しいコントローラを生成
    final ctrl = await VideoPlayerManager.instance.createController(path);
    if (ctrl == null || !mounted) {
      setState(() => _isPlayerLoading = false);
      return;
    }

    try {
      await ctrl.setLooping(false);
      await ctrl.setPlaybackSpeed(_playbackSpeed);
      ctrl.addListener(_onVideoProgress);

      setState(() {
        _videoController = ctrl;
        _isPlayerLoading = false;
      });

      if (_isPlaying) {
        await ctrl.play();
      }
    } catch (_) {
      await VideoPlayerManager.instance.disposeCurrentController();
      setState(() {
        _videoController = null;
        _isPlayerLoading = false;
      });
    }
  }

  void _onVideoProgress() {
    if (_videoController == null) return;
    final ctrl = _videoController!;
    final pos = ctrl.value.position;
    final dur = ctrl.value.duration;

    // クリップ終端 or 動画終端 → 次のスキルへ
    if (ctrl.value.isInitialized && !ctrl.value.isBuffering) {
      final routine =
          context.read<RoutineProvider>().getRoutineById(widget.routineId);
      if (routine == null) return;
      final skills = _getRoutineSkills(
          routine, context.read<SkillProvider>());

      final skill = skills.isNotEmpty ? skills[_currentSkillIndex] : null;
      int? endMs = skill?.endTimeMs;

      bool shouldAdvance = false;
      if (endMs != null &&
          pos.inMilliseconds >= endMs &&
          dur.inMilliseconds > 0) {
        shouldAdvance = true;
      } else if (dur.inMilliseconds > 0 &&
          pos.inMilliseconds >= dur.inMilliseconds - 100) {
        shouldAdvance = true;
      }

      if (shouldAdvance && _isPlaying) {
        final next = (_currentSkillIndex + 1) % routine.skillIds.length;
        if (next != _currentSkillIndex) {
          _advanceToSkill(next, skills);
        } else {
          // 1スキルのみ → ループ
          ctrl.seekTo(Duration(milliseconds: skill?.startTimeMs ?? 0));
          ctrl.play();
        }
      }
    }

    if (mounted) setState(() {});
  }

  Future<void> _advanceToSkill(int index, List<Skill?> skills) async {
    setState(() => _currentSkillIndex = index);
    final skill = skills[index];
    if (skill != null) {
      await _loadVideo(skill);
      if (_isPlaying && skill.startTimeMs != null) {
        await _videoController
            ?.seekTo(Duration(milliseconds: skill.startTimeMs!));
        await _videoController?.play();
      } else if (_isPlaying) {
        await _videoController?.play();
      }
    }
  }

  List<Skill?> _getRoutineSkills(Routine routine, SkillProvider sp) {
    return routine.skillIds.map((id) => sp.getSkillById(id)).toList();
  }

  // ─────────────────────────────────────────────
  // 再生コントロール
  // ─────────────────────────────────────────────
  Future<void> _togglePlayPause(Routine routine, SkillProvider sp) async {
    final skills = _getRoutineSkills(routine, sp);
    if (skills.isEmpty) return;

    if (!_isPlaying) {
      // 最初の再生 or 再開
      if (_videoController == null) {
        await _loadVideo(skills[_currentSkillIndex]!);
      }
      final startMs =
          skills[_currentSkillIndex]?.startTimeMs;
      if (startMs != null &&
          (_videoController?.value.position.inMilliseconds ?? 0) < startMs) {
        await _videoController
            ?.seekTo(Duration(milliseconds: startMs));
      }
      await _videoController?.play();
      setState(() => _isPlaying = true);
    } else {
      await _videoController?.pause();
      setState(() => _isPlaying = false);
    }
  }

  Future<void> _setSpeed(double speed) async {
    setState(() => _playbackSpeed = speed);
    await _videoController?.setPlaybackSpeed(speed);
  }

  Future<void> _enterFullscreen() async {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return;
    }
    setState(() => _isFullscreen = true);
    await pushFullscreenVideo(
      context: context,
      controller: _videoController!,
      isPlaying: _isPlaying,
      onTogglePlay: () {
        if (_isPlaying) {
          _videoController?.pause();
        } else {
          _videoController?.play();
        }
        if (mounted) setState(() => _isPlaying = !_isPlaying);
      },
      onExit: () {
        if (mounted) setState(() => _isFullscreen = false);
      },
    );
    if (mounted) setState(() => _isFullscreen = false);
  }

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Consumer2<RoutineProvider, SkillProvider>(
      builder: (context, routineProvider, skillProvider, _) {
        final routine =
            routineProvider.getRoutineById(widget.routineId);
        if (routine == null) {
          return const Scaffold(
            backgroundColor: AppTheme.backgroundDark,
            body: Center(
              child: Text('ルーティンが見つかりません',
                  style: TextStyle(color: AppTheme.textPrimary)),
            ),
          );
        }
        final skills = _getRoutineSkills(routine, skillProvider);
        return Scaffold(
          backgroundColor: AppTheme.backgroundDark,
          appBar: _buildAppBar(routine, routineProvider),
          body: Column(
            children: [
              // ① 連続再生プレイヤー
              _buildPlayer(routine, skills, skillProvider, routineProvider),
              // スクロール可能な下部
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // ② 成功率グラフ
                      if (skills.isNotEmpty)
                        _buildSuccessRateGraph(
                            routine, skills, routineProvider),
                      // ③ 編集リスト
                      _buildEditList(
                          routine, skills, skillProvider, routineProvider),
                      // ④ メモ
                      _buildNotesSection(routine, routineProvider),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  // AppBar
  // ─────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(
      Routine routine, RoutineProvider provider) {
    return AppBar(
      title: _isEditingTitle
          ? TextField(
              controller: _titleController,
              autofocus: true,
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontSize: 18),
              decoration: const InputDecoration(border: InputBorder.none),
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) {
                  provider.updateRoutine(routine.copyWith(title: v.trim()));
                }
                setState(() => _isEditingTitle = false);
              },
            )
          : GestureDetector(
              onTap: () => setState(() => _isEditingTitle = true),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(routine.title),
                  const SizedBox(width: 6),
                  const Icon(Icons.edit,
                      size: 14, color: AppTheme.textTertiary),
                ],
              ),
            ),
      backgroundColor: AppTheme.backgroundDark,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // ① 連続再生プレイヤー
  // ─────────────────────────────────────────────
  Widget _buildPlayer(Routine routine, List<Skill?> skills,
      SkillProvider skillProvider, RoutineProvider routineProvider) {
    final hasSkills = skills.isNotEmpty;
    final currentSkill =
        hasSkills ? skills[_currentSkillIndex] : null;

    return Container(
      color: Colors.black,
      child: Column(
        children: [
          // 動画エリア（Aspect Fit: アスペクト比維持・縦動画対応）
          Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.35,
            ),
            color: Colors.black,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 映像 or プレースホルダー（Aspect Fit）
                if (_videoController != null &&
                    _videoController!.value.isInitialized)
                  Center(
                    child: AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: VideoPlayer(_videoController!),
                    ),
                  )
                else
                  Container(
                    color: const Color(0xFF0A0A14),
                    child: Center(
                      child: _isPlayerLoading
                          ? const CircularProgressIndicator(
                              color: AppTheme.teal)
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  hasSkills
                                      ? Icons.play_circle_outline
                                      : Icons.queue_play_next,
                                  color: AppTheme.textTertiary,
                                  size: 56,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  hasSkills
                                      ? (currentSkill?.title ?? '動画なし')
                                      : '技を追加してください',
                                  style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13),
                                ),
                              ],
                            ),
                    ),
                  ),
                // 現在スキル名・インデックス（右上）
                if (hasSkills)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_currentSkillIndex + 1}/${skills.length}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                // スキル名（下部）
                if (hasSkills && currentSkill != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 24, 12, 8),
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
                      child: Text(
                        currentSkill.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                // 全画面ボタン（右下）
                if (_videoController != null &&
                    _videoController!.value.isInitialized)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: FullscreenButton(
                      isFullscreen: _isFullscreen,
                      onTap: _enterFullscreen,
                    ),
                  ),
              ],
            ),
          ),

          // シークバー
          if (_videoController != null &&
              _videoController!.value.isInitialized)
            _buildSeekBar(),

          // コントロール
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Row(
              children: [
                // 前スキル
                IconButton(
                  icon: const Icon(Icons.skip_previous,
                      color: Colors.white70, size: 28),
                  onPressed: hasSkills
                      ? () => _advanceToSkill(
                          (_currentSkillIndex - 1 + skills.length) %
                              skills.length,
                          skills)
                      : null,
                ),
                // 再生/一時停止
                GestureDetector(
                  onTap: hasSkills
                      ? () => _togglePlayPause(routine, skillProvider)
                      : null,
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
                // 次スキル
                IconButton(
                  icon: const Icon(Icons.skip_next,
                      color: Colors.white70, size: 28),
                  onPressed: hasSkills
                      ? () => _advanceToSkill(
                          (_currentSkillIndex + 1) % skills.length,
                          skills)
                      : null,
                ),

                const Spacer(),

                // ループ常時ON表示
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.teal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppTheme.teal.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.loop, color: AppTheme.teal, size: 14),
                      SizedBox(width: 3),
                      Text('LOOP',
                          style: TextStyle(
                              color: AppTheme.teal,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // 再生速度
                GestureDetector(
                  onTap: () => _showSpeedPicker(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPurple.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppTheme.primaryPurple
                              .withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '$_playbackSpeed×',
                      style: const TextStyle(
                          color: AppTheme.primaryPurple,
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeekBar() {
    final ctrl = _videoController!;
    final duration = ctrl.value.duration.inMilliseconds.toDouble();
    final position = ctrl.value.position.inMilliseconds
        .toDouble()
        .clamp(0.0, duration > 0 ? duration : 1.0);

    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 2,
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

  /// スキルリスト内のミスボタン
  Widget _buildInlineMissButton(RoutineProvider provider, String skillId) {
    final miss = provider.getMissCount(widget.routineId, skillId);
    return GestureDetector(
      onTap: () async {
        await provider.incrementMiss(widget.routineId, skillId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ミス +1（計${miss + 1}回）'),
              duration: const Duration(milliseconds: 700),
              backgroundColor: AppTheme.errorRed.withValues(alpha: 0.85),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 72),
            ),
          );
        }
      },
      child: Container(
        width: 48,
        height: 40,
        decoration: BoxDecoration(
          color: miss > 0
              ? AppTheme.errorRed.withValues(alpha: 0.2)
              : AppTheme.divider.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: miss > 0
                ? AppTheme.errorRed.withValues(alpha: 0.5)
                : AppTheme.divider,
            width: miss > 0 ? 1.5 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Miss',
              style: TextStyle(
                color: miss > 0 ? AppTheme.errorRed : AppTheme.textTertiary,
                fontSize: 9,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
            Text(
              '$miss',
              style: TextStyle(
                color: miss > 0 ? AppTheme.errorRed : AppTheme.textTertiary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSpeedPicker(BuildContext context) {
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
          children: [
            const Text('再生速度',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: _speedOptions.map((speed) {
                final selected = speed == _playbackSpeed;
                return GestureDetector(
                  onTap: () {
                    _setSpeed(speed);
                    Navigator.pop(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.primaryPurple
                          : AppTheme.cardDark,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? AppTheme.primaryPurple
                            : AppTheme.divider,
                      ),
                    ),
                    child: Text(
                      '$speed×',
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : AppTheme.textPrimary,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal,
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

  // ─────────────────────────────────────────────
  // ② 失敗率折れ線グラフ
  // ─────────────────────────────────────────────
  Widget _buildSuccessRateGraph(Routine routine, List<Skill?> skills,
      RoutineProvider routineProvider) {
    final validSkills = skills
        .asMap()
        .entries
        .where((e) => e.value != null)
        .toList();
    if (validSkills.isEmpty) return const SizedBox.shrink();

    // ミスカウント（routineProvider から取得）
    final missCounts = validSkills.map((e) {
      final skill = e.value!;
      return routineProvider.getMissCount(widget.routineId, skill.id);
    }).toList();

    // Y軸最大値：最大ミス数に余白を加えた値（最低4）
    final maxMiss = missCounts.isEmpty
        ? 4
        : missCounts.reduce((a, b) => a > b ? a : b);
    final yMax = (maxMiss < 4 ? 4 : maxMiss + 1).toDouble();

    final spots = validSkills.asMap().entries.map((e) {
      final miss = missCounts[e.key];
      return FlSpot(e.value.key.toDouble(), miss.toDouble());
    }).toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.show_chart,
                  color: AppTheme.errorRed, size: 18),
              const SizedBox(width: 6),
              const Text(
                '失敗率グラフ',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              const Text(
                'ミス回数（初期値0）',
                style: TextStyle(
                    color: AppTheme.textTertiary, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (skills.length - 1).toDouble().clamp(0, double.infinity),
                minY: 0,
                maxY: yMax,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: v == 0
                        ? AppTheme.textTertiary.withValues(alpha: 0.5)
                        : AppTheme.divider,
                    strokeWidth: v == 0 ? 1.0 : 0.5,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 1,
                      getTitlesWidget: (v, _) {
                        if (v != v.roundToDouble()) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          '${v.toInt()}',
                          style: const TextStyle(
                              color: AppTheme.textTertiary, fontSize: 9),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: 1,
                      getTitlesWidget: (v, meta) {
                        // 整数インデックスのみ表示
                        if (v != v.roundToDouble()) {
                          return const SizedBox.shrink();
                        }
                        final idx = v.toInt();
                        if (idx < 0 || idx >= skills.length) {
                          return const SizedBox.shrink();
                        }
                        final skill = skills[idx];
                        final isActive = idx == _currentSkillIndex;
                        // 技名を最大5文字に短縮
                        final rawTitle = skill?.title ?? '?';
                        final label = rawTitle.length > 5
                            ? '${rawTitle.substring(0, 5)}…'
                            : rawTitle;
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            label,
                            style: TextStyle(
                              color: isActive
                                  ? AppTheme.teal
                                  : AppTheme.textTertiary,
                              fontSize: 9,
                              fontWeight: isActive
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    gradient: const LinearGradient(
                      colors: [AppTheme.errorRed, Color(0xFFFF6B35)],
                    ),
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, _, __, index) {
                        final isActive = index == _currentSkillIndex;
                        return FlDotCirclePainter(
                          radius: isActive ? 7 : 4,
                          color: isActive
                              ? const Color(0xFFFF6B35)
                              : AppTheme.errorRed,
                          strokeWidth: isActive ? 2 : 0,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppTheme.errorRed.withValues(alpha: 0.25),
                          AppTheme.errorRed.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) =>
                        AppTheme.cardDarker.withValues(alpha: 0.95),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final idx = spot.x.toInt();
                        final skill =
                            idx < skills.length ? skills[idx] : null;
                        final miss = spot.y.toInt();
                        return LineTooltipItem(
                          '${skill?.title ?? '?'}\nMiss: $miss回',
                          TextStyle(
                            color: miss == 0
                                ? AppTheme.successGreen
                                : miss <= 2
                                    ? const Color(0xFFFF9800)
                                    : AppTheme.errorRed,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
          // ミスカウント凡例
          const SizedBox(height: 8),
          _buildMissLegend(skills, routineProvider),
        ],
      ),
    );
  }

  Widget _buildMissLegend(
      List<Skill?> skills, RoutineProvider routineProvider) {
    final items = skills
        .asMap()
        .entries
        .where((e) =>
            e.value != null &&
            routineProvider.getMissCount(
                    widget.routineId, e.value!.id) >
                0)
        .toList();
    if (items.isEmpty) {
      return const Text(
        'ミス記録なし  |  各スキルの Miss ボタンで記録',
        style: TextStyle(color: AppTheme.textTertiary, fontSize: 10),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: items.map((e) {
        final skill = e.value!;
        final miss = routineProvider.getMissCount(
            widget.routineId, skill.id);
        return Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.errorRed.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '▲${e.key + 1}. ${skill.title}: ×$miss',
            style: const TextStyle(
                color: AppTheme.errorRed, fontSize: 10),
          ),
        );
      }).toList(),
    );
  }

  // ─────────────────────────────────────────────
  // ③ 編集リスト
  // ─────────────────────────────────────────────
  Widget _buildEditList(Routine routine, List<Skill?> skills,
      SkillProvider skillProvider, RoutineProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー
          Row(
            children: [
              const Icon(Icons.list, color: AppTheme.textSecondary, size: 18),
              const SizedBox(width: 6),
              Text(
                '技リスト (${routine.skillIds.length})',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showAddSkillDialog(
                    context, routine, provider, skillProvider),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('追加', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.teal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (routine.skillIds.isEmpty)
            _buildEmptySkillList(
                context, routine, provider, skillProvider)
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: routine.skillIds.length,
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex--;
                final ids = List<String>.from(routine.skillIds);
                final item = ids.removeAt(oldIndex);
                ids.insert(newIndex, item);
                provider.updateRoutine(routine.copyWith(skillIds: ids));
                // 再生中インデックスを追従
                setState(() {
                  if (_currentSkillIndex == oldIndex) {
                    _currentSkillIndex = newIndex;
                  } else if (oldIndex < _currentSkillIndex &&
                      newIndex >= _currentSkillIndex) {
                    _currentSkillIndex--;
                  } else if (oldIndex > _currentSkillIndex &&
                      newIndex <= _currentSkillIndex) {
                    _currentSkillIndex++;
                  }
                });
              },
              itemBuilder: (context, index) {
                final skillId = routine.skillIds[index];
                final skill = skillProvider.getSkillById(skillId);
                return _buildSkillListItem(
                  key: Key(skillId),
                  context: context,
                  index: index,
                  skill: skill,
                  isActive: index == _currentSkillIndex,
                  routine: routine,
                  provider: provider,
                  routineProvider: provider,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSkillListItem({
    required Key key,
    required BuildContext context,
    required int index,
    required Skill? skill,
    required bool isActive,
    required Routine routine,
    required RoutineProvider provider,
    required RoutineProvider routineProvider,
  }) {
    final color = _getMasteryColor(skill?.mastery ?? 0);
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? AppTheme.teal.withValues(alpha: 0.6)
              : AppTheme.divider,
          width: isActive ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // 番号バッジ（タップで移動）
          GestureDetector(
            onTap: () {
              setState(() => _currentSkillIndex = index);
              if (_isPlaying && skill != null) _loadVideo(skill);
            },
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isActive
                    ? const LinearGradient(
                        colors: [AppTheme.teal, AppTheme.primaryPurple])
                    : AppTheme.primaryGradient,
              ),
              alignment: Alignment.center,
              child: isActive
                  ? const Icon(Icons.play_arrow,
                      color: Colors.white, size: 14)
                  : Text(
                      '${index + 1}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          // タイトル・習得度
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  skill?.title ?? '削除された技',
                  style: TextStyle(
                    color: isActive
                        ? AppTheme.teal
                        : AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: isActive
                        ? FontWeight.bold
                        : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${skill?.mastery ?? 0}%',
                        style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      skill?.successRateText ?? '-',
                      style: const TextStyle(
                          color: AppTheme.textTertiary, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // ミスボタン
          if (skill != null)
            _buildInlineMissButton(routineProvider, skill.id),
          // 削除
          IconButton(
            icon: const Icon(Icons.remove_circle_outline,
                color: AppTheme.errorRed, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () {
              final ids = List<String>.from(routine.skillIds);
              ids.removeAt(index);
              // インデックス調整
              setState(() {
                if (_currentSkillIndex >= ids.length && ids.isNotEmpty) {
                  _currentSkillIndex = ids.length - 1;
                } else if (ids.isEmpty) {
                  _currentSkillIndex = 0;
                  _isPlaying = false;
                  _videoController?.pause();
                }
              });
              provider.updateRoutine(routine.copyWith(skillIds: ids));
            },
          ),
          // ドラッグハンドル
          ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_handle,
                color: AppTheme.textTertiary, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySkillList(
    BuildContext context,
    Routine routine,
    RoutineProvider provider,
    SkillProvider skillProvider,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.add_box_outlined,
                color: AppTheme.textTertiary, size: 48),
            const SizedBox(height: 8),
            const Text(
              '技がありません',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _showAddSkillDialog(
                  context, routine, provider, skillProvider),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('技を追加'),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // ④ メモ
  // ─────────────────────────────────────────────
  Widget _buildNotesSection(Routine routine, RoutineProvider provider) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.notes, color: AppTheme.textTertiary, size: 16),
              SizedBox(width: 6),
              Text('メモ',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _notesController,
            style: const TextStyle(
                color: AppTheme.textPrimary, fontSize: 13),
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'ルーティンのメモ...',
              hintStyle: TextStyle(
                  color: AppTheme.textTertiary, fontSize: 13),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (v) {
              provider.updateRoutine(routine.copyWith(notes: v));
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // 技追加ダイアログ
  // ─────────────────────────────────────────────
  void _showAddSkillDialog(
    BuildContext context,
    Routine routine,
    RoutineProvider routineProvider,
    SkillProvider skillProvider,
  ) {
    _searchController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          var query = _searchController.text.toLowerCase();
          final availableSkills = skillProvider.skills
              .where((s) => !routine.skillIds.contains(s.id))
              .where((s) => query.isEmpty ||
                  s.title.toLowerCase().contains(query) ||
                  (s.category?.toLowerCase().contains(query) ?? false))
              .toList();

          return DraggableScrollableSheet(
            initialChildSize: 0.65,
            maxChildSize: 0.95,
            minChildSize: 0.4,
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
                        '技を選択',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: '技名・カテゴリで検索...',
                          prefixIcon: Icon(Icons.search,
                              color: AppTheme.textTertiary, size: 18),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        onChanged: (_) => setModalState(() {}),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: availableSkills.isEmpty
                      ? const Center(
                          child: Text(
                            '追加できる技がありません',
                            style: TextStyle(
                                color: AppTheme.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          itemCount: availableSkills.length,
                          itemBuilder: (context, index) {
                            final skill = availableSkills[index];
                            return ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 4),
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(8),
                                  gradient: LinearGradient(
                                    colors: [
                                      AppTheme.primaryPurple
                                          .withValues(alpha: 0.4),
                                      AppTheme.teal
                                          .withValues(alpha: 0.4),
                                    ],
                                  ),
                                ),
                                child: const Icon(
                                    Icons.videocam_outlined,
                                    color: Colors.white54,
                                    size: 20),
                              ),
                              title: Text(skill.title,
                                  style: const TextStyle(
                                      color: AppTheme.textPrimary)),
                              subtitle: Text(
                                '習得 ${skill.mastery}%  |  ${skill.successRateText}',
                                style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 11),
                              ),
                              trailing: const Icon(Icons.add_circle,
                                  color: AppTheme.teal),
                              onTap: () {
                                final ids =
                                    List<String>.from(routine.skillIds)
                                      ..add(skill.id);
                                routineProvider.updateRoutine(
                                    routine.copyWith(skillIds: ids));
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
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
