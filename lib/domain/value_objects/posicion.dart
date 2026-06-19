import 'direccion.dart';
import 'vector3.dart';

/// An immutable board coordinate, dimension-agnostic via [Vector3].
///
/// On a 2D board a position is a `(fila, columna)` pair; its [coordenada] maps
/// those onto the `Vector3` `y`/`x` axes so direction math stays uniform across
/// dimensions. It is value-equal, so positions compare and hash by content and
/// can be used as map keys and in assertions.
class Posicion {
  /// Creates a 2D position from its row ([fila]) and column ([columna]).
  const Posicion.en({required this.fila, required this.columna});

  /// Row index (the `y` axis) on a 2D board.
  final int fila;

  /// Column index (the `x` axis) on a 2D board.
  final int columna;

  /// This position as a dimension-agnostic coordinate (`x = columna`,
  /// `y = fila`, `z = 0`).
  Vector3 get coordenada => Vector3(columna, fila, 0);

  /// The neighbouring position one step along [direccion].
  Posicion desplazar(Direccion direccion) {
    final destino = coordenada + direccion.delta;
    return Posicion.en(fila: destino.y, columna: destino.x);
  }

  @override
  bool operator ==(Object other) =>
      other is Posicion && other.fila == fila && other.columna == columna;

  @override
  int get hashCode => Object.hash(fila, columna);

  @override
  String toString() => 'Posicion(fila: $fila, columna: $columna)';
}
