import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/skill.dart';

enum SortType { createdAt, mastery, difficulty }

class SkillProvider extends ChangeNotifier {
  late Box<Skill> _skillBox;
  List<Skill> _skills = [];

  // フィルター・ソート
  SortType _sortType = SortType.createdAt;
  bool _sortDescending = true;
  List<String> _filterTags = [];
  int? _filterDifficultyMin;
  int? _filterDifficultyMax;
  int? _filterMasteryMin;
  int? _filterMasteryMax;
  String _searchQuery = '';

  List<Skill> get skills => _skills;
  SortType get sortType => _sortType;
  bool get sortDescending => _sortDescending;
  List<String> get filterTags => _filterTags;
  int? get filterDifficultyMin => _filterDifficultyMin;
  int? get filterDifficultyMax => _filterDifficultyMax;
  int? get filterMasteryMin => _filterMasteryMin;
  int? get filterMasteryMax => _filterMasteryMax;
  String get searchQuery => _searchQuery;

  bool get hasActiveFilters =>
      _filterTags.isNotEmpty ||
      _filterDifficultyMin != null ||
      _filterDifficultyMax != null ||
      _filterMasteryMin != null ||
      _filterMasteryMax != null ||
      _searchQuery.isNotEmpty;

  Future<void> init(Box<Skill> box) async {
    _skillBox = box;
    _loadSkills();
  }

  void _loadSkills() {
    _skills = _skillBox.values.toList();
    _applyFiltersAndSort();
    notifyListeners();
  }

  void _applyFiltersAndSort() {
    var filtered = _skillBox.values.toList();

    // 検索
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((s) {
        return s.title.toLowerCase().contains(q) ||
            (s.category?.toLowerCase().contains(q) ?? false) ||
            s.tags.any((t) => t.toLowerCase().contains(q));
      }).toList();
    }

    // タグフィルター
    if (_filterTags.isNotEmpty) {
      filtered = filtered.where((s) {
        return _filterTags.any((t) => s.tags.contains(t));
      }).toList();
    }

    // 難易度フィルター
    if (_filterDifficultyMin != null) {
      filtered = filtered.where((s) => s.difficulty >= _filterDifficultyMin!).toList();
    }
    if (_filterDifficultyMax != null) {
      filtered = filtered.where((s) => s.difficulty <= _filterDifficultyMax!).toList();
    }

    // 習得度フィルター
    if (_filterMasteryMin != null) {
      filtered = filtered.where((s) => s.mastery >= _filterMasteryMin!).toList();
    }
    if (_filterMasteryMax != null) {
      filtered = filtered.where((s) => s.mastery <= _filterMasteryMax!).toList();
    }

    // ソート
    filtered.sort((a, b) {
      int compare;
      switch (_sortType) {
        case SortType.createdAt:
          compare = a.createdAt.compareTo(b.createdAt);
          break;
        case SortType.mastery:
          compare = a.mastery.compareTo(b.mastery);
          break;
        case SortType.difficulty:
          compare = a.difficulty.compareTo(b.difficulty);
          break;
      }
      return _sortDescending ? -compare : compare;
    });

    _skills = filtered;
  }

  // ホーム用
  List<Skill> get recentSkills {
    final all = _skillBox.values.toList();
    all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all.take(5).toList();
  }

  List<Skill> get practicingSkills {
    final all = _skillBox.values.toList();
    return all.where((s) => s.mastery <= 50).toList()
      ..sort((a, b) => b.updatedAt?.compareTo(a.updatedAt ?? a.createdAt) ?? 0);
  }

  List<Skill> get masteredSkills {
    final all = _skillBox.values.toList();
    return all.where((s) => s.mastery >= 80).toList()
      ..sort((a, b) => b.mastery.compareTo(a.mastery));
  }

  // 全タグ取得
  List<String> get allTags {
    final tags = <String>{};
    for (final skill in _skillBox.values) {
      tags.addAll(skill.tags);
    }
    return tags.toList()..sort();
  }

  // CRUD
  Future<void> addSkill(Skill skill) async {
    await _skillBox.put(skill.id, skill);
    _loadSkills();
  }

  Future<void> updateSkill(Skill skill) async {
    skill.updatedAt = DateTime.now();
    await _skillBox.put(skill.id, skill);
    _loadSkills();
  }

  Future<void> deleteSkill(String id) async {
    await _skillBox.delete(id);
    _loadSkills();
  }

  Skill? getSkillById(String id) {
    return _skillBox.get(id);
  }

  // ソート変更
  void setSortType(SortType type) {
    if (_sortType == type) {
      _sortDescending = !_sortDescending;
    } else {
      _sortType = type;
      _sortDescending = true;
    }
    _applyFiltersAndSort();
    notifyListeners();
  }

  // フィルター
  void setFilterTags(List<String> tags) {
    _filterTags = tags;
    _applyFiltersAndSort();
    notifyListeners();
  }

  void setFilterDifficulty(int? min, int? max) {
    _filterDifficultyMin = min;
    _filterDifficultyMax = max;
    _applyFiltersAndSort();
    notifyListeners();
  }

  void setFilterMastery(int? min, int? max) {
    _filterMasteryMin = min;
    _filterMasteryMax = max;
    _applyFiltersAndSort();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFiltersAndSort();
    notifyListeners();
  }

  void clearFilters() {
    _filterTags = [];
    _filterDifficultyMin = null;
    _filterDifficultyMax = null;
    _filterMasteryMin = null;
    _filterMasteryMax = null;
    _searchQuery = '';
    _applyFiltersAndSort();
    notifyListeners();
  }
}
