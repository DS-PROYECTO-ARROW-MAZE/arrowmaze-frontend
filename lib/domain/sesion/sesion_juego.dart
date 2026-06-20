import '../tablero.dart';
import '../value_objects/posicion.dart';
import 'estado_sesion.dart';
import 'resultado_toque.dart';

/// A single play session — the **context** of the GoF State machine (DM-F5).
///
/// It owns the [Tablero] being played, an optional countdown clock
/// ([limiteTiempo]) and the current [EstadoSesion], to which it delegates every
/// action. Behaviour that depends on *which* state we are in (can this tap move
/// an arrow? does the clock advance? are we finished?) lives in the state
/// classes, never in branching here — `SesionJuego` only forwards and swaps the
/// state via [cambiarEstado].
///
/// Defeat is the one rule the context arbitrates directly: a level with a
/// [limiteTiempo] is lost the instant its remaining time hits zero, and an
/// untimed level ([esCronometrado] is `false`) can therefore *never* reach
/// [EstadoDerrota] (PRD §3 B2). Victory, pause and tap-legality are owned by the
/// states themselves.
class SesionJuego {
  /// Opens a session on [tablero]. Pass a [limiteTiempo] to make the level timed;
  /// omit it for an untimed level that can never be lost. Starts in
  /// [EstadoJugando] unless an [estadoInicial] is supplied (for testing).
  SesionJuego({
    required Tablero tablero,
    Duration? limiteTiempo,
    EstadoSesion? estadoInicial,
  })  : _tablero = tablero,
        _limiteTiempo = limiteTiempo,
        _tiempoRestante = limiteTiempo,
        _estado = estadoInicial ?? EstadoJugando();

  final Tablero _tablero;
  final Duration? _limiteTiempo;
  Duration? _tiempoRestante;
  EstadoSesion _estado;

  /// The board this session is played on.
  Tablero get tablero => _tablero;

  /// The active session state (the GoF State).
  EstadoSesion get estado => _estado;

  /// Whether the session reached a terminal outcome (victory or defeat).
  bool get estaTerminada => _estado.estaTerminada;

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
  /// untimed level this is always a no-op, which is why such a level can never be
  /// lost.
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

  /// Swaps the active state — the single State-transition seam used by the state
  /// classes and the clock.
  void cambiarEstado(EstadoSesion estado) => _estado = estado;
}
