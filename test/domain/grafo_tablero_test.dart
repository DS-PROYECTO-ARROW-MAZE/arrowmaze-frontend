import 'package:arrowmaze/domain/entities/celda.dart';
import 'package:arrowmaze/domain/entities/trayectoria.dart';
import 'package:arrowmaze/domain/grafo_tablero.dart';
import 'package:arrowmaze/domain/value_objects/direccion.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:flutter_test/flutter_test.dart';

/// AC6 — removing a whole arrow path is *incremental*: each removed segment
/// unlinks its `Nodo` and its neighbours are re-wired to each other; untouched
/// nodes keep their identity (no full rebuild). A multi-cell path leaves a
/// fully transparent corridor behind.
void main() {
  group('absent positions', () {
    test('should_return_CeldaAusente_when_celdaEn_on_absent_position', () {
      final tablero = GrafoTablero.desde(
        filas: 4,
        columnas: 4,
        ausentes: {
          const Posicion.en(fila: 0, columna: 0),
          const Posicion.en(fila: 0, columna: 1),
          const Posicion.en(fila: 1, columna: 0),
        },
      );
      expect(tablero.celdaEn(const Posicion.en(fila: 0, columna: 0)),
          isA<CeldaAusente>());
      expect(tablero.celdaEn(const Posicion.en(fila: 0, columna: 1)),
          isA<CeldaAusente>());
      expect(tablero.celdaEn(const Posicion.en(fila: 1, columna: 0)),
          isA<CeldaAusente>());
    });

    test('should_return_normal_cells_for_non_absent_positions', () {
      final tablero = GrafoTablero.desde(
        filas: 3,
        columnas: 3,
        ausentes: {const Posicion.en(fila: 0, columna: 0)},
      );
      expect(tablero.celdaEn(const Posicion.en(fila: 1, columna: 1)),
          isA<CeldaVacia>());
      expect(tablero.celdaEn(const Posicion.en(fila: 2, columna: 2)),
          isA<CeldaVacia>());
    });

    test('should_not_link_nodes_to_absent_positions', () {
      final tablero = GrafoTablero.desde(
        filas: 3,
        columnas: 2,
        ausentes: {const Posicion.en(fila: 0, columna: 1)},
      );
      // (0,0) should NOT have a right neighbour since (0,1) is absent
      final nodo00 = tablero.nodoEn(const Posicion.en(fila: 0, columna: 0));
      expect(nodo00.vecinos.containsKey(Direccion.derecha), isFalse);
    });
  });
  test('should_clear_every_segment_when_trayectoria_removed', () {
    // Arrange — an L-shaped 2-cell path in a 3x3 board.
    final tablero = GrafoTablero.desde(
      filas: 3,
      columnas: 3,
      trayectorias: [
        Trayectoria(
          id: 7,
          direccionCabeza: Direccion.arriba,
          segmentos: const [
            Posicion.en(fila: 2, columna: 0),
            Posicion.en(fila: 1, columna: 0),
          ],
        ),
      ],
    );

    // Act
    tablero.eliminarTrayectoria(7);

    // Assert — both segments are now transparent empty space.
    expect(tablero.celdaEn(const Posicion.en(fila: 2, columna: 0)),
        isA<CeldaVacia>());
    expect(tablero.celdaEn(const Posicion.en(fila: 1, columna: 0)),
        isA<CeldaVacia>());
    expect(tablero.trayectoriaEn(const Posicion.en(fila: 1, columna: 0)),
        isNull);
  });

  test('should_unlink_nodes_without_full_rebuild_when_arrow_removed', () {
    // Arrange — a 3x1 column: empty / arrow / empty. The arrow is the middle.
    final tablero = GrafoTablero.desde(
      filas: 3,
      columnas: 1,
      trayectorias: [
        Trayectoria(
          id: 1,
          direccionCabeza: Direccion.arriba,
          segmentos: const [Posicion.en(fila: 1, columna: 0)],
        ),
      ],
    );
    const posArriba = Posicion.en(fila: 0, columna: 0);
    const posAbajo = Posicion.en(fila: 2, columna: 0);

    // Capture neighbour identities BEFORE removal.
    final nodoArriba = tablero.nodoEn(posArriba);
    final nodoAbajo = tablero.nodoEn(posAbajo);

    // Act — remove the whole (one-cell) path.
    tablero.eliminarTrayectoria(1);

    // Assert — untouched nodes keep their exact identity (no rebuild).
    expect(identical(tablero.nodoEn(posArriba), nodoArriba), isTrue);
    expect(identical(tablero.nodoEn(posAbajo), nodoAbajo), isTrue);

    // Assert — the two neighbours are now wired directly to each other,
    // skipping the removed node.
    expect(identical(nodoAbajo.vecinos[Direccion.arriba], nodoArriba), isTrue);
    expect(identical(nodoArriba.vecinos[Direccion.abajo], nodoAbajo), isTrue);
  });
}
