import 'package:arrowmaze/domain/value_objects/direccion.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:arrowmaze/presentation/viewmodels/juego_view_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Board-mapping unit for the shaped-board hit test (ticket 26, AC4).
///
/// Verifies the pure seam the View uses to turn a tapped grid position into a
/// playable cell: absent positions resolve to `null` (no hit-test target) while
/// a tap inside the shape resolves the owning path. Painter pixels are out of
/// scope — this tests the state mapping only.
void main() {
  /// A shaped 2×2 board: an arrow segment of path 7 at (1,1), a plain empty
  /// cell at (0,0), and an absent corner at (0,1) that is outside the shape.
  TableroUI construirTablero() {
    return const TableroUI(
      filas: 2,
      columnas: 2,
      celdas: [
        CeldaUI(
          posicion: Posicion.en(fila: 0, columna: 0),
          tipo: TipoCeldaUI.vacia,
        ),
        CeldaUI(
          posicion: Posicion.en(fila: 0, columna: 1),
          tipo: TipoCeldaUI.ausente,
        ),
        CeldaUI(
          posicion: Posicion.en(fila: 1, columna: 0),
          tipo: TipoCeldaUI.vacia,
        ),
        CeldaUI(
          posicion: Posicion.en(fila: 1, columna: 1),
          tipo: TipoCeldaUI.flecha,
          idFlecha: 7,
          esCabeza: true,
          direccion: Direccion.derecha,
        ),
      ],
    );
  }

  test('should_ignore_tap_on_absent_position', () {
    // Arrange
    final tablero = construirTablero();

    // Act — tap the absent corner, outside the playable region.
    final resultado =
        tablero.celdaJugableEn(const Posicion.en(fila: 0, columna: 1));

    // Assert — no hit-test target: the tap resolves to nothing (AC4).
    expect(resultado, isNull);
  });

  test('should_resolve_owning_path_when_tap_inside_shape', () {
    // Arrange
    final tablero = construirTablero();

    // Act — tap the arrow segment inside the shape.
    final celda =
        tablero.celdaJugableEn(const Posicion.en(fila: 1, columna: 1));

    // Assert — a playable cell that carries its owning path's id (AC4).
    expect(celda, isNotNull);
    expect(celda!.idFlecha, 7);
  });

  test('should_resolve_empty_cell_inside_shape_as_playable', () {
    // Arrange — an EmptyCell is present (transparent), distinct from absent.
    final tablero = construirTablero();

    // Act
    final celda =
        tablero.celdaJugableEn(const Posicion.en(fila: 0, columna: 0));

    // Assert — present but empty: still a hit-test target (AC2).
    expect(celda, isNotNull);
    expect(celda!.tipo, TipoCeldaUI.vacia);
  });

  test('should_ignore_tap_outside_board_bounds', () {
    // Arrange
    final tablero = construirTablero();

    // Act & Assert — off-grid taps resolve to nothing.
    expect(
      tablero.celdaJugableEn(const Posicion.en(fila: -1, columna: 0)),
      isNull,
    );
    expect(
      tablero.celdaJugableEn(const Posicion.en(fila: 2, columna: 2)),
      isNull,
    );
  });
}
