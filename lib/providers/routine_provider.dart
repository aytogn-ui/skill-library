import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/routine.dart';
import '../models/routine_skill_stats.dart';

class RoutineProvider extends ChangeNotifier {
  late Box<Routine> _routineBox;
  late Box<RoutineSkillStats> _statsBox;
  List<Routine> _routines = [];

  List<Routine> get routines => _routines;

  Future<void> init(Box<Routine> box, Box<RoutineSkillStats> statsBox) async {
    _routineBox = box;
    _statsBox = statsBox;
    _loadRoutines();
  }

  void _loadRoutines() {
    _routines = _routineBox.values.toList();
    _routines.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    notifyListeners();
  }

  Future<void> addRoutine(Routine routine) async {
    await _routineBox.put(routine.id, routine);
    _loadRoutines();
  }

  Future<void> updateRoutine(Routine routine) async {
    routine.updatedAt = DateTime.now();
    await _routineBox.put(routine.id, routine);
    _loadRoutines();
  }

  Future<void> deleteRoutine(String id) async {
    // 関連するStats削除
    final statsToDelete = _statsBox.values
        .where((s) => s.routineId == id)
        .map((s) => s.id)
        .toList();
    for (final key in statsToDelete) {
      await _statsBox.delete(key);
    }
    await _routineBox.delete(id);
    _loadRoutines();
  }

  Routine? getRoutineById(String id) => _routineBox.get(id);

  // ─── ミスカウント ──────────────────────────────────────

  RoutineSkillStats getStats(String routineId, String skillId) {
    final key = RoutineSkillStats.makeId(routineId, skillId);
    return _statsBox.get(key) ??
        RoutineSkillStats(id: key, routineId: routineId, skillId: skillId);
  }

  Future<void> incrementMiss(String routineId, String skillId) async {
    final key = RoutineSkillStats.makeId(routineId, skillId);
    final existing = _statsBox.get(key);
    if (existing != null) {
      existing.missCount += 1;
      await existing.save();
    } else {
      final stats = RoutineSkillStats(
        id: key,
        routineId: routineId,
        skillId: skillId,
        missCount: 1,
      );
      await _statsBox.put(key, stats);
    }
    notifyListeners();
  }

  Future<void> resetMiss(String routineId, String skillId) async {
    final key = RoutineSkillStats.makeId(routineId, skillId);
    final existing = _statsBox.get(key);
    if (existing != null) {
      existing.missCount = 0;
      await existing.save();
      notifyListeners();
    }
  }

  int getMissCount(String routineId, String skillId) {
    return getStats(routineId, skillId).missCount;
  }
}
