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

void main() {
  group('Solver.esSolvable', () {
    test('should_return_true_for_known_solvable_golden_board', () {
      final tablero = tableroSolvable();
      final resultado = Solver.esSolvable(tablero);
      expect(resultado, isTrue);
    });

    test('should_return_false_for_known_unsolvable_golden_board', () {
      final tablero = tableroInsolvable();
      final resultado = Solver.esSolvable(tablero);
      expect(resultado, isFalse);
    });

    test('should_return_same_verdict_across_shuffled_removal_orders', () {
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

    test('should_return_true_for_empty_board', () {
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
  });
}
