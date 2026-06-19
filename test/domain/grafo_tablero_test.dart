import 'package:arrowmaze/domain/entities/celda.dart';
import 'package:arrowmaze/domain/entities/fabrica_celdas_estandar.dart';
import 'package:arrowmaze/domain/grafo_tablero.dart';
import 'package:arrowmaze/domain/value_objects/direccion.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:flutter_test/flutter_test.dart';

/// AC6 — removal is *incremental*: the removed arrow unlinks its `Nodo` and its
/// neighbours are re-wired to each other; the rest of the graph is untouched
/// (same `Nodo` instances), so there is no full rebuild.
void main() {
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

  test('should_unlink_node_without_full_rebuild_when_arrow_removed', () {
    // Arrange — a 3x1 column: empty / arrow / empty. The arrow is the middle.
    final tablero = construirTablero(3, 1, [
      {'row': 1, 'col': 0, 'type': 'arrow', 'direction': 'UP'},
    ]);
    const posArriba = Posicion.en(fila: 0, columna: 0);
    const posFlecha = Posicion.en(fila: 1, columna: 0);
    const posAbajo = Posicion.en(fila: 2, columna: 0);

    // Capture neighbour identities BEFORE removal.
    final nodoArriba = tablero.nodoEn(posArriba);
    final nodoAbajo = tablero.nodoEn(posAbajo);

    // Act — remove the arrow (turns its cell empty + unlinks its node).
    tablero.eliminarFlecha(posFlecha);

    // Assert — the cell is now transparent empty space.
    expect(tablero.celdaEn(posFlecha), isA<CeldaVacia>());

    // Assert — untouched nodes keep their exact identity (no rebuild).
    expect(identical(tablero.nodoEn(posArriba), nodoArriba), isTrue);
    expect(identical(tablero.nodoEn(posAbajo), nodoAbajo), isTrue);

    // Assert — the two neighbours are now wired directly to each other,
    // skipping the removed node.
    expect(identical(nodoAbajo.vecinos[Direccion.arriba], nodoArriba), isTrue);
    expect(identical(nodoArriba.vecinos[Direccion.abajo], nodoAbajo), isTrue);
  });
}
