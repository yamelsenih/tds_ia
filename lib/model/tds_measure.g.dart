// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tds_measure.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TdsMeasureAdapter extends TypeAdapter<TdsMeasure> {
  @override
  final int typeId = 1;

  @override
  TdsMeasure read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TdsMeasure(
      latitude: fields[0] as double,
      longitude: fields[1] as double,
      measure: fields[2] as double,
      datetime: fields[3] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, TdsMeasure obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.latitude)
      ..writeByte(1)
      ..write(obj.longitude)
      ..writeByte(2)
      ..write(obj.measure)
      ..writeByte(3)
      ..write(obj.datetime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TdsMeasureAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
