import 'package:hive/hive.dart';

part 'routine_skill_stats.g.dart';

@HiveType(typeId: 2)
class RoutineSkillStats extends HiveObject {
  @HiveField(0)
  late String id; // "$routineId\_$skillId"

  @HiveField(1)
  late String routineId;

  @HiveField(2)
  late String skillId;

  @HiveField(3)
  int missCount;

  RoutineSkillStats({
    required this.id,
    required this.routineId,
    required this.skillId,
    this.missCount = 0,
  });

  static String makeId(String routineId, String skillId) =>
      '${routineId}__$skillId';
}
