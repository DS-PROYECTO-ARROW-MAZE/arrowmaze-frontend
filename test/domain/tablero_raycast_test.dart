import 'package:arrowmaze/domain/entities/fabrica_celdas_estandar.dart';
import 'package:arrowmaze/domain/grafo_tablero.dart';
import 'package:arrowmaze/domain/tablero.dart';
import 'package:arrowmaze/domain/value_objects/direccion.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests target the [Tablero] deep-module interface (`raycast`), never the
/// internal node walk. AC3 (transparent `CeldaVacia`) and AC4 (arrow adjacent
/// to the edge) from PRD §3 / §7.2.
void main() {
  /// Builds a [GrafoTablero] from a hand-written cell list (Factory Method).
  GrafoTablero construirTablero(
    int filas,
    int columnas,
    List<Map<String, dynamic>> celdas,
  ) {
    const fabrica = FabricaCeldasEstandar();
    return GrafoTablero.desdeCeldas(
      filas: filas,
      columnas: columnas,
      celdas: celdas.map(fabrica.crear).toList(),
    );
  }

  group('Tablero.raycast', () {
    test('should_return_clear_to_edge_when_path_has_only_vacias', () {
      // Arrange — an arrow at (2,2) pointing up; the column above it is empty.
      final tablero = construirTablero(3, 3, [
        {'row': 2, 'col': 2, 'type': 'arrow', 'direction': 'UP'},
      ]);

      // Act — fire the ray from the arrow's cell towards the top edge.
      final resultado = tablero.raycast(
        const Posicion.en(fila: 2, columna: 2),
        Direccion.arriba,
      );

      // Assert — the ray flew over the transparent empties to the edge.
      expect(resultado.despejadoHastaBorde, isTrue);
      expect(resultado.obstaculo, isNull);
    });

    test('should_report_arrow_adjacent_to_edge_as_clear', () {
      // Arrange — an arrow on the top row already touching the edge.
      final tablero = construirTablero(3, 3, [
        {'row': 0, 'col': 1, 'type': 'arrow', 'direction': 'UP'},
      ]);

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
      final tablero = construirTablero(3, 3, [
        {'row': 1, 'col': 0, 'type': 'arrow', 'direction': 'RIGHT'},
        {'row': 1, 'col': 2, 'type': 'wall'},
      ]);

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
      final tablero = construirTablero(3, 3, [
        {'row': 0, 'col': 0, 'type': 'arrow', 'direction': 'DOWN'},
        {'row': 2, 'col': 0, 'type': 'arrow', 'direction': 'UP'},
      ]);

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
