/// A single completed run, queued locally for batch upload (DM-B3, E2).
///
/// Pure domain value object — no Flutter, no infrastructure. The
/// infrastructure layer maps this to the sync DTO; the application layer
/// enqueues and dequeues through [IColaSincronizacion].
class RunCompletado {
  /// Creates a completed run.
  const RunCompletado({
    required this.nivelId,
    required this.movimientos,
    required this.segundosRestantes,
    required this.puntaje,
    required this.estrellas,
    required this.completadoEn,
  });

  /// The level that was cleared.
  final int nivelId;

  /// Total registered taps (valid + penalized).
  final int movimientos;

  /// Remaining clock seconds when the level was cleared (0 for untimed).
  final int segundosRestantes;

  /// Final computed score.
  final int puntaje;

  /// Star rating: 0, 1, 2, or 3.
  final int estrellas;

  /// ISO-8601 UTC timestamp of when the run was completed.
  final DateTime completadoEn;
}
