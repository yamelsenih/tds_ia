import 'package:tds_ia/model/tds_measure.dart';

class TdsMeasuresPayload {
  final List<TdsMeasure> measures;

  TdsMeasuresPayload({
    required this.measures,
  });

  // Método para convertir el objeto completo a un Map que luego será JSON
  Map<String, dynamic> toJson() {
    return {
      'measures': measures.map((m) => m.toJson()).toList(),
    };
  }
}