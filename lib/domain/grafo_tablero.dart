import 'detector_colisiones.dart';
import 'entities/celda.dart';
import 'entities/trayectoria.dart';
import 'nodo.dart';
import 'tablero.dart';
import 'value_objects/direccion.dart';
import 'value_objects/posicion.dart';

/// A [Tablero] backed by a graph of [Nodo]s, mutated incrementally.
///
/// Every position is a node linked to its in-bounds neighbours. Arrows are
/// [Trayectoria]s: each path tags its segment cells with a shared `idFlecha`, and
/// the board keeps the paths by id so a tap on any segment resolves the whole
/// arrow. [raycast] delegates the walk to a [DetectorColisiones];
/// [eliminarTrayectoria] removes every segment of a path by re-wiring each node's
/// neighbours directly to each other and clearing its links — touching only the
/// local neighbourhood, never rebuilding the graph, and preserving the identity
/// of every untouched node.
class GrafoTablero implements Tablero {
  GrafoTablero._(
    this._filas,
    this._columnas,
    this._nodos,
    this._trayectorias,
    this._detector,
  );

  /// Builds a board of [filas] × [columnas], empty everywhere except where a
  /// fixed [celdas] (walls) or a [trayectorias] segment overrides a position.
  ///
  /// [detector] is injectable for testing; it defaults to the standard collision
  /// walk.
  factory GrafoTablero.desde({
    required int filas,
    required int columnas,
    List<Trayectoria> trayectorias = const <Trayectoria>[],
    List<Celda> celdas = const <Celda>[],
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

    // Overlay fixed cells (walls).
    for (final celda in celdas) {
      nodos[celda.posicion]!.celda = celda;
    }

    // Overlay each arrow path: every segment becomes a CeldaFlecha tagged with
    // the path id and the path's exit direction.
    final indice = <int, Trayectoria>{};
    for (final trayectoria in trayectorias) {
      indice[trayectoria.id] = trayectoria;
      for (final posicion in trayectoria.segmentos) {
        nodos[posicion]!.celda = CeldaFlecha(
          posicion: posicion,
          direccion: trayectoria.direccionCabeza,
          idFlecha: trayectoria.id,
        );
      }
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

    return GrafoTablero._(filas, columnas, nodos, indice, detector);
  }

  final int _filas;
  final int _columnas;
  final Map<Posicion, Nodo> _nodos;
  final Map<int, Trayectoria> _trayectorias;
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
  Trayectoria? trayectoriaEn(Posicion posicion) {
    final celda = celdaEn(posicion);
    return celda is CeldaFlecha ? _trayectorias[celda.idFlecha] : null;
  }

  @override
  ResultadoRaycast raycast(Posicion origen, Direccion direccion) =>
      _detector.detectar(nodoEn(origen), direccion);

  @override
  void eliminarTrayectoria(int idFlecha) {
    final trayectoria = _trayectorias.remove(idFlecha);
    if (trayectoria == null) return;
    for (final posicion in trayectoria.segmentos) {
      _desvincularNodo(posicion);
    }
  }

  /// Turns the node at [posicion] into transparent empty space and re-wires its
  /// neighbours to each other so a ray walk steps straight over the gap.
  void _desvincularNodo(Posicion posicion) {
    final nodo = nodoEn(posicion);
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
