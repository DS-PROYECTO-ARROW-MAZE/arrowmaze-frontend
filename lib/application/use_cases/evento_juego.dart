import '../../domain/value_objects/posicion.dart';

/// The kind of thing that happened during a move.
///
/// Only the two events this slice produces exist here; later tickets extend the
/// enum (`ColeccionableRecogido`, `Victoria`, …). Events are a *record* of what
/// occurred — never a command telling a layer what to do (see `EventoJuego` in
/// `CONTEXT.md`).
enum TipoEvento {
  /// A tap resolved into a valid move (an arrow exited the board).
  movimientoRealizado,

  /// An arrow successfully left the board and its cell became empty.
  flechaEliminada,

  /// A tap on an arrow whose path is blocked: the move is **penalized** (it
  /// counts against `movimientos`) but the board is left unchanged.
  movimientoInvalido,

  /// The valid move that exited the last arrow emptied the board: the session
  /// has reached `EstadoVictoria` (PRD §3 B1).
  victoria,
}

/// An immutable value object describing one [TipoEvento] at a [posicion].
///
/// A move returns a `List<EventoJuego>`; downstream the Observer subject will
/// dispatch these to audio/score/HUD reactors (ticket 07) without the use case
/// knowing those reactors.
class EventoJuego {
  /// Creates an event of [tipo] located at [posicion].
  const EventoJuego(this.tipo, this.posicion);

  /// What happened.
  final TipoEvento tipo;

  /// Where on the board it happened.
  final Posicion posicion;
}
