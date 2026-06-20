import '../../domain/evento_juego.dart';
import '../../domain/publicador_eventos_juego.dart';
import '../../domain/sesion/sesion_juego.dart';
import '../../domain/tablero.dart';
import '../../domain/value_objects/posicion.dart';
import 'command_history.dart';
import 'contador_movimientos.dart';
import 'delta_tablero.dart';
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
///
/// After computing the event list the use case feeds every event to the
/// [publicador] (ticket 07 — GoF Observer). It has **no** direct reference to
/// audio or UI: it only knows about [PublicadorEventosJuego], a domain contract.
class MoverFlechaUseCase {
  /// Injects the [SesionJuego] this use case routes taps through, the
  /// [CommandHistory] that records every move, and the [PublicadorEventosJuego]
  /// that fans out emitted events to audio/score/HUD observers.
  ///
  /// For convenience an untimed session is built from [tablero] when no [sesion]
  /// is supplied, so existing call sites that only have a board keep working.
  /// A fresh [PublicadorEventosJuego] is created when none is supplied, so
  /// observers can always subscribe via [publicador].
  MoverFlechaUseCase(
    Tablero tablero, {
    CommandHistory? historial,
    SesionJuego? sesion,
    PublicadorEventosJuego? publicador,
    ContadorMovimientos? contador,
  })  : _sesion = sesion ?? SesionJuego(tablero: tablero),
        _historial = historial ?? CommandHistory(),
        _publicador = publicador ?? PublicadorEventosJuego(),
        _contador = contador ?? ContadorMovimientos();

  /// Bonus time granted for each collectible a valid move's ray crosses.
  static const Duration bonusPorColeccionable = Duration(seconds: 5);

  final SesionJuego _sesion;
  final CommandHistory _historial;
  final PublicadorEventosJuego _publicador;
  final ContadorMovimientos _contador;

  /// The taps registered as moves so far (valid + penalized invalid).
  int get movimientos => _contador.valor;

  /// The shared move counter, exposed so the undo use case
  /// ([DeshacerMovimientoUseCase]) rolls back the very same count this use case
  /// advances — the single source of truth that keeps the two from drifting.
  ContadorMovimientos get contador => _contador;

  /// The history of commands applied, exposed for inspection and future undo.
  CommandHistory get historial => _historial;

  /// The session whose state machine gates every tap, exposed so the ViewModel
  /// can map its domain state onto UI snapshots and drive pause/resume.
  SesionJuego get sesion => _sesion;

  /// The Observer Subject that dispatches emitted [EventoJuego]s to all
  /// registered observers (audio, HUD, score). Observers subscribe here at the
  /// composition root; the use case never inspects who they are.
  PublicadorEventosJuego get publicador => _publicador;

  /// Applies a tap at [posicion] and returns its [ResultadoMovimiento].
  ///
  /// Every event in the result is also fed to [publicador] so audio, HUD, and
  /// score observers react without the use case knowing about them.
  ResultadoMovimiento ejecutar(Posicion posicion) {
    final toque = _sesion.tocarCelda(posicion);

    // A tap the session did not register (no arrow, or rejected while
    // paused/finished) never touches the counter or the history.
    if (!toque.registrado) {
      return ResultadoMovimiento.ignorado(_contador.valor);
    }

    // Any registered tap counts as a move — even a blocked, board-unchanged one
    // (the anti-cheat invariant).
    _contador.incrementar();

    if (!toque.valido) {
      // Invalid (penalized): no board mutation, arrow not consumed, no delta.
      _historial.push(PlayerMoveCommand(posicion: posicion));
      final eventos = <EventoJuego>[
        EventoJuego(TipoEvento.movimientoInvalido, posicion),
      ];
      _publicarTodos(eventos);
      return ResultadoMovimiento(
        movimientos: _contador.valor,
        registrado: true,
        eventos: eventos,
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
    // Pass-through bonus (A4): the session already consumed each collectible the
    // ray crossed; record one event per collectible and extend the timer.
    for (final coleccionable in toque.coleccionables) {
      eventos.add(EventoJuego(TipoEvento.coleccionableRecogido, coleccionable));
    }
    if (toque.coleccionables.isNotEmpty) {
      _sesion.otorgarBonus(bonusPorColeccionable * toque.coleccionables.length);
    }
    // Emptying the board on this exit is the victory trigger (scoring, ticket 06).
    if (_sesion.estaTerminada) {
      eventos.add(EventoJuego(TipoEvento.victoria, posicion));
    }

    _publicarTodos(eventos);
    return ResultadoMovimiento(
      movimientos: _contador.valor,
      registrado: true,
      delta: delta,
      eventos: eventos,
    );
  }

  /// Publishes each event in [eventos] to the [publicador] in order.
  void _publicarTodos(List<EventoJuego> eventos) {
    for (final evento in eventos) {
      _publicador.publicar(evento);
    }
  }
}
