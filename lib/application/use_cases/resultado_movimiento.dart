import 'delta_tablero.dart';
import 'evento_juego.dart';

/// The immutable outcome of one tap, returned by `MoverFlechaUseCase.ejecutar`.
///
/// There is a single result shape for every outcome so callers branch on *data*
/// (the [delta]) rather than on a type or a boolean flag:
///
/// - **ignored** tap (no arrow under it): [registrado] is `false`, no [delta].
/// - **valid** move (arrow exits): [registrado] is `true` with a real [delta].
/// - **invalid** penalized move (path blocked): [registrado] is `true` but
///   [delta] is `null` — the move counts, yet the board is unchanged.
///
/// One tap yields exactly one `ResultadoMovimiento` (see `Movimiento` in
/// `CONTEXT.md`).
class ResultadoMovimiento {
  /// Creates a move result.
  const ResultadoMovimiento({
    required this.movimientos,
    required this.eventos,
    this.delta,
    this.registrado = false,
  });

  /// A tap that resolved to no arrow at all — ignored, nothing recorded.
  const ResultadoMovimiento.ignorado(this.movimientos)
      : eventos = const <EventoJuego>[],
        delta = null,
        registrado = false;

  /// Total taps registered as moves on the level so far (valid + penalized).
  final int movimientos;

  /// The events this move produced, in order.
  final List<EventoJuego> eventos;

  /// The board change this move applied, or `null` when nothing changed (an
  /// invalid penalized move, or an ignored tap).
  final DeltaTablero? delta;

  /// Whether the tap counted as a move — `true` for both valid and penalized
  /// invalid moves, `false` for an ignored tap.
  final bool registrado;

  /// Whether the tap changed the board (a real [delta] was applied).
  bool get valido => delta != null;
}
