// Offline authoring script for the three 3D QA fixtures (cube/pyramid/prism).
//
// A 3D generalization of GeneracionAleatoriaNivel's reverse-carving algorithm
// (lib/application/generadores/generacion_aleatoria_nivel.dart): it grows the
// board **backward** from empty, one arrow at a time, so the reverse of the
// carve order is guaranteed to be a valid clear sequence (real interlocking,
// verified against the actual Solver before anything is written).
//
// Run with: dart run tool/generar_niveles_3d.dart

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:arrowmaze/application/generadores/generador_nivel_base.dart'
    show minLongitudFlecha;
import 'package:arrowmaze/domain/entities/trayectoria.dart';
import 'package:arrowmaze/domain/grafo_tablero.dart';
import 'package:arrowmaze/domain/solver.dart';
import 'package:arrowmaze/domain/value_objects/direccion.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';

class _Flecha {
  _Flecha(this.segmentos, this.direccion);
  final List<Posicion> segmentos;
  final Direccion direccion;
}

class _Cabeza {
  _Cabeza(this.pos, this.direccion, this.rayo);
  final Posicion pos;
  final Direccion direccion;
  final List<Posicion> rayo;
}

/// One reverse-carve attempt over a `filas x columnas x profundo` box minus
/// [ausentes], targeting exactly [objetivoFlechas] arrows. Returns `null` if
/// this attempt stranded cells or didn't land on the target count.
List<_Flecha>? _carvar3D({
  required int filas,
  required int columnas,
  required int profundo,
  required Set<Posicion> ausentes,
  required double targetAvgLen,
  required Random rng,
}) {
  final ocupado = <Posicion, bool>{for (final p in ausentes) p: true};
  var restantes = filas * columnas * profundo - ausentes.length;
  final flechas = <_Flecha>[];

  bool dentro(Posicion p) =>
      p.fila >= 0 &&
      p.fila < filas &&
      p.columna >= 0 &&
      p.columna < columnas &&
      p.capa >= 0 &&
      p.capa < profundo;

  List<Posicion>? rayoLibre(Posicion origen, Direccion dir) {
    final rayo = <Posicion>[];
    var p = origen.desplazar(dir);
    while (dentro(p)) {
      if (ocupado[p] == true) return null;
      rayo.add(p);
      p = p.desplazar(dir);
    }
    return rayo;
  }

  _Cabeza? elegirCabeza() {
    final candidatos = <_Cabeza>[];
    final pesos = <int>[];
    var total = 0;
    for (var f = 0; f < filas; f++) {
      for (var c = 0; c < columnas; c++) {
        for (var p = 0; p < profundo; p++) {
          final pos = Posicion.en(fila: f, columna: c, capa: p);
          if (ocupado[pos] == true) continue;
          for (final dir in Direccion.todas) {
            final rayo = rayoLibre(pos, dir);
            if (rayo == null) continue;
            final peso = rayo.length + 1;
            candidatos.add(_Cabeza(pos, dir, rayo));
            pesos.add(peso);
            total += peso;
          }
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

  List<Posicion> vecinosLibres(Posicion p, Set<Posicion> reservado) {
    final libres = <Posicion>[];
    for (final dir in Direccion.todas) {
      final n = p.desplazar(dir);
      if (!dentro(n)) continue;
      if (ocupado[n] == true) continue;
      if (reservado.contains(n)) continue;
      libres.add(n);
    }
    return libres;
  }

  int gradoLibre(Posicion p) {
    var grado = 0;
    for (final dir in Direccion.todas) {
      final q = p.desplazar(dir);
      if (dentro(q) && ocupado[q] != true) grado++;
    }
    return grado;
  }

  // Every cell that was ever part of an *earlier* arrow's exit ray — stepping
  // a later arrow's body into one of these is exactly what blocks that
  // earlier arrow in the final board (the "interlocking" the reverse-carve
  // makes possible but doesn't guarantee on its own). Biasing growth toward
  // them turns "might interlock" into "reliably does".
  final raysHistoricas = <Posicion>{};

  Posicion elegirVecino(List<Posicion> vecinos) {
    // Strongly prefer a neighbour that crosses an earlier arrow's ray, when
    // one is available, so later arrows routinely block earlier ones.
    final bloqueantes =
        vecinos.where((v) => raysHistoricas.contains(v)).toList();
    final pool = (bloqueantes.isNotEmpty && rng.nextDouble() < 0.85)
        ? bloqueantes
        : vecinos;

    if (rng.nextDouble() < 0.25) return pool[rng.nextInt(pool.length)];
    var mejor = <Posicion>[];
    var menorGrado = 1 << 30;
    for (final v in pool) {
      final grado = gradoLibre(v);
      if (grado < menorGrado) {
        menorGrado = grado;
        mejor = [v];
      } else if (grado == menorGrado) {
        mejor.add(v);
      }
    }
    return mejor[rng.nextInt(mejor.length)];
  }

  while (restantes > 0) {
    final cabeza = elegirCabeza();
    if (cabeza == null) return null;
    final reservado = cabeza.rayo.toSet();
    final cuerpo = <Posicion>[cabeza.pos];
    ocupado[cabeza.pos] = true;
    restantes--;

    final objetivo = max(
        minLongitudFlecha, (targetAvgLen + rng.nextInt(3) - 1).round());

    var actual = cabeza.pos;
    while (cuerpo.length < objetivo) {
      final vecinos = vecinosLibres(actual, reservado);
      if (vecinos.isEmpty) break;
      final siguiente = elegirVecino(vecinos);
      cuerpo.add(siguiente);
      ocupado[siguiente] = true;
      restantes--;
      actual = siguiente;
    }
    if (cuerpo.length < minLongitudFlecha) return null;

    raysHistoricas.addAll(reservado);
    flechas.add(_Flecha(cuerpo.reversed.toList(), cabeza.direccion));
  }

  return flechas;
}

/// Tries to make [flechas] genuinely interlocking: for each arrow, in turn,
/// tests whether re-pointing its head at a direction **blocked by another
/// arrow's segment** (instead of the direction the carve originally verified
/// clear) still leaves the whole board solvable — verified against the real
/// [Solver], not assumed. Commits every redirect that stays solvable, so the
/// final board typically ends up with several genuine dependencies instead of
/// relying on the carve to produce one by chance. Returns the (possibly
/// modified) list; the caller re-checks solvability/blocking afterward.
List<_Flecha> _forzarBloqueo(
  List<_Flecha> flechas,
  int filas,
  int columnas,
  int profundo,
  Set<Posicion> ausentes,
) {
  bool dentro(Posicion p) =>
      p.fila >= 0 &&
      p.fila < filas &&
      p.columna >= 0 &&
      p.columna < columnas &&
      p.capa >= 0 &&
      p.capa < profundo;

  final resultado = [...flechas];

  bool solvableConDirecciones(List<Direccion> direcciones) {
    final trayectorias = [
      for (var i = 0; i < resultado.length; i++)
        Trayectoria(
          id: i + 1,
          direccionCabeza: direcciones[i],
          segmentos: resultado[i].segmentos,
        ),
    ];
    final tablero = GrafoTablero.desde(
      filas: filas,
      columnas: columnas,
      profundo: profundo,
      trayectorias: trayectorias,
      ausentes: ausentes,
    );
    return Solver.esSolvable(tablero);
  }

  for (var i = 0; i < resultado.length; i++) {
    final ocupante = <Posicion, int>{};
    for (var k = 0; k < resultado.length; k++) {
      for (final s in resultado[k].segmentos) {
        ocupante[s] = k;
      }
    }
    final cabeza = resultado[i].segmentos.last;
    for (final dir in Direccion.todas) {
      if (dir == resultado[i].direccion) continue;
      final siguiente = cabeza.desplazar(dir);
      if (!dentro(siguiente)) continue;
      final quienOcupa = ocupante[siguiente];
      if (quienOcupa == null || quienOcupa == i) continue; // not a real block

      final direccionesPrueba = [for (final f in resultado) f.direccion];
      direccionesPrueba[i] = dir;
      if (!solvableConDirecciones(direccionesPrueba)) continue;

      resultado[i] = _Flecha(resultado[i].segmentos, dir);
      break; // this arrow is now genuinely blocked; move to the next one.
    }
  }
  return resultado;
}

String _tokenDireccion(Direccion d) {
  if (d == Direccion.arriba) return 'UP';
  if (d == Direccion.abajo) return 'DOWN';
  if (d == Direccion.izquierda) return 'LEFT';
  if (d == Direccion.derecha) return 'RIGHT';
  if (d == Direccion.adelante) return 'FORWARD';
  if (d == Direccion.atras) return 'BACKWARD';
  throw ArgumentError.value(d, 'direccion', 'Dirección desconocida');
}

/// Builds and verifies one fixture, retrying with fresh seeds until an
/// interlocking, fully-dense, exactly-[objetivoFlechas] carve is found.
Map<String, dynamic> _generarFixture({
  required int id,
  required String nombre,
  required int filas,
  required int columnas,
  required int profundo,
  required Set<Posicion> ausentes,
  required int objetivoFlechas,
  required int semillaBase,
  int presupuesto = 20000,
}) {
  final totalCeldas = filas * columnas * profundo - ausentes.length;
  final targetAvgLen = totalCeldas / objetivoFlechas;

  var cNull = 0, cCount = 0, cDensa = 0, cSolv = 0, cBloq = 0;
  for (var i = 0; i < presupuesto; i++) {
    final rng = Random(semillaBase + i);
    final flechas = _carvar3D(
      filas: filas,
      columnas: columnas,
      profundo: profundo,
      ausentes: ausentes,
      targetAvgLen: targetAvgLen,
      rng: rng,
    );
    if (flechas == null) {
      cNull++;
      continue;
    }
    if (flechas.length != objetivoFlechas) {
      cCount++;
      continue;
    }

    final flechasForzadas =
        _forzarBloqueo(flechas, filas, columnas, profundo, ausentes);

    var idFlecha = 1;
    final celdas = <Map<String, dynamic>>[];
    for (final f in flechasForzadas) {
      final token = _tokenDireccion(f.direccion);
      for (final seg in f.segmentos) {
        celdas.add({
          'row': seg.fila,
          'col': seg.columna,
          'layer': seg.capa,
          'type': 'arrow',
          'id': idFlecha,
          'direction': token,
        });
      }
      idFlecha++;
    }
    final json = {
      'id': id,
      'name': nombre,
      // Untimed by construction: the 3D cube interaction (drag-to-orbit,
      // tap-any-visible-segment) is novel enough that these levels stay
      // pressure-free regardless of arrow count. The catalog card shows "3D"
      // instead of a difficulty label anyway (SeleccionNivelesView, es3D).
      'difficulty': 'easy',
      'rows': filas,
      'cols': columnas,
      'layers': profundo,
      'cells': celdas,
    };

    // Round-trip verify against the real domain: build the trajectories from
    // this JSON exactly as the loader would, and confirm the greedy Solver
    // actually empties it (interlocking, not just claimed-solvable).
    final trayectorias = <Trayectoria>[];
    final porId = <int, List<Map<String, dynamic>>>{};
    for (final c in celdas) {
      porId.putIfAbsent(c['id'] as int, () => []).add(c);
    }
    for (final entry in porId.entries) {
      final cs = entry.value;
      trayectorias.add(Trayectoria(
        id: entry.key,
        direccionCabeza: flechasForzadas[entry.key - 1].direccion,
        segmentos: [
          for (final c in cs)
            Posicion.en(
                fila: c['row'] as int,
                columna: c['col'] as int,
                capa: c['layer'] as int),
        ],
      ));
    }
    final tablero = GrafoTablero.desde(
      filas: filas,
      columnas: columnas,
      profundo: profundo,
      trayectorias: trayectorias,
      ausentes: ausentes,
    );
    // Structural check: every present, non-absent cell must be part of an
    // arrow (full density — no gaps).
    var densa = true;
    for (var f = 0; f < filas && densa; f++) {
      for (var c = 0; c < columnas && densa; c++) {
        for (var p = 0; p < profundo; p++) {
          final pos = Posicion.en(fila: f, columna: c, capa: p);
          if (ausentes.contains(pos)) continue;
          if (tablero.trayectoriaEn(pos) == null) {
            densa = false;
            break;
          }
        }
      }
    }
    if (!densa) {
      cDensa++;
      continue;
    }

    // Extra: require *real* interlocking — a specific release sequence, not
    // just one arrow blocked. Checked BEFORE Solver.esSolvable, which mutates
    // (empties) its board as it verifies — checking after would always see a
    // bare board.
    var bloqueados = 0;
    for (final t in trayectorias) {
      final rayo = tablero.raycast(t.cabeza, t.direccionCabeza);
      if (!rayo.despejadoHastaBorde) bloqueados++;
    }
    if (bloqueados < 2) {
      cBloq++;
      continue;
    }

    if (!Solver.esSolvable(tablero)) {
      cSolv++;
      continue;
    }

    stderr.writeln('$nombre: found at seed ${semillaBase + i} '
        '(${flechas.length} arrows, attempt ${i + 1})');
    return json;
  }
  stderr.writeln('$nombre stage failures over $presupuesto attempts: '
      'null=$cNull count=$cCount densa=$cDensa solv=$cSolv bloq=$cBloq');
  throw StateError('No se pudo generar $nombre con $objetivoFlechas flechas.');
}

void main() {
  final basePath = 'assets/levels';

  // Cube: 3x3x3, fully dense, 7 arrows. Catalog level 16.
  final cubo = _generarFixture(
    id: 16,
    nombre: 'Level 16',
    filas: 3,
    columnas: 3,
    profundo: 3,
    ausentes: const {},
    objetivoFlechas: 7,
    semillaBase: 1000000,
  );
  File('$basePath/level_16.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(cubo));

  // Pyramid: 5x5 base, 3x3 middle, 1x1 apex — a stepped square pyramid, fully
  // dense within its silhouette, 10 arrows. Catalog level 17.
  final piramideAusentes = <Posicion>{};
  for (var f = 0; f < 5; f++) {
    for (var c = 0; c < 5; c++) {
      if (f < 1 || f > 3 || c < 1 || c > 3) {
        piramideAusentes.add(Posicion.en(fila: f, columna: c, capa: 1));
      }
      if (!(f == 2 && c == 2)) {
        piramideAusentes.add(Posicion.en(fila: f, columna: c, capa: 2));
      }
    }
  }
  final piramide = _generarFixture(
    id: 17,
    nombre: 'Level 17',
    filas: 5,
    columnas: 5,
    profundo: 3,
    ausentes: piramideAusentes,
    objetivoFlechas: 10,
    semillaBase: 2000000,
  );
  File('$basePath/level_17.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(piramide));

  // Rectangular prism: 5x3x2, fully dense, 12 arrows. Catalog level 18.
  final prisma = _generarFixture(
    id: 18,
    nombre: 'Level 18',
    filas: 5,
    columnas: 3,
    profundo: 2,
    ausentes: const {},
    objetivoFlechas: 12,
    semillaBase: 3000000,
  );
  File('$basePath/level_18.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(prisma));

  stderr.writeln('Done.');
}
