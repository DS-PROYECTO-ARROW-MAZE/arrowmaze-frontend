import '../../domain/tablero.dart';
import '../../domain/value_objects/posicion.dart';
import 'command_history.dart';
import 'delta_tablero.dart';
import 'evento_juego.dart';
import 'resultado_movimiento.dart';

/// Resolves a tap on a board cell into a move over a whole arrow path.
///
/// It depends only on the [Tablero] *port* (DIP) and a [CommandHistory], both
/// injected — it never constructs a concrete board. A tap may land on any segment
/// of an arrow `Trayectoria`; the arrow resolves as a whole. There are three
/// outcomes, all returned as one `ResultadoMovimiento` shape:
///
/// - **Ignored**: the tap is not on an arrow → no-op, nothing recorded.
/// - **Valid** (PRD A1/A3): the head's ray is clear to the edge → the whole path
///   leaves, `movimientos` advances, a real-delta `PlayerMoveCommand` is pushed,
///   and `MovimientoRealizado` + `FlechaEliminada` are emitted.
/// - **Invalid/penalized** (PRD A2): the head's ray is blocked by a wall or
///   another arrow → the board is left byte-identical and the arrow is **not**
///   consumed, yet `movimientos` **still** advances (anti-cheat) and a no-delta
///   `PlayerMoveCommand` is pushed, emitting `MovimientoInvalido`.
class MoverFlechaUseCase {
  /// Injects the board [Tablero] this use case operates on, and the
  /// [CommandHistory] that records every move (a fresh one by default).
  MoverFlechaUseCase(this._tablero, {CommandHistory? historial})
      : _historial = historial ?? CommandHistory();

  final Tablero _tablero;
  final CommandHistory _historial;

  int _movimientos = 0;

  /// The taps registered as moves so far (valid + penalized invalid).
  int get movimientos => _movimientos;

  /// The history of commands applied, exposed for inspection and future undo.
  CommandHistory get historial => _historial;

  /// Applies a tap at [posicion] and returns its [ResultadoMovimiento].
  ResultadoMovimiento ejecutar(Posicion posicion) {
    final trayectoria = _tablero.trayectoriaEn(posicion);

    // Only arrow paths can move; taps on empty/wall cells are ignored entirely
    // — they are not moves and never touch the counter or the history.
    if (trayectoria == null) {
      return ResultadoMovimiento.ignorado(_movimientos);
    }

    // Any tap on an arrow counts as a move: the anti-cheat invariant means even
    // a blocked, board-unchanged tap still advances the counter.
    _movimientos++;

    final rayo =
        _tablero.raycast(trayectoria.cabeza, trayectoria.direccionCabeza);
    if (!rayo.despejadoHastaBorde) {
      // Invalid (penalized): no board mutation, arrow not consumed, no delta.
      _historial.push(PlayerMoveCommand(posicion: posicion));
      return ResultadoMovimiento(
        movimientos: _movimientos,
        registrado: true,
        eventos: <EventoJuego>[
          EventoJuego(TipoEvento.movimientoInvalido, posicion),
        ],
      );
    }

    // Valid exit: the whole arrow leaves the board.
    _tablero.eliminarTrayectoria(trayectoria.id);
    final delta = DeltaTablero.eliminacion(trayectoria);
    _historial.push(PlayerMoveCommand(posicion: posicion, delta: delta));

    return ResultadoMovimiento(
      movimientos: _movimientos,
      registrado: true,
      delta: delta,
      eventos: <EventoJuego>[
        EventoJuego(TipoEvento.movimientoRealizado, posicion),
        EventoJuego(TipoEvento.flechaEliminada, trayectoria.cabeza),
      ],
    );
  }
}
