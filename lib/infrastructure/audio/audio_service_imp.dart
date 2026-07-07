import '../../application/ports/i_control_audio.dart';
import '../../domain/evento_juego.dart';
import '../../domain/observador_juego.dart';
import 'i_reproductor_audio.dart';
import 'reproductor_audio_assets.dart';

/// The one honest GoF Singleton for audio (ADR-0002).
///
/// Reacts to game events through the Observer pattern ([ObservadorJuego]),
/// mapping each [TipoEvento] to a soft sound asset and playing it through the
/// injected [IReproductorAudio].
///
/// The event→sound mapping is data-driven (a static table of asset + gain),
/// so retuning or swapping a sample is a single entry — never a new branch
/// (ticket 25). Rapid repeated notifications of the same [TipoEvento] are
/// debounced so they never pile up into a harsh overlapping burst.
///
/// Registered with [PublicadorEventosJuego] at the composition root
/// (`Inyeccion`). A global mute toggle ([IControlAudio]) lets the UI silence
/// all sounds without touching game logic.
class AudioServiceImp implements ObservadorJuego, IControlAudio {
  AudioServiceImp({
    required IReproductorAudio reproductor,
    Duration debounce = const Duration(milliseconds: 120),
    DateTime Function() ahora = DateTime.now,
  }) : _reproductor = reproductor,
       _debounce = debounce,
       _ahora = ahora;

  final IReproductorAudio _reproductor;
  final Duration _debounce;
  final DateTime Function() _ahora;
  bool _muted = false;
  final Map<TipoEvento, DateTime> _ultimaReproduccion = {};

  /// The single shared instance across the app's lifetime.
  static AudioServiceImp get instance => _instance;
  static AudioServiceImp _instance = AudioServiceImp._crearPorDefecto();

  static AudioServiceImp _crearPorDefecto() =>
      AudioServiceImp(reproductor: ReproductorAudioAssets());

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
  // ObservadorJuego — softened event-to-sound mapping (AC1/AC3)
  // ---------------------------------------------------------------------------

  /// Data-driven event→(asset, gain) table (OCP): retuning a sound or wiring
  /// a new event is a single entry here, never a new code branch. Every gain
  /// is kept below full scale for a comfortable, non-clipping level (AC3).
  static const _mapaSonidos = <TipoEvento, ({String asset, double volumen})>{
    TipoEvento.movimientoRealizado: (
      asset: 'sounds/move_soft.wav',
      volumen: 0.55,
    ),
    TipoEvento.flechaEliminada: (asset: 'sounds/move_soft.wav', volumen: 0.55),
    TipoEvento.movimientoInvalido: (
      asset: 'sounds/invalid_soft.wav',
      volumen: 0.5,
    ),
    TipoEvento.coleccionableRecogido: (
      asset: 'sounds/collect_soft.wav',
      volumen: 0.6,
    ),
    TipoEvento.victoria: (asset: 'sounds/victory_soft.wav', volumen: 0.7),
    // A dedicated, attention-grabbing cue for the 15-second heads-up (ticket 29,
    // AC4) — deliberately its *own* sample, not a reused move/invalid sound.
    TipoEvento.avisoTiempo: (asset: 'sounds/warning_soft.wav', volumen: 0.65),
    TipoEvento.derrota: (asset: 'sounds/defeat_soft.wav', volumen: 0.6),
  };

  @override
  void alOcurrirEvento(EventoJuego evento) {
    if (_muted) return;
    final sonido = _mapaSonidos[evento.tipo];
    if (sonido == null) return;
    if (_debeDescartarPorDebounce(evento.tipo)) return;

    try {
      _reproductor.reproducir(sonido.asset, volumen: sonido.volumen);
    } catch (_) {
      // Graceful degradation on missing asset or player error (AC4).
    }
  }

  /// Bounded polyphony (AC3): the same [tipo] may not retrigger within
  /// [_debounce], so rapid repeated notifications never stack into a harsh
  /// overlapping burst. Different event types are never debounced against
  /// each other.
  bool _debeDescartarPorDebounce(TipoEvento tipo) {
    final ahora = _ahora();
    final ultima = _ultimaReproduccion[tipo];
    if (ultima != null && ahora.difference(ultima) < _debounce) {
      return true;
    }
    _ultimaReproduccion[tipo] = ahora;
    return false;
  }
}
