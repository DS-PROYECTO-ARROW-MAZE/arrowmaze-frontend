import '../tablero.dart';
import '../value_objects/presupuesto_movimientos.dart';
import '../value_objects/posicion.dart';
import 'contexto_sesion.dart';
import 'estado_sesion.dart';
import 'resultado_toque.dart';

/// A single play session — the **context** of the GoF State machine (DM-F5).
///
/// It owns the [Tablero] being played, an optional countdown clock
/// ([limiteTiempo]), an optional move budget ([presupuestoMovimientos]) and the
/// current [EstadoSesion], to which it delegates every action. Behaviour that
/// depends on *which* state we are in lives in the state classes, never in
/// branching here — `SesionJuego` only forwards and swaps the state via
/// [cambiarEstado].
///
/// Defeat is arbitrated in two places:
/// - **Timer timeout** ([avanzarTiempo]): a level with a [limiteTiempo] is lost
///   when the clock hits zero; untimed levels skip this path.
/// - **Move exhaustion** ([registrarMovimiento]): the budget decrements on every
///   registered tap; reaching zero before the board is clear triggers
///   [EstadoDerrota]. Victory wins ties (clearing on the last allowed move is a
///   win). When [presupuestoMovimientos] is `null`, the budget is unlimited and
///   no move-exhaustion defeat can occur.
class SesionJuego implements ContextoSesion {
  /// Opens a session on [tablero]. Pass a [limiteTiempo] to make the level timed;
  /// pass a [presupuestoMovimientos] to cap the number of registered taps. Omit
  /// either (or both) to make the respective defeat path impossible. Starts in
  /// [EstadoJugando] unless an [estadoInicial] is supplied (for testing).
  SesionJuego({
    required Tablero tablero,
    Duration? limiteTiempo,
    PresupuestoMovimientos? presupuestoMovimientos,
    EstadoSesion? estadoInicial,
  })  : _tablero = tablero,
        _limiteTiempo = limiteTiempo,
        _tiempoRestante = limiteTiempo,
        _presupuestoMovimientos = presupuestoMovimientos,
        _estado = estadoInicial ?? EstadoJugando();

  final Tablero _tablero;
  final Duration? _limiteTiempo;
  Duration? _tiempoRestante;
  PresupuestoMovimientos? _presupuestoMovimientos;
  EstadoSesion _estado;

  /// The board this session is played on.
  Tablero get tablero => _tablero;

  /// The active session state (the GoF State).
  EstadoSesion get estado => _estado;

  /// Whether the session reached a terminal outcome (victory or defeat).
  bool get estaTerminada => _estado.estaTerminada;

  /// Whether undoing the last move is legal right now — true only in a
  /// non-terminal state (ticket 09, DM-F5).
  bool get permiteDeshacer => _estado.permiteDeshacer;

  /// Whether this level is timed (has a [limiteTiempo]).
  bool get esCronometrado => _limiteTiempo != null;

  /// Time left on the clock, or `null` on an untimed level. Frozen while not in
  /// [EstadoJugando].
  Duration? get tiempoRestante => _tiempoRestante;

  /// Routes a tap at [posicion] through the active state.
  ResultadoToque tocarCelda(Posicion posicion) =>
      _estado.tocarCelda(this, posicion);

  /// Requests a pause; honoured only while playing.
  void pausar() => _estado.pausar(this);

  /// Requests a resume; honoured only while paused.
  void reanudar() => _estado.reanudar(this);

  /// Advances the level clock by [transcurrido].
  ///
  /// Time only flows while the active state's [EstadoSesion.relojActivo] is
  /// `true`, so a paused or finished session ignores it (the clock is frozen).
  /// On a timed level, reaching zero transitions to [EstadoDerrota]; on an
  /// untimed level this is always a no-op. Defeat can still happen on an untimed
  /// level via move exhaustion ([registrarMovimiento]).
  void avanzarTiempo(Duration transcurrido) {
    if (!esCronometrado || !_estado.relojActivo) return;

    final restante = _tiempoRestante! - transcurrido;
    if (restante <= Duration.zero) {
      _tiempoRestante = Duration.zero;
      cambiarEstado(EstadoDerrota());
    } else {
      _tiempoRestante = restante;
    }
  }

  /// Adds [bonus] seconds back to the level clock (collectible pass-through,
  /// PRD §3 A4).
  ///
  /// A no-op on an untimed level (no clock to extend) or once the session is
  /// finished. Unlike [avanzarTiempo] this *grows* the remaining time and can
  /// never trigger a state transition.
  void otorgarBonus(Duration bonus) {
    if (!esCronometrado || _estado.estaTerminada) return;
    _tiempoRestante = _tiempoRestante! + bonus;
  }

  /// The move budget for this level, or `null` when unlimited.
  @override
  PresupuestoMovimientos? get presupuestoMovimientos => _presupuestoMovimientos;

  /// Decrements the move budget by one.
  ///
  /// Always decrements on a registered tap, even when the board was just
  /// cleared (victory). If the budget reaches zero and the board is NOT empty
  /// (i.e. victory did not happen on this same tap), transitions to
  /// [EstadoDerrota]. A no-op when the budget is unlimited.
  ///
  /// Victory wins ties: if the board was cleared on the same tap that exhausts
  /// the budget, the session is already in [EstadoVictoria] and the board is
  /// empty, so this method declines to override it.
  @override
  void registrarMovimiento() {
    if (_presupuestoMovimientos == null) return;
    _presupuestoMovimientos = _presupuestoMovimientos!.decrementar();
    if (_presupuestoMovimientos!.estaAgotado && !_tablero.estaVacio) {
      cambiarEstado(EstadoDerrota());
    }
  }

  /// Restores one unit of the move budget (undo). A no-op when the budget is
  /// unlimited.
  @override
  void restaurarMovimiento() {
    if (_presupuestoMovimientos == null) return;
    _presupuestoMovimientos = _presupuestoMovimientos!.restaurar();
  }

  /// Swaps the active state — the single State-transition seam used by the state
  /// classes and the clock.
  void cambiarEstado(EstadoSesion estado) => _estado = estado;
}
