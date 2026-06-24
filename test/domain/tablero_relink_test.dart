import 'package:arrowmaze/domain/entities/celda.dart';
import 'package:arrowmaze/domain/entities/trayectoria.dart';
import 'package:arrowmaze/domain/grafo_tablero.dart';
import 'package:arrowmaze/domain/value_objects/direccion.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 09 — restoring a removed arrow path re-links its `Nodo`s
/// *incrementally*: the exact mirror of ticket 01's unlink. The restored node
/// regains its identity (no full rebuild) and its neighbours point back through
/// it again instead of across the gap.
void main() {
  test('should_relink_node_incrementally_when_arrow_restored', () {
    // Arrange — a 3x1 column: empty / arrow / empty (the arrow is the middle),
    // exactly the layout of the unlink test it mirrors.
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
    const posMedio = Posicion.en(fila: 1, columna: 0);
    const posAbajo = Posicion.en(fila: 2, columna: 0);

    // Capture node identities and the path BEFORE removal (removal drops the
    // path from the board, so we grab it now).
    final nodoArriba = tablero.nodoEn(posArriba);
    final nodoMedio = tablero.nodoEn(posMedio);
    final nodoAbajo = tablero.nodoEn(posAbajo);
    final trayectoria = tablero.trayectoriaEn(posMedio)!;

    tablero.eliminarTrayectoria(1);

    // Act — restore the removed path.
    tablero.restaurarTrayectoria(trayectoria);

    // Assert — the middle cell is an arrow again and the path is back.
    expect(tablero.celdaEn(posMedio), isA<CeldaFlecha>());
    expect(tablero.trayectoriaEn(posMedio), isNotNull);
    expect(tablero.estaVacio, isFalse);

    // Assert — untouched nodes keep their exact identity (incremental, no rebuild).
    expect(identical(tablero.nodoEn(posMedio), nodoMedio), isTrue);
    expect(identical(tablero.nodoEn(posArriba), nodoArriba), isTrue);
    expect(identical(tablero.nodoEn(posAbajo), nodoAbajo), isTrue);

    // Assert — the restored node is wired to BOTH neighbours again…
    expect(identical(nodoMedio.vecinos[Direccion.arriba], nodoArriba), isTrue);
    expect(identical(nodoMedio.vecinos[Direccion.abajo], nodoAbajo), isTrue);

    // …and the neighbours point back through it, not across the gap.
    expect(identical(nodoArriba.vecinos[Direccion.abajo], nodoMedio), isTrue);
    expect(identical(nodoAbajo.vecinos[Direccion.arriba], nodoMedio), isTrue);
  });

  test('should_relink_across_still_removed_neighbour_when_undone_in_reverse',
      () {
    // Arrange — a 4x1 column with two adjacent single-cell arrows (rows 1 and 2).
    // Removing both, then undoing in reverse order (row 2 first), must re-link
    // row 2 across the still-removed row 1 — exactly mirroring how removal wired
    // the neighbours across the gap.
    final tablero = GrafoTablero.desde(
      filas: 4,
      columnas: 1,
      trayectorias: [
        Trayectoria(
          id: 1,
          direccionCabeza: Direccion.arriba,
          segmentos: const [Posicion.en(fila: 1, columna: 0)],
        ),
        Trayectoria(
          id: 2,
          direccionCabeza: Direccion.arriba,
          segmentos: const [Posicion.en(fila: 2, columna: 0)],
        ),
      ],
    );
    const p0 = Posicion.en(fila: 0, columna: 0);
    const p1 = Posicion.en(fila: 1, columna: 0);
    const p2 = Posicion.en(fila: 2, columna: 0);
    const p3 = Posicion.en(fila: 3, columna: 0);
    final n0 = tablero.nodoEn(p0);
    final n1 = tablero.nodoEn(p1);
    final n2 = tablero.nodoEn(p2);
    final n3 = tablero.nodoEn(p3);
    final arrowA = tablero.trayectoriaEn(p1)!;
    final arrowB = tablero.trayectoriaEn(p2)!;
    tablero.eliminarTrayectoria(1);
    tablero.eliminarTrayectoria(2);

    // Act — undo the most recent removal first (row 2), then row 1.
    tablero.restaurarTrayectoria(arrowB);

    // Assert — row 2 re-linked across the still-removed row 1, to rows 0 and 3.
    expect(identical(n2.vecinos[Direccion.arriba], n0), isTrue);
    expect(identical(n2.vecinos[Direccion.abajo], n3), isTrue);
    expect(n1.vecinos, isEmpty); // row 1 stays removed for now

    // Act — finish undoing (row 1) and the full chain is back.
    tablero.restaurarTrayectoria(arrowA);

    // Assert — every node re-linked to its true neighbour, identities intact.
    expect(identical(n0.vecinos[Direccion.abajo], n1), isTrue);
    expect(identical(n1.vecinos[Direccion.arriba], n0), isTrue);
    expect(identical(n1.vecinos[Direccion.abajo], n2), isTrue);
    expect(identical(n2.vecinos[Direccion.arriba], n1), isTrue);
    expect(identical(n2.vecinos[Direccion.abajo], n3), isTrue);
    expect(identical(n3.vecinos[Direccion.arriba], n2), isTrue);
  });

  test('should_restore_ray_block_when_arrow_restored', () {
    // Arrange — a 3x1 column with the arrow in the middle. With it removed the
    // column is a clear corridor; restoring it must block a ray again, proving
    // the re-link rebuilt the walk (not just the cell label).
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
    final trayectoria =
        tablero.trayectoriaEn(const Posicion.en(fila: 1, columna: 0))!;
    tablero.eliminarTrayectoria(1);
    // Clear corridor: a ray fired upward from the bottom edge reaches the top.
    expect(
      tablero
          .raycast(const Posicion.en(fila: 2, columna: 0), Direccion.arriba)
          .despejadoHastaBorde,
      isTrue,
    );

    // Act
    tablero.restaurarTrayectoria(trayectoria);

    // Assert — the restored arrow blocks the ray once more.
    expect(
      tablero
          .raycast(const Posicion.en(fila: 2, columna: 0), Direccion.arriba)
          .despejadoHastaBorde,
      isFalse,
    );
  });
}
