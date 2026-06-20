import '../../domain/sesion/sesion_juego.dart';
import '../../domain/tablero.dart';
import '../../domain/value_objects/posicion.dart';
import 'command_history.dart';
import 'delta_tablero.dart';
import 'evento_juego.dart';
import 'resultado_movimiento.dart';

/// Resolves a tap on a board cell into a move, **routing it through the active
/// `EstadoSesion`** of a [SesionJuego] (DM-F5) and layering the application-level
/// bookkeeping the domain session does not own.
///
/// The session (GoF State) decides what a tap *means* in the current state — a
/// real exit, a penalized invalid tap, or nothing at all while paused/finished —
/// and owns the victory transition when the board empties. This use case wraps
/// that domain outcome with the move counter, the [CommandHistory] command and
/// the `EventoJuego` record. There are still three outcomes, one
/// `ResultadoMovimiento` shape:
///
/// - **Ignored**: no arrow under the tap, or rejected by a paused/finished
///   session → no-op, nothing recorded.
/// - **Valid** (PRD A1/A3): the whole path leaves, `movimientos` advances, a
///   real-delta `PlayerMoveCommand` is pushed, and `MovimientoRealizado` +
///   `FlechaEliminada` are emitted — plus `Victoria` when that exit emptied the
///   board.
/// - **Invalid/penalized** (PRD A2): the head's ray is blocked → the board is
///   left byte-identical and the arrow is **not** consumed, yet `movimientos`
///   **still** advances (anti-cheat) and a no-delta `PlayerMoveCommand` is
///   pushed, emitting `MovimientoInvalido`.
class MoverFlechaUseCase {
  /// Injects the [SesionJuego] this use case routes taps through, and the
  /// [CommandHistory] that records every move (a fresh one by default).
  ///
  /// For convenience an untimed session is built from [tablero] when no [sesion]
  /// is supplied, so existing call sites that only have a board keep working.
  MoverFlechaUseCase(
    Tablero tablero, {
    CommandHistory? historial,
    SesionJuego? sesion,
  })  : _sesion = sesion ?? SesionJuego(tablero: tablero),
        _historial = historial ?? CommandHistory();

  final SesionJuego _sesion;
  final CommandHistory _historial;

  int _movimientos = 0;

  /// The taps registered as moves so far (valid + penalized invalid).
  int get movimientos => _movimientos;

  /// The history of commands applied, exposed for inspection and future undo.
  CommandHistory get historial => _historial;

  /// The session whose state machine gates every tap, exposed so the ViewModel
  /// can map its domain state onto UI snapshots and drive pause/resume.
  SesionJuego get sesion => _sesion;

  /// Applies a tap at [posicion] and returns its [ResultadoMovimiento].
  ResultadoMovimiento ejecutar(Posicion posicion) {
    final toque = _sesion.tocarCelda(posicion);

    // A tap the session did not register (no arrow, or rejected while
    // paused/finished) never touches the counter or the history.
    if (!toque.registrado) {
      return ResultadoMovimiento.ignorado(_movimientos);
    }

    // Any registered tap counts as a move — even a blocked, board-unchanged one
    // (the anti-cheat invariant).
    _movimientos++;

    if (!toque.valido) {
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

    // Valid exit: the session already removed the whole path; record the delta.
    final trayectoria = toque.trayectoria!;
    final delta = DeltaTablero.eliminacion(trayectoria);
    _historial.push(PlayerMoveCommand(posicion: posicion, delta: delta));

    final eventos = <EventoJuego>[
      EventoJuego(TipoEvento.movimientoRealizado, posicion),
      EventoJuego(TipoEvento.flechaEliminada, trayectoria.cabeza),
    ];
    // Emptying the board on this exit is the victory trigger (scoring, ticket 06).
    if (_sesion.estaTerminada) {
      eventos.add(EventoJuego(TipoEvento.victoria, posicion));
    }

    return ResultadoMovimiento(
      movimientos: _movimientos,
      registrado: true,
      delta: delta,
      eventos: eventos,
    );
  }
}
