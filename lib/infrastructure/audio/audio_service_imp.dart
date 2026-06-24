import '../../application/ports/i_control_audio.dart';
import '../../domain/evento_juego.dart';
import '../../domain/observador_juego.dart';
import 'i_reproductor_audio.dart';
import 'reproductor_audio_assets.dart';

/// The one honest GoF Singleton for audio (ADR-0002).
///
/// Reacts to game events through the Observer pattern ([ObservadorJuego]),
/// mapping each [TipoEvento] to a sound asset and playing it through the
/// injected [IReproductorAudio].
///
/// The event→sound mapping is data-driven (a static table), so adding a sound
/// for a new event is a single entry — never a new branch.
///
/// Registered with [PublicadorEventosJuego] at the composition root
/// (`Inyeccion`). A global mute toggle ([IControlAudio]) lets the UI silence
/// all sounds without touching game logic.
class AudioServiceImp implements ObservadorJuego, IControlAudio {
  AudioServiceImp({required this._reproductor});

  final IReproductorAudio _reproductor;
  bool _muted = false;

  /// The single shared instance across the app's lifetime.
  static AudioServiceImp get instance => _instance;
  static AudioServiceImp _instance = AudioServiceImp._crearPorDefecto();

  static AudioServiceImp _crearPorDefecto() => AudioServiceImp(
        reproductor: ReproductorAudioAssets(),
      );

  /// Replaces the singleton instance with one using [reproductor].
  /// Tests call this in [setUpAll] to avoid platform-channel dependencies.
  static void usarReproductor(IReproductorAudio reproductor) {
    _instance = AudioServiceImp(reproductor: reproductor);
  }

  // ---------------------------------------------------------------------------
  // IControlAudio
  // ---------------------------------------------------------------------------

  @override
  bool get muted => _muted;

  @override
  void toggleMute() => _muted = !_muted;

  // ---------------------------------------------------------------------------
  // ObservadorJuego — event-to-sound mapping (AC1)
  // ---------------------------------------------------------------------------

  /// Data-driven event→asset table (OCP): adding a new event sound is a single
  /// entry here, never a new code branch.
  static const _mapaSonidos = <TipoEvento, String>{
    TipoEvento.movimientoRealizado: 'sounds/move.wav',
    TipoEvento.flechaEliminada: 'sounds/move.wav',
    TipoEvento.movimientoInvalido: 'sounds/invalid.wav',
    TipoEvento.coleccionableRecogido: 'sounds/collect.wav',
    TipoEvento.victoria: 'sounds/victory.wav',
    TipoEvento.derrota: 'sounds/defeat.wav',
  };

  @override
  void alOcurrirEvento(EventoJuego evento) {
    if (_muted) return;
    final asset = _mapaSonidos[evento.tipo];
    if (asset != null) {
      try {
        _reproductor.reproducir(asset);
      } catch (_) {
        // Graceful degradation on missing asset or player error (AC4).
      }
    }
  }
}
