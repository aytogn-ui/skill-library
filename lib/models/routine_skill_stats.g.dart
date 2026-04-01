// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routine_skill_stats.dart';

class RoutineSkillStatsAdapter extends TypeAdapter<RoutineSkillStats> {
  @override
  final int typeId = 2;

  @override
  RoutineSkillStats read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RoutineSkillStats(
      id: fields[0] as String,
      routineId: fields[1] as String,
      skillId: fields[2] as String,
      missCount: fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, RoutineSkillStats obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.routineId)
      ..writeByte(2)
      ..write(obj.skillId)
      ..writeByte(3)
      ..write(obj.missCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoutineSkillStatsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
