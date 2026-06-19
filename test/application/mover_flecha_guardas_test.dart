import 'package:arrowmaze/application/use_cases/mover_flecha_use_case.dart';
import 'package:arrowmaze/domain/entities/trayectoria.dart';
import 'package:arrowmaze/domain/tablero.dart';
import 'package:arrowmaze/domain/value_objects/direccion.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// Guards for this slice's *honest surface*: a tap that is not a valid exit is a
/// no-op here (no board change, no counter bump). Penalised invalid moves and
/// history are ticket 02 — deliberately absent.
class _TableroFalso extends Mock implements Tablero {}

void main() {
  setUpAll(() {
    registerFallbackValue(Direccion.arriba);
    registerFallbackValue(const Posicion.en(fila: 0, columna: 0));
  });

  late _TableroFalso tablero;
  late MoverFlechaUseCase useCase;

  setUp(() {
    tablero = _TableroFalso();
    useCase = MoverFlechaUseCase(tablero);
    when(() => tablero.eliminarTrayectoria(any())).thenReturn(null);
  });

  test('should_noop_when_tapped_cell_has_no_arrow', () {
    // Arrange — the tapped cell is empty/wall (no path).
    const posicion = Posicion.en(fila: 0, columna: 0);
    when(() => tablero.trayectoriaEn(posicion)).thenReturn(null);

    // Act
    final resultado = useCase.ejecutar(posicion);

    // Assert — no exit, no counter change, board untouched.
    expect(resultado.valido, isFalse);
    expect(resultado.movimientos, 0);
    expect(useCase.movimientos, 0);
    expect(resultado.eventos, isEmpty);
    verifyNever(() => tablero.eliminarTrayectoria(any()));
  });

  test('should_noop_when_head_ray_is_blocked', () {
    // Arrange — a path whose head ray is stopped before the edge.
    const posicion = Posicion.en(fila: 2, columna: 2);
    final trayectoria = Trayectoria(
      id: 3,
      direccionCabeza: Direccion.arriba,
      segmentos: const [posicion],
    );
    when(() => tablero.trayectoriaEn(posicion)).thenReturn(trayectoria);
    when(() => tablero.raycast(any(), any())).thenReturn(
      const ResultadoRaycast.bloqueado(Posicion.en(fila: 0, columna: 2)),
    );

    // Act
    final resultado = useCase.ejecutar(posicion);

    // Assert — blocked ray does not consume the path in this slice.
    expect(resultado.valido, isFalse);
    expect(resultado.movimientos, 0);
    verifyNever(() => tablero.eliminarTrayectoria(any()));
  });
}
