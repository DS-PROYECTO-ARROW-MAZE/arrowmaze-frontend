import 'package:arrowmaze/domain/evento_juego.dart';
import 'package:arrowmaze/domain/observador_juego.dart';
import 'package:arrowmaze/domain/publicador_eventos_juego.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:flutter_test/flutter_test.dart';

/// A hand-rolled spy: accumulates every event it receives so tests can
/// inspect what the publisher delivered and in what order.
class _EspiaObservador implements ObservadorJuego {
  final List<EventoJuego> recibidos = [];

  @override
  void alOcurrirEvento(EventoJuego evento) => recibidos.add(evento);
}

void main() {
  // A stable position used throughout — the exact value is irrelevant to these
  // tests; it just needs to be non-null.
  const posicion = Posicion.en(fila: 0, columna: 0);

  // The event sent in each publish call.
  final eventoFicha = EventoJuego(TipoEvento.flechaEliminada, posicion);

  group('PublicadorEventosJuego — GoF Observer (Subject)', () {
    test(
      'should_notify_all_subscribed_observers_when_event_published',
      () {
        // Arrange — two independent spies subscribed to the same publisher.
        final publicador = PublicadorEventosJuego();
        final espia1 = _EspiaObservador();
        final espia2 = _EspiaObservador();
        publicador.suscribir(espia1);
        publicador.suscribir(espia2);

        // Act
        publicador.publicar(eventoFicha);

        // Assert — both observers received exactly one event of the right type.
        expect(espia1.recibidos, hasLength(1));
        expect(espia1.recibidos.first.tipo, TipoEvento.flechaEliminada);
        expect(espia2.recibidos, hasLength(1));
        expect(espia2.recibidos.first.tipo, TipoEvento.flechaEliminada);
      },
    );

    test(
      'should_stop_notifying_after_desuscribir',
      () {
        // Arrange — subscribe, then immediately unsubscribe.
        final publicador = PublicadorEventosJuego();
        final espia = _EspiaObservador();
        publicador.suscribir(espia);
        publicador.desuscribir(espia);

        // Act — publish an event that the unsubscribed observer must NOT see.
        publicador.publicar(eventoFicha);

        // Assert — zero events delivered after unsubscription.
        expect(espia.recibidos, isEmpty);
      },
    );

    test(
      'should_deliver_multiple_events_in_order_when_published_sequentially',
      () {
        // Arrange
        final publicador = PublicadorEventosJuego();
        final espia = _EspiaObservador();
        publicador.suscribir(espia);

        final eventosEsperados = <TipoEvento>[
          TipoEvento.movimientoRealizado,
          TipoEvento.flechaEliminada,
          TipoEvento.victoria,
        ];

        // Act — publish three events in sequence.
        for (final tipo in eventosEsperados) {
          publicador.publicar(EventoJuego(tipo, posicion));
        }

        // Assert — received in order.
        expect(
          espia.recibidos.map((e) => e.tipo).toList(),
          eventosEsperados,
        );
      },
    );
  });
}
