import 'package:hive/hive.dart';

part 'skill_attempt.g.dart';

/// スキル1回分の試技記録
@HiveType(typeId: 3)
class SkillAttempt extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String skillId;

  @HiveField(2)
  late DateTime attemptAt;

  /// true = 成功, false = 失敗
  @HiveField(3)
  late bool isSuccess;

  /// ルーティンID（任意）
  @HiveField(4)
  String? routineId;

  SkillAttempt({
    required this.id,
    required this.skillId,
    required this.attemptAt,
    required this.isSuccess,
    this.routineId,
  });
}
