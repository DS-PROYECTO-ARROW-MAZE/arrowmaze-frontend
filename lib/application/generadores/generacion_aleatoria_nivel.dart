import 'dart:math';

import '../../domain/entities/trayectoria.dart';
import '../../domain/grafo_tablero.dart';
import '../../domain/tablero.dart';
import '../../domain/value_objects/direccion.dart';
import '../../domain/value_objects/posicion.dart';
import 'configuracion_generacion.dart';
import 'generador_nivel_base.dart';

/// One arrow planned during carving: its [segmentos] (ordered tail → head) and
/// the head's exit [direccion].
class _Flecha {
  const _Flecha(this.segmentos, this.direccion);

  final List<Posicion> segmentos;
  final Direccion direccion;
}

/// A candidate arrowhead: an empty cell [pos] that can fire a clear ray in
/// [direccion], crossing only the still-empty cells in [rayo] before leaving the
/// board.
class _Cabeza {
  const _Cabeza(this.pos, this.direccion, this.rayo);

  final Posicion pos;
  final Direccion direccion;
  final List<Posicion> rayo;
}

/// Random level strategy that grows a **tangled, interlocking** maze by
/// reverse-carving with random walks — not stacked geometric bands.
///
/// It works **backwards**, the order the GoF Template Method [GeneradorNivelBase]
/// then re-validates. On an empty board it repeatedly:
///
/// 1. **picks a head** — any empty cell with a clear straight ray to an edge over
///    still-empty cells, weighted toward cells with the *longest* such ray (the
///    deep interior). A deep head's ray is later overrun by the bodies of arrows
///    carved after it, which is exactly what forces the **interlocking**
///    extraction order;
/// 2. **grows its body backward** from the head as a random walk of random
///    length, biased by Warnsdorff's rule (step toward the neighbour with the
///    fewest free cells) so the empty region is not stranded — with a dash of
///    pure randomness so paths **snake unpredictably and vary in length**;
/// 3. never lets a body cross its own head's exit ray (that would self-block).
///
/// Because every head's ray is clear of all *earlier*-carved arrows at carve
/// time, the reverse order empties the board — the carve is **solvable by
/// construction**, so [GeneradorNivelBase.validarSolvencia] always passes. A
/// carve that can't reach **100% density** (a rare stranded attempt) is simply
/// retried; an extreme run falls back to a single space-filling snake so the UI
/// is never handed a partial board.
class GeneracionAleatoriaNivel extends GeneradorNivelBase {
  /// Creates the strategy. Pass [semilla] to make generation deterministic
  /// (used by tests); omit it for a fresh maze on each run.
  const GeneracionAleatoriaNivel({int? semilla}) : _semilla = semilla;

  final int? _semilla;

  /// How many full-board carves to attempt before the snake fallback.
  static const _maxIntentos = 200;

  /// Probability of ignoring Warnsdorff and stepping to a uniformly random
  /// neighbour, to keep the walk from looking mechanical.
  static const _probabilidadCaos = 0.25;

  @override
  void poblar(Tablero tablero, ConfiguracionGeneracion config) {
    final grafo = tablero as GrafoTablero;
    final rng = Random(_semilla);
    final filas = config.filas;
    final columnas = config.columnas;

    List<_Flecha>? plan;
    for (var intento = 0; intento < _maxIntentos && plan == null; intento++) {
      plan = _carvar(filas, columnas, rng);
    }
    plan ??= _snakeRespaldo(filas, columnas);

    var id = 1;
    for (final flecha in plan) {
      grafo.agregarTrayectoria(Trayectoria(
        id: id++,
        segmentos: flecha.segmentos,
        direccionCabeza: flecha.direccion,
      ));
    }
  }

  /// Attempts one full backward carve. Returns the arrows tail → head, or `null`
  /// if the walk stranded empty cells before filling the board (caller retries).
  List<_Flecha>? _carvar(int filas, int columnas, Random rng) {
    final ocupado =
        List.generate(filas, (_) => List<bool>.filled(columnas, false));
    final maxLargo = max(3, (filas * columnas) ~/ 3);
    var restantes = filas * columnas;
    final flechas = <_Flecha>[];

    while (restantes > 0) {
      final cabeza = _elegirCabeza(filas, columnas, ocupado, rng);
      if (cabeza == null) return null; // stranded — cannot reach 100% density.

      final reservado = cabeza.rayo.toSet();
      final cuerpo = <Posicion>[cabeza.pos];
      ocupado[cabeza.pos.fila][cabeza.pos.columna] = true;
      restantes--;

      final objetivo = 1 + rng.nextInt(maxLargo);
      var actual = cabeza.pos;
      while (cuerpo.length < objetivo) {
        final vecinos =
            _vecinosLibres(actual, filas, columnas, ocupado, reservado);
        if (vecinos.isEmpty) break;
        final siguiente = _elegirVecino(vecinos, filas, columnas, ocupado, rng);
        cuerpo.add(siguiente);
        ocupado[siguiente.fila][siguiente.columna] = true;
        restantes--;
        actual = siguiente;
      }

      // Stored tail → head: the head is where the body started.
      flechas.add(_Flecha(cuerpo.reversed.toList(), cabeza.direccion));
    }
    return flechas;
  }

  /// Picks an arrowhead among every empty cell with a clear ray to an edge,
  /// weighted by ray length (deep interior preferred), or `null` if none exists.
  _Cabeza? _elegirCabeza(
    int filas,
    int columnas,
    List<List<bool>> ocupado,
    Random rng,
  ) {
    final candidatos = <_Cabeza>[];
    final pesos = <int>[];
    var total = 0;

    for (var f = 0; f < filas; f++) {
      for (var c = 0; c < columnas; c++) {
        if (ocupado[f][c]) continue;
        final pos = Posicion.en(fila: f, columna: c);
        for (final dir in Direccion.cardinales) {
          final rayo = _rayoLibre(pos, dir, filas, columnas, ocupado);
          if (rayo == null) continue;
          // A longer clear ray means a deeper head: weight it higher so deep
          // heads (which later arrows will block) are favoured — more interlock.
          final peso = rayo.length + 1;
          candidatos.add(_Cabeza(pos, dir, rayo));
          pesos.add(peso);
          total += peso;
        }
      }
    }

    if (candidatos.isEmpty) return null;

    var r = rng.nextInt(total);
    for (var i = 0; i < candidatos.length; i++) {
      r -= pesos[i];
      if (r < 0) return candidatos[i];
    }
    return candidatos.last;
  }

  /// The empty cells the ray from [origen] crosses before leaving the board, or
  /// `null` if a filled cell blocks it first.
  List<Posicion>? _rayoLibre(
    Posicion origen,
    Direccion dir,
    int filas,
    int columnas,
    List<List<bool>> ocupado,
  ) {
    final rayo = <Posicion>[];
    var p = origen.desplazar(dir);
    while (_dentro(p, filas, columnas)) {
      if (ocupado[p.fila][p.columna]) return null;
      rayo.add(p);
      p = p.desplazar(dir);
    }
    return rayo;
  }

  /// The in-bounds, empty, non-reserved orthogonal neighbours of [p].
  List<Posicion> _vecinosLibres(
    Posicion p,
    int filas,
    int columnas,
    List<List<bool>> ocupado,
    Set<Posicion> reservado,
  ) {
    final libres = <Posicion>[];
    for (final dir in Direccion.cardinales) {
      final n = p.desplazar(dir);
      if (!_dentro(n, filas, columnas)) continue;
      if (ocupado[n.fila][n.columna]) continue;
      if (reservado.contains(n)) continue;
      libres.add(n);
    }
    return libres;
  }

  /// Chooses the next walk step: usually Warnsdorff (fewest free neighbours,
  /// random tie-break) to avoid stranding, occasionally a random neighbour.
  Posicion _elegirVecino(
    List<Posicion> vecinos,
    int filas,
    int columnas,
    List<List<bool>> ocupado,
    Random rng,
  ) {
    if (rng.nextDouble() < _probabilidadCaos) {
      return vecinos[rng.nextInt(vecinos.length)];
    }

    var mejor = <Posicion>[];
    var menorGrado = 1 << 30;
    for (final v in vecinos) {
      final grado = _gradoLibre(v, filas, columnas, ocupado);
      if (grado < menorGrado) {
        menorGrado = grado;
        mejor = [v];
      } else if (grado == menorGrado) {
        mejor.add(v);
      }
    }
    return mejor[rng.nextInt(mejor.length)];
  }

  /// How many in-bounds, still-empty orthogonal neighbours [p] has.
  int _gradoLibre(Posicion p, int filas, int columnas, List<List<bool>> ocupado) {
    var grado = 0;
    for (final dir in Direccion.cardinales) {
      final q = p.desplazar(dir);
      if (_dentro(q, filas, columnas) && !ocupado[q.fila][q.columna]) grado++;
    }
    return grado;
  }

  bool _dentro(Posicion p, int filas, int columnas) =>
      p.fila >= 0 && p.fila < filas && p.columna >= 0 && p.columna < columnas;

  /// Guaranteed-complete safety net (essentially never reached): the whole board
  /// as one boustrophedon snake whose head exits off the top edge.
  List<_Flecha> _snakeRespaldo(int filas, int columnas) {
    final orden = <Posicion>[];
    for (var f = 0; f < filas; f++) {
      if (f.isEven) {
        for (var c = 0; c < columnas; c++) {
          orden.add(Posicion.en(fila: f, columna: c));
        }
      } else {
        for (var c = columnas - 1; c >= 0; c--) {
          orden.add(Posicion.en(fila: f, columna: c));
        }
      }
    }
    // Head at (0,0) pointing UP (ray leaves the board immediately → clear).
    return [_Flecha(orden.reversed.toList(), Direccion.arriba)];
  }
}
