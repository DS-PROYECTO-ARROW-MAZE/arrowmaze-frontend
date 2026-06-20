import 'package:arrowmaze/application/use_cases/command_history.dart';
import 'package:arrowmaze/application/use_cases/mover_flecha_use_case.dart';
import 'package:arrowmaze/domain/entities/celda.dart';
import 'package:arrowmaze/domain/entities/trayectoria.dart';
import 'package:arrowmaze/domain/grafo_tablero.dart';
import 'package:arrowmaze/domain/value_objects/direccion.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 02 — the GoF **Command** history. Every tap that counts as a move
/// pushes a [PlayerMoveCommand]: a valid move carries a real board delta, an
/// invalid (penalized) move a **no-delta +1** command. Recording both outcomes
/// sets up clean undo in ticket 09.
void main() {
  Trayectoria flecha(int id, int fila, int columna, Direccion direccion) =>
      Trayectoria(
        id: id,
        direccionCabeza: direccion,
        segmentos: [Posicion.en(fila: fila, columna: columna)],
      );

  test('should_push_no_delta_plus_one_command_when_move_invalid', () {
    // Arrange — arrow blocked by a wall (an invalid move).
    final historial = CommandHistory();
    final tablero = GrafoTablero.desde(
      filas: 3,
      columnas: 3,
      trayectorias: [flecha(1, 1, 0, Direccion.derecha)],
      celdas: const [CeldaPared(Posicion.en(fila: 1, columna: 2))],
    );
    final useCase = MoverFlechaUseCase(tablero, historial: historial);

    // Act
    useCase.ejecutar(const Posicion.en(fila: 1, columna: 0));

    // Assert — exactly one command, recording the move but carrying no delta.
    expect(historial.longitud, 1);
    expect(historial.ultimo.tieneDelta, isFalse);
  });

  test('should_push_real_delta_command_when_move_valid', () {
    // Arrange — arrow with a clear ray to the edge (a valid move).
    final historial = CommandHistory();
    final tablero = GrafoTablero.desde(
      filas: 3,
      columnas: 3,
      trayectorias: [flecha(1, 2, 2, Direccion.arriba)],
    );
    final useCase = MoverFlechaUseCase(tablero, historial: historial);

    // Act
    useCase.ejecutar(const Posicion.en(fila: 2, columna: 2));

    // Assert — one command carrying the real board delta (the removed path).
    expect(historial.longitud, 1);
    expect(historial.ultimo.tieneDelta, isTrue);
  });
}
