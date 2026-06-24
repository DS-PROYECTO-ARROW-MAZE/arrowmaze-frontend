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
      ausentes: _extraerAusentes(json),
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

  /// Extracts absent cells (outside the playable region of a shaped board).
  List<Map<String, dynamic>> _extraerAusentes(Map<String, dynamic> json) {
    final celdas = json['cells'] as List<dynamic>;
    return celdas
        .cast<Map<String, dynamic>>()
        .where((c) => c['type'] == 'absent')
        .map((c) => <String, dynamic>{
              'row': c['row'],
              'col': c['col'],
              'type': c['type'],
            })
        .toList();
  }
}
