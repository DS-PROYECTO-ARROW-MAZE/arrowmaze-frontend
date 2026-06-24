import 'nodo.dart';
import 'tablero.dart';
import 'value_objects/direccion.dart';
import 'value_objects/posicion.dart';

/// Walks the node graph along one direction and reports the first obstacle.
///
/// This is the collision algorithm extracted out from behind `Tablero.raycast`,
/// so the "does this ray reach the edge?" decision lives in one place. It works
/// purely on [Nodo] neighbour links and a [Direccion], knowing nothing about
/// grid coordinates or board dimensions — that is the OCP seam a future 3D
/// `Tablero` reuses unchanged.
class DetectorColisiones {
  /// Stateless — safe to share as a `const`.
  const DetectorColisiones();

  /// Fires a ray from [origen] along [direccion].
  ///
  /// The origin node is excluded; the walk starts at its neighbour and follows
  /// links until it hits a blocking cell ([ResultadoRaycast.bloqueado]) or runs
  /// off the edge ([ResultadoRaycast.despejado]). Removed nodes are already
  /// unlinked, so the walk transparently steps over emptied cells. Every
  /// transparent collectible met on the way is gathered (asked of the cell via
  /// `esColeccionable`, never by type) and reported only when the ray is clear.
  ResultadoRaycast detectar(Nodo origen, Direccion direccion) {
    final coleccionables = <Posicion>[];
    Nodo? actual = origen.vecinos[direccion];
    while (actual != null) {
      if (actual.celda.bloqueaRayo) {
        return ResultadoRaycast.bloqueado(actual.celda.posicion);
      }
      if (actual.celda.esColeccionable) {
        coleccionables.add(actual.celda.posicion);
      }
      actual = actual.vecinos[direccion];
    }
    return ResultadoRaycast.despejado(coleccionables: coleccionables);
  }
}
