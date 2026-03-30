import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/routine.dart';
import '../providers/routine_provider.dart';
import '../providers/skill_provider.dart';
import '../theme/app_theme.dart';

class RoutineDetailScreen extends StatefulWidget {
  final String routineId;
  const RoutineDetailScreen({super.key, required this.routineId});

  @override
  State<RoutineDetailScreen> createState() => _RoutineDetailScreenState();
}

class _RoutineDetailScreenState extends State<RoutineDetailScreen> {
  bool _isEditingTitle = false;
  late TextEditingController _titleController;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    final routine = context.read<RoutineProvider>().getRoutineById(widget.routineId);
    _titleController = TextEditingController(text: routine?.title ?? '');
    _notesController = TextEditingController(text: routine?.notes ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RoutineProvider>(
      builder: (context, provider, _) {
        final routine = provider.getRoutineById(widget.routineId);
        if (routine == null) {
          return const Scaffold(
            backgroundColor: AppTheme.backgroundDark,
            body: Center(child: Text('ルーティンが見つかりません', style: TextStyle(color: AppTheme.textPrimary))),
          );
        }
        return _buildScaffold(context, routine, provider);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, Routine routine, RoutineProvider provider) {
    final skillProvider = context.read<SkillProvider>();

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        title: _isEditingTitle
            ? TextField(
                controller: _titleController,
                autofocus: true,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18),
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
                    const Icon(Icons.edit, size: 14, color: AppTheme.textTertiary),
                  ],
                ),
              ),
        backgroundColor: AppTheme.backgroundDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppTheme.teal),
            onPressed: () => _showAddSkillDialog(context, routine, provider, skillProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // 技リスト（ドラッグ並び替え）
          Expanded(
            child: routine.skillIds.isEmpty
                ? _buildEmptySkillList(context, routine, provider, skillProvider)
                : ReorderableListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: routine.skillIds.length,
                    onReorder: (oldIndex, newIndex) {
                      if (newIndex > oldIndex) newIndex--;
                      final ids = List<String>.from(routine.skillIds);
                      final item = ids.removeAt(oldIndex);
                      ids.insert(newIndex, item);
                      provider.updateRoutine(routine.copyWith(skillIds: ids));
                    },
                    itemBuilder: (context, index) {
                      final skillId = routine.skillIds[index];
                      final skill = skillProvider.getSkillById(skillId);
                      return _buildSkillItem(
                        key: Key(skillId),
                        context: context,
                        index: index,
                        skillTitle: skill?.title ?? '削除された技',
                        mastery: skill?.mastery ?? 0,
                        routine: routine,
                        provider: provider,
                      );
                    },
                  ),
          ),
          // メモ欄
          _buildNotesSection(routine, provider),
        ],
      ),
    );
  }

  Widget _buildSkillItem({
    required Key key,
    required BuildContext context,
    required int index,
    required String skillTitle,
    required int mastery,
    required Routine routine,
    required RoutineProvider provider,
  }) {
    final color = _getMasteryColor(mastery);
    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          // 番号
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.primaryGradient,
            ),
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          // 技タイトル・習得度
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  skillTitle,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$mastery%',
                        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 削除ボタン
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: AppTheme.errorRed, size: 20),
            onPressed: () {
              final ids = List<String>.from(routine.skillIds);
              ids.removeAt(index);
              provider.updateRoutine(routine.copyWith(skillIds: ids));
            },
          ),
          // ドラッグハンドル
          ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_handle, color: AppTheme.textTertiary),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.add_box_outlined, color: AppTheme.textTertiary, size: 56),
          const SizedBox(height: 12),
          const Text(
            '技がありません',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _showAddSkillDialog(context, routine, provider, skillProvider),
            icon: const Icon(Icons.add),
            label: const Text('技を追加'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection(Routine routine, RoutineProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        border: Border(top: BorderSide(color: AppTheme.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notes, color: AppTheme.textTertiary, size: 16),
              const SizedBox(width: 6),
              const Text('メモ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _notesController,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'ルーティンのメモ...',
              hintStyle: TextStyle(color: AppTheme.textTertiary, fontSize: 13),
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

  void _showAddSkillDialog(
    BuildContext context,
    Routine routine,
    RoutineProvider routineProvider,
    SkillProvider skillProvider,
  ) {
    final availableSkills = skillProvider.skills
        .where((s) => !routine.skillIds.contains(s.id))
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, controller) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
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
                  const SizedBox(height: 16),
                  const Text(
                    '技を選択',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: availableSkills.isEmpty
                  ? const Center(
                      child: Text(
                        '追加できる技がありません',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      controller: controller,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: availableSkills.length,
                      itemBuilder: (context, index) {
                        final skill = availableSkills[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              gradient: LinearGradient(
                                colors: [
                                  AppTheme.primaryPurple.withValues(alpha: 0.4),
                                  AppTheme.teal.withValues(alpha: 0.4),
                                ],
                              ),
                            ),
                            child: const Icon(Icons.videocam_outlined, color: Colors.white54, size: 20),
                          ),
                          title: Text(
                            skill.title,
                            style: const TextStyle(color: AppTheme.textPrimary),
                          ),
                          subtitle: Text(
                            '習得度: ${skill.mastery}%',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                          trailing: const Icon(Icons.add_circle, color: AppTheme.teal),
                          onTap: () {
                            final ids = List<String>.from(routine.skillIds)..add(skill.id);
                            routineProvider.updateRoutine(routine.copyWith(skillIds: ids));
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
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
