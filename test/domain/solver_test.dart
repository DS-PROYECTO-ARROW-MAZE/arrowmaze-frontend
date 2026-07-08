import 'package:arrowmaze/domain/entities/celda.dart';
import 'package:arrowmaze/domain/entities/trayectoria.dart';
import 'package:arrowmaze/domain/grafo_tablero.dart';
import 'package:arrowmaze/domain/solver.dart';
import 'package:arrowmaze/domain/tablero.dart';
import 'package:arrowmaze/domain/value_objects/direccion.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:flutter_test/flutter_test.dart';

Trayectoria flecha(int id, int fila, int columna, Direccion direccion) =>
    Trayectoria(
      id: id,
      direccionCabeza: direccion,
      segmentos: [Posicion.en(fila: fila, columna: columna)],
    );

/// Golden solvable board: every arrow's head ray is clear to its edge.
/// Mirrors the fully-covered 5×5 demo board from FuenteTableroMemoria.
Tablero tableroSolvable() {
  return GrafoTablero.desde(
    filas: 5,
    columnas: 5,
    trayectorias: [
      Trayectoria(
        id: 1,
        direccionCabeza: Direccion.arriba,
        segmentos: const [
          Posicion.en(fila: 4, columna: 2),
          Posicion.en(fila: 3, columna: 2),
          Posicion.en(fila: 2, columna: 2),
          Posicion.en(fila: 1, columna: 2),
          Posicion.en(fila: 0, columna: 2),
        ],
      ),
      Trayectoria(
        id: 2,
        direccionCabeza: Direccion.arriba,
        segmentos: const [
          Posicion.en(fila: 4, columna: 3),
          Posicion.en(fila: 3, columna: 3),
          Posicion.en(fila: 2, columna: 3),
          Posicion.en(fila: 1, columna: 3),
          Posicion.en(fila: 0, columna: 3),
        ],
      ),
      Trayectoria(
        id: 3,
        direccionCabeza: Direccion.arriba,
        segmentos: const [
          Posicion.en(fila: 4, columna: 4),
          Posicion.en(fila: 3, columna: 4),
          Posicion.en(fila: 2, columna: 4),
          Posicion.en(fila: 1, columna: 4),
          Posicion.en(fila: 0, columna: 4),
        ],
      ),
      Trayectoria(
        id: 4,
        direccionCabeza: Direccion.izquierda,
        segmentos: const [
          Posicion.en(fila: 1, columna: 1),
          Posicion.en(fila: 0, columna: 1),
          Posicion.en(fila: 0, columna: 0),
        ],
      ),
      Trayectoria(
        id: 5,
        direccionCabeza: Direccion.izquierda,
        segmentos: const [
          Posicion.en(fila: 4, columna: 1),
          Posicion.en(fila: 4, columna: 0),
          Posicion.en(fila: 3, columna: 0),
          Posicion.en(fila: 3, columna: 1),
          Posicion.en(fila: 2, columna: 1),
          Posicion.en(fila: 2, columna: 0),
          Posicion.en(fila: 1, columna: 0),
        ],
      ),
    ],
  );
}

/// Golden unsolvable board: two arrows point at each other, blocking each
/// other's exit — neither can ever leave.
Tablero tableroInsolvable() {
  return GrafoTablero.desde(
    filas: 3,
    columnas: 3,
    trayectorias: [
      flecha(1, 1, 0, Direccion.derecha),
      flecha(2, 1, 2, Direccion.izquierda),
    ],
    celdas: const [
      CeldaPared(Posicion.en(fila: 0, columna: 1)),
      CeldaPared(Posicion.en(fila: 2, columna: 1)),
    ],
  );
}

/// A 4×2 shaped golden board (solvable): the right column (col 1) is absent,
/// so arrows in the left column can only exit left or up/down.
/// A 3×3 shaped golden board (solvable): the border is absent, leaving only the
/// centre cell (1,1) and the top-left corner (0,0) playable. An arrow at (0,0)
/// pointing LEFT exits clear (no neighbour → board edge). All arrows are length
/// ≥ 2 to satisfy the structural invariant.
Tablero tableroShapedSolvable() {
  return GrafoTablero.desde(
    filas: 3,
    columnas: 2,
    ausentes: {
      const Posicion.en(fila: 0, columna: 1),
      const Posicion.en(fila: 1, columna: 1),
      const Posicion.en(fila: 2, columna: 1),
    },
    trayectorias: [
      Trayectoria(
        id: 1,
        direccionCabeza: Direccion.izquierda,
        segmentos: const [
          Posicion.en(fila: 0, columna: 0),
        ],
      ),
    ],
  );
}

/// A 3×2 shaped golden board (unsolvable): the right column is absent, a wall
/// at (0,0) blocks the arrow below it pointing UP — the ray cannot exit.
Tablero tableroShapedInsolvable() {
  return GrafoTablero.desde(
    filas: 3,
    columnas: 2,
    ausentes: {
      const Posicion.en(fila: 0, columna: 1),
      const Posicion.en(fila: 1, columna: 1),
      const Posicion.en(fila: 2, columna: 1),
    },
    celdas: const [
      CeldaPared(Posicion.en(fila: 0, columna: 0)),
    ],
    trayectorias: [
      Trayectoria(
        id: 1,
        direccionCabeza: Direccion.arriba,
        segmentos: const [
          Posicion.en(fila: 1, columna: 0),
        ],
      ),
    ],
  );
}

void main() {
  group('Solver.esSolvable', () {
    test('should_return_true_when_board_is_known_solvable_golden', () {
      final tablero = tableroSolvable();
      final resultado = Solver.esSolvable(tablero);
      expect(resultado, isTrue);
    });

    test('should_return_false_when_board_is_known_unsolvable_golden', () {
      final tablero = tableroInsolvable();
      final resultado = Solver.esSolvable(tablero);
      expect(resultado, isFalse);
    });

    test('should_return_same_verdict_when_removal_orders_shuffled', () {
      final resultados = <bool>[];
      for (var i = 0; i < 10; i++) {
        final copia = GrafoTablero.desde(
          filas: 5,
          columnas: 5,
          trayectorias: [
            Trayectoria(
              id: 1,
              direccionCabeza: Direccion.arriba,
              segmentos: const [
                Posicion.en(fila: 4, columna: 2),
                Posicion.en(fila: 3, columna: 2),
                Posicion.en(fila: 2, columna: 2),
                Posicion.en(fila: 1, columna: 2),
                Posicion.en(fila: 0, columna: 2),
              ],
            ),
            Trayectoria(
              id: 2,
              direccionCabeza: Direccion.arriba,
              segmentos: const [
                Posicion.en(fila: 4, columna: 3),
                Posicion.en(fila: 3, columna: 3),
                Posicion.en(fila: 2, columna: 3),
                Posicion.en(fila: 1, columna: 3),
                Posicion.en(fila: 0, columna: 3),
              ],
            ),
            Trayectoria(
              id: 3,
              direccionCabeza: Direccion.arriba,
              segmentos: const [
                Posicion.en(fila: 4, columna: 4),
                Posicion.en(fila: 3, columna: 4),
                Posicion.en(fila: 2, columna: 4),
                Posicion.en(fila: 1, columna: 4),
                Posicion.en(fila: 0, columna: 4),
              ],
            ),
            Trayectoria(
              id: 4,
              direccionCabeza: Direccion.izquierda,
              segmentos: const [
                Posicion.en(fila: 1, columna: 1),
                Posicion.en(fila: 0, columna: 1),
                Posicion.en(fila: 0, columna: 0),
              ],
            ),
            Trayectoria(
              id: 5,
              direccionCabeza: Direccion.izquierda,
              segmentos: const [
                Posicion.en(fila: 4, columna: 1),
                Posicion.en(fila: 4, columna: 0),
                Posicion.en(fila: 3, columna: 0),
                Posicion.en(fila: 3, columna: 1),
                Posicion.en(fila: 2, columna: 1),
                Posicion.en(fila: 2, columna: 0),
                Posicion.en(fila: 1, columna: 0),
              ],
            ),
          ],
        );
        resultados.add(Solver.esSolvable(copia));
      }
      expect(resultados.every((r) => r == resultados.first), isTrue);
      expect(resultados.first, isTrue);
    });

    test('should_return_true_when_board_is_empty', () {
      final tablero = GrafoTablero.desde(filas: 3, columnas: 3);
      final resultado = Solver.esSolvable(tablero);
      expect(resultado, isTrue);
    });

    test('should_return_false_when_all_arrows_mutually_block', () {
      final tablero = GrafoTablero.desde(
        filas: 2,
        columnas: 2,
        trayectorias: [
          flecha(1, 0, 0, Direccion.derecha),
          flecha(2, 0, 1, Direccion.izquierda),
          flecha(3, 1, 0, Direccion.derecha),
          flecha(4, 1, 1, Direccion.izquierda),
        ],
      );
      final resultado = Solver.esSolvable(tablero);
      expect(resultado, isFalse);
    });

    test('should_skip_absent_positions_when_raycasting', () {
      // Arrow at (0,0) pointing left; (0,1) is absent so the left ray
      // should see the absent position as a non-node (like board edge).
      final tablero = GrafoTablero.desde(
        filas: 2,
        columnas: 3,
        ausentes: {const Posicion.en(fila: 0, columna: 1)},
        trayectorias: [flecha(1, 0, 2, Direccion.izquierda)],
      );
      // Ray from (0,2) left: hits (0,1) which is absent → no node → edge.
      final resultado = tablero.raycast(
        const Posicion.en(fila: 0, columna: 2),
        Direccion.izquierda,
      );
      expect(resultado.despejadoHastaBorde, isTrue);
    });

    test('should_return_true_when_shaped_board_is_solvable_golden', () {
      final tablero = tableroShapedSolvable();
      expect(Solver.esSolvable(tablero), isTrue);
    });

    test('should_return_false_when_shaped_board_is_unsolvable_golden', () {
      final tablero = tableroShapedInsolvable();
      expect(Solver.esSolvable(tablero), isFalse);
    });

    test('should_return_true_when_shaped_board_is_empty', () {
      final tablero = GrafoTablero.desde(
        filas: 3,
        columnas: 3,
        ausentes: {const Posicion.en(fila: 0, columna: 0)},
      );
      expect(Solver.esSolvable(tablero), isTrue);
    });
  });
}
