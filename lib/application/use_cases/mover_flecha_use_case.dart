import '../../domain/entities/celda.dart';
import '../../domain/tablero.dart';
import '../../domain/value_objects/posicion.dart';
import 'evento_juego.dart';
import 'resultado_movimiento.dart';

/// Resolves a tap on a board cell into a move.
///
/// It depends only on the [Tablero] *port* (DIP), injected by the constructor —
/// it never constructs a concrete board. This slice implements the **valid
/// exit** branch only (PRD A1/A3): if the tapped cell is an arrow whose ray is
/// clear to the edge, the arrow leaves, its cell becomes empty, the move count
/// advances and `FlechaEliminada` + `MovimientoRealizado` are emitted. Invalid
/// moves (a blocked ray) are out of scope until ticket 02, so they are a no-op
/// here rather than being silently penalised.
class MoverFlechaUseCase {
  /// Injects the board [Tablero] this use case operates on.
  MoverFlechaUseCase(this._tablero);

  final Tablero _tablero;

  int _movimientos = 0;

  /// The taps registered so far (valid moves in this slice).
  int get movimientos => _movimientos;

  /// Applies a tap at [posicion] and returns its [ResultadoMovimiento].
  ResultadoMovimiento ejecutar(Posicion posicion) {
    final celda = _tablero.celdaEn(posicion);

    // Only arrows can move; taps on other cells are ignored in this slice.
    if (celda is! CeldaFlecha) {
      return ResultadoMovimiento(
        valido: false,
        movimientos: _movimientos,
        eventos: const <EventoJuego>[],
      );
    }

    // Valid-exit path only: a blocked ray is ticket 02's invalid-move logic.
    final rayo = _tablero.raycast(posicion, celda.direccion);
    if (!rayo.despejadoHastaBorde) {
      return ResultadoMovimiento(
        valido: false,
        movimientos: _movimientos,
        eventos: const <EventoJuego>[],
      );
    }

    _tablero.eliminarFlecha(posicion);
    _movimientos++;

    return ResultadoMovimiento(
      valido: true,
      movimientos: _movimientos,
      eventos: <EventoJuego>[
        EventoJuego(TipoEvento.movimientoRealizado, posicion),
        EventoJuego(TipoEvento.flechaEliminada, posicion),
      ],
    );
  }
}
