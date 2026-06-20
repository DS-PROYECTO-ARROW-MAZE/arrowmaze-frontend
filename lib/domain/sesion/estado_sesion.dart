import '../value_objects/posicion.dart';
import 'contexto_sesion.dart';
import 'resultado_toque.dart';

/// The GoF **State** of a play session — the single place where the legality of
/// a tap, a pause and the running of the clock is decided **by type** rather than
/// by scattered `if`s (PRD §3 B1–B3, DM-F5).
///
/// A [SesionJuego] holds one `EstadoSesion` and delegates every action to it,
/// swapping the instance through `SesionJuego.cambiarEstado` when a transition is
/// due. The four concrete states are exactly [EstadoJugando], [EstadoPausado],
/// [EstadoVictoria] and [EstadoDerrota]. This is *not* the MVVM `*ViewState`
/// snapshot (see `EstadoSesion` in `CONTEXT.md`).
sealed class EstadoSesion {
  /// Routes a tap at [posicion] through this state, returning its domain
  /// [ResultadoToque]. Only [EstadoJugando] resolves a real move; the other
  /// states reject the tap as [TipoToque.ignorado].
  ResultadoToque tocarCelda(ContextoSesion sesion, Posicion posicion);

  /// Suspends play. Only meaningful from [EstadoJugando]; a no-op elsewhere.
  void pausar(ContextoSesion sesion);

  /// Resumes play. Only meaningful from [EstadoPausado]; a no-op elsewhere.
  void reanudar(ContextoSesion sesion);

  /// Whether the session has reached a terminal outcome (victory or defeat).
  bool get estaTerminada;

  /// Whether the level clock advances in this state. Only [EstadoJugando] lets
  /// time pass; pausing or finishing freezes it.
  bool get relojActivo;

  /// Whether undoing the last move is legal in this state (ticket 09, B4): only
  /// the non-terminal states ([EstadoJugando], [EstadoPausado]) allow it; once
  /// the level is won or lost the history is frozen.
  bool get permiteDeshacer => !estaTerminada;
}

/// Active play: taps resolve real moves and the clock runs.
final class EstadoJugando extends EstadoSesion {
  @override
  ResultadoToque tocarCelda(ContextoSesion sesion, Posicion posicion) {
    final tablero = sesion.tablero;
    final trayectoria = tablero.trayectoriaEn(posicion);

    // A tap that lands on no arrow is ignored entirely — not a move.
    if (trayectoria == null) {
      return const ResultadoToque.ignorado();
    }

    // A blocked head ray is an invalid (penalized) tap: the board is unchanged.
    final rayo =
        tablero.raycast(trayectoria.cabeza, trayectoria.direccionCabeza);
    if (!rayo.despejadoHastaBorde) {
      return const ResultadoToque.invalido();
    }

    // A clear ray exits the whole path and collects any bonus cells it crossed
    // (pass-through). Collectibles never block, never count toward emptiness, so
    // emptying the board — and thus victory (B1) — stays independent of them.
    tablero.eliminarTrayectoria(trayectoria.id);
    for (final coleccionable in rayo.coleccionables) {
      tablero.recogerColeccionable(coleccionable);
    }
    if (tablero.estaVacio) {
      sesion.cambiarEstado(EstadoVictoria());
    }
    return ResultadoToque.valido(trayectoria, coleccionables: rayo.coleccionables);
  }

  @override
  void pausar(ContextoSesion sesion) => sesion.cambiarEstado(EstadoPausado());

  @override
  void reanudar(ContextoSesion sesion) {/* already playing */}

  @override
  bool get estaTerminada => false;

  @override
  bool get relojActivo => true;
}

/// Paused play: taps are rejected and the clock is frozen (B3).
final class EstadoPausado extends EstadoSesion {
  @override
  ResultadoToque tocarCelda(ContextoSesion sesion, Posicion posicion) =>
      const ResultadoToque.ignorado();

  @override
  void pausar(ContextoSesion sesion) {/* already paused */}

  @override
  void reanudar(ContextoSesion sesion) => sesion.cambiarEstado(EstadoJugando());

  @override
  bool get estaTerminada => false;

  @override
  bool get relojActivo => false;
}

/// Terminal victory: the board was emptied (B1). Nothing more can happen.
final class EstadoVictoria extends EstadoSesion {
  @override
  ResultadoToque tocarCelda(ContextoSesion sesion, Posicion posicion) =>
      const ResultadoToque.ignorado();

  @override
  void pausar(ContextoSesion sesion) {/* terminal */}

  @override
  void reanudar(ContextoSesion sesion) {/* terminal */}

  @override
  bool get estaTerminada => true;

  @override
  bool get relojActivo => false;
}

/// Terminal defeat: a timed level's clock reached zero (B2). Only timed levels
/// can ever reach this state.
final class EstadoDerrota extends EstadoSesion {
  @override
  ResultadoToque tocarCelda(ContextoSesion sesion, Posicion posicion) =>
      const ResultadoToque.ignorado();

  @override
  void pausar(ContextoSesion sesion) {/* terminal */}

  @override
  void reanudar(ContextoSesion sesion) {/* terminal */}

  @override
  bool get estaTerminada => true;

  @override
  bool get relojActivo => false;
}
