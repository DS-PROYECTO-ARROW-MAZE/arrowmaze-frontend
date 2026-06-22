import 'package:arrowmaze/domain/evento_juego.dart';
import 'package:arrowmaze/domain/publicador_eventos_juego.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:arrowmaze/infrastructure/audio/audio_service_imp.dart';
import 'package:arrowmaze/infrastructure/audio/i_reproductor_audio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake audio player that records every asset it was asked to play.
class _ReproductorFake implements IReproductorAudio {
  final List<String> assetsReproducidos = [];
  bool debeFallar = false;

  @override
  void reproducir(String asset) {
    if (debeFallar) throw Exception('Simulated audio failure');
    assetsReproducidos.add(asset);
  }

  @override
  void detener() {}

  @override
  void liberar() {}

  void reiniciar() => assetsReproducidos.clear();
}

void main() {
  const posicion = Posicion.en(fila: 0, columna: 0);
  late _ReproductorFake reproductor;
  late AudioServiceImp audioService;

  setUp(() {
    reproductor = _ReproductorFake();
    audioService = AudioServiceImp(reproductor: reproductor);
  });

  group('AudioServiceImp — event-to-sound mapping (AC1)', () {
    test(
      'should_play_move_sound_when_notified_of_valid_move',
      () {
        audioService.alOcurrirEvento(
          EventoJuego(TipoEvento.movimientoRealizado, posicion),
        );

        expect(reproductor.assetsReproducidos, contains('sounds/move.wav'));
      },
    );

    test(
      'should_play_move_sound_when_notified_of_arrow_exit',
      () {
        audioService.alOcurrirEvento(
          EventoJuego(TipoEvento.flechaEliminada, posicion),
        );

        expect(reproductor.assetsReproducidos, contains('sounds/move.wav'));
      },
    );

    test(
      'should_play_invalid_sound_when_notified_of_invalid_move',
      () {
        audioService.alOcurrirEvento(
          EventoJuego(TipoEvento.movimientoInvalido, posicion),
        );

        expect(reproductor.assetsReproducidos, contains('sounds/invalid.wav'));
      },
    );

    test(
      'should_play_collectible_sound_when_notified_of_collectible',
      () {
        audioService.alOcurrirEvento(
          EventoJuego(TipoEvento.coleccionableRecogido, posicion),
        );

        expect(
          reproductor.assetsReproducidos,
          contains('sounds/collect.wav'),
        );
      },
    );

    test(
      'should_play_victory_sound_when_notified_of_victory',
      () {
        audioService.alOcurrirEvento(
          EventoJuego(TipoEvento.victoria, posicion),
        );

        expect(
          reproductor.assetsReproducidos,
          contains('sounds/victory.wav'),
        );
      },
    );

    test(
      'should_play_defeat_sound_when_notified_of_defeat',
      () {
        audioService.alOcurrirEvento(
          EventoJuego(TipoEvento.derrota, posicion),
        );

        expect(
          reproductor.assetsReproducidos,
          contains('sounds/defeat.wav'),
        );
      },
    );
  });

  group('AudioServiceImp — mute toggle (AC4)', () {
    test(
      'should_not_play_sound_when_muted',
      () {
        audioService.toggleMute();
        expect(audioService.muted, isTrue);

        audioService.alOcurrirEvento(
          EventoJuego(TipoEvento.movimientoRealizado, posicion),
        );
        audioService.alOcurrirEvento(
          EventoJuego(TipoEvento.victoria, posicion),
        );

        expect(reproductor.assetsReproducidos, isEmpty);
      },
    );

    test(
      'should_resume_playing_when_unmuted',
      () {
        audioService.toggleMute();
        expect(audioService.muted, isTrue);
        audioService.alOcurrirEvento(
          EventoJuego(TipoEvento.movimientoRealizado, posicion),
        );
        expect(reproductor.assetsReproducidos, isEmpty);

        audioService.toggleMute();
        expect(audioService.muted, isFalse);
        audioService.alOcurrirEvento(
          EventoJuego(TipoEvento.victoria, posicion),
        );

        expect(reproductor.assetsReproducidos, contains('sounds/victory.wav'));
      },
    );
  });

  group('AudioServiceImp — graceful degradation (AC4)', () {
    test(
      'should_not_crash_when_asset_missing_or_player_error',
      () {
        reproductor.debeFallar = true;

        expect(
          () => audioService.alOcurrirEvento(
            EventoJuego(TipoEvento.movimientoRealizado, posicion),
          ),
          returnsNormally,
        );
      },
    );

    test(
      'should_handle_all_event_types_without_error',
      () {
        for (final tipo in TipoEvento.values) {
          expect(
            () => audioService.alOcurrirEvento(EventoJuego(tipo, posicion)),
            returnsNormally,
          );
        }
      },
    );
  });

  group('AudioServiceImp — IControlAudio', () {
    test(
      'should_expose_muted_state',
      () {
        expect(audioService.muted, isFalse);

        audioService.toggleMute();
        expect(audioService.muted, isTrue);

        audioService.toggleMute();
        expect(audioService.muted, isFalse);
      },
    );
  });

  group('AudioServiceImp — Singleton (ADR-0002)', () {
    setUpAll(() {
      AudioServiceImp.usarReproductor(_ReproductorFake());
    });

    test(
      'should_return_same_instance_when_accessed_twice',
      () {
        final a = AudioServiceImp.instance;
        final b = AudioServiceImp.instance;

        expect(identical(a, b), isTrue);
      },
    );
  });

  group('AudioServiceImp — Observer wiring through publisher', () {
    test(
      'should_play_when_event_published_through_real_publisher',
      () {
        final publicador = PublicadorEventosJuego();
        publicador.suscribir(audioService);

        publicador.publicar(
          EventoJuego(TipoEvento.movimientoRealizado, posicion),
        );

        expect(reproductor.assetsReproducidos, contains('sounds/move.wav'));
      },
    );

    test(
      'should_not_play_when_muted_and_event_published',
      () {
        audioService.toggleMute();
        final publicador = PublicadorEventosJuego();
        publicador.suscribir(audioService);

        publicador.publicar(
          EventoJuego(TipoEvento.victoria, posicion),
        );

        expect(reproductor.assetsReproducidos, isEmpty);
      },
    );
  });
}
