/// A single row in the leaderboard — a pure domain entity (DM-B5, E3).
///
/// Represents one player's position in the top-N ranking for a level.
/// Immutable, no Flutter dependency — lives in the domain layer.
class FilaRanking {
  /// Creates a ranking row.
  const FilaRanking({
    required this.posicion,
    required this.nombreJugador,
    required this.puntaje,
    required this.estrellas,
  });

  /// The row's position in the leaderboard (1-based).
  final int posicion;

  /// The player's display name.
  final String nombreJugador;

  /// The player's score on this level.
  final int puntaje;

  /// Star rating: 0–3.
  final int estrellas;
}
