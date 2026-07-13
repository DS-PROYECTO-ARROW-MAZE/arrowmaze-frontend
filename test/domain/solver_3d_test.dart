import 'package:arrowmaze/domain/entities/trayectoria.dart';
import 'package:arrowmaze/domain/grafo_tablero.dart';
import 'package:arrowmaze/domain/solver.dart';
import 'package:arrowmaze/domain/tablero.dart';
import 'package:arrowmaze/domain/value_objects/direccion.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:flutter_test/flutter_test.dart';

import 'solver_test.dart' as solver2d;

/// Ticket 36 (DM-F4) — `Solver.esSolvable` gives the correct verdict on a
/// depth-aware `GrafoTablero`, mirroring the three bundled golden 3D fixtures
/// (`assets/levels/level_3d_test_0{1,2,3}.json`) built directly through the
/// domain API. `DetectorColisiones`'s raycast walk needs no change at all (it
/// already only follows `Nodo.vecinos` links by `Direccion`); the position
/// enumeration Solver drives now also spans `capa` via `Tablero.profundo`.
void main() {
  /// Mirrors `level_3d_test_01` — minimal depth smoke test (1×1 footprint, 2
  /// layers): a single 2-segment arrow, tail on layer 0, head on layer 1,
  /// exiting FORWARD off the top of the stack.
  Tablero tablero3dMinimo() {
    return GrafoTablero.desde(
      filas: 1,
      columnas: 1,
      profundo: 2,
      trayectorias: [
        Trayectoria(
          id: 1,
          direccionCabeza: Direccion.adelante,
          segmentos: const [
            Posicion.en(fila: 0, columna: 0, capa: 0),
            Posicion.en(fila: 0, columna: 0, capa: 1),
          ],
        ),
      ],
    );
  }

  /// Mirrors `level_3d_test_02` — cross-layer bending path (1×2 footprint, 2
  /// layers): a 3-segment path bending once in-plane then once through depth,
  /// head on layer 1 exiting FORWARD.
  Tablero tablero3dBend() {
    return GrafoTablero.desde(
      filas: 1,
      columnas: 2,
      profundo: 2,
      trayectorias: [
        Trayectoria(
          id: 1,
          direccionCabeza: Direccion.adelante,
          segmentos: const [
            Posicion.en(fila: 0, columna: 0, capa: 0),
            Posicion.en(fila: 0, columna: 1, capa: 0),
            Posicion.en(fila: 0, columna: 1, capa: 1),
          ],
        ),
      ],
    );
  }

  /// Mirrors `level_3d_test_03` — mutual cross-layer block (1×2 footprint, 3
  /// layers, unsolvable): two 2-segment arrows face each other nose-to-nose
  /// across the middle layer at column 0, so neither's head ray ever clears.
  Tablero tablero3dBloqueoMutuo() {
    return GrafoTablero.desde(
      filas: 1,
      columnas: 2,
      profundo: 3,
      trayectorias: [
        Trayectoria(
          id: 1,
          direccionCabeza: Direccion.adelante,
          segmentos: const [
            Posicion.en(fila: 0, columna: 0, capa: 0),
            Posicion.en(fila: 0, columna: 0, capa: 1),
          ],
        ),
        Trayectoria(
          id: 2,
          direccionCabeza: Direccion.atras,
          segmentos: const [
            Posicion.en(fila: 0, columna: 1, capa: 2),
            Posicion.en(fila: 0, columna: 0, capa: 2),
          ],
        ),
      ],
    );
  }

  test(
      'should_return_false_when_a_deeper_layer_holds_a_mutual_block_and_layer_zero_is_empty',
      () {
    // Arrange — layer 0 is entirely empty; both blocking arrows live on layer
    // 1 only. A position-enumeration that stopped at capa 0 (the pre-3D
    // Solver loop) would never encounter either arrow and would wrongly
    // report the board solvable/empty.
    final tablero = GrafoTablero.desde(
      filas: 1,
      columnas: 2,
      profundo: 2,
      trayectorias: [
        Trayectoria(
          id: 1,
          direccionCabeza: Direccion.derecha,
          segmentos: const [Posicion.en(fila: 0, columna: 0, capa: 1)],
        ),
        Trayectoria(
          id: 2,
          direccionCabeza: Direccion.izquierda,
          segmentos: const [Posicion.en(fila: 0, columna: 1, capa: 1)],
        ),
      ],
    );

    // Act / Assert — the two arrows point straight at each other on layer 1;
    // neither ray ever clears, so the board must be reported unsolvable.
    expect(Solver.esSolvable(tablero), isFalse);
  });

  group('Solver.esSolvable — golden 3D boards', () {
    test('should_return_true_for_minimal_depth_smoke_test', () {
      expect(Solver.esSolvable(tablero3dMinimo()), isTrue);
    });

    test('should_return_true_for_cross_layer_bending_path', () {
      expect(Solver.esSolvable(tablero3dBend()), isTrue);
    });

    test('should_return_false_for_mutual_cross_layer_block', () {
      expect(Solver.esSolvable(tablero3dBloqueoMutuo()), isFalse);
    });
  });

  group('Solver.esSolvable — 2D regression against a depth-aware board', () {
    test('should_return_true_when_2d_golden_board_wrapped_at_profundo_two', () {
      // A profundo:2 board with all content on layer 0 must behave exactly
      // like the plain 2D golden board — the OCP proof (DM-F4): zero Solver
      // code changed its *decision* logic, only its position enumeration
      // grew a third loop over an always-empty extra layer here.
      final tablero = GrafoTablero.desde(
        filas: 5,
        columnas: 5,
        profundo: 2,
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
        ],
      );
      expect(Solver.esSolvable(tablero), isTrue);
    });

    test('should_return_false_when_2d_insolvable_board_wrapped_at_profundo_two',
        () {
      final tablero = GrafoTablero.desde(
        filas: 3,
        columnas: 3,
        profundo: 2,
        trayectorias: [
          solver2d.flecha(1, 1, 0, Direccion.derecha),
          solver2d.flecha(2, 1, 2, Direccion.izquierda),
        ],
      );
      expect(Solver.esSolvable(tablero), isFalse);
    });
  });
}
