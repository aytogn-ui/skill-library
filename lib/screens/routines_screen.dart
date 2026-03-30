import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/routine_provider.dart';
import '../providers/skill_provider.dart';
import '../models/routine.dart';
import '../theme/app_theme.dart';
import 'routine_detail_screen.dart';

class RoutinesScreen extends StatelessWidget {
  const RoutinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(child: _buildRoutineList(context)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddRoutineDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('ルーティン追加'),
        backgroundColor: AppTheme.primaryPurple,
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          const Text(
            'ルーティン',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Consumer<RoutineProvider>(
            builder: (_, p, __) => Text(
              '${p.routines.length}件',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutineList(BuildContext context) {
    return Consumer<RoutineProvider>(
      builder: (context, provider, _) {
        if (provider.routines.isEmpty) {
          return _buildEmptyState(context);
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          itemCount: provider.routines.length,
          itemBuilder: (context, index) {
            final routine = provider.routines[index];
            return _buildRoutineCard(context, routine, provider);
          },
        );
      },
    );
  }

  Widget _buildRoutineCard(BuildContext context, Routine routine, RoutineProvider provider) {
    final skillProvider = context.read<SkillProvider>();
    final skills = routine.skillIds
        .map((id) => skillProvider.getSkillById(id))
        .where((s) => s != null)
        .toList();

    return Dismissible(
      key: Key(routine.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.errorRed.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: AppTheme.errorRed),
      ),
      confirmDismiss: (_) async {
        return await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: AppTheme.surfaceDark,
            title: const Text('削除確認', style: TextStyle(color: AppTheme.textPrimary)),
            content: Text(
              '「${routine.title}」を削除しますか？',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('削除', style: TextStyle(color: AppTheme.errorRed)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => provider.deleteRoutine(routine.id),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RoutineDetailScreen(routineId: routine.id),
          ),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppTheme.cardGradient,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.divider),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.primaryPurple.withValues(alpha: 0.2),
                    ),
                    child: const Icon(Icons.playlist_play, color: AppTheme.primaryPurple, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      routine.title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios, color: AppTheme.textTertiary, size: 14),
                ],
              ),
              if (skills.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: skills.take(4).map((skill) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.teal.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      skill!.title,
                      style: const TextStyle(color: AppTheme.tealLight, fontSize: 11),
                    ),
                  )).toList(),
                ),
                if (skills.length > 4)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+${skills.length - 4}個の技',
                      style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11),
                    ),
                  ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.sports_martial_arts, color: AppTheme.textTertiary, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${routine.skillIds.length}技',
                    style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12),
                  ),
                  const SizedBox(width: 12),
                  const Icon(Icons.calendar_today, color: AppTheme.textTertiary, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(routine.createdAt),
                    style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
            child: const Icon(Icons.playlist_add, size: 72, color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text(
            'ルーティンがありません',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '複数の技を組み合わせて\nルーティンを作成しましょう',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.6),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  void _showAddRoutineDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('ルーティン追加', style: TextStyle(color: AppTheme.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'ルーティン名',
            hintStyle: TextStyle(color: AppTheme.textTertiary),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              final title = controller.text.trim();
              if (title.isEmpty) return;
              context.read<RoutineProvider>().addRoutine(
                Routine(id: DateTime.now().millisecondsSinceEpoch.toString(), title: title),
              );
              Navigator.pop(context);
              // 詳細画面へ遷移
              final routine = context.read<RoutineProvider>().routines.first;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RoutineDetailScreen(routineId: routine.id),
                ),
              );
            },
            child: const Text('作成'),
          ),
        ],
      ),
    );
  }
}
