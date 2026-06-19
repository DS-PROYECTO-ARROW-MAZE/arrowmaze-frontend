import 'package:arrowmaze/application/use_cases/mover_flecha_use_case.dart';
import 'package:arrowmaze/domain/entities/trayectoria.dart';
import 'package:arrowmaze/domain/grafo_tablero.dart';
import 'package:arrowmaze/domain/value_objects/direccion.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:arrowmaze/presentation/viewmodels/juego_view_model.dart';
import 'package:arrowmaze/presentation/viewmodels/juego_view_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// Verifies the MVVM binding: a tap on the VM runs the use case and publishes a
/// *new immutable* [JuegoViewState] (via `copyWith`) with the whole path now
/// empty, notifying listeners exactly once. Also checks the snapshot carries the
/// path geometry (corner connections, head) the painter needs.
void main() {
  GrafoTablero construirTablero() {
    // 3x3 with an L-shaped path: (2,1)->(1,1)->(1,0), head (1,0) exits left.
    return GrafoTablero.desde(
      filas: 3,
      columnas: 3,
      trayectorias: [
        Trayectoria(
          id: 1,
          direccionCabeza: Direccion.izquierda,
          segmentos: const [
            Posicion.en(fila: 2, columna: 1),
            Posicion.en(fila: 1, columna: 1),
            Posicion.en(fila: 1, columna: 0),
          ],
        ),
      ],
    );
  }

  test('should_expose_path_geometry_in_the_initial_snapshot', () {
    // Arrange
    final tablero = construirTablero();
    final viewModel = JuegoViewModel(
      tablero: tablero,
      moverFlecha: MoverFlechaUseCase(tablero),
    );

    // Assert — the bend at (1,1) is a corner; (1,0) is the head exiting left.
    final esquina =
        viewModel.estado.tablero.celdaEn(const Posicion.en(fila: 1, columna: 1));
    expect(esquina.tipo, TipoCeldaUI.flecha);
    expect(esquina.conexiones, {Direccion.abajo, Direccion.izquierda});

    final cabeza =
        viewModel.estado.tablero.celdaEn(const Posicion.en(fila: 1, columna: 0));
    expect(cabeza.esCabeza, isTrue);
    expect(cabeza.direccion, Direccion.izquierda);
  });

  test('should_expose_new_JuegoViewState_with_emptied_path_when_move_valid', () {
    // Arrange
    final tablero = construirTablero();
    final viewModel = JuegoViewModel(
      tablero: tablero,
      moverFlecha: MoverFlechaUseCase(tablero),
    );
    final JuegoViewState estadoInicial = viewModel.estado;
    var notificaciones = 0;
    viewModel.addListener(() => notificaciones++);

    // Tap any segment of the path — the whole arrow should resolve.
    const tap = Posicion.en(fila: 2, columna: 1);
    expect(estadoInicial.tablero.celdaEn(tap).tipo, TipoCeldaUI.flecha);

    // Act
    viewModel.tocar(tap);

    // Assert — a brand new immutable state instance was published.
    expect(identical(viewModel.estado, estadoInicial), isFalse);
    final tablero2 = viewModel.estado.tablero;
    for (final p in const [
      Posicion.en(fila: 2, columna: 1),
      Posicion.en(fila: 1, columna: 1),
      Posicion.en(fila: 1, columna: 0),
    ]) {
      expect(tablero2.celdaEn(p).tipo, TipoCeldaUI.vacia);
    }
    expect(viewModel.estado.movimientos, 1);
    expect(notificaciones, 1);
  });
}
