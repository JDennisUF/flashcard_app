// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'flashcard_set.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FlashcardSetAdapter extends TypeAdapter<FlashcardSet> {
  @override
  final int typeId = 1;

  @override
  FlashcardSet read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FlashcardSet(
      name: fields[0] as String,
      cards: (fields[1] as List).cast<Flashcard>(),
    );
  }

  @override
  void write(BinaryWriter writer, FlashcardSet obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.cards);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FlashcardSetAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
