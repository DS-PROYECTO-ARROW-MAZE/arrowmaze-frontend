import 'package:arrowmaze/application/use_cases/mover_flecha_use_case.dart';
import 'package:arrowmaze/domain/tablero.dart';
import 'package:arrowmaze/domain/value_objects/direccion.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// Guards for the only *true* no-op: a tap that lands on no arrow at all
/// (an empty or wall cell) is ignored — no board change, no counter bump, no
/// command recorded. A tap on an arrow with a blocked ray is **not** a no-op
/// anymore; it is a penalized invalid move (see `mover_flecha_invalida_test`).
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
    expect(resultado.registrado, isFalse);
    verifyNever(() => tablero.eliminarTrayectoria(any()));
  });
}
