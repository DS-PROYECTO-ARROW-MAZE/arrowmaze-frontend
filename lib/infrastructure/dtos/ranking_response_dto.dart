import 'fila_ranking_dto.dart';

/// DTO for the `GET /leaderboard` response payload.
///
/// Shape: `{ "entradas": [FilaRankingDto...] }`.
class RankingResponseDto {
  /// Creates a ranking response DTO.
  const RankingResponseDto({required this.entradas});

  /// The ordered ranking entries.
  final List<FilaRankingDto> entradas;

  /// Serializes to the contract JSON shape.
  Map<String, dynamic> toJson() => {
        'entradas': entradas.map((e) => e.toJson()).toList(),
      };

  /// Deserializes from the backend JSON response.
  factory RankingResponseDto.fromJson(Map<String, dynamic> json) {
    return RankingResponseDto(
      entradas: (json['entradas'] as List<dynamic>)
          .map((e) => FilaRankingDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
