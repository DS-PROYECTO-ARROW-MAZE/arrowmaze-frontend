import 'package:arrowmaze/application/ports/reloj.dart';
import 'package:arrowmaze/application/use_cases/mover_flecha_use_case.dart';
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

/// Ticket 09 (DM-F8) — the undo button flows View → VM → use case, and the
/// published [JuegoViewState] reflects the reversal: the board snapshot and the
/// move counter roll back together.
void main() {
  const definicion = DefinicionNivel(
    id: 0,
    baseNivel: 1000,
    kmov: 10,
    ktiempo: 2,
    umbralesEstrellas: [300, 600, 900],
    limiteTiempo: null,
  );

  // Two clear-ray arrows so clearing one leaves the board in play (undo legal).
  GrafoTablero tableroDeDosFlechas() => GrafoTablero.desde(
        filas: 3,
        columnas: 3,
        trayectorias: [
          Trayectoria(
            id: 1,
            direccionCabeza: Direccion.arriba,
            segmentos: const [Posicion.en(fila: 2, columna: 0)],
          ),
          Trayectoria(
            id: 2,
            direccionCabeza: Direccion.arriba,
            segmentos: const [Posicion.en(fila: 2, columna: 2)],
          ),
        ],
      );

  JuegoViewModel construir(GrafoTablero tablero) {
    final moverFlecha = MoverFlechaUseCase(tablero);
    return JuegoViewModel(
      tablero: tablero,
      moverFlecha: moverFlecha,
      definicionNivel: definicion,
      reloj: _RelojNulo(),
    );
  }

  test('should_restore_board_and_decrement_moves_when_deshacer_valid_move', () {
    // Arrange — clear one arrow through the VM.
    final tablero = tableroDeDosFlechas();
    final viewModel = construir(tablero);
    const posicion = Posicion.en(fila: 2, columna: 0);
    viewModel.tocar(posicion);
    expect(viewModel.estado.movimientos, 1);
    expect(viewModel.estado.tablero.celdaEn(posicion).tipo, TipoCeldaUI.vacia);
    expect(viewModel.puedeDeshacer, isTrue);

    // Act
    viewModel.deshacer();

    // Assert — the board snapshot shows the arrow again and the counter rolled back.
    expect(viewModel.estado.movimientos, 0);
    expect(viewModel.estado.tablero.celdaEn(posicion).tipo, TipoCeldaUI.flecha);
    expect(viewModel.estado.movimientoInvalido, isFalse);
    expect(viewModel.puedeDeshacer, isFalse);
  });

  test('should_be_noop_when_deshacer_with_empty_history', () {
    // Arrange — nothing played yet.
    final viewModel = construir(tableroDeDosFlechas());
    expect(viewModel.puedeDeshacer, isFalse);

    // Act + Assert — no underflow, board stays put.
    viewModel.deshacer();
    expect(viewModel.estado.movimientos, 0);
  });
}
