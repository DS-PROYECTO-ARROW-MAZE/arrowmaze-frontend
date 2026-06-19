import 'detector_colisiones.dart';
import 'entities/celda.dart';
import 'nodo.dart';
import 'tablero.dart';
import 'value_objects/direccion.dart';
import 'value_objects/posicion.dart';

/// A [Tablero] backed by a graph of [Nodo]s, mutated incrementally.
///
/// Every position is a node linked to its in-bounds neighbours. [raycast]
/// delegates the walk to a [DetectorColisiones], and [eliminarFlecha] removes an
/// arrow by re-wiring its neighbours directly to each other and clearing its
/// links — touching only the local neighbourhood, never rebuilding the graph,
/// and preserving the identity of every untouched node.
class GrafoTablero implements Tablero {
  GrafoTablero._(
    this._filas,
    this._columnas,
    this._nodos,
    this._detector,
  );

  /// Builds a board of [filas] × [columnas], empty everywhere except where a
  /// cell in [celdas] overrides a position.
  ///
  /// [detector] is injectable for testing; it defaults to the standard collision
  /// walk.
  factory GrafoTablero.desdeCeldas({
    required int filas,
    required int columnas,
    required List<Celda> celdas,
    DetectorColisiones detector = const DetectorColisiones(),
  }) {
    final nodos = <Posicion, Nodo>{};

    // Seed every position with transparent empty space.
    for (var f = 0; f < filas; f++) {
      for (var c = 0; c < columnas; c++) {
        final posicion = Posicion.en(fila: f, columna: c);
        nodos[posicion] = Nodo(CeldaVacia(posicion));
      }
    }

    // Overlay the explicit cells (arrows, walls, …).
    for (final celda in celdas) {
      nodos[celda.posicion]!.celda = celda;
    }

    // Link each node to its existing neighbours in all directions.
    for (final nodo in nodos.values) {
      for (final direccion in Direccion.cardinales) {
        final vecino = nodos[nodo.celda.posicion.desplazar(direccion)];
        if (vecino != null) {
          nodo.vecinos[direccion] = vecino;
        }
      }
    }

    return GrafoTablero._(filas, columnas, nodos, detector);
  }

  final int _filas;
  final int _columnas;
  final Map<Posicion, Nodo> _nodos;
  final DetectorColisiones _detector;

  @override
  int get filas => _filas;

  @override
  int get columnas => _columnas;

  /// The node at [posicion]. Exposed so the graph's incremental re-wiring is
  /// observable by domain tests; not part of the [Tablero] port.
  Nodo nodoEn(Posicion posicion) => _nodos[posicion]!;

  @override
  Celda celdaEn(Posicion posicion) => nodoEn(posicion).celda;

  @override
  ResultadoRaycast raycast(Posicion origen, Direccion direccion) =>
      _detector.detectar(nodoEn(origen), direccion);

  @override
  void eliminarFlecha(Posicion posicion) {
    final nodo = nodoEn(posicion);

    // Re-wire each neighbour to the node on the opposite side, so the ray walk
    // steps straight over the gap left by the removed arrow.
    for (final direccion in nodo.vecinos.keys.toList()) {
      final vecino = nodo.vecinos[direccion]!;
      final opuesto = nodo.vecinos[direccion.opuesta];
      if (opuesto != null) {
        vecino.vecinos[direccion.opuesta] = opuesto;
      } else {
        vecino.vecinos.remove(direccion.opuesta);
      }
    }

    nodo.celda = CeldaVacia(posicion);
    nodo.vecinos.clear();
  }
}
