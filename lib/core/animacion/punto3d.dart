/// A plain 3D point in an abstract unit space (cell units), independent of any
/// UI framework.
///
/// Mirrors [Punto2D] one dimension up: the rotatable cube view works in cell
/// coordinates so it stays pure Dart with no `dart:ui`/Flutter dependency.
/// Value-equal, so points compare and hash by content.
class Punto3D {
  /// Creates a point at ([x], [y], [z]) in cell units.
  const Punto3D(this.x, this.y, this.z);

  /// The horizontal coordinate (column axis).
  final double x;

  /// The vertical coordinate (row axis).
  final double y;

  /// The depth coordinate (layer axis).
  final double z;

  @override
  bool operator ==(Object other) =>
      other is Punto3D && other.x == x && other.y == y && other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() => 'Punto3D($x, $y, $z)';
}
