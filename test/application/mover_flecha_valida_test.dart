import 'package:arrowmaze/application/use_cases/mover_flecha_use_case.dart';
import 'package:arrowmaze/application/use_cases/resultado_movimiento.dart';
import 'package:arrowmaze/application/use_cases/evento_juego.dart';
import 'package:arrowmaze/domain/entities/celda.dart';
import 'package:arrowmaze/domain/tablero.dart';
import 'package:arrowmaze/domain/value_objects/direccion.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// The use case is tested against the [Tablero] *port* only — a mocktail fake.
/// Covers AC1 (empty + movimientos+1), AC2 (events) and AC5 (tap any order).
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
    // Default happy path: every cell is an upward arrow with a clear ray.
    when(() => tablero.celdaEn(any())).thenAnswer(
      (inv) => CeldaFlecha(
        posicion: inv.positionalArguments.first as Posicion,
        direccion: Direccion.arriba,
      ),
    );
    when(() => tablero.raycast(any(), any()))
        .thenReturn(const ResultadoRaycast.despejado());
    when(() => tablero.eliminarFlecha(any())).thenReturn(null);
  });

  test('should_empty_cell_and_increment_movimientos_when_ray_clear', () {
    // Arrange
    const posicion = Posicion.en(fila: 2, columna: 2);

    // Act
    final resultado = useCase.ejecutar(posicion);

    // Assert — the arrow's cell was emptied and the counter advanced.
    expect(resultado.valido, isTrue);
    expect(resultado.movimientos, 1);
    verify(() => tablero.eliminarFlecha(posicion)).called(1);
  });

  test('should_emit_FlechaEliminada_and_MovimientoRealizado_when_move_valid',
      () {
    // Arrange
    const posicion = Posicion.en(fila: 1, columna: 0);

    // Act
    final ResultadoMovimiento resultado = useCase.ejecutar(posicion);

    // Assert — both domain events are present on the result.
    final tipos = resultado.eventos.map((e) => e.tipo).toSet();
    expect(tipos, containsAll(<TipoEvento>{
      TipoEvento.movimientoRealizado,
      TipoEvento.flechaEliminada,
    }));
  });

  test('should_resolve_without_reachability_error_when_tapping_any_arrow', () {
    // Arrange — an arbitrary tap order over different positions.
    const posiciones = <Posicion>[
      Posicion.en(fila: 4, columna: 1),
      Posicion.en(fila: 0, columna: 0),
      Posicion.en(fila: 2, columna: 3),
    ];

    // Act + Assert — no reachability/position exception, counter just grows.
    var ultimo = 0;
    for (final posicion in posiciones) {
      final resultado = useCase.ejecutar(posicion);
      expect(resultado.valido, isTrue);
      ultimo = resultado.movimientos;
    }
    expect(ultimo, posiciones.length);
  });
}
