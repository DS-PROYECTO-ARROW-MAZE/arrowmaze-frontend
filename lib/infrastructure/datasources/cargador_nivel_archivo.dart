import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import '../../application/ports/cargador_nivel.dart';
import '../../application/ports/definicion_nivel_dto.dart';

class CargadorNivelArchivo implements CargadorNivel {
  final String _basePath;

  const CargadorNivelArchivo({String basePath = 'assets/levels'})
      : _basePath = basePath;

  @override
  Future<DefinicionNivelDto> cargar(int id) async {
    final ruta = '$_basePath/level_${id.toString().padLeft(2, '0')}.json';
    final jsonStr = await rootBundle.loadString(ruta);
    final json = jsonDecode(jsonStr) as Map<String, dynamic>;
    return DefinicionNivelDto(
      id: json['id'] as int,
      filas: json['rows'] as int,
      columnas: json['cols'] as int,
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
              'type': c['type'],
            })
        .toList();
  }

  /// Extracts absent positions (outside the playable region of a shaped board).
  ///
  /// Shaped boards are stored **sparse**: a position outside the shape is simply
  /// omitted from `cells` (no filler, no `type: "absent"` marker — Ticket 31,
  /// FE-16/FE-26). Any grid position with no present cell is therefore absent —
  /// a void the renderer draws as nothing and the ray treats like the board edge
  /// (distinct from a transparent `CeldaVacia`). An explicit `type: "absent"`
  /// marker is still honoured for backward compatibility. Fully-dense
  /// rectangular boards yield no absent positions, so this is a no-op for them.
  ///
  /// Pure and static so the sparse → absent rule can be unit-tested offline
  /// without the Flutter asset bundle.
  static List<Map<String, dynamic>> derivarAusentes(Map<String, dynamic> json) {
    final filas = json['rows'] as int;
    final columnas = json['cols'] as int;
    final celdas = (json['cells'] as List<dynamic>).cast<Map<String, dynamic>>();

    final presentes = <int>{};
    for (final celda in celdas) {
      if (celda['type'] == 'absent') continue;
      presentes.add((celda['row'] as int) * columnas + (celda['col'] as int));
    }

    final ausentes = <Map<String, dynamic>>[];
    for (var f = 0; f < filas; f++) {
      for (var c = 0; c < columnas; c++) {
        if (!presentes.contains(f * columnas + c)) {
          ausentes.add(<String, dynamic>{'row': f, 'col': c, 'type': 'absent'});
        }
      }
    }
    return ausentes;
  }
}
