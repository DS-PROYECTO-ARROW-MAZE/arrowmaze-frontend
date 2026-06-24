import 'package:arrowmaze/application/ports/reloj.dart';
import 'package:arrowmaze/application/use_cases/mover_flecha_use_case.dart';
import 'package:arrowmaze/domain/entities/celda.dart';
import 'package:arrowmaze/domain/entities/trayectoria.dart';
import 'package:arrowmaze/domain/grafo_tablero.dart';
import 'package:arrowmaze/domain/puntuacion/definicion_nivel.dart';
import 'package:arrowmaze/domain/value_objects/direccion.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:arrowmaze/presentation/viewmodels/juego_view_model.dart';
import 'package:arrowmaze/presentation/viewmodels/juego_view_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _RelojNulo implements Reloj {
  @override
  void iniciar(Duration intervalo, void Function() tic) {}
  @override
  void detener() {}
}

/// Ticket 02 (DM-F8) — the ViewModel surfaces an "invalid tap" feedback flag in
/// the [JuegoViewState] *without* mutating the board, so the View can shake/flash
/// while every cell stays exactly where it was.
void main() {
  const definicion = DefinicionNivel(
    id: 0,
    baseNivel: 1000,
    kmov: 10,
    ktiempo: 2,
    umbralesEstrellas: [300, 600, 900],
    limiteTiempo: null,
  );
  // 3x3: arrow at (1,0) aims right but a wall at (1,2) blocks its ray.
  GrafoTablero construirTablero() => GrafoTablero.desde(
        filas: 3,
        columnas: 3,
        trayectorias: [
          Trayectoria(
            id: 1,
            direccionCabeza: Direccion.derecha,
            segmentos: const [Posicion.en(fila: 1, columna: 0)],
          ),
        ],
        celdas: const [CeldaPared(Posicion.en(fila: 1, columna: 2))],
      );

  test('should_flag_movimiento_invalido_without_changing_board_when_blocked', () {
    // Arrange
    final tablero = construirTablero();
    final viewModel = JuegoViewModel(
      tablero: tablero,
      moverFlecha: MoverFlechaUseCase(tablero),
      definicionNivel: definicion,
      reloj: _RelojNulo(),
    );
    final tableroInicial = viewModel.estado.tablero;
    var notificaciones = 0;
    viewModel.addListener(() => notificaciones++);

    // Act — tap the blocked arrow.
    viewModel.tocar(const Posicion.en(fila: 1, columna: 0));

    // Assert — feedback flag set, counter advanced, board snapshot untouched.
    expect(viewModel.estado.movimientoInvalido, isTrue);
    expect(viewModel.estado.movimientos, 1);
    expect(identical(viewModel.estado.tablero, tableroInicial), isTrue);
    expect(
      viewModel.estado.tablero
          .celdaEn(const Posicion.en(fila: 1, columna: 0))
          .tipo,
      TipoCeldaUI.flecha,
    );
    expect(notificaciones, 1);
  });

  test('should_clear_movimiento_invalido_flag_after_a_valid_move', () {
    // Arrange — first an invalid tap raises the flag.
    final tablero = GrafoTablero.desde(
      filas: 3,
      columnas: 3,
      trayectorias: [
        // Blocked arrow.
        Trayectoria(
          id: 1,
          direccionCabeza: Direccion.derecha,
          segmentos: const [Posicion.en(fila: 1, columna: 0)],
        ),
        // Free arrow at (2,1) with a clear upward ray to the top edge.
        Trayectoria(
          id: 2,
          direccionCabeza: Direccion.arriba,
          segmentos: const [Posicion.en(fila: 2, columna: 1)],
        ),
      ],
      celdas: const [CeldaPared(Posicion.en(fila: 1, columna: 2))],
    );
    final viewModel = JuegoViewModel(
      tablero: tablero,
      moverFlecha: MoverFlechaUseCase(tablero),
      definicionNivel: definicion,
      reloj: _RelojNulo(),
    );
    viewModel.tocar(const Posicion.en(fila: 1, columna: 0));
    expect(viewModel.estado.movimientoInvalido, isTrue);

    // Act — a valid move resolves and must clear the feedback flag.
    viewModel.tocar(const Posicion.en(fila: 2, columna: 1));

    // Assert
    expect(viewModel.estado.movimientoInvalido, isFalse);
    expect(viewModel.estado.movimientos, 2);
  });
}
