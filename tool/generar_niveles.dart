// ignore_for_file: avoid_print
//
// Authoring tool — generates the 15 bundled puzzle levels into
// `assets/levels/level_XX.json`.
//
// Why a tool and not a hand-authored file: the frontend already owns a proven,
// deterministic, *solvable-by-construction* interlocking maze generator
// ([GeneracionAleatoriaNivel]). Re-using it guarantees every bundled level is a
// real, fully-dense, interlocking puzzle whose arrows genuinely block each other
// — not a static grid. Each level is seeded by its `numero`, so layouts are
// unique per level and reproducible across runs (re-running this tool is
// idempotent).
//
// Difficulty scales progressively by band (matching the backend catalog's
// FACIL/MEDIO/DIFICIL ordinals):
//   • Levels  1–5  → easy   (5×5)
//   • Levels  6–10 → medium (6×6)
//   • Levels 11–15 → hard   (7×7)
//
// Run from the frontend package root:
//   dart run tool/generar_niveles.dart
//
// The generated boards are pure trajectory mazes in the engine's own asset
// format; this tool also round-trips each file back through the level loader and
// re-checks solvability, so a written file is provably loadable and clearable.

import 'dart:convert';
import 'dart:io';

import 'package:arrowmaze/application/generadores/configuracion_generacion.dart';
import 'package:arrowmaze/application/generadores/generacion_aleatoria_nivel.dart';
import 'package:arrowmaze/application/generadores/generador_nivel_base.dart';
import 'package:arrowmaze/domain/entities/celda.dart';
import 'package:arrowmaze/domain/entities/fabrica_celdas_estandar.dart';
import 'package:arrowmaze/domain/entities/trayectoria.dart';
import 'package:arrowmaze/domain/grafo_tablero.dart';
import 'package:arrowmaze/domain/solver.dart';
import 'package:arrowmaze/domain/value_objects/direccion.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';

const _totalNiveles = 15;

/// Stable display names per level (1-indexed), preserved from the prior catalog.
const _nombres = <String>[
  'Interlock', 'Crosswind', 'Deadlock', 'Aperture', 'Zephyr',
  'Tangle', 'Gridlock', 'Overpass', 'Maelstrom', 'Conduit',
  'Spire', 'Labyrinth', 'Citadel', 'Vortex', 'Apex',
];

/// Board edge, difficulty band, and the inclusive trajectory-count window the
/// generated puzzle must fall in, per level ordinal (1-indexed).
///
/// The window is the difficulty knob: more interlocking arrows on a cell means
/// a longer clear-order dependency chain. It also rejects the generator's
/// degenerate 2-trajectory "snake" fallback (which is a near-linear, trivial
/// board). Bands widen and shift up as the board grows, so complexity scales:
///   • easy   (5×5) → 4–5 arrows
///   • medium (6×6) → 5–6 arrows
///   • hard   (7×7) → 6–8 arrows
({int lado, String dificultad, int minTray, int maxTray}) _perfil(int numero) {
  if (numero <= 5) {
    return (lado: 5, dificultad: 'easy', minTray: 4, maxTray: 5);
  }
  if (numero <= 10) {
    return (lado: 6, dificultad: 'medium', minTray: 5, maxTray: 6);
  }
  return (lado: 7, dificultad: 'hard', minTray: 6, maxTray: 8);
}

void main() {
  final salida = Directory('assets/levels');
  if (!salida.existsSync()) salida.createSync(recursive: true);

  for (var numero = 1; numero <= _totalNiveles; numero++) {
    final perfil = _perfil(numero);
    final lado = perfil.lado;

    final trayectorias = _generarTrayectorias(
      numero,
      lado,
      perfil.minTray,
      perfil.maxTray,
    );
    final json = _aJsonNivel(
      numero: numero,
      nombre: _nombres[numero - 1],
      dificultad: perfil.dificultad,
      lado: lado,
      trayectorias: trayectorias,
    );

    // Round-trip guard: parse what we are about to write and re-verify it loads
    // and is solvable, so no broken file is ever emitted.
    _verificarRoundTrip(json, lado);

    final ruta =
        'assets/levels/level_${numero.toString().padLeft(2, '0')}.json';
    File(ruta).writeAsStringSync('${_pretty(json)}\n');
    print(
      'level ${numero.toString().padLeft(2, '0')}  '
      '${perfil.dificultad.padRight(6)}  ${lado}x$lado  '
      'trayectorias=${trayectorias.length}  -> $ruta',
    );
  }

  print('\nDone — $_totalNiveles levels written to assets/levels/.');
}

/// Per-level seed search budget. Disjoint per-level ranges (see [_inicioSemilla])
/// stay well under this, so every level's chosen seed — and thus its layout — is
/// unique.
const _presupuestoBusqueda = 200000;

/// The start of level [numero]'s private seed range. Ranges are spaced a full
/// million apart so the [_presupuestoBusqueda]-wide windows never overlap →
/// distinct seeds → distinct layouts across all 15 levels.
int _inicioSemilla(int numero) => numero * 1000000;

/// Generates the interlocking trajectories for one level via the engine's own
/// reverse-carving generator. Scans level [numero]'s private seed range for the
/// first board whose trajectory count lands in the band window
/// `[minTray, maxTray]`, which rejects the degenerate snake fallback and tunes
/// difficulty. Falls back to the best (most-interlocking) board found if no seed
/// hits the window within the budget.
List<Trayectoria> _generarTrayectorias(
  int numero,
  int lado,
  int minTray,
  int maxTray,
) {
  final inicio = _inicioSemilla(numero);
  List<Trayectoria>? mejor;
  for (var i = 0; i < _presupuestoBusqueda; i++) {
    final generador = GeneracionAleatoriaNivel(semilla: inicio + i);
    final tablero =
        generador.generar(ConfiguracionGeneracion(filas: lado, columnas: lado));
    if (tablero == null) continue;
    final trayectorias = _extraerTrayectorias(tablero as GrafoTablero, lado);
    if (trayectorias.length >= minTray && trayectorias.length <= maxTray) {
      return trayectorias;
    }
    if (mejor == null || trayectorias.length > mejor.length) {
      mejor = trayectorias;
    }
  }
  if (mejor != null && mejor.length >= minTray) return mejor;
  throw StateError(
    'No se pudo generar el nivel $numero (${lado}x$lado) con '
    '$minTray–$maxTray trayectorias.',
  );
}

/// Reads back every trajectory from a populated board, in stable id order.
List<Trayectoria> _extraerTrayectorias(GrafoTablero tablero, int lado) {
  final porId = <int, Trayectoria>{};
  for (var f = 0; f < lado; f++) {
    for (var c = 0; c < lado; c++) {
      final t = tablero.trayectoriaEn(Posicion.en(fila: f, columna: c));
      if (t != null) porId.putIfAbsent(t.id, () => t);
    }
  }
  final lista = porId.values.toList()..sort((a, b) => a.id.compareTo(b.id));
  return lista;
}

/// Serializes a level to the asset JSON the loader (`CargadorNivelArchivo`)
/// understands: arrow cells grouped by trajectory `id`, ordered tail → head,
/// every cell carrying the head's `direction` token.
Map<String, dynamic> _aJsonNivel({
  required int numero,
  required String nombre,
  required String dificultad,
  required int lado,
  required List<Trayectoria> trayectorias,
}) {
  final celdas = <Map<String, dynamic>>[];
  for (final t in trayectorias) {
    final token = _tokenDireccion(t.direccionCabeza);
    for (final seg in t.segmentos) {
      celdas.add({
        'row': seg.fila,
        'col': seg.columna,
        'type': 'arrow',
        'id': t.id,
        'direction': token,
      });
    }
  }

  return {
    'id': numero,
    'name': nombre,
    'difficulty': dificultad,
    'rows': lado,
    'cols': lado,
    // player_start/exit are decorative metadata only — the win condition is an
    // empty board (all trajectories cleared), not reaching a cell. Kept for
    // format parity with the existing assets.
    'player_start': {'row': 0, 'col': 0},
    'exit': {'row': lado - 1, 'col': lado - 1},
    'cells': celdas,
  };
}

/// Re-parses an in-memory level JSON the same way the runtime loader does and
/// asserts it builds a valid, solvable board. Throws on any failure.
void _verificarRoundTrip(Map<String, dynamic> json, int lado) {
  const fabrica = FabricaCeldasEstandar();
  final celdas = (json['cells'] as List<dynamic>).cast<Map<String, dynamic>>();

  final agrupadas = <int, Map<String, dynamic>>{};
  for (final celda in celdas) {
    if (celda['type'] != 'arrow') continue;
    final id = celda['id'] as int;
    agrupadas.putIfAbsent(
      id,
      () => {
        'id': id,
        'head': celda['direction'],
        'cells': <Map<String, dynamic>>[],
      },
    );
    (agrupadas[id]!['cells'] as List<Map<String, dynamic>>)
        .add({'row': celda['row'], 'col': celda['col']});
  }

  final trayectorias =
      agrupadas.values.map(fabrica.crearTrayectoria).toList();
  final tablero = GrafoTablero.desde(
    filas: lado,
    columnas: lado,
    trayectorias: trayectorias,
  );

  for (final t in trayectorias) {
    if (t.segmentos.length < minLongitudFlecha) {
      throw StateError('Trayectoria ${t.id} más corta que el mínimo.');
    }
  }
  // Sanity: the board must be fully dense (no transparent gaps) for a real
  // puzzle — every cell is part of some trajectory. Checked before solving,
  // since the solver mutates the board as it clears it.
  for (var f = 0; f < lado; f++) {
    for (var c = 0; c < lado; c++) {
      final celda = tablero.celdaEn(Posicion.en(fila: f, columna: c));
      if (celda is! CeldaFlecha) {
        throw StateError('Celda vacía en ($f,$c): el tablero no es denso.');
      }
    }
  }
  // Solvability last: esSolvable greedily empties the board in place.
  if (!Solver.esSolvable(tablero)) {
    throw StateError('El nivel generado no es resoluble.');
  }
}

String _tokenDireccion(Direccion d) {
  if (d == Direccion.arriba) return 'UP';
  if (d == Direccion.abajo) return 'DOWN';
  if (d == Direccion.izquierda) return 'LEFT';
  if (d == Direccion.derecha) return 'RIGHT';
  throw ArgumentError.value(d, 'direccion', 'Dirección desconocida');
}

String _pretty(Map<String, dynamic> json) =>
    const JsonEncoder.withIndent('  ').convert(json);
