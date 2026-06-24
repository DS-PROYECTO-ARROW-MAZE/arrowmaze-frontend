import '../entities/trayectoria.dart';
import '../value_objects/posicion.dart';

/// How the active [EstadoSesion] resolved a single tap, in **domain** terms.
///
/// This is the pure-domain outcome of routing a tap through the session's GoF
/// State — it knows nothing of move counters, command history or UI. The
/// application `MoverFlechaUseCase` maps it onto the richer `ResultadoMovimiento`
/// (counter, events, board delta). There are exactly three outcomes:
///
/// - [ignorado]: the tap had no effect — either no arrow lay under it, or the
///   session is paused/finished and rejected it. Nothing is counted.
/// - [invalido]: an arrow was tapped but its head's ray is blocked; the board is
///   left unchanged (the move is *penalized* by the use case, not here).
/// - [valido]: the whole [trayectoria] left the board.
enum TipoToque {
  /// The tap produced no move (no arrow, or rejected while paused/finished).
  ignorado,

  /// A tapped arrow whose ray is blocked — board unchanged.
  invalido,

  /// A tapped arrow exited the board as a whole.
  valido,
}

/// The immutable result of `SesionJuego.tocarCelda`.
class ResultadoToque {
  const ResultadoToque._(
    this.tipo,
    this.trayectoria, {
    this.coleccionables = const <Posicion>[],
  });

  /// The tap did nothing (no arrow, or rejected by a non-playing state).
  const ResultadoToque.ignorado() : this._(TipoToque.ignorado, null);

  /// The tapped arrow's ray was blocked; the board did not change.
  const ResultadoToque.invalido() : this._(TipoToque.invalido, null);

  /// The whole [trayectoria] exited the board, collecting [coleccionables] (the
  /// positions of any bonus cells its ray crossed; empty when none).
  ResultadoToque.valido(
    Trayectoria trayectoria, {
    List<Posicion> coleccionables = const <Posicion>[],
  }) : this._(TipoToque.valido, trayectoria, coleccionables: coleccionables);

  /// Which of the three outcomes occurred.
  final TipoToque tipo;

  /// The path that left the board on a [TipoToque.valido] tap; otherwise `null`.
  final Trayectoria? trayectoria;

  /// The collectibles consumed by a valid move's ray, in the order crossed.
  /// Always empty for an ignored or invalid tap.
  final List<Posicion> coleccionables;

  /// Whether the tap counted as a move (a valid exit or a penalized invalid tap).
  bool get registrado => tipo != TipoToque.ignorado;

  /// Whether the tap changed the board (a whole path exited).
  bool get valido => tipo == TipoToque.valido;
}
