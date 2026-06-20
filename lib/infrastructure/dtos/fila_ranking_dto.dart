/// DTO for a single ranking row in the HTTP response (Pact consumer, AC3).
class FilaRankingDto {
  /// Creates a ranking row DTO.
  const FilaRankingDto({
    required this.posicion,
    required this.nombreJugador,
    required this.puntaje,
    required this.estrellas,
  });

  /// The row's position in the leaderboard (1-based).
  final int posicion;

  /// The player's display name.
  final String nombreJugador;

  /// The player's score.
  final int puntaje;

  /// Star rating: 0–3.
  final int estrellas;

  /// Serializes to Pact contract JSON shape.
  Map<String, dynamic> toJson() => {
        'posicion': posicion,
        'nombreJugador': nombreJugador,
        'puntaje': puntaje,
        'estrellas': estrellas,
      };

  /// Deserializes from the backend JSON response.
  factory FilaRankingDto.fromJson(Map<String, dynamic> json) {
    return FilaRankingDto(
      posicion: json['posicion'] as int,
      nombreJugador: json['nombreJugador'] as String,
      puntaje: json['puntaje'] as int,
      estrellas: json['estrellas'] as int,
    );
  }
}
