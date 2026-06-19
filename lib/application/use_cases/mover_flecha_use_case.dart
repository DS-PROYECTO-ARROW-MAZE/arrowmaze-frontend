import '../../domain/tablero.dart';
import '../../domain/value_objects/posicion.dart';
import 'evento_juego.dart';
import 'resultado_movimiento.dart';

/// Resolves a tap on a board cell into a move over a whole arrow path.
///
/// It depends only on the [Tablero] *port* (DIP), injected by the constructor —
/// it never constructs a concrete board. A tap may land on any segment of an
/// arrow [Trayectoria]; the arrow resolves as a whole. This slice implements the
/// **valid exit** branch only (PRD A1/A3): if the tapped path's head has a clear
/// ray to the edge, the entire path leaves (every segment becomes empty), the
/// move count advances and `FlechaEliminada` + `MovimientoRealizado` are emitted.
/// Invalid moves (a blocked head ray) are out of scope until ticket 02, so they
/// are a no-op here rather than being silently penalised.
class MoverFlechaUseCase {
  /// Injects the board [Tablero] this use case operates on.
  MoverFlechaUseCase(this._tablero);

  final Tablero _tablero;

  int _movimientos = 0;

  /// The taps registered so far (valid moves in this slice).
  int get movimientos => _movimientos;

  /// Applies a tap at [posicion] and returns its [ResultadoMovimiento].
  ResultadoMovimiento ejecutar(Posicion posicion) {
    final trayectoria = _tablero.trayectoriaEn(posicion);

    // Only arrow paths can move; taps on empty/wall cells are ignored here.
    if (trayectoria == null) {
      return _sinCambios();
    }

    // Valid-exit path only: the whole arrow exits when its head's ray is clear.
    // A blocked head ray is ticket 02's invalid-move logic.
    final rayo = _tablero.raycast(trayectoria.cabeza, trayectoria.direccionCabeza);
    if (!rayo.despejadoHastaBorde) {
      return _sinCambios();
    }

    _tablero.eliminarTrayectoria(trayectoria.id);
    _movimientos++;

    return ResultadoMovimiento(
      valido: true,
      movimientos: _movimientos,
      eventos: <EventoJuego>[
        EventoJuego(TipoEvento.movimientoRealizado, posicion),
        EventoJuego(TipoEvento.flechaEliminada, trayectoria.cabeza),
      ],
    );
  }

  ResultadoMovimiento _sinCambios() => ResultadoMovimiento(
        valido: false,
        movimientos: _movimientos,
        eventos: const <EventoJuego>[],
      );
}
