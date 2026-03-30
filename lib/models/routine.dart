import 'package:hive/hive.dart';

part 'routine.g.dart';

@HiveType(typeId: 1)
class Routine extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String title;

  @HiveField(2)
  List<String> skillIds;

  @HiveField(3)
  String? notes;

  @HiveField(4)
  late DateTime createdAt;

  @HiveField(5)
  DateTime? updatedAt;

  Routine({
    required this.id,
    required this.title,
    List<String>? skillIds,
    this.notes,
    DateTime? createdAt,
    this.updatedAt,
  })  : skillIds = skillIds ?? [],
        createdAt = createdAt ?? DateTime.now();

  Routine copyWith({
    String? id,
    String? title,
    List<String>? skillIds,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Routine(
      id: id ?? this.id,
      title: title ?? this.title,
      skillIds: skillIds ?? List.from(this.skillIds),
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
