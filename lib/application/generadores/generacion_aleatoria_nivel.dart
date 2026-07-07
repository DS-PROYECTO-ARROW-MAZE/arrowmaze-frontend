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
  GeneracionAleatoriaNivel({int? semilla}) : _semilla = semilla;

  final int? _semilla;

  /// Positions excluded from the playable region (shaped board).
  Set<Posicion> _ausentes = const <Posicion>{};

  /// How many full-board carves to attempt before the mask-aware fill.
  static const _maxIntentos = 200;

  /// Board area above which the interlocking carve reliably strands (it cannot
  /// fill a region this large to 100% density). Past it we skip the doomed
  /// carve entirely and go straight to the winding fill — far faster on the
  /// large, dense boards the difficulty curve now reaches.
  static const _maxCeldasCarve = 81;

  /// How many winding-walk covers to try before falling back to the guaranteed
  /// (but straight) vertical strip fill. Tight shapes (a 7×7 star) need many
  /// tries to hit a peelable winding cover.
  static const _maxIntentosRelleno = 80;

  /// Probability of ignoring Warnsdorff and stepping to a uniformly random
  /// neighbour, to keep the walk from looking mechanical.
  static const _probabilidadCaos = 0.25;

  /// Winding-arrow target length is [_minLargoSerp] .. [_minLargoSerp] +
  /// [_varLargoSerp] − 1: long enough to turn several times, short enough that a
  /// board carries many arrows (and therefore many firing directions) and that
  /// walks still fit inside a tight shape.
  static const _minLargoSerp = 4;
  static const _varLargoSerp = 10;

  @override
  void poblar(Tablero tablero, ConfiguracionGeneracion config) {
    _ausentes = config.ausentes;
    final grafo = tablero as GrafoTablero;
    final rng = Random(_semilla);
    final filas = config.filas;
    final columnas = config.columnas;

    final area = filas * columnas;
    List<_Flecha>? plan;
    if (area <= _maxCeldasCarve) {
      for (var intento = 0; intento < _maxIntentos && plan == null; intento++) {
        plan = _carvar(filas, columnas, rng);
      }
    }
    // Fallback choice: a small, unshaped board keeps the tangled boustrophedon
    // snake (the interlocking contract small rectangles rely on). A shaped or
    // large board is covered by the winding random-walk fill, which zig-zags
    // through the mask exactly like the carve's body walk; the safe vertical
    // strip fill is only a last resort if a walk cannot cover the shape. Either
    // cover's arrows get varied, valid firing directions from [_asignarDirecciones].
    if (plan == null) {
      if (_ausentes.isEmpty && area <= _maxCeldasCarve) {
        plan = _snakeRespaldo(filas, columnas);
      } else {
        for (var i = 0; i < _maxIntentosRelleno && plan == null; i++) {
          final caminos = _rellenoSerpenteante(filas, columnas, rng);
          if (caminos != null) {
            plan = _asignarDirecciones(caminos, filas, columnas);
          }
        }
        // Guaranteed, always-peelable fallback if every winding attempt failed.
        plan ??= _asignarDirecciones(
            _rellenoVertical(filas, columnas), filas, columnas)!;
      }
    }

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
  /// Absent positions are pre-marked as occupied so they are never carved.
  List<_Flecha>? _carvar(int filas, int columnas, Random rng) {
    final ocupado =
        List.generate(filas, (_) => List<bool>.filled(columnas, false));
    final maxLargo = max(3, (filas * columnas) ~/ 3);
    // Pre-mark absent positions as occupied.
    for (final p in _ausentes) {
      ocupado[p.fila][p.columna] = true;
    }
    var restantes = filas * columnas - _ausentes.length;
    final flechas = <_Flecha>[];

    while (restantes > 0) {
      final cabeza = _elegirCabeza(filas, columnas, ocupado, rng);
      if (cabeza == null) return null; // stranded — cannot reach 100% density.

      final reservado = cabeza.rayo.toSet();
      final cuerpo = <Posicion>[cabeza.pos];
      ocupado[cabeza.pos.fila][cabeza.pos.columna] = true;
      restantes--;

      // Every arrow must span at least minLongitudFlecha cells.
      final minObj = minLongitudFlecha;
      final rango = max(maxLargo - minObj + 1, 1);
      final objetivo = minObj + rng.nextInt(rango);
      var actual = cabeza.pos;
      while (cuerpo.length < objetivo) {
        final vecinos =
            _vecinosLibres(actual, filas, columnas, ocupado, reservado);
        if (vecinos.isEmpty) return null; // cannot reach target length
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

  /// Preferred vertical-strip length. Long runs are cut into chunks of about
  /// this many cells so a large board yields *many* stacked arrows (denser,
  /// higher clear-order chains) instead of a few full-height columns. A chunk
  /// never drops below [minLongitudFlecha].
  static const _tamFranja = 3;

  /// Winding, **mask-respecting** path cover — the maze-like counterpart of the
  /// carve's body walk, used when the carve itself strands. Returns arrow
  /// *paths* (the head + firing direction are assigned later by
  /// [_asignarDirecciones]); returns `null` if a walk strands a cell it cannot
  /// fold into a neighbour, so the caller retries with fresh randomness.
  ///
  /// Each path starts at the current **topmost** unused cell (so the head stays
  /// the path's topmost cell — the invariant [_asignarDirecciones] needs) and
  /// then random-walks through same-row-or-lower unused cells, biased by
  /// Warnsdorff (fewest onward options first, to consume dead-ends) with a dash
  /// of [_probabilidadCaos] pure randomness, so paths **turn repeatedly** and
  /// vary in length instead of running straight. Growth stops at a random target
  /// length, giving many medium, zig-zagging arrows.
  List<List<Posicion>>? _rellenoSerpenteante(
    int filas,
    int columnas,
    Random rng,
  ) {
    final usado =
        List.generate(filas, (_) => List<bool>.filled(columnas, false));
    for (final p in _ausentes) {
      usado[p.fila][p.columna] = true;
    }
    var restantes = filas * columnas - _ausentes.length;
    final caminos = <List<Posicion>>[];

    while (restantes > 0) {
      final cabeza = _celdaSuperiorLibre(filas, columnas, usado);
      final filaCabeza = cabeza.fila;
      final camino = <Posicion>[cabeza];
      usado[cabeza.fila][cabeza.columna] = true;
      restantes--;

      // Grow to a random medium length so the board carries *many* winding
      // arrows (a single maximal snake would leave one direction). Warnsdorff
      // keeps the walk out of dead-ends; the leftover is folded in afterwards.
      final objetivo = _minLargoSerp + rng.nextInt(_varLargoSerp);
      var actual = cabeza;
      while (true) {
        final vecinos =
            _vecinosSerp(actual, filaCabeza, filas, columnas, usado);
        if (vecinos.isEmpty) break;
        // Past the target length, stop — unless stepping away would strand a
        // neighbour that has no other exit (a dead-end arm tip). Grab it instead.
        if (camino.length >= objetivo &&
            !vecinos.any((v) =>
                _vecinosSerp(v, filaCabeza, filas, columnas, usado).isEmpty)) {
          break;
        }
        final siguiente = rng.nextDouble() < _probabilidadCaos
            ? vecinos[rng.nextInt(vecinos.length)]
            : _menosOpciones(vecinos, filaCabeza, filas, columnas, usado, rng);
        camino.add(siguiente);
        usado[siguiente.fila][siguiente.columna] = true;
        restantes--;
        actual = siguiente;
      }

      if (camino.length >= minLongitudFlecha) {
        caminos.add(camino);
      } else if (!_absorberSuelta(camino.first, caminos, 0)) {
        return null; // stranded and unabsorbable — caller retries.
      }
    }
    return caminos;
  }

  /// The topmost, then leftmost, unused cell — the head of the next winding path
  /// (kept topmost so [_asignarDirecciones]'s clear order never stalls).
  Posicion _celdaSuperiorLibre(int filas, int columnas, List<List<bool>> usado) {
    for (var f = 0; f < filas; f++) {
      for (var c = 0; c < columnas; c++) {
        if (!usado[f][c]) return Posicion.en(fila: f, columna: c);
      }
    }
    throw StateError('No hay celda jugable disponible.');
  }

  /// Unused in-bounds neighbours of [p] on the head's row [filaCabeza] or below
  /// (never above it, so the head stays the path's topmost cell).
  List<Posicion> _vecinosSerp(
    Posicion p,
    int filaCabeza,
    int filas,
    int columnas,
    List<List<bool>> usado,
  ) {
    final libres = <Posicion>[];
    for (final dir in Direccion.cardinales) {
      final n = p.desplazar(dir);
      if (!_dentro(n, filas, columnas)) continue;
      if (n.fila < filaCabeza) continue;
      if (usado[n.fila][n.columna]) continue;
      libres.add(n);
    }
    return libres;
  }

  /// Warnsdorff pick: the neighbour with the fewest onward options (random
  /// tie-break), so the walk heads into dead-ends first and strands nothing.
  Posicion _menosOpciones(
    List<Posicion> vecinos,
    int filaCabeza,
    int filas,
    int columnas,
    List<List<bool>> usado,
    Random rng,
  ) {
    var mejor = <Posicion>[];
    var menor = 1 << 30;
    for (final v in vecinos) {
      final g =
          _vecinosSerp(v, filaCabeza, filas, columnas, usado).length;
      if (g < menor) {
        menor = g;
        mejor = [v];
      } else if (g == menor) {
        mejor.add(v);
      }
    }
    return mejor[rng.nextInt(mejor.length)];
  }

  /// Folds a stranded single [celda] into the cover. First tries a no-split
  /// endpoint attach (tail, or same-row head). Failing that it splits an
  /// adjacent path at the cell next to [celda], appends [celda] to the
  /// head-side (keeping that arrow's topmost head) and re-homes the tail-side:
  /// a ≥2 tail becomes its own arrow, a single leftover is folded in the same
  /// way (it almost always has a neighbour a row up). [prof] bounds the cascade;
  /// returns `false` if no attachment exists, so the caller retries afresh.
  bool _absorberSuelta(
    Posicion celda,
    List<List<Posicion>> caminos,
    int prof,
  ) {
    if (prof > _maxCascadaAbsorcion) return false;
    for (final camino in caminos) {
      if (_adyacentes(celda, camino.last)) {
        camino.add(celda);
        return true;
      }
      if (_adyacentes(celda, camino.first) &&
          celda.fila == camino.first.fila) {
        camino.insert(0, celda);
        return true;
      }
    }
    for (var k = 0; k < caminos.length; k++) {
      final camino = caminos[k];
      for (var i = 1; i < camino.length - 1; i++) {
        if (!_adyacentes(celda, camino[i])) continue;
        final resto = camino.sublist(i + 1);
        caminos[k] = [...camino.sublist(0, i + 1), celda];
        if (resto.length >= minLongitudFlecha) {
          caminos.add(resto);
          return true;
        }
        return _absorberSuelta(resto.first, caminos, prof + 1);
      }
    }
    return false;
  }

  /// Maximum recursion depth when re-homing split leftovers.
  static const _maxCascadaAbsorcion = 8;

  bool _adyacentes(Posicion a, Posicion b) =>
      (a.fila - b.fila).abs() + (a.columna - b.columna).abs() == 1;

  /// Guaranteed-complete, **mask-respecting** path cover used only if every
  /// winding attempt strands. Unlike a naïve snake, it never covers a cell
  /// outside the shape, but its arrows run straight (the winding fill is
  /// preferred). Returns the arrow *paths* ordered top → bottom.
  ///
  /// Built from vertical strips of ~[_tamFranja] cells; length-1 vertical runs
  /// (thin horizontal arms) are folded into a neighbour's arrow so no cell is
  /// ever stranded as a length-1 arrow.
  List<List<Posicion>> _rellenoVertical(int filas, int columnas) {
    bool jugable(int f, int c) =>
        f >= 0 &&
        f < filas &&
        c >= 0 &&
        c < columnas &&
        !_ausentes.contains(Posicion.en(fila: f, columna: c));

    // Arrows as paths ordered top → bottom (head = first = topmost cell).
    final arreglos = <List<Posicion>>[];
    final indiceArreglo = <Posicion, int>{};

    void registrar(List<Posicion> path) {
      final idx = arreglos.length;
      arreglos.add(path);
      for (final p in path) {
        indiceArreglo[p] = idx;
      }
    }

    // 1. Cut each column into vertical strips of ~[_tamFranja]; length-1 runs
    //    (thin horizontal arms) are set aside as singles.
    final singles = <Posicion>[];
    for (var c = 0; c < columnas; c++) {
      var f = 0;
      while (f < filas) {
        if (!jugable(f, c)) {
          f++;
          continue;
        }
        var g = f;
        while (jugable(g + 1, c)) {
          g++;
        }
        final largo = g - f + 1;
        if (largo == 1) {
          singles.add(Posicion.en(fila: f, columna: c));
        } else {
          _trocearColumna(f, g, c, registrar);
        }
        f = g + 1;
      }
    }

    // 2. Fold every single cell into the shape. Each arrow is stored head-first
    //    (index 0 = topmost). We prefer attaching a single at an arrow's *end*
    //    (prepend at the head when same-row, or append at the tail) so no cell is
    //    ever evicted; only when the single's sole placed neighbour is a middle
    //    cell do we split the arrow — which keeps both halves valid paths whose
    //    head is still their topmost cell.
    final cola = [...singles];
    var guarda = 0;
    final maxGuarda = filas * columnas * 8 + 32;
    while (cola.isNotEmpty && guarda++ < maxGuarda) {
      final x = cola.removeAt(0);
      if (indiceArreglo.containsKey(x)) continue;

      final vecinos = <Posicion>[
        for (final dir in Direccion.cardinales) x.desplazar(dir),
      ].where((n) => jugable(n.fila, n.columna)).toList();

      // (a) pair with an unplaced single neighbour → a two-cell arrow.
      Posicion? pareja;
      for (final n in vecinos) {
        if (!indiceArreglo.containsKey(n) && cola.contains(n)) {
          pareja = n;
          break;
        }
      }
      if (pareja != null) {
        final orden = x.fila <= pareja.fila ? [x, pareja] : [pareja, x];
        registrar(orden);
        cola.remove(pareja);
        continue;
      }

      // (b) endpoint attach (no eviction): append at a tail, or prepend at a
      //     same-row head.
      var enganchado = false;
      for (final n in vecinos) {
        final ai = indiceArreglo[n];
        if (ai == null) continue;
        final arrow = arreglos[ai];
        if (identical(n, arrow.last) || n == arrow.last) {
          arreglos[ai] = [...arrow, x]; // append at tail; head unchanged
          indiceArreglo[x] = ai;
          enganchado = true;
          break;
        }
        if ((n == arrow.first) && x.fila <= arrow.first.fila) {
          arreglos[ai] = [x, ...arrow]; // prepend as new topmost head
          indiceArreglo[x] = ai;
          enganchado = true;
          break;
        }
      }
      if (enganchado) continue;

      // (c) split at a middle neighbour: keep the head→anchor part (+x), spin
      //     off the tail below the anchor as its own arrow.
      Posicion? ancla;
      for (final n in vecinos) {
        if (indiceArreglo.containsKey(n)) {
          ancla = n;
          break;
        }
      }
      if (ancla == null) {
        cola.add(x); // neighbour not placed yet — revisit later.
        continue;
      }
      final ai = indiceArreglo[ancla]!;
      final arrow = arreglos[ai];
      final i = arrow.indexOf(ancla);
      final top = [...arrow.sublist(0, i + 1), x];
      final bot = arrow.sublist(i + 1);
      arreglos[ai] = top;
      for (final p in top) {
        indiceArreglo[p] = ai;
      }
      if (bot.length >= minLongitudFlecha) {
        registrar(bot);
      } else if (bot.length == 1) {
        indiceArreglo.remove(bot.first);
        cola.add(bot.first);
      }
    }

    return arreglos;
  }

  /// Assigns each fill path a **head cell and a valid, varied firing direction**
  /// by replaying the clear in reverse, so the board stays solvable but its
  /// arrows point every which way (not all UP).
  ///
  /// It peels the board like the greedy solver would: repeatedly it picks a path
  /// with an *endpoint* whose straight ray, in some direction, reaches the board
  /// edge crossing only already-peeled or absent cells (an arrow that would be
  /// clearable at that moment), fixes that endpoint as the head and that
  /// direction as [Direccion], then marks the path cleared. Ties prefer the
  /// least-used direction so the four directions stay well mixed.
  ///
  /// It never stalls: the topmost still-pending path can always fire UP (every
  /// cell above its head is absent or already cleared), so a valid pick always
  /// exists — which is exactly why the resulting board is guaranteed solvable.
  List<_Flecha>? _asignarDirecciones(
    List<List<Posicion>> caminos,
    int filas,
    int columnas,
  ) {
    final despejado =
        List.generate(filas, (_) => List<bool>.filled(columnas, false));
    final hecho = List<bool>.filled(caminos.length, false);
    final conteo = <Direccion, int>{for (final d in Direccion.cardinales) d: 0};
    final flechas = <_Flecha>[];

    var restantes = caminos.length;
    while (restantes > 0) {
      int? elegido;
      Posicion? cabeza;
      Direccion? direccion;
      var mejorClave = <int>[1 << 30, 1 << 30, 1 << 30, 1 << 30];

      for (var i = 0; i < caminos.length; i++) {
        if (hecho[i]) continue;
        final camino = caminos[i];
        for (final extremo in <Posicion>{camino.first, camino.last}) {
          for (var d = 0; d < Direccion.cardinales.length; d++) {
            final dir = Direccion.cardinales[d];
            if (!_rayoHastaBorde(extremo, dir, filas, columnas, despejado)) {
              continue;
            }
            // Prefer the least-used direction, then a stable order, for a
            // deterministic yet well-mixed assignment.
            final clave = <int>[conteo[dir]!, extremo.fila, extremo.columna, d];
            if (_menor(clave, mejorClave)) {
              mejorClave = clave;
              elegido = i;
              cabeza = extremo;
              direccion = dir;
            }
          }
        }
      }

      // A topmost-headed path can always fire UP; a pick only goes missing if a
      // split left a path whose highest cell is interior — then this cover is
      // not peelable, so bail and let the caller retry with fresh randomness.
      if (elegido == null) return null;
      final indice = elegido;
      final dir = direccion!;
      final camino = caminos[indice];
      final segmentos =
          camino.last == cabeza ? camino : camino.reversed.toList();
      flechas.add(_Flecha(segmentos, dir));
      conteo[dir] = conteo[dir]! + 1;
      for (final p in camino) {
        despejado[p.fila][p.columna] = true;
      }
      hecho[indice] = true;
      restantes--;
    }
    return flechas;
  }

  /// Whether the straight ray from [origen] along [dir] reaches the board edge
  /// crossing only absent cells (which the ray exits through, like the edge) or
  /// already-[despejado] cells (transparent). A still-present arrow cell blocks
  /// it — including the firing arrow's own body, so a head never fires into
  /// itself.
  bool _rayoHastaBorde(
    Posicion origen,
    Direccion dir,
    int filas,
    int columnas,
    List<List<bool>> despejado,
  ) {
    var p = origen.desplazar(dir);
    while (_dentro(p, filas, columnas)) {
      if (_ausentes.contains(p)) return true; // ray exits through the void
      if (!despejado[p.fila][p.columna]) return false; // a live arrow blocks
      p = p.desplazar(dir);
    }
    return true; // reached the board edge
  }

  /// Lexicographic `<` over equal-length int keys.
  bool _menor(List<int> a, List<int> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return a[i] < b[i];
    }
    return false;
  }

  /// Cuts the column-[c] run spanning rows [desde]..[hasta] into vertical arrows
  /// of about [_tamFranja] cells, never leaving a length-1 remainder, and
  /// registers each via [registrar] (ordered top → bottom).
  void _trocearColumna(
    int desde,
    int hasta,
    int c,
    void Function(List<Posicion>) registrar,
  ) {
    var f = desde;
    while (f <= hasta) {
      var fin = f + _tamFranja - 1;
      if (fin > hasta) fin = hasta;
      // Avoid leaving a single trailing cell in the next chunk.
      if (hasta - fin == 1) fin = hasta;
      registrar([
        for (var r = f; r <= fin; r++) Posicion.en(fila: r, columna: c),
      ]);
      f = fin + 1;
    }
  }

  /// Boustrophedon safety net for a small **unshaped** board whose carve
  /// stranded: the whole grid as a single snaking arrow plus a short tail arrow,
  /// giving a solvable, dense, bending, varied-length board. Only used when
  /// there are no absent cells (it would otherwise paint outside the shape).
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

    final n = orden.length;
    if (n < minLongitudFlecha * 2) {
      return [_Flecha(orden.reversed.toList(), Direccion.arriba)];
    }

    // Arrow 2 — last [minLongitudFlecha] cells; its head is the last cell of the
    // snake (always a bottom corner) pointing outward so the detector exits
    // immediately without hitting another CeldaFlecha (which blocks the ray).
    final tail = orden.sublist(n - minLongitudFlecha);
    final dir2 = (filas - 1).isEven ? Direccion.derecha : Direccion.izquierda;

    return [
      _Flecha(
          orden.sublist(0, n - minLongitudFlecha).reversed.toList(),
          Direccion.arriba),
      _Flecha(tail, dir2),
    ];
  }
}
