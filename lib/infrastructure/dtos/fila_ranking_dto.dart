import '../../domain/ranking/fila_ranking.dart';

/// DTO for a single leaderboard entry in the HTTP response.
///
/// Shape: `{ puntaje, estrellas, movimientos, segundosRestantes, completadoEn,
/// email }` where `segundosRestantes` may be `null`.
class FilaRankingDto {
  /// Creates a ranking entry DTO.
  const FilaRankingDto({
    required this.puntaje,
    required this.estrellas,
    required this.movimientos,
    required this.segundosRestantes,
    required this.completadoEn,
    required this.email,
  });

  /// The player's score.
  final int puntaje;

  /// Star rating: 0–3.
  final int estrellas;

  /// Moves used.
  final int movimientos;

  /// Remaining clock seconds, or `null` for untimed levels.
  final int? segundosRestantes;

  /// ISO-8601 completion timestamp.
  final String completadoEn;

  /// The player's email.
  final String email;

  /// Serializes to the contract JSON shape.
  Map<String, dynamic> toJson() => {
        'puntaje': puntaje,
        'estrellas': estrellas,
        'movimientos': movimientos,
        'segundosRestantes': segundosRestantes,
        'completadoEn': completadoEn,
        'email': email,
      };

  /// Deserializes from the backend JSON response.
  factory FilaRankingDto.fromJson(Map<String, dynamic> json) {
    return FilaRankingDto(
      puntaje: json['puntaje'] as int,
      estrellas: json['estrellas'] as int,
      movimientos: json['movimientos'] as int,
      segundosRestantes: json['segundosRestantes'] as int?,
      completadoEn: json['completadoEn'] as String,
      email: json['email'] as String,
    );
  }

  /// Maps this DTO to the domain entity.
  FilaRanking toEntidad() => FilaRanking(
        puntaje: puntaje,
        estrellas: estrellas,
        movimientos: movimientos,
        segundosRestantes: segundosRestantes,
        completadoEn: DateTime.parse(completadoEn),
        email: email,
      );
}
