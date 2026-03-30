import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/routine.dart';

class RoutineProvider extends ChangeNotifier {
  late Box<Routine> _routineBox;
  List<Routine> _routines = [];

  List<Routine> get routines => _routines;

  Future<void> init(Box<Routine> box) async {
    _routineBox = box;
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
    await _routineBox.delete(id);
    _loadRoutines();
  }

  Routine? getRoutineById(String id) {
    return _routineBox.get(id);
  }
}
