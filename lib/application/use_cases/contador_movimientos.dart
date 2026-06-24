/// The single, mutable source of truth for a run's move counter.
///
/// Both the forward move ([MoverFlechaUseCase]) and the undo
/// ([DeshacerMovimientoUseCase]) mutate the **same** instance, so the count the
/// forward move advances and the undo rolls back can never drift apart (PRD §3
/// B4, §7.3). It deliberately exposes nothing but the value and the two
/// in-place transitions — a narrow, deep surface shared at the composition root.
class ContadorMovimientos {
  int _valor = 0;

  /// The number of moves registered so far (valid + penalized invalid).
  int get valor => _valor;

  /// Counts one more move (a valid exit or a penalized invalid tap).
  void incrementar() => _valor++;

  /// Rolls one move back on undo, clamped at zero so an empty-history undo can
  /// never underflow the counter.
  void decrementar() {
    if (_valor > 0) _valor--;
  }
}
