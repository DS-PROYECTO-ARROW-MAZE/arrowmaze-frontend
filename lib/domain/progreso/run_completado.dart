/// A single completed run, queued locally for batch upload (DM-B3, E2).
///
/// Pure domain value object — no Flutter, no infrastructure. Its fields mirror
/// the backend's `progresos[]` sync item: the server computes the score from
/// these, so no client-side score travels here. The infrastructure layer maps
/// this to the sync DTO; the application layer enqueues and dequeues through
/// [IColaSincronizacion].
class RunCompletado {
  /// Creates a completed run.
  const RunCompletado({
    required this.nivelId,
    required this.estrellas,
    required this.movimientos,
    this.segundosRestantes,
    required this.completadoEn,
  });

  /// The level that was cleared (server UUID).
  final String nivelId;

  /// Star rating: 0, 1, 2, or 3.
  final int estrellas;

  /// Total registered taps (valid + penalized).
  final int movimientos;

  /// Remaining clock seconds when cleared, or `null` for untimed levels.
  final int? segundosRestantes;

  /// Timestamp of when the run was completed.
  final DateTime completadoEn;
}
