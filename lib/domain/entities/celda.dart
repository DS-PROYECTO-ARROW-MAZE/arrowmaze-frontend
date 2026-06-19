import '../value_objects/direccion.dart';
import '../value_objects/posicion.dart';

/// A single board position and its content.
///
/// Exactly the three move-mechanic kinds exist in this slice ([CeldaFlecha],
/// [CeldaPared], [CeldaVacia]); `Coleccionable` arrives with ticket 03. `Celda`
/// is a `sealed` type, so the compiler enforces exhaustive handling and the
/// hierarchy stays closed — the four kinds are Factory products
/// (`FabricaCeldasEstandar`), never decorators (see `CONTEXT.md`).
///
/// The only behaviour every cell shares is whether it stops a ray
/// ([bloqueaRayo]); LSP holds because any `Celda` answers that question without
/// the caller knowing its concrete kind.
sealed class Celda {
  /// Binds a cell to its board [posicion].
  const Celda(this.posicion);

  /// Where this cell sits on the board.
  final Posicion posicion;

  /// Whether a ray crossing this cell is stopped by it.
  ///
  /// `true` for solid content (an arrow or a wall), `false` for transparent
  /// cells the ray flies over (empties — and, later, collectibles).
  bool get bloqueaRayo;
}

/// One **segment** of an arrow path (`Trayectoria`) occupying this cell.
///
/// An arrow is no longer a single cell: it is a continuous, possibly bending
/// path, and each cell it covers holds a [CeldaFlecha] tagged with the owning
/// path's [idFlecha]. [direccion] is the path's exit direction (the way its
/// arrowhead points), shared by every segment of the same path. A segment blocks
/// rays while present; a valid move removes the **whole** path at once, turning
/// each of its segments into a [CeldaVacia]. Arrows are never rotated (see
/// `Flecha` in `CONTEXT.md`).
final class CeldaFlecha extends Celda {
  /// Creates an arrow segment at [posicion] belonging to path [idFlecha], whose
  /// head points in [direccion].
  const CeldaFlecha({
    required Posicion posicion,
    required this.direccion,
    required this.idFlecha,
  }) : super(posicion);

  /// The exit direction of the path this segment belongs to.
  final Direccion direccion;

  /// Identity of the owning [Trayectoria]; segments of the same path share it.
  final int idFlecha;

  @override
  bool get bloqueaRayo => true;
}

/// A static, permanent obstacle that always stops a ray and is never removed.
final class CeldaPared extends Celda {
  /// Creates a wall at [posicion].
  const CeldaPared(super.posicion);

  @override
  bool get bloqueaRayo => true;
}

/// Transparent empty space: a ray flies over it without interacting.
final class CeldaVacia extends Celda {
  /// Creates an empty cell at [posicion].
  const CeldaVacia(super.posicion);

  @override
  bool get bloqueaRayo => false;
}
