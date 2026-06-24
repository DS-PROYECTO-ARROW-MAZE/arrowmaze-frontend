/// A single cell descriptor in a level being created (`POST /levels`).
///
/// Pure domain value object — no Flutter, no infrastructure.
class CeldaNivel {
  /// Creates a cell descriptor.
  const CeldaNivel({required this.x, required this.y, required this.tipo});

  /// Column coordinate (0-based).
  final int x;

  /// Row coordinate (0-based).
  final int y;

  /// Cell kind token, e.g. `inicio`, `flecha`, `pared`, `salida`.
  final String tipo;
}
