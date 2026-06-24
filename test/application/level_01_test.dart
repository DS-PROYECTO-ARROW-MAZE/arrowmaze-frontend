import 'dart:convert';
import 'dart:io';

import 'package:arrowmaze/application/generadores/configuracion_generacion.dart';
import 'package:arrowmaze/application/generadores/generacion_por_archivo_nivel.dart';
import 'package:arrowmaze/application/ports/cargador_nivel.dart';
import 'package:arrowmaze/application/ports/definicion_nivel_dto.dart';
import 'package:arrowmaze/domain/entities/celda.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loads `assets/levels/level_01.json` from disk and parses it exactly the way
/// [CargadorNivelArchivo] does (grouping arrow cells by id, in array order), so
/// the real generation pipeline can validate the handcrafted level.
class _CargadorArchivoReal implements CargadorNivel {
  @override
  Future<DefinicionNivelDto> cargar(int id) async {
    final texto =
        await File('assets/levels/level_01.json').readAsString();
    final json = jsonDecode(texto) as Map<String, dynamic>;
    final celdas = (json['cells'] as List<dynamic>).cast<Map<String, dynamic>>();

    final agrupadas = <int, Map<String, dynamic>>{};
    for (final celda in celdas) {
      if (celda['type'] != 'arrow') continue;
      final idFlecha = celda['id'] as int;
      agrupadas.putIfAbsent(
        idFlecha,
        () => <String, dynamic>{
          'id': idFlecha,
          'head': celda['direction'],
          'cells': <Map<String, dynamic>>[],
        },
      );
      (agrupadas[idFlecha]!['cells'] as List<Map<String, dynamic>>)
          .add({'row': celda['row'], 'col': celda['col']});
    }

    return DefinicionNivelDto(
      id: json['id'] as int,
      filas: json['rows'] as int,
      columnas: json['cols'] as int,
      trayectorias: agrupadas.values.toList(),
      celdas: const <Map<String, dynamic>>[],
    );
  }
}

void main() {
  group('level_01.json — handcrafted starter puzzle', () {
    test('should_be_solvable_and_fully_dense_when_loaded', () async {
      // Arrange
      final generador =
          GeneracionPorArchivoNivel(cargador: _CargadorArchivoReal());

      // Act — generarAsync runs the solvability gate; null means unsolvable.
      final tablero = await generador.generarAsync(
        const ConfiguracionGeneracion(filas: 0, columnas: 0),
        idNivel: 1,
      );

      // Assert — solvable.
      expect(tablero, isNotNull);

      // Assert — 100% density: every one of the 5×5 cells is an arrow segment.
      for (var f = 0; f < tablero!.filas; f++) {
        for (var c = 0; c < tablero.columnas; c++) {
          expect(
            tablero.celdaEn(Posicion.en(fila: f, columna: c)),
            isA<CeldaFlecha>(),
            reason: 'cell ($f,$c) is not an arrow segment',
          );
        }
      }
    });
  });
}
