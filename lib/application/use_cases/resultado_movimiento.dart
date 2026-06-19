import 'evento_juego.dart';

/// The immutable outcome of one tap, returned by `MoverFlechaUseCase.ejecutar`.
///
/// It carries whether the tap was a [valido] move, the running [movimientos]
/// count after it, and the [eventos] it produced. One tap yields exactly one
/// `ResultadoMovimiento` (see `Movimiento` in `CONTEXT.md`).
class ResultadoMovimiento {
  /// Creates a move result.
  const ResultadoMovimiento({
    required this.valido,
    required this.movimientos,
    required this.eventos,
  });

  /// Whether the tap resolved into a board change (an arrow exiting).
  ///
  /// In this slice only the valid-exit branch is implemented; invalid-move
  /// penalties arrive with ticket 02.
  final bool valido;

  /// Total taps registered on the level so far.
  final int movimientos;

  /// The events this move produced, in order.
  final List<EventoJuego> eventos;
}
