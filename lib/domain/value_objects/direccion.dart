import 'vector3.dart';

/// A movement direction expressed as a unit [Vector3] step.
///
/// On a 2D board there are exactly four directions ([arriba], [abajo],
/// [izquierda], [derecha] — [cardinales]); a 3D board adds [adelante]/[atras]
/// (the depth axis) without changing the `Tablero` contract — see [todas]. A
/// `Flecha` points in one `Direccion` and its ray walks the board by
/// repeatedly applying [delta]. Value-equal, so directions are usable as map
/// keys (e.g. a node's neighbour table).
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

  /// Forward — into the stack (increasing depth layer).
  static const Direccion adelante = Direccion(Vector3(0, 0, 1));

  /// Backward — out of the stack (decreasing depth layer).
  static const Direccion atras = Direccion(Vector3(0, 0, -1));

  /// The four 2D directions, in reading order. Stays four so the 2D contract
  /// never changes shape; use [todas] where depth neighbours also matter.
  static const List<Direccion> cardinales = <Direccion>[
    arriba,
    abajo,
    izquierda,
    derecha,
  ];

  /// All six directions — [cardinales] plus [adelante]/[atras] — the
  /// dimension-agnostic set a depth-aware board links neighbours across. On a
  /// `profundo: 1` board the two depth directions simply find no neighbour, so
  /// using this set costs nothing for a 2D board (no branching on dimension).
  static const List<Direccion> todas = <Direccion>[
    arriba,
    abajo,
    izquierda,
    derecha,
    adelante,
    atras,
  ];

  /// The direction (of the six) whose [delta] equals the unit [paso].
  ///
  /// Used to recover the direction connecting two orthogonally adjacent
  /// positions (e.g. consecutive segments of a `Trayectoria`, which may now
  /// bend through depth). Throws [ArgumentError] when [paso] is not a single-
  /// cell step, so a malformed (diagonal or non-contiguous) path fails loudly.
  static Direccion desdePaso(Vector3 paso) => todas.firstWhere(
        (direccion) => direccion.delta == paso,
        orElse: () => throw ArgumentError.value(
          paso,
          'paso',
          'Not a unit step',
        ),
      );

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
