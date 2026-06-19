import 'package:arrowmaze/application/use_cases/mover_flecha_use_case.dart';
import 'package:arrowmaze/domain/entities/fabrica_celdas_estandar.dart';
import 'package:arrowmaze/domain/grafo_tablero.dart';
import 'package:arrowmaze/presentation/viewmodels/juego_view_model.dart';
import 'package:arrowmaze/presentation/viewmodels/juego_view_state.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies the MVVM binding: a tap on the VM runs the use case and publishes a
/// *new immutable* [JuegoViewState] (via `copyWith`) with the tapped cell now
/// empty, notifying listeners exactly once.
void main() {
  GrafoTablero construirTablero() {
    const fabrica = FabricaCeldasEstandar();
    // 3x3 with a single upward arrow at (2,1) whose column is clear.
    return GrafoTablero.desdeCeldas(
      filas: 3,
      columnas: 3,
      celdas: [
        fabrica.crear(
          {'row': 2, 'col': 1, 'type': 'arrow', 'direction': 'UP'},
        ),
      ],
    );
  }

  test('should_expose_new_JuegoViewState_with_emptied_cell_when_move_valid',
      () {
    // Arrange
    final tablero = construirTablero();
    final viewModel = JuegoViewModel(
      tablero: tablero,
      moverFlecha: MoverFlechaUseCase(tablero),
    );
    final JuegoViewState estadoInicial = viewModel.estado;
    var notificaciones = 0;
    viewModel.addListener(() => notificaciones++);

    const posicion = Posicion.en(fila: 2, columna: 1);
    expect(
      estadoInicial.tablero.celdaEn(posicion).tipo,
      TipoCeldaUI.flecha,
    );

    // Act
    viewModel.tocar(posicion);

    // Assert — a brand new immutable state instance was published.
    expect(identical(viewModel.estado, estadoInicial), isFalse);
    expect(viewModel.estado.tablero.celdaEn(posicion).tipo, TipoCeldaUI.vacia);
    expect(viewModel.estado.movimientos, 1);
    expect(notificaciones, 1);
  });
}
