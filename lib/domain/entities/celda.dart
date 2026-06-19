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

/// A directional, removable cell: an arrow pointing in one [direccion].
///
/// It blocks rays while present and is the only cell a move can consume — a
/// valid move turns it into a [CeldaVacia]. It is never rotated (see `Flecha` in
/// `CONTEXT.md`).
final class CeldaFlecha extends Celda {
  /// Creates an arrow cell at [posicion] pointing in [direccion].
  const CeldaFlecha({required Posicion posicion, required this.direccion})
      : super(posicion);

  /// The fixed direction this arrow shoots towards.
  final Direccion direccion;

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
