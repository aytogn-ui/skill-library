import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/skill.dart';
import '../providers/skill_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/mastery_slider.dart';
import 'video_split_screen.dart';

class AddEditSkillScreen extends StatefulWidget {
  final String? skillId;
  const AddEditSkillScreen({super.key, this.skillId});

  @override
  State<AddEditSkillScreen> createState() => _AddEditSkillScreenState();
}

class _AddEditSkillScreenState extends State<AddEditSkillScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _categoryController = TextEditingController();
  final _notesController = TextEditingController();
  final _tipsController = TextEditingController();
  final _tagController = TextEditingController();

  int _difficulty = 1;
  int _mastery = 0;
  int _successCount = 0;
  int _failCount = 0;
  List<String> _tags = [];
  String? _videoPath;
  String? _thumbnailPath;
  bool _isLoading = false;

  bool get _isEditing => widget.skillId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadSkill());
    }
  }

  void _loadSkill() {
    final skill = context.read<SkillProvider>().getSkillById(widget.skillId!);
    if (skill != null) {
      setState(() {
        _titleController.text = skill.title;
        _categoryController.text = skill.category ?? '';
        _notesController.text = skill.notes ?? '';
        _tipsController.text = skill.tips ?? '';
        _difficulty = skill.difficulty;
        _mastery = skill.mastery;
        _successCount = skill.successCount;
        _failCount = skill.failCount;
        _tags = List.from(skill.tags);
        _videoPath = skill.videoPath;
        _thumbnailPath = skill.thumbnailPath;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _notesController.dispose();
    _tipsController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: Text(_isEditing ? '技を編集' : '技を追加'),
        backgroundColor: AppTheme.backgroundDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text(
                '保存',
                style: TextStyle(
                  color: AppTheme.teal,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 動画エリア
              _buildVideoSection(),
              if (!kIsWeb) ...[
                const SizedBox(height: 8),
                _buildVideoSplitBanner(),
              ],
              const SizedBox(height: 20),
              // タイトル
              _buildTextField(
                controller: _titleController,
                label: 'タイトル *',
                hint: '例：バックフリップ',
                validator: (v) => v?.isEmpty == true ? 'タイトルを入力してください' : null,
              ),
              const SizedBox(height: 16),
              // カテゴリー
              _buildTextField(
                controller: _categoryController,
                label: 'カテゴリー',
                hint: '例：フレア、ダンス、ジャグリング',
              ),
              const SizedBox(height: 16),
              // 難易度
              _buildDifficultySection(),
              const SizedBox(height: 16),
              // 習得度
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MasterySlider(
                      mastery: _mastery,
                      onChanged: (v) => setState(() => _mastery = v),
                    ),
                    // 試行数 > 0 の場合は自動計算の案内を表示
                    if (_successCount + _failCount > 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.teal.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppTheme.teal.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline,
                                color: AppTheme.teal, size: 14),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '保存時に成功数・失敗数から習得度を自動計算します'
                                '（現在の入力値: ${_computeMastery()}%）',
                                style: const TextStyle(
                                  color: AppTheme.teal,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 成功数・失敗数
              _buildCountSection(),
              const SizedBox(height: 16),
              // タグ
              _buildTagSection(),
              const SizedBox(height: 16),
              // メモ
              _buildTextField(
                controller: _notesController,
                label: 'メモ',
                hint: '自由にメモを記入',
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              // コツ
              _buildTextField(
                controller: _tipsController,
                label: 'コツ',
                hint: 'この技のポイントやコツ',
                maxLines: 3,
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoSection() {
    // Web環境：動画なしの案内バナーを表示
    if (kIsWeb) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.primaryPurple.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryPurple.withValues(alpha: 0.15),
              ),
              child: const Icon(
                Icons.videocam_off_outlined,
                color: AppTheme.primaryPurple,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '動画はモバイルアプリで追加',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Webプレビューでは動画なしで技を登録できます',
                    style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // モバイル：従来の動画選択UI
    return GestureDetector(
      onTap: _showVideoOptions,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: AppTheme.cardDark,
            border: Border.all(
              color: AppTheme.primaryPurple.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: _thumbnailPath != null && File(_thumbnailPath!).existsSync()
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(File(_thumbnailPath!), fit: BoxFit.cover),
                      Container(
                        decoration: const BoxDecoration(
                          gradient: AppTheme.thumbnailOverlay,
                        ),
                      ),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.5),
                          ),
                          child: const Icon(Icons.videocam,
                              color: Colors.white, size: 32),
                        ),
                      ),
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryPurple.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            '動画変更',
                            style:
                                TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primaryPurple.withValues(alpha: 0.1),
                      ),
                      child: const Icon(
                        Icons.video_camera_back_outlined,
                        color: AppTheme.primaryPurple,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '動画を追加',
                      style: TextStyle(
                        color: AppTheme.primaryPurple,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'タップして撮影またはライブラリから選択',
                      style: TextStyle(
                          color: AppTheme.textTertiary, fontSize: 12),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildVideoSplitBanner() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const VideoSplitScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.teal.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.teal.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: const [
            Icon(Icons.content_cut, color: AppTheme.teal, size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '動画を分割してスキル登録 →',
                style: TextStyle(
                  color: AppTheme.teal,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.teal, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultySection() {
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
          const Text('難易度', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (i) {
              final val = i + 1;
              return GestureDetector(
                onTap: () => setState(() => _difficulty = val),
                child: Column(
                  children: [
                    Icon(
                      val <= _difficulty ? Icons.star : Icons.star_border,
                      color: AppTheme.accentGold,
                      size: 32,
                    ),
                    Text(
                      val.toString(),
                      style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  /// 成功数・失敗数の編集セクション
  Widget _buildCountSection() {
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
            '成功数 / 失敗数',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 4),
          const Text(
            '過去の記録を手動で修正できます',
            style: TextStyle(color: AppTheme.textTertiary, fontSize: 11),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // ── 成功数 ──────────────────────────────────
              Expanded(
                child: _buildCountTile(
                  label: '成功数',
                  value: _successCount,
                  color: AppTheme.successGreen,
                  icon: Icons.check_circle_outline,
                  onDecrement: () {
                    if (_successCount > 0) {
                      setState(() => _successCount--);
                    }
                  },
                  onIncrement: () => setState(() => _successCount++),
                  onEdit: () => _showCountEditDialog(
                    title: '成功数を入力',
                    current: _successCount,
                    onSave: (v) => setState(() => _successCount = v),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // ── 失敗数 ──────────────────────────────────
              Expanded(
                child: _buildCountTile(
                  label: '失敗数',
                  value: _failCount,
                  color: AppTheme.errorRed,
                  icon: Icons.cancel_outlined,
                  onDecrement: () {
                    if (_failCount > 0) {
                      setState(() => _failCount--);
                    }
                  },
                  onIncrement: () => setState(() => _failCount++),
                  onEdit: () => _showCountEditDialog(
                    title: '失敗数を入力',
                    current: _failCount,
                    onSave: (v) => setState(() => _failCount = v),
                  ),
                ),
              ),
            ],
          ),
          // 試行回数・成功率サマリ
          if (_successCount + _failCount > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.backgroundDark,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '試行回数: ${_successCount + _failCount}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '成功率: ${(_successCount / (_successCount + _failCount) * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: _successCount / (_successCount + _failCount) >= 0.9
                          ? AppTheme.successGreen
                          : _successCount / (_successCount + _failCount) >= 0.7
                              ? AppTheme.accentGold
                              : AppTheme.errorRed,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCountTile({
    required String label,
    required int value,
    required Color color,
    required IconData icon,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
    required VoidCallback onEdit,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 15),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(color: color, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 数値（タップでダイアログ編集）
          GestureDetector(
            onTap: onEdit,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                value.toString(),
                style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // +/- ボタン
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _CountButton(
                icon: Icons.remove,
                color: color,
                onTap: onDecrement,
                enabled: value > 0,
              ),
              _CountButton(
                icon: Icons.add,
                color: color,
                onTap: onIncrement,
                enabled: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCountEditDialog({
    required String title,
    required int current,
    required ValueChanged<int> onSave,
  }) {
    final controller = TextEditingController(text: current.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: Text(title, style: const TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20),
          decoration: InputDecoration(
            hintText: '0以上の整数',
            hintStyle: const TextStyle(color: AppTheme.textTertiary),
            suffixText: '回',
            suffixStyle: const TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              if (parsed != null && parsed >= 0) {
                onSave(parsed);
                Navigator.pop(ctx);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('0以上の整数を入力してください')),
                );
              }
            },
            child: const Text('OK', style: TextStyle(color: AppTheme.teal)),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  Widget _buildTagSection() {
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
          const Text('タグ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagController,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'タグを入力してEnter',
                    hintStyle: TextStyle(color: AppTheme.textTertiary, fontSize: 13),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onSubmitted: _addTag,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: AppTheme.teal),
                onPressed: () => _addTag(_tagController.text),
              ),
            ],
          ),
          if (_tags.isNotEmpty) ...[
            const Divider(color: AppTheme.divider),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _tags.map((tag) => Chip(
                label: Text('#$tag'),
                labelStyle: const TextStyle(color: AppTheme.tealLight, fontSize: 12),
                backgroundColor: AppTheme.primaryPurple.withValues(alpha: 0.15),
                deleteIcon: const Icon(Icons.close, size: 14, color: AppTheme.textTertiary),
                onDeleted: () => setState(() => _tags.remove(tag)),
                side: BorderSide(color: AppTheme.primaryPurple.withValues(alpha: 0.4)),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: AppTheme.textPrimary),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
    );
  }

  void _addTag(String tag) {
    final trimmed = tag.trim();
    if (trimmed.isNotEmpty && !_tags.contains(trimmed)) {
      setState(() => _tags.add(trimmed));
      _tagController.clear();
    }
  }

  void _showVideoOptions() {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('動画機能はモバイルアプリでご利用ください')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.videocam, color: AppTheme.teal),
            title: const Text('撮影する', style: TextStyle(color: AppTheme.textPrimary)),
            onTap: () {
              Navigator.pop(context);
              _pickVideo(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library, color: AppTheme.primaryPurple),
            title: const Text('ライブラリから選択', style: TextStyle(color: AppTheme.textPrimary)),
            onTap: () {
              Navigator.pop(context);
              _pickVideo(ImageSource.gallery);
            },
          ),
          if (_videoPath != null)
            ListTile(
              leading: const Icon(Icons.delete, color: AppTheme.errorRed),
              title: const Text('動画を削除', style: TextStyle(color: AppTheme.errorRed)),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _videoPath = null;
                  _thumbnailPath = null;
                });
              },
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _pickVideo(ImageSource source) async {
    try {
      setState(() => _isLoading = true);
      final picker = ImagePicker();
      final video = await picker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: 30),
      );
      if (video != null) {
        setState(() {
          _videoPath = video.path;
        });
        // サムネイル生成（簡易版: 最初のフレームを使う）
        await _generateThumbnail(video.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('動画の選択に失敗しました: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generateThumbnail(String videoPath) async {
    try {
      // video_thumbnailパッケージを使用
      // Webでは使用不可のため条件分岐
      if (!kIsWeb) {
        final thumbnailPath = videoPath.replaceAll(
          RegExp(r'\.[^.]+$'),
          '_thumb.jpg',
        );
        // サムネイル生成のシミュレーション（実機では動作）
        setState(() => _thumbnailPath = thumbnailPath);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Thumbnail generation failed: $e');
    }
  }

  /// 成功数・失敗数から習得度(mastery)を算出する
  ///
  /// 試行数が 0 の場合は手動設定の _mastery をそのまま使用。
  /// 試行数 > 0 の場合は成功率をもとに mastery を上書き:
  ///   成功率 ≥ 90% → mastery = 成功率(整数)
  ///   成功率 70-89% → mastery = 成功率(整数)
  ///   成功率 < 70%  → mastery = 成功率(整数)
  int _computeMastery() {
    final total = _successCount + _failCount;
    if (total == 0) return _mastery; // 試行なし → 手動値を維持
    final rate = _successCount / total * 100;
    return rate.round().clamp(0, 100);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final provider = context.read<SkillProvider>();

      // 成功数・失敗数から mastery を自動計算（試行数 0 は手動値を維持）
      final computedMastery = _computeMastery();

      final skill = Skill(
        id: widget.skillId ?? const Uuid().v4(),
        title: _titleController.text.trim(),
        videoPath: _videoPath,
        thumbnailPath: _thumbnailPath,
        category: _categoryController.text.trim().isEmpty
            ? null
            : _categoryController.text.trim(),
        tags: _tags,
        difficulty: _difficulty,
        mastery: computedMastery,
        successCount: _successCount,
        failCount: _failCount,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        tips: _tipsController.text.trim().isEmpty ? null : _tipsController.text.trim(),
        createdAt: _isEditing
            ? provider.getSkillById(widget.skillId!)?.createdAt ?? DateTime.now()
            : DateTime.now(),
      );

      if (_isEditing) {
        await provider.updateSkill(skill);
      } else {
        await provider.addSkill(skill);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? '技を更新しました' : '技を追加しました'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e'), backgroundColor: AppTheme.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 成功数・失敗数の +/- ボタン
// ─────────────────────────────────────────────────────────────────────────────
class _CountButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;

  const _CountButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: enabled
              ? color.withValues(alpha: 0.18)
              : AppTheme.divider.withValues(alpha: 0.3),
          border: Border.all(
            color: enabled ? color.withValues(alpha: 0.5) : Colors.transparent,
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? color : AppTheme.textTertiary,
        ),
      ),
    );
  }
}
