import 'package:arrowmaze/application/use_cases/mover_flecha_use_case.dart';
import 'package:arrowmaze/domain/entities/celda.dart';
import 'package:arrowmaze/domain/entities/trayectoria.dart';
import 'package:arrowmaze/domain/evento_juego.dart';
import 'package:arrowmaze/domain/grafo_tablero.dart';
import 'package:arrowmaze/domain/value_objects/direccion.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 36 (DM-F2) — `MoverFlechaUseCase` needs **zero** code changes to
/// play a depth-aware board: it only ever calls the `Tablero` port with the
/// exact `Posicion` it was handed, so a path that bends through depth (a
/// `capa` step) resolves exactly like a same-layer path. This mirrors the
/// existing `mover_flecha_use_case_test.dart` assertions against a
/// `profundo: 2` fixture.
void main() {
  GrafoTablero construirTablero() {
    // 1x2 footprint, 2 layers — a bend in-plane then through depth, head on
    // layer 1 exiting FORWARD (mirrors level_3d_test_02).
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

  test('should_remove_whole_cross_layer_path_when_tapping_a_visible_segment',
      () {
    // Arrange
    final tablero = construirTablero();
    final useCase = MoverFlechaUseCase(tablero);

    // Act — tap the tail segment, on layer 0; the head sits on layer 1.
    final resultado =
        useCase.ejecutar(const Posicion.en(fila: 0, columna: 0, capa: 0));

    // Assert — the whole path left, across every layer it occupied.
    expect(resultado.valido, isTrue);
    expect(resultado.movimientos, 1);
    expect(
      tablero.celdaEn(const Posicion.en(fila: 0, columna: 0, capa: 0)),
      isA<CeldaVacia>(),
    );
    expect(tablero.trayectoriaEn(const Posicion.en(fila: 0, columna: 1, capa: 1)),
        isNull);
    expect(tablero.estaVacio, isTrue);
  });

  test('should_emit_FlechaEliminada_and_MovimientoRealizado_across_layers', () {
    // Arrange
    final tablero = construirTablero();
    final useCase = MoverFlechaUseCase(tablero);

    // Act — tap a middle segment (still layer 0).
    final resultado =
        useCase.ejecutar(const Posicion.en(fila: 0, columna: 1, capa: 0));

    // Assert — same event contract as the 2D suite.
    final tipos = resultado.eventos.map((e) => e.tipo).toSet();
    expect(tipos, containsAll(<TipoEvento>{
      TipoEvento.movimientoRealizado,
      TipoEvento.flechaEliminada,
    }));
  });

  test(
      'should_penalize_without_mutating_board_when_head_ray_blocked_by_deeper_layer',
      () {
    // Arrange — the arrow's forward ray is blocked one layer deeper by a wall.
    final tablero = GrafoTablero.desde(
      filas: 1,
      columnas: 1,
      profundo: 2,
      trayectorias: [
        Trayectoria(
          id: 1,
          direccionCabeza: Direccion.adelante,
          segmentos: const [Posicion.en(fila: 0, columna: 0, capa: 0)],
        ),
      ],
      celdas: const [CeldaPared(Posicion.en(fila: 0, columna: 0, capa: 1))],
    );
    final useCase = MoverFlechaUseCase(tablero);

    // Act
    final resultado =
        useCase.ejecutar(const Posicion.en(fila: 0, columna: 0, capa: 0));

    // Assert — invalid/penalized: the arrow stays, the counter still advances.
    expect(resultado.valido, isFalse);
    expect(resultado.movimientos, 1);
    expect(
      tablero.celdaEn(const Posicion.en(fila: 0, columna: 0, capa: 0)),
      isA<CeldaFlecha>(),
    );
  });
}
