import '../../application/ports/progreso_remoto_item.dart';

/// DTO for a single item in the `GET /progress` response.
///
/// The backend (`ProgressController.list`, backend ticket 18) returns a **bare
/// JSON array** of these items — *not* an object envelope:
/// ```json
/// [ { "nivelId": "uuid", "puntaje": 600, "estrellas": 2,
///     "movimientos": 12, "segundosRestantes": 55, "completadoEn": "…" }, … ]
/// ```
/// The client only needs `nivelId`, `estrellas` and `puntaje` to merge best
/// per-level; the remaining fields are ignored. Numeric fields are read through
/// `num` so an int or double payload both parse without throwing.
class ProgresoRemotoItemDto {
  /// Creates a progress item DTO.
  const ProgresoRemotoItemDto({
    required this.nivelId,
    required this.estrellas,
    required this.puntaje,
  });

  /// Backend level UUID.
  final String nivelId;

  /// Star rating (0–3).
  final int estrellas;

  /// Best score for this level.
  final int puntaje;

  /// Deserialises from one element of the backend's response array.
  factory ProgresoRemotoItemDto.fromJson(Map<String, dynamic> json) {
    return ProgresoRemotoItemDto(
      nivelId: json['nivelId'] as String,
      estrellas: (json['estrellas'] as num).toInt(),
      puntaje: (json['puntaje'] as num).toInt(),
    );
  }

  /// Maps the DTO to the domain value object.
  ProgresoRemotoItem toEntidad() => ProgresoRemotoItem(
        nivelId: nivelId,
        estrellas: estrellas,
        puntaje: puntaje,
      );
}
