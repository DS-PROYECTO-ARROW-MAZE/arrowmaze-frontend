/// A single entry in the leaderboard — a pure domain entity (DM-B5, E3).
///
/// Mirrors one row of the `GET /leaderboard` response. Immutable, no Flutter
/// dependency — lives in the domain layer.
class FilaRanking {
  /// Creates a ranking entry.
  const FilaRanking({
    required this.email,
    required this.puntaje,
    required this.estrellas,
    required this.movimientos,
    required this.segundosRestantes,
    required this.completadoEn,
  });

  /// The player's email (identity shown on the board).
  final String email;

  /// The player's score on this level.
  final int puntaje;

  /// Star rating: 0–3.
  final int estrellas;

  /// Moves used in the recorded run.
  final int movimientos;

  /// Remaining clock seconds when cleared, or `null` for untimed levels.
  final int? segundosRestantes;

  /// When the run was completed (server timestamp).
  final DateTime completadoEn;
}
