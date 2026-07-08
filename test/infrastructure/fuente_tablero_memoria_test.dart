import 'package:arrowmaze/domain/entities/celda.dart';
import 'package:arrowmaze/domain/entities/fabrica_celdas_estandar.dart';
import 'package:arrowmaze/domain/entities/trayectoria.dart';
import 'package:arrowmaze/domain/grafo_tablero.dart';
import 'package:arrowmaze/domain/tablero.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:arrowmaze/infrastructure/datasources/fuente_tablero_memoria.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the hand-authored demo board against the two non-negotiable rules of
/// the continuous-path model: **full initial coverage** (zero empty cells at the
/// start) and **solvability** (a greedy sequence of valid moves empties it).
void main() {
  const fuente = FuenteTableroMemoria();
  const fabrica = FabricaCeldasEstandar();

  Tablero construir() => GrafoTablero.desde(
        filas: fuente.filas,
        columnas: fuente.columnas,
        trayectorias:
            fuente.cargarTrayectorias().map(fabrica.crearTrayectoria).toList(),
        celdas: fuente.cargarParedes().map(fabrica.crear).toList(),
      );

  test('should_cover_every_cell_with_a_path_when_at_start', () {
    // Arrange
    final tablero = construir();

    // Act + Assert — no cell is empty before any move (full coverage).
    for (var f = 0; f < tablero.filas; f++) {
      for (var c = 0; c < tablero.columnas; c++) {
        final celda = tablero.celdaEn(Posicion.en(fila: f, columna: c));
        expect(celda, isA<CeldaFlecha>(),
            reason: 'cell ($f,$c) should start covered by an arrow path');
      }
    }
  });

  test('should_be_solvable_when_playing_a_greedy_sequence_of_valid_moves', () {
    // Arrange
    final tablero = construir();
    final pendientes = <Trayectoria>[
      ...fuente.cargarTrayectorias().map(fabrica.crearTrayectoria),
    ];

    // Act — greedily remove any path whose head ray is clear, until stuck.
    var progreso = true;
    while (progreso && pendientes.isNotEmpty) {
      progreso = false;
      for (final trayectoria in [...pendientes]) {
        final rayo =
            tablero.raycast(trayectoria.cabeza, trayectoria.direccionCabeza);
        if (rayo.despejadoHastaBorde) {
          tablero.eliminarTrayectoria(trayectoria.id);
          pendientes.remove(trayectoria);
          progreso = true;
        }
      }
    }

    // Assert — every path was removable and the board is now empty.
    expect(pendientes, isEmpty);
    for (var f = 0; f < tablero.filas; f++) {
      for (var c = 0; c < tablero.columnas; c++) {
        expect(tablero.celdaEn(Posicion.en(fila: f, columna: c)),
            isA<CeldaVacia>());
      }
    }
  });
}
