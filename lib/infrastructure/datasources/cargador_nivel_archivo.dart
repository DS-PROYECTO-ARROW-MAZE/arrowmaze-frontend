import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import '../../application/ports/cargador_nivel.dart';
import '../../application/ports/definicion_nivel_dto.dart';

class CargadorNivelArchivo implements CargadorNivel {
  final String _basePath;

  const CargadorNivelArchivo({String basePath = 'assets/levels'})
      : _basePath = basePath;

  @override
  Future<DefinicionNivelDto> cargar(int id) =>
      cargarPorNombre('level_${id.toString().padLeft(2, '0')}');

  /// Loads a level by its bundled asset filename (without extension).
  ///
  /// [cargar] is implemented in terms of this — the numbered `level_NN`
  /// convention is just the usual choice of filename. Exposed directly too,
  /// so a level outside that convention can still be loaded explicitly by
  /// name (Ticket 36).
  Future<DefinicionNivelDto> cargarPorNombre(String nombreArchivo) async {
    final ruta = '$_basePath/$nombreArchivo.json';
    final jsonStr = await rootBundle.loadString(ruta);
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return DefinicionNivelDto(
      id: json['id'] as int,
      filas: json['rows'] as int,
      columnas: json['cols'] as int,
      layers: json['layers'] as int? ?? 1,
      trayectorias: _extraerTrayectorias(json),
      celdas: _extraerCeldasFijas(json),
      ausentes: derivarAusentes(json),
    );
  }

  List<Map<String, dynamic>> _extraerTrayectorias(
    Map<String, dynamic> json,
  ) {
    final celdas = json['cells'] as List<dynamic>;
    final agrupadas = <int, Map<String, dynamic>>{};
    final trayectorias = <Map<String, dynamic>>[];

    for (final celda in celdas.cast<Map<String, dynamic>>()) {
      if (celda['type'] == 'arrow') {
        final id = celda['id'] as int? ?? celda.hashCode;
        if (!agrupadas.containsKey(id)) {
          agrupadas[id] = <String, dynamic>{
            'id': id,
            'head': celda['direction'],
            'cells': <Map<String, dynamic>>[],
          };
        }
        (agrupadas[id]!['cells'] as List<Map<String, dynamic>>).add({
          'row': celda['row'],
          'col': celda['col'],
          'layer': celda['layer'],
        });
      }
    }

    for (final entry in agrupadas.entries) {
      trayectorias.add(entry.value);
    }
    return trayectorias;
  }

  /// Extracts fixed cells (wall, empty, collectible) from the level JSON.
  List<Map<String, dynamic>> _extraerCeldasFijas(Map<String, dynamic> json) {
    final celdas = json['cells'] as List<dynamic>;
    const tiposValidos = {'wall', 'empty', 'collectible'};
    return celdas
        .cast<Map<String, dynamic>>()
        .where((c) => tiposValidos.contains(c['type'] as String?))
        .map((c) => <String, dynamic>{
              'row': c['row'],
              'col': c['col'],
              'layer': c['layer'],
              'type': c['type'],
            })
        .toList();
  }

  /// Extracts absent positions (outside the playable region of a shaped
  /// board), depth-aware.
  ///
  /// Shaped boards are stored **sparse**: a position outside the shape is simply
  /// omitted from `cells` (no filler, no `type: "absent"` marker — Ticket 31,
  /// FE-16/FE-26). Any `(row, col, layer)` triple with no present cell is
  /// therefore absent — a void the renderer draws as nothing and the ray treats
  /// like the board edge (distinct from a transparent `CeldaVacia`). An
  /// explicit `type: "absent"` marker is still honoured for backward
  /// compatibility. `layers` defaults to `1`, so a 2D level (or one omitting
  /// `layer` on every cell) derives absent positions exactly as before — one
  /// flattened index formula, no branching on dimension. Fully-dense
  /// rectangular boards yield no absent positions, so this is a no-op for them.
  ///
  /// Pure and static so the sparse → absent rule can be unit-tested offline
  /// without the Flutter asset bundle.
  static List<Map<String, dynamic>> derivarAusentes(Map<String, dynamic> json) {
    final filas = json['rows'] as int;
    final columnas = json['cols'] as int;
    final capas = json['layers'] as int? ?? 1;
    final celdas = (json['cells'] as List<dynamic>).cast<Map<String, dynamic>>();

    int indice(int fila, int columna, int capa) =>
        (capa * filas + fila) * columnas + columna;

    final presentes = <int>{};
    for (final celda in celdas) {
      if (celda['type'] == 'absent') continue;
      presentes.add(indice(
        celda['row'] as int,
        celda['col'] as int,
        celda['layer'] as int? ?? 0,
      ));
    }

    final ausentes = <Map<String, dynamic>>[];
    for (var p = 0; p < capas; p++) {
      for (var f = 0; f < filas; f++) {
        for (var c = 0; c < columnas; c++) {
          if (!presentes.contains(indice(f, c, p))) {
            ausentes.add(<String, dynamic>{
              'row': f,
              'col': c,
              'layer': p,
              'type': 'absent',
            });
          }
        }
      }
    }
    return ausentes;
  }
}
