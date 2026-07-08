import 'package:arrowmaze/domain/evento_juego.dart';
import 'package:arrowmaze/domain/observador_juego.dart';
import 'package:arrowmaze/domain/publicador_eventos_juego.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:arrowmaze/infrastructure/audio/audio_service_imp.dart';
import 'package:arrowmaze/infrastructure/audio/i_reproductor_audio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Silent player used by the singleton in tests so platform-channel
/// dependencies are never triggered.
class _ReproductorSilencioso implements IReproductorAudio {
  @override
  void reproducir(String asset, {double volumen = 1.0}) {}
  @override
  void detener() {}
  @override
  void liberar() {}
}

void main() {
  const posicion = Posicion.en(fila: 0, columna: 0);

  setUpAll(() {
    AudioServiceImp.usarReproductor(_ReproductorSilencioso());
  });

  group('AudioServiceImp — GoF Singleton + Observer', () {
    test('should_return_same_instance_when_accessed_twice', () {
      // Arrange + Act
      final a = AudioServiceImp.instance;
      final b = AudioServiceImp.instance;

      // Assert — both accesses yield the exact same object.
      expect(identical(a, b), isTrue);
    });

    test('should_implement_ObservadorJuego_when_used_as_observer', () {
      expect(AudioServiceImp.instance, isA<ObservadorJuego>());
    });

    test('should_play_when_notified_of_FlechaEliminada_and_Victoria', () {
      // Arrange — wire AudioServiceImp as an observer via a real publisher.
      final publicador = PublicadorEventosJuego();
      publicador.suscribir(AudioServiceImp.instance);

      // Act — publish the two events the audio service must react to.
      // If the service crashes, the test fails here.
      expect(
        () => publicador.publicar(
          EventoJuego(TipoEvento.flechaEliminada, posicion),
        ),
        returnsNormally,
      );
      expect(
        () => publicador.publicar(EventoJuego(TipoEvento.victoria, posicion)),
        returnsNormally,
      );

      // Assert — unsubscribing is clean (no state leak between tests).
      expect(
        () => publicador.desuscribir(AudioServiceImp.instance),
        returnsNormally,
      );
    });

    test('should_ignore_unrelated_events_when_notified_without_error', () {
      // The service must handle every TipoEvento gracefully, not only the two
      // it cares about.
      final publicador = PublicadorEventosJuego();
      publicador.suscribir(AudioServiceImp.instance);

      for (final tipo in TipoEvento.values) {
        expect(
          () => publicador.publicar(EventoJuego(tipo, posicion)),
          returnsNormally,
        );
      }

      publicador.desuscribir(AudioServiceImp.instance);
    });
  });
}
