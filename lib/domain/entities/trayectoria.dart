import '../value_objects/direccion.dart';
import '../value_objects/posicion.dart';

/// An arrow as a **continuous, possibly bending path** of board cells.
///
/// This is the core of the move mechanic: a `Trayectoria` (arrow) is no longer a
/// single 1×1 cell but an ordered chain of orthogonally-adjacent [segmentos]
/// from its tail ([cola]) to its tip ([cabeza]). The path may turn 90° at any
/// segment (a *corner*), and it carries exactly one arrowhead, at the head,
/// pointing in [direccionCabeza] — the direction the whole path tries to exit.
///
/// A move resolves a whole `Trayectoria` at once: if the head's ray is clear to
/// the board edge, every segment of the path is removed together (see
/// `MoverFlechaUseCase`). Geometry is pure Dart — this entity never imports
/// Flutter; the renderer reads [conexionesEn]/[esCabeza] to draw the continuous
/// line and the single arrowhead.
///
/// See `Flecha` in `CONTEXT.md`.
class Trayectoria {
  /// Creates a path of [segmentos] (tail → head) exiting toward
  /// [direccionCabeza].
  ///
  /// [segmentos] must be non-empty and every consecutive pair must be
  /// orthogonally adjacent; [validar] enforces both and throws [ArgumentError]
  /// otherwise, so a malformed path never reaches the board.
  Trayectoria({
    required this.id,
    required this.segmentos,
    required this.direccionCabeza,
  }) {
    _validar();
  }

  /// Stable identity shared by every segment cell of this path; used to group
  /// and remove the whole arrow at once.
  final int id;

  /// The path's cells in order from tail to head; the head is [segmentos.last].
  final List<Posicion> segmentos;

  /// The direction the arrowhead at [cabeza] points (the path's exit direction).
  final Direccion direccionCabeza;

  /// The tip cell carrying the arrowhead — the origin of the exit ray.
  Posicion get cabeza => segmentos.last;

  /// The tail cell — the far end of the path from the arrowhead.
  Posicion get cola => segmentos.first;

  /// Whether [posicion] is this path's head (where the arrowhead is drawn).
  bool esCabeza(Posicion posicion) => posicion == cabeza;

  /// Whether [posicion] is one of this path's segments.
  bool contiene(Posicion posicion) => segmentos.contains(posicion);

  /// The directions from [posicion] toward its connected path neighbours.
  ///
  /// A middle segment yields two directions (a straight when they are opposite,
  /// a corner when perpendicular); the two endpoints yield one each. The
  /// renderer uses this to draw a single continuous line that bends with the
  /// path. Returns an empty set for a one-cell path or a position not on it.
  Set<Direccion> conexionesEn(Posicion posicion) {
    final indice = segmentos.indexOf(posicion);
    if (indice < 0) return const <Direccion>{};

    final conexiones = <Direccion>{};
    if (indice > 0) {
      conexiones.add(_direccionEntre(posicion, segmentos[indice - 1]));
    }
    if (indice < segmentos.length - 1) {
      conexiones.add(_direccionEntre(posicion, segmentos[indice + 1]));
    }
    return conexiones;
  }

  /// The direction stepping from [desde] to the adjacent [hacia].
  Direccion _direccionEntre(Posicion desde, Posicion hacia) =>
      Direccion.desdePaso(hacia.coordenada + desde.coordenada.negado);

  void _validar() {
    if (segmentos.isEmpty) {
      throw ArgumentError.value(segmentos, 'segmentos', 'Path cannot be empty');
    }
    for (var i = 0; i < segmentos.length - 1; i++) {
      // Throws if the step is not a unit cardinal — i.e. the path is diagonal
      // or has a gap between two consecutive segments.
      _direccionEntre(segmentos[i], segmentos[i + 1]);
    }
  }
}
