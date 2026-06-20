import 'package:arrowmaze/domain/evento_juego.dart';
import 'package:arrowmaze/application/use_cases/mover_flecha_use_case.dart';
import 'package:arrowmaze/domain/entities/trayectoria.dart';
import 'package:arrowmaze/domain/sesion/sesion_juego.dart';
import 'package:arrowmaze/domain/tablero.dart';
import 'package:arrowmaze/domain/value_objects/direccion.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

/// AC2/AC3 (PRD §3 A4, §7.2). The use case is exercised against the [Tablero]
/// *port* (a mocktail fake) plus a real timed [SesionJuego] acting as the
/// fake clock — `tiempoRestante` is the timer under test. A valid ray crossing a
/// collectible must emit `ColeccionableRecogido` and add seconds; victory must
/// never depend on a collectible.
class _TableroFalso extends Mock implements Tablero {}

void main() {
  setUpAll(() {
    registerFallbackValue(Direccion.arriba);
    registerFallbackValue(const Posicion.en(fila: 0, columna: 0));
  });

  late _TableroFalso tablero;

  // Every tap lands on a clear single-cell arrow path.
  Trayectoria pathEn(Posicion tapped) => Trayectoria(
        id: 9,
        direccionCabeza: Direccion.arriba,
        segmentos: [tapped],
      );

  setUp(() {
    tablero = _TableroFalso();
    when(() => tablero.trayectoriaEn(any())).thenAnswer(
      (inv) => pathEn(inv.positionalArguments.first as Posicion),
    );
    when(() => tablero.eliminarTrayectoria(any())).thenReturn(null);
    when(() => tablero.recogerColeccionable(any())).thenReturn(null);
  });

  test(
      'should_emit_ColeccionableRecogido_and_add_seconds_when_ray_crosses_collectible',
      () {
    // Arrange — a timed level; the head ray is clear and flew over a collectible.
    const collectible = Posicion.en(fila: 0, columna: 1);
    when(() => tablero.raycast(any(), any())).thenReturn(
      const ResultadoRaycast.despejado(coleccionables: [collectible]),
    );
    when(() => tablero.estaVacio).thenReturn(false);
    final sesion =
        SesionJuego(tablero: tablero, limiteTiempo: const Duration(minutes: 1));
    final useCase = MoverFlechaUseCase(tablero, sesion: sesion);

    // Act
    final resultado = useCase.ejecutar(const Posicion.en(fila: 1, columna: 1));

    // Assert — a collection event rode on the move result…
    expect(
      resultado.eventos.map((e) => e.tipo),
      contains(TipoEvento.coleccionableRecogido),
    );
    // …the collectible was consumed from the board…
    verify(() => tablero.recogerColeccionable(collectible)).called(1);
    // …and bonus seconds were added to the level timer.
    expect(sesion.tiempoRestante, greaterThan(const Duration(minutes: 1)));
  });

  test('should_reach_victory_without_collecting_when_board_empties', () {
    // Arrange — a clear ray with no collectible; this exit empties the board.
    when(() => tablero.raycast(any(), any()))
        .thenReturn(const ResultadoRaycast.despejado());
    when(() => tablero.estaVacio).thenReturn(true);
    final sesion =
        SesionJuego(tablero: tablero, limiteTiempo: const Duration(minutes: 1));
    final useCase = MoverFlechaUseCase(tablero, sesion: sesion);

    // Act
    final resultado = useCase.ejecutar(const Posicion.en(fila: 0, columna: 0));
    final tipos = resultado.eventos.map((e) => e.tipo).toSet();

    // Assert — victory fired regardless, and nothing was collected…
    expect(tipos, contains(TipoEvento.victoria));
    expect(tipos, isNot(contains(TipoEvento.coleccionableRecogido)));
    verifyNever(() => tablero.recogerColeccionable(any()));
    // …so the timer is untouched (no bonus without a collectible).
    expect(sesion.tiempoRestante, const Duration(minutes: 1));
  });
}
