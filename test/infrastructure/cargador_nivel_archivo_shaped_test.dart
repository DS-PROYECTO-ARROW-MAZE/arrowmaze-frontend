import 'dart:convert';
import 'dart:io';

import 'package:arrowmaze/application/generadores/configuracion_generacion.dart';
import 'package:arrowmaze/application/generadores/generacion_por_archivo_nivel.dart';
import 'package:arrowmaze/application/ports/cargador_nivel.dart';
import 'package:arrowmaze/application/ports/definicion_nivel_dto.dart';
import 'package:arrowmaze/domain/entities/celda.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:arrowmaze/infrastructure/datasources/cargador_nivel_archivo.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 31 (AC4/AC5) — the regenerated shaped, sparse catalog assets load
/// through the runtime path without crashing, as void-shaped solvable boards.
///
/// [CargadorNivelArchivo] reads from the Flutter asset bundle, which is not
/// available in a plain VM test; this loader reads the very same files from disk
/// and reuses the real, static [CargadorNivelArchivo.derivarAusentes] so the
/// production sparse → absent rule is what's under test.
class _CargadorArchivoDisco implements CargadorNivel {
  @override
  Future<DefinicionNivelDto> cargar(int id) async {
    final ruta = 'assets/levels/level_${id.toString().padLeft(2, '0')}.json';
    final json = jsonDecode(await File(ruta).readAsString())
        as Map<String, dynamic>;
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
      ausentes: CargadorNivelArchivo.derivarAusentes(json),
    );
  }
}

void main() {
  group('shaped catalog assets — load & solve', () {
    for (var id = 1; id <= 15; id++) {
      test('should_load_solvable_shaped_board_when_reading_level_$id', () async {
        // Arrange
        final generador =
            GeneracionPorArchivoNivel(cargador: _CargadorArchivoDisco());

        // Act — generarAsync runs the solvability gate; null means unsolvable.
        final tablero = await generador.generarAsync(
          const ConfiguracionGeneracion(filas: 0, columnas: 0),
          idNivel: id,
        );

        // Assert — the shaped board loads and is solvable.
        expect(tablero, isNotNull, reason: 'level $id must load and be solvable');

        // Assert — omitted positions load as void (absent), the rest as arrows;
        // no transparent EmptyCell leaks in from the sparse omission.
        final json = jsonDecode(
          await File('assets/levels/level_${id.toString().padLeft(2, '0')}.json')
              .readAsString(),
        ) as Map<String, dynamic>;
        final ausentes = CargadorNivelArchivo.derivarAusentes(json)
            .map((c) => Posicion.en(fila: c['row'] as int, columna: c['col'] as int))
            .toSet();

        for (var f = 0; f < tablero!.filas; f++) {
          for (var c = 0; c < tablero.columnas; c++) {
            final pos = Posicion.en(fila: f, columna: c);
            final celda = tablero.celdaEn(pos);
            if (ausentes.contains(pos)) {
              expect(celda, isA<CeldaAusente>(),
                  reason: 'level $id ($f,$c) omitted → absent');
            } else {
              expect(celda, isA<CeldaFlecha>(),
                  reason: 'level $id ($f,$c) playable → arrow');
            }
          }
        }
      });
    }
  });
}
