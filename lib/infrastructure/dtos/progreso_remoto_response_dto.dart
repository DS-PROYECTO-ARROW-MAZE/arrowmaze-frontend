import '../../application/ports/progreso_remoto_item.dart';

/// DTO for the `GET /progress` response envelope — mirrors backend ticket 18's
/// contract exactly: `{ "niveles": [ { "nivelId", "estrellas", "puntaje" }, … ] }`.
class ProgresoRemotoResponseDto {
  /// Creates the response DTO.
  const ProgresoRemotoResponseDto({required this.niveles});

  /// The list of progression items returned by the backend.
  final List<ProgresoRemotoItemDto> niveles;

  /// Deserialises from the backend JSON shape.
  factory ProgresoRemotoResponseDto.fromJson(Map<String, dynamic> json) {
    final items = (json['niveles'] as List<dynamic>)
        .map((e) => ProgresoRemotoItemDto.fromJson(e as Map<String, dynamic>))
        .toList();
    return ProgresoRemotoResponseDto(niveles: items);
  }
}

/// DTO for a single item inside the `GET /progress` response.
///
/// Shape: `{ "nivelId": "uuid", "estrellas": 2, "puntaje": 600 }`.
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

  /// Deserialises from the backend JSON shape.
  factory ProgresoRemotoItemDto.fromJson(Map<String, dynamic> json) {
    return ProgresoRemotoItemDto(
      nivelId: json['nivelId'] as String,
      estrellas: json['estrellas'] as int,
      puntaje: json['puntaje'] as int,
    );
  }

  /// Maps the DTO to the domain value object.
  ProgresoRemotoItem toEntidad() => ProgresoRemotoItem(
        nivelId: nivelId,
        estrellas: estrellas,
        puntaje: puntaje,
      );
}