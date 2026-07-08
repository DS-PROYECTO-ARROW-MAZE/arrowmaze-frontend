import 'value_objects/posicion.dart';

/// The kind of thing that happened during a move.
///
/// Events are a *record* of what occurred — never a command telling a layer
/// what to do. The application use case emits a `List<EventoJuego>` after each
/// tap; the `PublicadorEventosJuego` (ticket 07) dispatches them to audio,
/// score, and HUD observers without the use case knowing who is listening.
enum TipoEvento {
  /// A tap resolved into a valid move (an arrow exited the board).
  movimientoRealizado,

  /// An arrow successfully left the board and its cell became empty.
  flechaEliminada,

  /// A tap on an arrow whose path is blocked: the move is **penalized** (it
  /// counts against `movimientos`) but the board is left unchanged.
  movimientoInvalido,

  /// A valid move's ray flew over a collectible: it was consumed by
  /// pass-through and bonus seconds were added to the level timer (PRD §3 A4).
  coleccionableRecogido,

  /// The valid move that exited the last arrow emptied the board: the session
  /// has reached `EstadoVictoria` (PRD §3 B1).
  victoria,

  /// A timed level's countdown crossed the final-warning threshold (15 s left):
  /// a heads-up cue that time is nearly up (PRD §3 B2, ticket 29). Emitted
  /// **once per run** as the clock reaches the threshold — never each tick.
  avisoTiempo,

  /// Terminal defeat: a timed level's clock reached zero (PRD §3 B2).
  derrota,
}

/// An immutable value object describing one [TipoEvento] at a [posicion].
///
/// A move returns a `List<EventoJuego>`; downstream the `PublicadorEventosJuego`
/// dispatches these to audio/score/HUD reactors (ticket 07) without the use
/// case knowing those reactors exist.
class EventoJuego {
  /// Creates an event of [tipo] located at [posicion].
  const EventoJuego(this.tipo, this.posicion);

  /// What happened.
  final TipoEvento tipo;

  /// Where on the board it happened.
  final Posicion posicion;
}
