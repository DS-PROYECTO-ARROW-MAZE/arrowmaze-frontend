/// A single completed run, queued locally for batch upload (DM-B3, E2).
///
/// Pure domain value object — no Flutter, no infrastructure. Its fields mirror
/// the backend's `progresos[]` sync item exactly (`nivelId`, `movimientos`,
/// `segundosRestantes?`, `completadoEn`): the server recomputes the score from
/// these, so **no client-side score (stars/points) travels here** — sending one
/// would be rejected by the backend's `forbidNonWhitelisted` validation
/// (Ticket 19 / ADR-0005). The infrastructure layer maps this to the sync DTO;
/// the application layer enqueues and dequeues through [IColaSincronizacion].
class RunCompletado {
  /// Creates a completed run.
  const RunCompletado({
    required this.nivelId,
    required this.movimientos,
    this.segundosRestantes,
    required this.completadoEn,
  });

  /// The level that was cleared — the backend level **UUID** (so the server can
  /// resolve and re-score it; an int ordinal would fail `@IsUUID()`).
  final String nivelId;

  /// Total registered taps (valid + penalized).
  final int movimientos;

  /// Remaining clock seconds when cleared, or `null` for untimed levels.
  final int? segundosRestantes;

  /// Timestamp of when the run was completed.
  final DateTime completadoEn;
}
