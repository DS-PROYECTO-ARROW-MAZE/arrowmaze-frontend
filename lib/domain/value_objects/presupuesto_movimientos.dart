/// The move budget for one level — how many taps (valid or invalid) the player
/// gets before running out (Ticket 30, FE-30).
///
/// Immutable: every mutation returns a new instance so it is safe to share
/// across use cases and the session state machine.
final class PresupuestoMovimientos {
  /// Creates a budget with [total] moves available; [restante] starts equal to
  /// [total].
  const PresupuestoMovimientos(this.total) : _restante = total;

  const PresupuestoMovimientos._(this.total, this._restante);

  /// The initial budget (arrows + error margin).
  final int total;

  final int _restante;

  /// How many moves are left before game over.
  int get restante => _restante;

  /// Whether the budget is exhausted (no moves left).
  bool get estaAgotado => _restante == 0;

  /// Records one move, returning a new budget with one fewer move remaining.
  ///
  /// Clamped at 0 so an empty-history undo can never underflow.
  PresupuestoMovimientos decrementar() =>
      PresupuestoMovimientos._(total, (_restante - 1).clamp(0, total));

  /// Reverses one move, returning a new budget with one more move remaining.
  ///
  /// Clamped at [total] so it never exceeds the initial budget.
  PresupuestoMovimientos restaurar() =>
      PresupuestoMovimientos._(total, (_restante + 1).clamp(0, total));
}
