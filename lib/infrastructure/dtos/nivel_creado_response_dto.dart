import '../../domain/niveles/nivel_creado.dart';

/// DTO for the `POST /levels` response body.
///
/// Expected shape: `{ "id": "uuid", "nombre": "...", ... }`. Only the fields the
/// client needs are mapped; extra server fields are ignored.
class NivelCreadoResponseDto {
  /// Creates a created-level response DTO.
  const NivelCreadoResponseDto({required this.nivel});

  /// Parses the response JSON into the domain value object.
  factory NivelCreadoResponseDto.fromJson(Map<String, dynamic> json) {
    return NivelCreadoResponseDto(
      nivel: NivelCreado(
        id: json['id'] as String,
        nombre: json['nombre'] as String,
      ),
    );
  }

  /// The created level mapped to the domain.
  final NivelCreado nivel;
}
