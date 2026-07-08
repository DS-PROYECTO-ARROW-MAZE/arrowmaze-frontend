import 'package:arrowmaze/domain/entities/celda.dart';
import 'package:arrowmaze/domain/entities/trayectoria.dart';
import 'package:arrowmaze/domain/grafo_tablero.dart';
import 'package:arrowmaze/domain/tablero.dart';
import 'package:arrowmaze/domain/value_objects/direccion.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests target the [Tablero] deep-module interface (`raycast`), never the
/// internal node walk. AC3 (transparent `CeldaVacia`) and AC4 (arrow adjacent
/// to the edge) from PRD §3 / §7.2. Arrows are single-cell `Trayectoria`s here.
void main() {
  /// A one-cell arrow path at [fila],[columna] pointing in [direccion].
  Trayectoria flecha(int id, int fila, int columna, Direccion direccion) =>
      Trayectoria(
        id: id,
        direccionCabeza: direccion,
        segmentos: [Posicion.en(fila: fila, columna: columna)],
      );

  group('Tablero.raycast', () {
    test('should_return_clear_to_edge_when_path_has_only_vacias', () {
      // Arrange — an arrow at (2,2) pointing up; the column above it is empty.
      final tablero = GrafoTablero.desde(
        filas: 3,
        columnas: 3,
        trayectorias: [flecha(1, 2, 2, Direccion.arriba)],
      );

      // Act — fire the ray from the arrow's cell towards the top edge.
      final resultado = tablero.raycast(
        const Posicion.en(fila: 2, columna: 2),
        Direccion.arriba,
      );

      // Assert — the ray flew over the transparent empties to the edge.
      expect(resultado.despejadoHastaBorde, isTrue);
      expect(resultado.obstaculo, isNull);
    });

    test('should_report_arrow_as_clear_when_adjacent_to_edge', () {
      // Arrange — an arrow on the top row already touching the edge.
      final tablero = GrafoTablero.desde(
        filas: 3,
        columnas: 3,
        trayectorias: [flecha(1, 0, 1, Direccion.arriba)],
      );

      // Act
      final resultado = tablero.raycast(
        const Posicion.en(fila: 0, columna: 1),
        Direccion.arriba,
      );

      // Assert — one step out of bounds means an immediate clear exit.
      expect(resultado.despejadoHastaBorde, isTrue);
    });

    test('should_report_blocked_when_a_wall_stands_in_the_ray', () {
      // Arrange — a wall sits between the arrow and the right edge.
      final tablero = GrafoTablero.desde(
        filas: 3,
        columnas: 3,
        trayectorias: [flecha(1, 1, 0, Direccion.derecha)],
        celdas: const [CeldaPared(Posicion.en(fila: 1, columna: 2))],
      );

      // Act
      final resultado = tablero.raycast(
        const Posicion.en(fila: 1, columna: 0),
        Direccion.derecha,
      );

      // Assert — the wall stops the ray; this is NOT a clear path.
      expect(resultado.despejadoHastaBorde, isFalse);
      expect(resultado.obstaculo, const Posicion.en(fila: 1, columna: 2));
    });

    test('should_report_blocked_when_another_arrow_stands_in_the_ray', () {
      // Arrange — a second arrow sits in the first one's path.
      final tablero = GrafoTablero.desde(
        filas: 3,
        columnas: 3,
        trayectorias: [
          flecha(1, 0, 0, Direccion.abajo),
          flecha(2, 2, 0, Direccion.arriba),
        ],
      );

      // Act
      final resultado = tablero.raycast(
        const Posicion.en(fila: 0, columna: 0),
        Direccion.abajo,
      );

      // Assert — an arrow is opaque, so it stops the ray too.
      expect(resultado.despejadoHastaBorde, isFalse);
      expect(resultado.obstaculo, const Posicion.en(fila: 2, columna: 0));
    });
  });
}
