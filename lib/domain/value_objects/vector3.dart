/// A dimension-agnostic integer coordinate `(x, y, z)`.
///
/// `Vector3` is the single primitive behind both [Posicion] and
/// [Direccion]: a 2D board uses the `x`/`y` plane and leaves `z` at `0`, while a
/// future 3D board reuses the same type with `z` active — so the `Tablero`
/// contract never changes shape with the dimension. Pure Dart, value-equal.
///
/// See `Posicion / Vector3` in `CONTEXT.md`.
class Vector3 {
  /// Creates a coordinate from its three integer components.
  const Vector3(this.x, this.y, this.z);

  /// The horizontal component (column axis on a 2D board).
  final int x;

  /// The vertical component (row axis on a 2D board).
  final int y;

  /// The depth component (unused on a 2D board; always `0` there).
  final int z;

  /// Component-wise sum — used to step a position along a direction.
  Vector3 operator +(Vector3 otro) =>
      Vector3(x + otro.x, y + otro.y, z + otro.z);

  /// The opposite vector (each component negated).
  Vector3 get negado => Vector3(-x, -y, -z);

  @override
  bool operator ==(Object other) =>
      other is Vector3 && other.x == x && other.y == y && other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => 'Vector3($x, $y, $z)';
}
