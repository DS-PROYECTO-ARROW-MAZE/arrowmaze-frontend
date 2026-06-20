import 'fila_ranking_dto.dart';

/// DTO for the ranking response payload (Pact consumer, AC3).
///
/// Shape: `{ "idNivel": int, "limite": int, "filas": [FilaRankingDto...] }`
class RankingResponseDto {
  /// Creates a ranking response DTO.
  const RankingResponseDto({
    required this.idNivel,
    required this.limite,
    required this.filas,
  });

  /// The level this ranking belongs to.
  final int idNivel;

  /// The limit used in the request.
  final int limite;

  /// The ordered ranking rows.
  final List<FilaRankingDto> filas;

  /// Serializes to Pact contract JSON shape.
  Map<String, dynamic> toJson() => {
        'idNivel': idNivel,
        'limite': limite,
        'filas': filas.map((f) => f.toJson()).toList(),
      };

  /// Deserializes from the backend JSON response.
  factory RankingResponseDto.fromJson(Map<String, dynamic> json) {
    return RankingResponseDto(
      idNivel: json['idNivel'] as int,
      limite: json['limite'] as int,
      filas: (json['filas'] as List<dynamic>)
          .map((f) => FilaRankingDto.fromJson(f as Map<String, dynamic>))
          .toList(),
    );
  }
}
