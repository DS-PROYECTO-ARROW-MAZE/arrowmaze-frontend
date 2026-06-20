import '../../domain/sesion/sesion_juego.dart';
import 'command_history.dart';
import 'contador_movimientos.dart';
import 'resultado_movimiento.dart';

/// Undoes the last registered move — valid or invalid — keeping every counter
/// consistent (PRD §3 B4, §7.3, ticket 09).
///
/// It is the inverse of [MoverFlechaUseCase] and deliberately shares its
/// collaborators: the same [CommandHistory] it pops from, the same
/// [ContadorMovimientos] it rolls back, and the [SesionJuego] whose GoF State
/// decides legality (DM-F5 — undo is allowed only in a non-terminal state).
/// Reusing those instances is what guarantees the forward and reverse counts
/// never drift.
///
/// Every outcome is reported as a single [ResultadoMovimiento], the same shape
/// the forward move returns, so the ViewModel reacts to undo exactly as it does
/// to a move (rebuilding the board only when the reversal changed it):
///
/// - **Undo of a valid move**: the command restores its board delta (the arrow
///   re-appears at its `Posicion`); the result carries that delta, so
///   `valido` is `true`.
/// - **Undo of an invalid move**: the no-delta +1 is rolled back; the board is
///   untouched, so the result has no delta (`valido` is `false`).
/// - **Nothing to undo** (empty history) or **undo not allowed** (terminal
///   state): a safe no-op, reported as an ignored result with the counter left
///   exactly where it was.
class DeshacerMovimientoUseCase {
  /// Injects the [sesion] that gates legality, the [historial] to pop from, and
  /// the shared [contador] to roll back — all the same instances the forward
  /// [MoverFlechaUseCase] uses.
  DeshacerMovimientoUseCase({
    required SesionJuego sesion,
    required CommandHistory historial,
    required ContadorMovimientos contador,
  })  : _sesion = sesion,
        _historial = historial,
        _contador = contador;

  final SesionJuego _sesion;
  final CommandHistory _historial;
  final ContadorMovimientos _contador;

  /// Whether there is a move to undo and the session state allows it — what the
  /// UI binds an undo button's enabled state to.
  bool get puedeDeshacer => _sesion.permiteDeshacer && !_historial.estaVacio;

  /// Reverses the last move and returns the resulting [ResultadoMovimiento].
  ///
  /// A safe no-op (an ignored result) when there is nothing to undo or the
  /// session has finished; otherwise it pops the last command, reverses its
  /// board delta and decrements the shared counter.
  ResultadoMovimiento ejecutar() {
    if (!puedeDeshacer) {
      return ResultadoMovimiento.ignorado(_contador.valor);
    }

    final comando = _historial.pop();
    comando.deshacer(_sesion.tablero);
    _contador.decrementar();

    return ResultadoMovimiento(
      movimientos: _contador.valor,
      registrado: true,
      // Carry the reversed delta so the result's `valido` mirrors whether the
      // board changed: a restored arrow (valid-move undo) vs. an unchanged board
      // (invalid-move undo).
      delta: comando.delta,
      eventos: const [],
    );
  }
}
