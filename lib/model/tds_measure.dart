import 'package:hive/hive.dart';

part 'tds_measure.g.dart';

@HiveType(typeId: 1)
class TdsMeasure {
  @HiveField(0)
  double latitude;
  @HiveField(1)
  double longitude;
  @HiveField(2)
  final double measure;
  @HiveField(3)
  final DateTime datetime;

  TdsMeasure(
      {required this.latitude,
        required this.longitude,
        required this.measure,
        required this.datetime});

  factory TdsMeasure.fromJson(Map<dynamic, dynamic> json) {
    return TdsMeasure(
        longitude: json['longitude'],
        latitude: json['latitude'],
        measure: json['measure'],
        datetime: json['datetime']);
  }

  Map<String, dynamic> toJson() {
    Map<String, dynamic> data = <String, dynamic>{};
    data['latitude'] = latitude;
    data['longitude'] = longitude;
    data['measure'] = measure;
    data['datetime'] = datetime;
    return data;
  }
}
