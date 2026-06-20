import 'package:arrowmaze/application/use_cases/command_history.dart';
import 'package:arrowmaze/application/use_cases/deshacer_movimiento_use_case.dart';
import 'package:arrowmaze/application/use_cases/mover_flecha_use_case.dart';
import 'package:arrowmaze/domain/entities/celda.dart';
import 'package:arrowmaze/domain/entities/trayectoria.dart';
import 'package:arrowmaze/domain/grafo_tablero.dart';
import 'package:arrowmaze/domain/sesion/sesion_juego.dart';
import 'package:arrowmaze/domain/value_objects/direccion.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 09 — undo of the last move, valid or invalid, with every counter
/// staying consistent. The undo use case shares the run's [CommandHistory] and
/// move counter with [MoverFlechaUseCase], so popping a command and reversing
/// its delta can never let the two drift (PRD §3 B4, §7.3).
void main() {
  Trayectoria flecha(int id, int fila, int columna, Direccion direccion) =>
      Trayectoria(
        id: id,
        direccionCabeza: direccion,
        segmentos: [Posicion.en(fila: fila, columna: columna)],
      );

  test('should_restore_arrow_and_decrement_movimientos_when_undo_valid_move',
      () {
    // Arrange — two clear-ray arrows so clearing one leaves the board non-empty
    // (the session stays in play, where undo is legal).
    final tablero = GrafoTablero.desde(
      filas: 3,
      columnas: 3,
      trayectorias: [
        flecha(1, 2, 0, Direccion.arriba),
        flecha(2, 2, 2, Direccion.arriba),
      ],
    );
    final historial = CommandHistory();
    final sesion = SesionJuego(tablero: tablero);
    final mover =
        MoverFlechaUseCase(tablero, historial: historial, sesion: sesion);
    const posicion = Posicion.en(fila: 2, columna: 0);
    mover.ejecutar(posicion);
    expect(mover.movimientos, 1);
    expect(tablero.celdaEn(posicion), isA<CeldaVacia>());

    final deshacer = DeshacerMovimientoUseCase(
      sesion: sesion,
      historial: historial,
      contador: mover.contador,
    );

    // Act
    final resultado = deshacer.ejecutar();

    // Assert — the arrow is back on the board, the delta was reversed…
    expect(tablero.celdaEn(posicion), isA<CeldaFlecha>());
    expect(resultado.valido, isTrue);
    // …and every counter rolled back in lock-step.
    expect(resultado.movimientos, 0);
    expect(mover.movimientos, 0);
    expect(historial.longitud, 0);
  });

  test('should_rollback_no_delta_plus_one_when_undo_invalid_move', () {
    // Arrange — an arrow blocked by a wall: a penalized (no-delta +1) move.
    final tablero = GrafoTablero.desde(
      filas: 3,
      columnas: 3,
      trayectorias: [flecha(1, 1, 0, Direccion.derecha)],
      celdas: const [CeldaPared(Posicion.en(fila: 1, columna: 2))],
    );
    final historial = CommandHistory();
    final sesion = SesionJuego(tablero: tablero);
    final mover =
        MoverFlechaUseCase(tablero, historial: historial, sesion: sesion);
    const posicion = Posicion.en(fila: 1, columna: 0);
    mover.ejecutar(posicion);
    expect(mover.movimientos, 1);
    expect(historial.ultimo.tieneDelta, isFalse);

    final deshacer = DeshacerMovimientoUseCase(
      sesion: sesion,
      historial: historial,
      contador: mover.contador,
    );

    // Act
    final resultado = deshacer.ejecutar();

    // Assert — the anti-cheat +1 is rolled back; the board never changed.
    expect(resultado.valido, isFalse);
    expect(resultado.movimientos, 0);
    expect(mover.movimientos, 0);
    expect(historial.longitud, 0);
    expect(tablero.celdaEn(posicion), isA<CeldaFlecha>());
  });

  test('should_be_noop_when_history_empty', () {
    // Arrange — nothing has been played yet.
    final tablero = GrafoTablero.desde(
      filas: 3,
      columnas: 3,
      trayectorias: [flecha(1, 2, 2, Direccion.arriba)],
    );
    final historial = CommandHistory();
    final sesion = SesionJuego(tablero: tablero);
    final mover =
        MoverFlechaUseCase(tablero, historial: historial, sesion: sesion);
    final deshacer = DeshacerMovimientoUseCase(
      sesion: sesion,
      historial: historial,
      contador: mover.contador,
    );

    // Act
    final resultado = deshacer.ejecutar();

    // Assert — a safe no-op: nothing recorded, no counter underflow.
    expect(resultado.registrado, isFalse);
    expect(resultado.movimientos, 0);
    expect(mover.movimientos, 0);
    expect(historial.longitud, 0);
  });
}
