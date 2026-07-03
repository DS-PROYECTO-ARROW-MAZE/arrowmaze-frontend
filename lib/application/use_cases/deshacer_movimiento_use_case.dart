import '../../domain/sesion/sesion_juego.dart';
import 'command_history.dart';
import 'contador_movimientos.dart';
import 'resultado_movimiento.dart';

/// Undoes the last registered move — valid or invalid — keeping every counter
/// consistent (PRD §3 B4, §7.3, ticket 09). Undo is capped at 3 uses per level
/// (ticket 30, FE-30).
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
///   state or cap exhausted): a safe no-op, reported as an ignored result with
///   the counter left exactly where it was.
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

  /// Maximum undos per level.
  static const int maxUsos = 3;

  final SesionJuego _sesion;
  final CommandHistory _historial;
  final ContadorMovimientos _contador;
  int _usosRestantes = maxUsos;

  /// How many undos remain for this level — starts at [maxUsos] (3) and
  /// decrements with each successful undo. A fresh use case resets this.
  int get usosRestantes => _usosRestantes;

  /// Whether there is a move to undo, the session state allows it, and the
  /// undo cap is not exhausted — what the UI binds an undo button's enabled
  /// state to.
  bool get puedeDeshacer =>
      _usosRestantes > 0 &&
      _sesion.permiteDeshacer &&
      !_historial.estaVacio;

  /// Reverses the last move and returns the resulting [ResultadoMovimiento].
  ///
  /// A safe no-op (an ignored result) when there is nothing to undo, the
  /// session has finished, or the undo cap (3) has been reached; otherwise it
  /// pops the last command, reverses its board delta, decrements the shared
  /// counter, restores one budget unit, and counts down the undo cap.
  ResultadoMovimiento ejecutar() {
    if (!puedeDeshacer) {
      return ResultadoMovimiento.ignorado(_contador.valor);
    }

    _usosRestantes--;
    final comando = _historial.pop();
    comando.deshacer(_sesion.tablero);
    _contador.decrementar();
    _sesion.restaurarMovimiento();

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
