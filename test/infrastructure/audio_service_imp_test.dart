import 'package:arrowmaze/domain/evento_juego.dart';
import 'package:arrowmaze/domain/publicador_eventos_juego.dart';
import 'package:arrowmaze/domain/value_objects/posicion.dart';
import 'package:arrowmaze/infrastructure/audio/audio_service_imp.dart';
import 'package:arrowmaze/infrastructure/audio/i_reproductor_audio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake audio player that records every asset (and volume) it was asked to
/// play.
class _ReproductorFake implements IReproductorAudio {
  final List<String> assetsReproducidos = [];
  final List<double> volumenesReproducidos = [];
  bool debeFallar = false;

  @override
  void reproducir(String asset, {double volumen = 1.0}) {
    if (debeFallar) throw Exception('Simulated audio failure');
    assetsReproducidos.add(asset);
    volumenesReproducidos.add(volumen);
  }

  @override
  void detener() {}

  @override
  void liberar() {}

  void reiniciar() {
    assetsReproducidos.clear();
    volumenesReproducidos.clear();
  }
}

void main() {
  const posicion = Posicion.en(fila: 0, columna: 0);
  late _ReproductorFake reproductor;
  late AudioServiceImp audioService;

  setUp(() {
    reproductor = _ReproductorFake();
    audioService = AudioServiceImp(reproductor: reproductor);
  });

  group('AudioServiceImp — softened event-to-sound mapping (AC1/AC3)', () {
    test('should_play_softened_asset_for_each_event_type', () {
      const esperado = <TipoEvento, String>{
        TipoEvento.movimientoRealizado: 'sounds/move_soft.wav',
        TipoEvento.flechaEliminada: 'sounds/move_soft.wav',
        TipoEvento.movimientoInvalido: 'sounds/invalid_soft.wav',
        TipoEvento.coleccionableRecogido: 'sounds/collect_soft.wav',
        TipoEvento.victoria: 'sounds/victory_soft.wav',
        TipoEvento.derrota: 'sounds/defeat_soft.wav',
      };

      for (final entry in esperado.entries) {
        reproductor.reiniciar();

        audioService.alOcurrirEvento(EventoJuego(entry.key, posicion));

        expect(reproductor.assetsReproducidos, contains(entry.value));
        // AC3 — comfortable, non-clipping level: strictly below full scale.
        expect(reproductor.volumenesReproducidos.single, greaterThan(0));
        expect(reproductor.volumenesReproducidos.single, lessThan(1.0));
      }
    });
  });

  group('AudioServiceImp — bounded polyphony (AC3)', () {
    test('should_debounce_rapid_repeats_of_same_event', () {
      var ahora = DateTime(2026, 1, 1);
      audioService = AudioServiceImp(
        reproductor: reproductor,
        ahora: () => ahora,
      );

      // Act — three notifications of the same event in immediate succession.
      audioService.alOcurrirEvento(
        EventoJuego(TipoEvento.movimientoRealizado, posicion),
      );
      audioService.alOcurrirEvento(
        EventoJuego(TipoEvento.movimientoRealizado, posicion),
      );
      audioService.alOcurrirEvento(
        EventoJuego(TipoEvento.movimientoRealizado, posicion),
      );

      // Assert — only the first one played; the rapid repeats were debounced.
      expect(reproductor.assetsReproducidos, hasLength(1));

      // Act — once the debounce window elapses, the event plays again.
      ahora = ahora.add(const Duration(milliseconds: 200));
      audioService.alOcurrirEvento(
        EventoJuego(TipoEvento.movimientoRealizado, posicion),
      );

      expect(reproductor.assetsReproducidos, hasLength(2));
    });

    test('should_not_debounce_different_event_types_against_each_other', () {
      var ahora = DateTime(2026, 1, 1);
      audioService = AudioServiceImp(
        reproductor: reproductor,
        ahora: () => ahora,
      );

      audioService.alOcurrirEvento(
        EventoJuego(TipoEvento.movimientoRealizado, posicion),
      );
      audioService.alOcurrirEvento(EventoJuego(TipoEvento.victoria, posicion));

      expect(reproductor.assetsReproducidos, hasLength(2));
    });
  });

  group('AudioServiceImp — mute toggle (AC4)', () {
    test('should_suppress_playback_when_muted', () {
      audioService.toggleMute();
      expect(audioService.muted, isTrue);

      audioService.alOcurrirEvento(
        EventoJuego(TipoEvento.movimientoRealizado, posicion),
      );
      audioService.alOcurrirEvento(EventoJuego(TipoEvento.victoria, posicion));

      expect(reproductor.assetsReproducidos, isEmpty);
    });

    test('should_resume_playing_when_unmuted', () {
      audioService.toggleMute();
      expect(audioService.muted, isTrue);
      audioService.alOcurrirEvento(
        EventoJuego(TipoEvento.movimientoRealizado, posicion),
      );
      expect(reproductor.assetsReproducidos, isEmpty);

      audioService.toggleMute();
      expect(audioService.muted, isFalse);
      audioService.alOcurrirEvento(EventoJuego(TipoEvento.victoria, posicion));

      expect(
        reproductor.assetsReproducidos,
        contains('sounds/victory_soft.wav'),
      );
    });
  });

  group('AudioServiceImp — graceful degradation (AC4)', () {
    test('should_not_crash_when_asset_missing_or_player_error', () {
      reproductor.debeFallar = true;

      expect(
        () => audioService.alOcurrirEvento(
          EventoJuego(TipoEvento.movimientoRealizado, posicion),
        ),
        returnsNormally,
      );
    });

    test('should_handle_all_event_types_without_error', () {
      for (final tipo in TipoEvento.values) {
        expect(
          () => audioService.alOcurrirEvento(EventoJuego(tipo, posicion)),
          returnsNormally,
        );
      }
    });
  });

  group('AudioServiceImp — IControlAudio', () {
    test('should_expose_muted_state', () {
      expect(audioService.muted, isFalse);

      audioService.toggleMute();
      expect(audioService.muted, isTrue);

      audioService.toggleMute();
      expect(audioService.muted, isFalse);
    });
  });

  group('AudioServiceImp — Singleton (ADR-0002)', () {
    setUpAll(() {
      AudioServiceImp.usarReproductor(_ReproductorFake());
    });

    test('should_return_same_instance_when_accessed_twice', () {
      final a = AudioServiceImp.instance;
      final b = AudioServiceImp.instance;

      expect(identical(a, b), isTrue);
    });
  });

  group('AudioServiceImp — Observer wiring through publisher', () {
    test('should_play_when_event_published_through_real_publisher', () {
      final publicador = PublicadorEventosJuego();
      publicador.suscribir(audioService);

      publicador.publicar(
        EventoJuego(TipoEvento.movimientoRealizado, posicion),
      );

      expect(reproductor.assetsReproducidos, contains('sounds/move_soft.wav'));
    });

    test('should_not_play_when_muted_and_event_published', () {
      audioService.toggleMute();
      final publicador = PublicadorEventosJuego();
      publicador.suscribir(audioService);

      publicador.publicar(EventoJuego(TipoEvento.victoria, posicion));

      expect(reproductor.assetsReproducidos, isEmpty);
    });
  });
}
