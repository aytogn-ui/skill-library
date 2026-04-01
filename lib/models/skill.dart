import 'package:hive/hive.dart';

part 'skill.g.dart';

@HiveType(typeId: 0)
class Skill extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String title;

  @HiveField(2)
  String? videoPath;

  @HiveField(3)
  String? thumbnailPath;

  @HiveField(4)
  String? category;

  @HiveField(5)
  List<String> tags;

  @HiveField(6)
  int difficulty;

  @HiveField(7)
  int mastery;

  @HiveField(8)
  int successCount;

  @HiveField(9)
  int failCount;

  @HiveField(10)
  String? notes;

  @HiveField(11)
  String? tips;

  @HiveField(12)
  String visibility;

  @HiveField(13)
  late DateTime createdAt;

  @HiveField(14)
  DateTime? updatedAt;

  @HiveField(15)
  String? thumbnailUrl;

  // 動画分割用フィールド
  @HiveField(16)
  int? startTimeMs; // ミリ秒

  @HiveField(17)
  int? endTimeMs; // ミリ秒

  @HiveField(18)
  String? sourceVideoId; // 元動画のスキルID or パス

  Skill({
    required this.id,
    required this.title,
    this.videoPath,
    this.thumbnailPath,
    this.thumbnailUrl,
    this.category,
    List<String>? tags,
    this.difficulty = 1,
    this.mastery = 0,
    this.successCount = 0,
    this.failCount = 0,
    this.notes,
    this.tips,
    this.visibility = 'private',
    DateTime? createdAt,
    this.updatedAt,
    this.startTimeMs,
    this.endTimeMs,
    this.sourceVideoId,
  })  : tags = tags ?? [],
        createdAt = createdAt ?? DateTime.now();

  double get successRate {
    final total = successCount + failCount;
    if (total == 0) return 0.0;
    return successCount / total;
  }

  String get successRateText {
    final total = successCount + failCount;
    if (total == 0) return '-';
    return '${(successRate * 100).toStringAsFixed(1)}%';
  }

  bool get isClipped => startTimeMs != null && endTimeMs != null;

  Skill copyWith({
    String? id,
    String? title,
    String? videoPath,
    String? thumbnailPath,
    String? thumbnailUrl,
    String? category,
    List<String>? tags,
    int? difficulty,
    int? mastery,
    int? successCount,
    int? failCount,
    String? notes,
    String? tips,
    String? visibility,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? startTimeMs,
    int? endTimeMs,
    String? sourceVideoId,
  }) {
    return Skill(
      id: id ?? this.id,
      title: title ?? this.title,
      videoPath: videoPath ?? this.videoPath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      category: category ?? this.category,
      tags: tags ?? List.from(this.tags),
      difficulty: difficulty ?? this.difficulty,
      mastery: mastery ?? this.mastery,
      successCount: successCount ?? this.successCount,
      failCount: failCount ?? this.failCount,
      notes: notes ?? this.notes,
      tips: tips ?? this.tips,
      visibility: visibility ?? this.visibility,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      startTimeMs: startTimeMs ?? this.startTimeMs,
      endTimeMs: endTimeMs ?? this.endTimeMs,
      sourceVideoId: sourceVideoId ?? this.sourceVideoId,
    );
  }
}
