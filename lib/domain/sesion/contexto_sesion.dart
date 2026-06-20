import '../tablero.dart';
import 'estado_sesion.dart';

/// The minimal contract a session context must fulfil for its GoF State classes.
///
/// [SesionJuego] implements this interface; the concrete states
/// ([EstadoJugando], [EstadoPausado], etc.) receive a `ContextoSesion` so they
/// never depend on the concrete session — only on this lean port. This breaks the
/// otherwise circular dependency between the context and its states.
abstract interface class ContextoSesion {
  /// The board being played.
  Tablero get tablero;

  /// Whether this level has a countdown clock.
  bool get esCronometrado;

  /// Remaining time on the clock, or `null` on an untimed level.
  Duration? get tiempoRestante;

  /// Swaps the active state — the single State-transition seam.
  void cambiarEstado(EstadoSesion estado);

  /// Adds bonus seconds (collectible pass-through).
  void otorgarBonus(Duration bonus);
}
