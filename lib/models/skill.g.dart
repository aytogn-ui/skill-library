// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'skill.dart';

class SkillAdapter extends TypeAdapter<Skill> {
  @override
  final int typeId = 0;

  @override
  Skill read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Skill(
      id: fields[0] as String,
      title: fields[1] as String,
      videoPath: fields[2] as String?,
      thumbnailPath: fields[3] as String?,
      category: fields[4] as String?,
      tags: (fields[5] as List?)?.cast<String>(),
      difficulty: fields[6] as int,
      mastery: fields[7] as int,
      successCount: fields[8] as int,
      failCount: fields[9] as int,
      notes: fields[10] as String?,
      tips: fields[11] as String?,
      visibility: fields[12] as String,
      createdAt: fields[13] as DateTime,
      updatedAt: fields[14] as DateTime?,
      thumbnailUrl: fields[15] as String?,
      startTimeMs: fields[16] as int?,
      endTimeMs: fields[17] as int?,
      sourceVideoId: fields[18] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Skill obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.videoPath)
      ..writeByte(3)
      ..write(obj.thumbnailPath)
      ..writeByte(4)
      ..write(obj.category)
      ..writeByte(5)
      ..write(obj.tags)
      ..writeByte(6)
      ..write(obj.difficulty)
      ..writeByte(7)
      ..write(obj.mastery)
      ..writeByte(8)
      ..write(obj.successCount)
      ..writeByte(9)
      ..write(obj.failCount)
      ..writeByte(10)
      ..write(obj.notes)
      ..writeByte(11)
      ..write(obj.tips)
      ..writeByte(12)
      ..write(obj.visibility)
      ..writeByte(13)
      ..write(obj.createdAt)
      ..writeByte(14)
      ..write(obj.updatedAt)
      ..writeByte(15)
      ..write(obj.thumbnailUrl)
      ..writeByte(16)
      ..write(obj.startTimeMs)
      ..writeByte(17)
      ..write(obj.endTimeMs)
      ..writeByte(18)
      ..write(obj.sourceVideoId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SkillAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
