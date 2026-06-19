import 'vector3.dart';

/// A movement direction expressed as a unit [Vector3] step.
///
/// On a 2D board there are exactly four directions ([arriba], [abajo],
/// [izquierda], [derecha]); a future 3D board adds two more without changing the
/// `Tablero` contract. A `Flecha` points in one `Direccion` and its ray walks
/// the board by repeatedly applying [delta]. Value-equal, so directions are
/// usable as map keys (e.g. a node's neighbour table).
class Direccion {
  /// Creates a direction from its unit step [delta].
  const Direccion(this.delta);

  /// The one-cell step this direction applies to a [Vector3] coordinate.
  final Vector3 delta;

  /// Up — towards the top edge (decreasing row).
  static const Direccion arriba = Direccion(Vector3(0, -1, 0));

  /// Down — towards the bottom edge (increasing row).
  static const Direccion abajo = Direccion(Vector3(0, 1, 0));

  /// Left — towards the left edge (decreasing column).
  static const Direccion izquierda = Direccion(Vector3(-1, 0, 0));

  /// Right — towards the right edge (increasing column).
  static const Direccion derecha = Direccion(Vector3(1, 0, 0));

  /// The four 2D directions, in reading order.
  static const List<Direccion> cardinales = <Direccion>[
    arriba,
    abajo,
    izquierda,
    derecha,
  ];

  /// The reverse direction (used to re-wire a removed node's neighbours).
  Direccion get opuesta => Direccion(delta.negado);

  @override
  bool operator ==(Object other) =>
      other is Direccion && other.delta == delta;

  @override
  int get hashCode => delta.hashCode;

  @override
  String toString() => 'Direccion(${delta.x}, ${delta.y}, ${delta.z})';
}
