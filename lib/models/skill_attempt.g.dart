// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'skill_attempt.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SkillAttemptAdapter extends TypeAdapter<SkillAttempt> {
  @override
  final int typeId = 3;

  @override
  SkillAttempt read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SkillAttempt(
      id: fields[0] as String,
      skillId: fields[1] as String,
      attemptAt: fields[2] as DateTime,
      isSuccess: fields[3] as bool,
      routineId: fields[4] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SkillAttempt obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.skillId)
      ..writeByte(2)
      ..write(obj.attemptAt)
      ..writeByte(3)
      ..write(obj.isSuccess)
      ..writeByte(4)
      ..write(obj.routineId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SkillAttemptAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
