import 'package:arrowmaze/domain/entities/celda.dart';
import 'package:arrowmaze/domain/entities/trayectoria.dart';
import 'package:arrowmaze/domain/grafo_tablero.dart';
import 'package:arrowmaze/domain/value_objects/direccion.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:flutter_test/flutter_test.dart';

/// AC1 (PRD §3 A4 / §7.2): a `Coleccionable` is **transparent** to the ray —
/// queried through the [Tablero] deep module (`raycast`), never the node walk.
/// The ray reports the collectibles it flew over so the move can later grant the
/// bonus, but they never stop it.
void main() {
  group('Tablero.raycast con Coleccionable', () {
    test('should_not_block_ray_when_path_crosses_collectible', () {
      // Arrange — an arrow at (2,1) pointing up with a collectible at (1,1)
      // sitting directly on its exit ray; the rest of the column is empty.
      final tablero = GrafoTablero.desde(
        filas: 3,
        columnas: 3,
        trayectorias: [
          Trayectoria(
            id: 1,
            direccionCabeza: Direccion.arriba,
            segmentos: const [Posicion.en(fila: 2, columna: 1)],
          ),
        ],
        celdas: const [Coleccionable(Posicion.en(fila: 1, columna: 1))],
      );

      // Act — fire the ray from the arrow's head toward the top edge.
      final resultado = tablero.raycast(
        const Posicion.en(fila: 2, columna: 1),
        Direccion.arriba,
      );

      // Assert — the collectible did not stop the ray (it reached the edge)…
      expect(resultado.despejadoHastaBorde, isTrue);
      expect(resultado.obstaculo, isNull);
      // …and the ray reports the collectible it crossed for later collection.
      expect(
        resultado.coleccionables,
        contains(const Posicion.en(fila: 1, columna: 1)),
      );
    });

    test('should_not_collect_when_a_wall_blocks_the_ray_after_a_collectible',
        () {
      // Arrange — the ray crosses a collectible at (1,1) but a wall at (0,1)
      // stops it short of the edge, so the move is invalid.
      final tablero = GrafoTablero.desde(
        filas: 3,
        columnas: 3,
        trayectorias: [
          Trayectoria(
            id: 1,
            direccionCabeza: Direccion.arriba,
            segmentos: const [Posicion.en(fila: 2, columna: 1)],
          ),
        ],
        celdas: const [
          Coleccionable(Posicion.en(fila: 1, columna: 1)),
          CeldaPared(Posicion.en(fila: 0, columna: 1)),
        ],
      );

      // Act
      final resultado = tablero.raycast(
        const Posicion.en(fila: 2, columna: 1),
        Direccion.arriba,
      );

      // Assert — a blocked ray is not a valid move, so nothing is collected.
      expect(resultado.despejadoHastaBorde, isFalse);
      expect(resultado.coleccionables, isEmpty);
    });
  });
}
