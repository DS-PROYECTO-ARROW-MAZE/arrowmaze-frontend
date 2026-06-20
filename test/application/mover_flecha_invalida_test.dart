import 'package:arrowmaze/application/use_cases/evento_juego.dart';
import 'package:arrowmaze/application/use_cases/mover_flecha_use_case.dart';
import 'package:arrowmaze/application/use_cases/resultado_movimiento.dart';
import 'package:arrowmaze/domain/entities/celda.dart';
import 'package:arrowmaze/domain/entities/trayectoria.dart';
import 'package:arrowmaze/domain/grafo_tablero.dart';
import 'package:arrowmaze/domain/tablero.dart';
import 'package:arrowmaze/domain/value_objects/direccion.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ticket 02 — the invalid (penalized) move. These tests run against a *real*
/// [GrafoTablero] so byte-identity of the board can be proven by serializing a
/// snapshot before and after the tap (the anti-cheat invariant of PRD §3 A2).
///
/// Covers AC1 (blocked by wall: board identical, arrow present, movimientos==1),
/// AC2 (blocked by another arrow: same), AC3 (`ResultadoMovimiento` with no
/// board delta) and AC5 (the arrow is not consumed).
void main() {
  /// A serialized, byte-comparable snapshot of every cell's kind and arrow id.
  String instantanea(Tablero tablero) {
    final buffer = StringBuffer();
    for (var fila = 0; fila < tablero.filas; fila++) {
      for (var columna = 0; columna < tablero.columnas; columna++) {
        final celda = tablero.celdaEn(Posicion.en(fila: fila, columna: columna));
        final marca = switch (celda) {
          CeldaFlecha(:final idFlecha) => 'F$idFlecha',
          CeldaPared() => 'P',
          CeldaVacia() => '.',
        };
        buffer.write('$marca|');
      }
    }
    return buffer.toString();
  }

  /// A one-cell arrow path at ([fila],[columna]) pointing in [direccion].
  Trayectoria flecha(int id, int fila, int columna, Direccion direccion) =>
      Trayectoria(
        id: id,
        direccionCabeza: direccion,
        segmentos: [Posicion.en(fila: fila, columna: columna)],
      );

  group('MoverFlechaUseCase — invalid (penalized) move', () {
    test('should_keep_board_identical_when_ray_blocked_by_wall', () {
      // Arrange — arrow at (1,0) aims right; a wall at (1,2) blocks the ray.
      final tablero = GrafoTablero.desde(
        filas: 3,
        columnas: 3,
        trayectorias: [flecha(1, 1, 0, Direccion.derecha)],
        celdas: const [CeldaPared(Posicion.en(fila: 1, columna: 2))],
      );
      final useCase = MoverFlechaUseCase(tablero);
      const tap = Posicion.en(fila: 1, columna: 0);
      final antes = instantanea(tablero);

      // Act
      final resultado = useCase.ejecutar(tap);

      // Assert — board byte-identical, arrow present, anti-cheat counter +1.
      expect(instantanea(tablero), antes);
      expect(tablero.celdaEn(tap), isA<CeldaFlecha>());
      expect(resultado.movimientos, 1);
    });

    test('should_keep_board_identical_when_ray_blocked_by_arrow', () {
      // Arrange — arrow 1 at (0,0) aims down into arrow 2 at (2,0).
      final tablero = GrafoTablero.desde(
        filas: 3,
        columnas: 3,
        trayectorias: [
          flecha(1, 0, 0, Direccion.abajo),
          flecha(2, 2, 0, Direccion.arriba),
        ],
      );
      final useCase = MoverFlechaUseCase(tablero);
      const tap = Posicion.en(fila: 0, columna: 0);
      final antes = instantanea(tablero);

      // Act
      final resultado = useCase.ejecutar(tap);

      // Assert — board byte-identical, both arrows present, counter +1.
      expect(instantanea(tablero), antes);
      expect(tablero.celdaEn(tap), isA<CeldaFlecha>());
      expect(resultado.movimientos, 1);
    });

    test('should_increment_movimientos_when_move_invalid', () {
      // Arrange — a single arrow blocked by a wall, tapped twice.
      final tablero = GrafoTablero.desde(
        filas: 3,
        columnas: 3,
        trayectorias: [flecha(1, 1, 0, Direccion.derecha)],
        celdas: const [CeldaPared(Posicion.en(fila: 1, columna: 2))],
      );
      final useCase = MoverFlechaUseCase(tablero);
      const tap = Posicion.en(fila: 1, columna: 0);

      // Act — two invalid taps must not be "free".
      useCase.ejecutar(tap);
      final resultado = useCase.ejecutar(tap);

      // Assert — every invalid tap is registered as a move (anti-cheat).
      expect(resultado.movimientos, 2);
      expect(useCase.movimientos, 2);
    });

    test('should_produce_result_without_board_delta_when_invalid', () {
      // Arrange
      final tablero = GrafoTablero.desde(
        filas: 3,
        columnas: 3,
        trayectorias: [flecha(1, 1, 0, Direccion.derecha)],
        celdas: const [CeldaPared(Posicion.en(fila: 1, columna: 2))],
      );
      final useCase = MoverFlechaUseCase(tablero);

      // Act
      final ResultadoMovimiento resultado =
          useCase.ejecutar(const Posicion.en(fila: 1, columna: 0));

      // Assert — registered as a move, but no board delta and not "valid".
      expect(resultado.registrado, isTrue);
      expect(resultado.delta, isNull);
      expect(resultado.valido, isFalse);
      expect(
        resultado.eventos.map((e) => e.tipo),
        contains(TipoEvento.movimientoInvalido),
      );
    });
  });
}
