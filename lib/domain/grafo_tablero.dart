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
    this._profundo,
    this._nodos,
    this._trayectorias,
    this._detector,
  );

  /// Builds a board of [filas] × [columnas] × [profundo] layers, empty
  /// everywhere except where a fixed [celdas] (walls), a [trayectorias]
  /// segment overrides a position, or the position is marked [ausentes]
  /// (outside the playable region). [profundo] defaults to `1` (a 2D board).
  ///
  /// [detector] is injectable for testing; it defaults to the standard collision
  /// walk.
  factory GrafoTablero.desde({
    required int filas,
    required int columnas,
    int profundo = 1,
    List<Trayectoria> trayectorias = const <Trayectoria>[],
    List<Celda> celdas = const <Celda>[],
    Set<Posicion> ausentes = const <Posicion>{},
    DetectorColisiones detector = const DetectorColisiones(),
  }) {
    final nodos = <Posicion, Nodo>{};

    // Seed every playable position with transparent empty space.
    // Absent positions get no node — they are void (like the board edge).
    for (var f = 0; f < filas; f++) {
      for (var c = 0; c < columnas; c++) {
        for (var p = 0; p < profundo; p++) {
          final posicion = Posicion.en(fila: f, columna: c, capa: p);
          if (ausentes.contains(posicion)) continue;
          nodos[posicion] = Nodo(CeldaVacia(posicion));
        }
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

    // Link each node to its existing neighbours in all six directions (a
    // single loop, no branching on dimension) — a layer-1 board simply finds
    // no depth neighbour to link, so this costs nothing for a 2D board.
    for (final nodo in nodos.values) {
      for (final direccion in Direccion.todas) {
        final vecino = nodos[nodo.celda.posicion.desplazar(direccion)];
        if (vecino != null) {
          nodo.vecinos[direccion] = vecino;
        }
      }
    }

    return GrafoTablero._(filas, columnas, profundo, nodos, indice, detector);
  }

  final int _filas;
  final int _columnas;
  final int _profundo;
  final Map<Posicion, Nodo> _nodos;
  final Map<int, Trayectoria> _trayectorias;
  final DetectorColisiones _detector;

  @override
  int get filas => _filas;

  @override
  int get columnas => _columnas;

  @override
  int get profundo => _profundo;

  @override
  bool get estaVacio => _trayectorias.isEmpty;

  /// The node at [posicion]. Exposed so the graph's incremental re-wiring is
  /// observable by domain tests; not part of the [Tablero] port.
  ///
  /// Throws when [posicion] is absent (no node was seeded for it).
  Nodo nodoEn(Posicion posicion) => _nodos[posicion]!;

  @override
  Celda celdaEn(Posicion posicion) {
    final nodo = _nodos[posicion];
    return nodo?.celda ?? CeldaAusente(posicion);
  }

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

  @override
  void restaurarTrayectoria(Trayectoria trayectoria) {
    _trayectorias[trayectoria.id] = trayectoria;
    final segmentos = trayectoria.segmentos.toSet();
    // Re-materialise every segment cell first, so a segment is never mistaken
    // for a gap while its siblings are being re-linked.
    for (final posicion in trayectoria.segmentos) {
      _nodos[posicion]!.celda = CeldaFlecha(
        posicion: posicion,
        direccion: trayectoria.direccionCabeza,
        idFlecha: trayectoria.id,
      );
    }
    // Re-link each segment to the nearest still-present node in every direction —
    // the inverse of removal's wire-across-the-gap (walls and live cells stop the
    // walk; nodes still removed are skipped, matching the state at removal time).
    for (final posicion in trayectoria.segmentos) {
      final nodo = _nodos[posicion]!;
      for (final direccion in Direccion.todas) {
        final vecino = _vecinoPresenteMasCercano(posicion, direccion, segmentos);
        if (vecino != null) {
          nodo.vecinos[direccion] = vecino;
          vecino.vecinos[direccion.opuesta] = nodo;
        }
      }
    }
  }

  /// Walks from [desde] along [direccion] skipping nodes that are currently a
  /// removed gap (unlinked and not part of the path being restored) and returns
  /// the first node still present, or `null` at the board edge.
  Nodo? _vecinoPresenteMasCercano(
    Posicion desde,
    Direccion direccion,
    Set<Posicion> segmentos,
  ) {
    var posicion = desde.desplazar(direccion);
    while (true) {
      final nodo = _nodos[posicion];
      if (nodo == null) return null; // off the board
      final esBrecha = nodo.vecinos.isEmpty && !segmentos.contains(posicion);
      if (!esBrecha) return nodo;
      posicion = posicion.desplazar(direccion);
    }
  }

  @override
  void recogerColeccionable(Posicion posicion) {
    final nodo = _nodos[posicion];
    // Only a collectible is consumed; the cell is already transparent (it never
    // unlinks neighbours), so swapping it for empty space is enough.
    if (nodo == null || !nodo.celda.esColeccionable) return;
    nodo.celda = CeldaVacia(posicion);
  }

  /// Overlays an arrow [trayectoria] onto the already-linked graph during board
  /// construction: each segment cell becomes a `CeldaFlecha`. No re-link is
  /// needed because building never unlinks nodes (use [restaurarTrayectoria] to
  /// bring back a path that *was* removed).
  void agregarTrayectoria(Trayectoria trayectoria) {
    _trayectorias[trayectoria.id] = trayectoria;
    for (final posicion in trayectoria.segmentos) {
      final nodo = _nodos[posicion];
      if (nodo == null) continue;
      nodo.celda = CeldaFlecha(
        posicion: posicion,
        direccion: trayectoria.direccionCabeza,
        idFlecha: trayectoria.id,
      );
    }
  }

  void agregarCelda(Celda celda) {
    final nodo = _nodos[celda.posicion];
    if (nodo == null) return;
    nodo.celda = celda;
  }

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
