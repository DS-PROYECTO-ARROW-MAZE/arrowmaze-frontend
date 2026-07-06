/// A plain 2D point in an abstract unit space (cell units), independent of any
/// UI framework.
///
/// The path-sampling helpers work in *cell coordinates* — one unit per board
/// cell — so they stay pure Dart with no `dart:ui`/Flutter dependency. The View
/// converts these to pixel `Offset`s when it paints. Value-equal, so points
/// compare and hash by content.
class Punto2D {
  /// Creates a point at ([x], [y]) in cell units.
  const Punto2D(this.x, this.y);

  /// The horizontal coordinate (column axis).
  final double x;

  /// The vertical coordinate (row axis).
  final double y;

  /// Linearly interpolates from this point toward [otro] by fraction [t].
  Punto2D interpolarHacia(Punto2D otro, double t) =>
      Punto2D(x + (otro.x - x) * t, y + (otro.y - y) * t);

  @override
  bool operator ==(Object other) =>
      other is Punto2D && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Punto2D($x, $y)';
}
