import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/skill_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/skill_card.dart';
import 'skill_detail_screen.dart';
import 'add_edit_skill_screen.dart';

class SkillsScreen extends StatefulWidget {
  const SkillsScreen({super.key});

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen> {
  final _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            if (_showSearch) _buildSearchBar(context),
            _buildFilterChips(context),
            _buildSortBar(context),
            Expanded(child: _buildSkillGrid(context)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddSkill(context),
        icon: const Icon(Icons.add),
        label: const Text('技を追加'),
        backgroundColor: AppTheme.primaryPurple,
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
      child: Row(
        children: [
          const Text(
            '技一覧',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              _showSearch ? Icons.search_off : Icons.search,
              color: AppTheme.textSecondary,
            ),
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                  context.read<SkillProvider>().setSearchQuery('');
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list, color: AppTheme.textSecondary),
            onPressed: () => _showFilterSheet(context),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: InputDecoration(
          hintText: 'タイトル・カテゴリー・タグで検索',
          prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: AppTheme.textSecondary),
                  onPressed: () {
                    _searchController.clear();
                    context.read<SkillProvider>().setSearchQuery('');
                  },
                )
              : null,
        ),
        onChanged: (v) => context.read<SkillProvider>().setSearchQuery(v),
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    return Consumer<SkillProvider>(
      builder: (context, provider, _) {
        if (!provider.hasActiveFilters) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.filter_alt, color: AppTheme.teal, size: 16),
              const SizedBox(width: 4),
              const Text(
                'フィルター適用中',
                style: TextStyle(color: AppTheme.teal, fontSize: 12),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => provider.clearFilters(),
                child: const Text('クリア', style: TextStyle(color: AppTheme.errorRed, fontSize: 12)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortBar(BuildContext context) {
    return Consumer<SkillProvider>(
      builder: (context, provider, _) {
        return Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                '${provider.skills.length}件',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const Spacer(),
              _buildSortButton(context, provider, SortType.createdAt, '日付'),
              const SizedBox(width: 8),
              _buildSortButton(context, provider, SortType.mastery, '習得度'),
              const SizedBox(width: 8),
              _buildSortButton(context, provider, SortType.difficulty, '難易度'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortButton(
    BuildContext context,
    SkillProvider provider,
    SortType type,
    String label,
  ) {
    final isActive = provider.sortType == type;
    return GestureDetector(
      onTap: () => provider.setSortType(type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primaryPurple.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppTheme.primaryPurple : AppTheme.divider,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppTheme.primaryPurple : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 2),
              Icon(
                provider.sortDescending
                    ? Icons.arrow_downward
                    : Icons.arrow_upward,
                color: AppTheme.primaryPurple,
                size: 12,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSkillGrid(BuildContext context) {
    return Consumer<SkillProvider>(
      builder: (context, provider, _) {
        if (provider.skills.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search_off, color: AppTheme.textTertiary, size: 48),
                const SizedBox(height: 12),
                Text(
                  provider.hasActiveFilters ? '該当する技がありません' : '技がまだありません',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                ),
                if (provider.hasActiveFilters) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => provider.clearFilters(),
                    child: const Text('フィルターをクリア'),
                  ),
                ],
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: provider.skills.length,
          itemBuilder: (context, index) {
            final skill = provider.skills[index];
            return SkillCard(
              skill: skill,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SkillDetailScreen(skillId: skill.id),
                  ),
                );
              },
              onLongPress: () => _showSkillOptions(context, skill.id),
            );
          },
        );
      },
    );
  }

  void _showSkillOptions(BuildContext context, String skillId) {
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
          ListTile(
            leading: const Icon(Icons.edit, color: AppTheme.teal),
            title: const Text('編集', style: TextStyle(color: AppTheme.textPrimary)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddEditSkillScreen(skillId: skillId),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: AppTheme.errorRed),
            title: const Text('削除', style: TextStyle(color: AppTheme.errorRed)),
            onTap: () {
              Navigator.pop(context);
              _confirmDelete(context, skillId);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String skillId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('削除確認', style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text('この技を削除しますか？', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              context.read<SkillProvider>().deleteSkill(skillId);
              Navigator.pop(context);
            },
            child: const Text('削除', style: TextStyle(color: AppTheme.errorRed)),
          ),
        ],
      ),
    );
  }

  void _navigateToAddSkill(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddEditSkillScreen()),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _FilterSheet(),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet();

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  List<String> _selectedTags = [];
  int? _diffMin;
  int? _diffMax;
  int? _masteryMin;
  int? _masteryMax;

  @override
  void initState() {
    super.initState();
    final provider = context.read<SkillProvider>();
    _selectedTags = List.from(provider.filterTags);
    _diffMin = provider.filterDifficultyMin;
    _diffMax = provider.filterDifficultyMax;
    _masteryMin = provider.filterMasteryMin;
    _masteryMax = provider.filterMasteryMax;
  }

  @override
  Widget build(BuildContext context) {
    final allTags = context.read<SkillProvider>().allTags;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (_, controller) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
              'フィルター',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                controller: controller,
                children: [
                  // タグフィルター
                  if (allTags.isNotEmpty) ...[
                    const Text('タグ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: allTags.map((tag) {
                        final selected = _selectedTags.contains(tag);
                        return FilterChip(
                          label: Text(tag),
                          selected: selected,
                          onSelected: (v) {
                            setState(() {
                              if (v) {
                                _selectedTags.add(tag);
                              } else {
                                _selectedTags.remove(tag);
                              }
                            });
                          },
                          selectedColor: AppTheme.primaryPurple.withValues(alpha: 0.3),
                          checkmarkColor: AppTheme.teal,
                          labelStyle: TextStyle(
                            color: selected ? AppTheme.teal : AppTheme.textSecondary,
                            fontSize: 13,
                          ),
                          side: BorderSide(
                            color: selected ? AppTheme.primaryPurple : AppTheme.divider,
                          ),
                          backgroundColor: AppTheme.cardDark,
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 難易度フィルター
                  const Text('難易度', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: List.generate(5, (i) {
                      final val = i + 1;
                      final selected = (_diffMin ?? 1) <= val && val <= (_diffMax ?? 5);
                      return FilterChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(val, (_) => const Icon(Icons.star, size: 12, color: AppTheme.accentGold)),
                        ),
                        selected: selected,
                        onSelected: (v) {
                          setState(() {
                            if (v) {
                              _diffMin = (_diffMin == null || val < _diffMin!) ? val : _diffMin;
                              _diffMax = (_diffMax == null || val > _diffMax!) ? val : _diffMax;
                            }
                          });
                        },
                        selectedColor: AppTheme.primaryPurple.withValues(alpha: 0.3),
                        backgroundColor: AppTheme.cardDark,
                        side: BorderSide(
                          color: selected ? AppTheme.primaryPurple : AppTheme.divider,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),

                  // 習得度フィルター
                  const Text('習得度', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _masteryChip('初心者', 0, 30),
                      _masteryChip('練習中', 31, 60),
                      _masteryChip('上達中', 61, 79),
                      _masteryChip('高習得', 80, 100),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      context.read<SkillProvider>().clearFilters();
                      Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.divider),
                    ),
                    child: const Text('クリア', style: TextStyle(color: AppTheme.textSecondary)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final provider = context.read<SkillProvider>();
                      provider.setFilterTags(_selectedTags);
                      provider.setFilterDifficulty(_diffMin, _diffMax);
                      provider.setFilterMastery(_masteryMin, _masteryMax);
                      Navigator.pop(context);
                    },
                    child: const Text('適用'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _masteryChip(String label, int min, int max) {
    final selected = _masteryMin == min && _masteryMax == max;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (v) {
        setState(() {
          if (v) {
            _masteryMin = min;
            _masteryMax = max;
          } else {
            _masteryMin = null;
            _masteryMax = null;
          }
        });
      },
      selectedColor: AppTheme.teal.withValues(alpha: 0.3),
      checkmarkColor: AppTheme.teal,
      labelStyle: TextStyle(
        color: selected ? AppTheme.teal : AppTheme.textSecondary,
        fontSize: 13,
      ),
      side: BorderSide(
        color: selected ? AppTheme.teal : AppTheme.divider,
      ),
      backgroundColor: AppTheme.cardDark,
    );
  }
}
