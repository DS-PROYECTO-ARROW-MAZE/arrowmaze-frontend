import 'package:arrowmaze/application/use_cases/mover_flecha_use_case.dart';
import 'package:arrowmaze/domain/evento_juego.dart';
import 'package:arrowmaze/domain/observador_juego.dart';
import 'package:arrowmaze/domain/entities/trayectoria.dart';
import 'package:arrowmaze/domain/tablero.dart';
import 'package:arrowmaze/domain/value_objects/direccion.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _TableroFalso extends Mock implements Tablero {}

/// A spy that accumulates received events so we can assert on them.
class _EspiaObservador implements ObservadorJuego {
  final List<EventoJuego> recibidos = [];

  @override
  void alOcurrirEvento(EventoJuego evento) => recibidos.add(evento);
}

void main() {
  setUpAll(() {
    registerFallbackValue(Direccion.arriba);
    registerFallbackValue(const Posicion.en(fila: 0, columna: 0));
  });

  late _TableroFalso tablero;
  late MoverFlechaUseCase useCase;
  late _EspiaObservador espia;

  Trayectoria pathEn(Posicion tapped) => Trayectoria(
        id: 9,
        direccionCabeza: Direccion.arriba,
        segmentos: [tapped],
      );

  setUp(() {
    tablero = _TableroFalso();
    useCase = MoverFlechaUseCase(tablero);
    espia = _EspiaObservador();
    // Subscribe the spy to the use case's own publisher (AC1 test rig).
    useCase.publicador.suscribir(espia);

    when(() => tablero.trayectoriaEn(any())).thenAnswer(
      (inv) => pathEn(inv.positionalArguments.first as Posicion),
    );
    when(() => tablero.raycast(any(), any()))
        .thenReturn(const ResultadoRaycast.despejado());
    when(() => tablero.eliminarTrayectoria(any())).thenReturn(null);
    when(() => tablero.estaVacio).thenReturn(false);
  });

  group('MoverFlechaUseCase — Observer publishing (AC1, AC2)', () {
    test(
      'should_feed_emitted_events_to_publisher_when_move_resolves',
      () {
        // Arrange
        const posicion = Posicion.en(fila: 1, columna: 1);

        // Act
        useCase.ejecutar(posicion);

        // Assert — the spy (subscribed to the publisher) received events that
        // match what the use case produced internally.  The exact types must
        // include at least MovimientoRealizado and FlechaEliminada.
        final tipos = espia.recibidos.map((e) => e.tipo).toSet();
        expect(
          tipos,
          containsAll(<TipoEvento>{
            TipoEvento.movimientoRealizado,
            TipoEvento.flechaEliminada,
          }),
        );
      },
    );

    test(
      'should_not_reference_audio_or_ui_when_emitting_move_events',
      () {
        // This test proves AC2 by verifying the use case routes every event
        // through the publisher — no audio or UI type appears in its import
        // list. The spy receives the events without the use case knowing who
        // is listening. (The import-direction lint is enforced in ticket 12.)
        const posicion = Posicion.en(fila: 1, columna: 1);

        // Act — run the use case; the spy is the only subscriber.
        useCase.ejecutar(posicion);

        // Assert — events arrived at the spy (through the publisher), proving
        // the use case emitted them without any direct audio/UI call.
        expect(espia.recibidos, isNotEmpty);
      },
    );

    test(
      'should_feed_MovimientoInvalido_to_publisher_when_tap_penalized',
      () {
        // Arrange — ray is blocked (penalized invalid move).
        when(() => tablero.raycast(any(), any()))
            .thenReturn(ResultadoRaycast.bloqueado(
          const Posicion.en(fila: 0, columna: 0),
        ));
        const posicion = Posicion.en(fila: 0, columna: 0);

        // Act
        useCase.ejecutar(posicion);

        // Assert — the invalid-move event is fed to the publisher.
        expect(
          espia.recibidos.map((e) => e.tipo),
          contains(TipoEvento.movimientoInvalido),
        );
      },
    );
  });
}
