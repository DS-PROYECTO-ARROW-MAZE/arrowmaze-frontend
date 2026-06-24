import '../value_objects/direccion.dart';
import '../value_objects/posicion.dart';

/// A single board position and its content.
///
/// Exactly the four move-mechanic kinds exist ([CeldaFlecha], [CeldaPared],
/// [CeldaVacia], [Coleccionable]). `Celda` is a `sealed` type, so the compiler
/// enforces exhaustive handling and the hierarchy stays closed — the four kinds
/// are Factory products (`FabricaCeldasEstandar`), never decorators (see
/// `CONTEXT.md`).
///
/// Two questions every cell answers polymorphically, so a caller never branches
/// on the concrete kind (LSP/OCP): whether it stops a ray ([bloqueaRayo]) and
/// whether a ray that flies over it collects it ([esColeccionable]). Adding a new
/// cell kind means overriding these — never editing the `raycast` walk or a use
/// case.
sealed class Celda {
  /// Binds a cell to its board [posicion].
  const Celda(this.posicion);

  /// Where this cell sits on the board.
  final Posicion posicion;

  /// Whether a ray crossing this cell is stopped by it.
  ///
  /// `true` for solid content (an arrow or a wall), `false` for transparent
  /// cells the ray flies over (empties and collectibles).
  bool get bloqueaRayo;

  /// Whether a ray flying over this cell collects it (granting bonus time).
  ///
  /// `false` for every kind except [Coleccionable]; this is what lets the
  /// collision walk gather collectibles without knowing their concrete type.
  bool get esColeccionable => false;
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

/// An optional bonus element, transparent to rays.
///
/// Like a [CeldaVacia] a ray flies straight over it ([bloqueaRayo] is `false`),
/// so it never blocks a move and is never required for victory. The difference
/// is that a *valid* move whose ray crosses it collects it
/// ([esColeccionable] is `true`): the board removes it and the
/// `MoverFlechaUseCase` adds seconds to the level timer (PRD §3 A4). It is a
/// plain Factory product — never a decorator (see `CONTEXT.md`).
final class Coleccionable extends Celda {
  /// Creates a collectible at [posicion].
  const Coleccionable(super.posicion);

  @override
  bool get bloqueaRayo => false;

  @override
  bool get esColeccionable => true;
}

/// A grid position outside the playable region of a shaped board.
///
/// Absent cells are not part of the level's active area: the solver skips them,
/// the renderer draws nothing, and hit-testing ignores them (the touch falls
/// through to the backdrop). They are semantically void — the ray treats them
/// like the board edge (no node in the graph → ray exits clear). This is
/// distinct from [CeldaVacia] (a present-but-transparent playable cell) and from
/// [CeldaPared] (a solid boundary inside the playable region).
///
/// [bloqueaRayo] is `false` because absent positions are never linked in the
/// graph, so the collision walker never encounters them; the property exists
/// for completeness of the sealed switch and is unused in practice.
final class CeldaAusente extends Celda {
  /// Marks [posicion] as absent (outside the playable region).
  const CeldaAusente(super.posicion);

  @override
  bool get bloqueaRayo => false;

  @override
  bool get esColeccionable => false;
}
