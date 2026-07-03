import 'package:arrowmaze/application/ports/reloj.dart';
import 'package:arrowmaze/application/use_cases/command_history.dart';
import 'package:arrowmaze/application/use_cases/deshacer_movimiento_use_case.dart';
import 'package:arrowmaze/application/use_cases/mover_flecha_use_case.dart';
import 'package:arrowmaze/domain/entities/trayectoria.dart';
import 'package:arrowmaze/domain/grafo_tablero.dart';
import 'package:arrowmaze/domain/puntuacion/definicion_nivel.dart';
import 'package:arrowmaze/domain/sesion/sesion_juego.dart';
import 'package:arrowmaze/domain/value_objects/direccion.dart';
import 'package:arrowmaze/domain/value_objects/presupuesto_movimientos.dart';
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

  // ---------------------------------------------------------------------------
  // Ticket 30 — budget countdown + undo cap in the ViewState
  // ---------------------------------------------------------------------------

  test('should_expose_remaining_moves_and_undos_and_disable_undo_at_zero',
      () {
    // Arrange — a ViewModel with budget + manually wired undo.
    const definicion = DefinicionNivel(
      id: 0,
      baseNivel: 1000,
      kmov: 10,
      ktiempo: 2,
      umbralesEstrellas: [300, 600, 900],
      limiteTiempo: null,
    );

    // A 3×5 board with 4 arrows (3 for taps + 1 left to keep board non-empty
    // so undo stays legal after the third tap).
    final tablero = GrafoTablero.desde(
      filas: 3,
      columnas: 5,
      trayectorias: [
        Trayectoria(
          id: 1,
          direccionCabeza: Direccion.arriba,
          segmentos: const [Posicion.en(fila: 2, columna: 0)],
        ),
        Trayectoria(
          id: 2,
          direccionCabeza: Direccion.arriba,
          segmentos: const [Posicion.en(fila: 2, columna: 1)],
        ),
        Trayectoria(
          id: 3,
          direccionCabeza: Direccion.arriba,
          segmentos: const [Posicion.en(fila: 2, columna: 2)],
        ),
        Trayectoria(
          id: 4,
          direccionCabeza: Direccion.arriba,
          segmentos: const [Posicion.en(fila: 2, columna: 3)],
        ),
      ],
    );
    const presupuesto = PresupuestoMovimientos(5);
    final historial = CommandHistory();
    final sesion = SesionJuego(
      tablero: tablero,
      presupuestoMovimientos: presupuesto,
    );
    final moverFlecha =
        MoverFlechaUseCase(tablero, historial: historial, sesion: sesion);
    final deshacerMovimiento = DeshacerMovimientoUseCase(
      sesion: sesion,
      historial: historial,
      contador: moverFlecha.contador,
    );
    final viewModel = JuegoViewModel(
      tablero: tablero,
      moverFlecha: moverFlecha,
      definicionNivel: definicion,
      reloj: _RelojNulo(),
      deshacerMovimiento: deshacerMovimiento,
    );

    // Assert initial state
    expect(viewModel.estado.movimientosRestantes, 5);
    expect(viewModel.estado.usosUndoRestantes, 3);

    // Act — make 3 moves, each on a different arrow. One arrow stays on the
    // board so the session remains in play (undo legal).
    const taps = <Posicion>[
      Posicion.en(fila: 2, columna: 0),
      Posicion.en(fila: 2, columna: 1),
      Posicion.en(fila: 2, columna: 2),
    ];
    viewModel.tocar(taps[0]);
    expect(viewModel.estado.movimientosRestantes, 4);

    viewModel.tocar(taps[1]);
    expect(viewModel.estado.movimientosRestantes, 3);

    viewModel.tocar(taps[2]);
    expect(viewModel.estado.movimientosRestantes, 2);

    // Undo twice — budget restores, undo counter drops.
    viewModel.deshacer();
    expect(viewModel.estado.movimientosRestantes, 3);
    expect(viewModel.estado.usosUndoRestantes, 2);

    viewModel.deshacer();
    expect(viewModel.estado.movimientosRestantes, 4);
    expect(viewModel.estado.usosUndoRestantes, 1);

    // 3rd undo — cap is now 0, button disabled.
    viewModel.deshacer();
    expect(viewModel.estado.usosUndoRestantes, 0);
    expect(viewModel.puedeDeshacer, isFalse);
    // A 4th undo is a safe no-op.
    viewModel.deshacer();
    expect(viewModel.puedeDeshacer, isFalse);
  });
}
