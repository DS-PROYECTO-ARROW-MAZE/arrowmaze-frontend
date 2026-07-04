import 'package:flutter/foundation.dart';

import '../application/ports/i_control_audio.dart';
import '../application/ports/preferencias_usuario.dart';

/// DI-lifetime configuration manager (ADR-0002 — **not** a Singleton).
///
/// Holds the two user-controlled settings ([sonidoHabilitado], [idioma]),
/// persists them through [PreferenciasUsuario], and keeps [IControlAudio]'s
/// mute flag in sync so game logic never needs to reference this layer.
///
/// Must be initialised exactly once at the composition root by calling
/// [inicializar] before the first frame; until then the fields hold sensible
/// defaults (sound on, English).
///
/// Lives in `core/` rather than `application/` because [ChangeNotifier] pulls
/// in `flutter/foundation`, which the architecture guard forbids in
/// `application/` (strict Dart-purity rule for that layer).
class ConfiguracionManager extends ChangeNotifier {
  /// Creates the manager with [prefs] for persistence and [audioControl] for
  /// the audio mute bridge.
  ConfiguracionManager({
    required PreferenciasUsuario prefs,
    required IControlAudio audioControl,
  })  : _prefs = prefs,
        _audioControl = audioControl;

  final PreferenciasUsuario _prefs;
  final IControlAudio _audioControl;

  bool _sonidoHabilitado = true;
  String _idioma = 'en';

  /// Whether game sounds are enabled.
  bool get sonidoHabilitado => _sonidoHabilitado;

  /// Active language code — `'en'` or `'es'`.
  String get idioma => _idioma;

  /// Reads saved settings from the persistence port and applies them.
  ///
  /// [idiomaFallback] is used only when no language has been saved yet
  /// (first run). Callers should pass the device language code (filtered to
  /// `'en'`/`'es'`) so the app starts in the user's preferred language (AC5).
  /// The filtering is intentionally delegated to the composition root to keep
  /// this class Flutter-free (ADR-0002 — device locale detection uses a
  /// Flutter API that belongs outside core).
  Future<void> inicializar({String idiomaFallback = 'en'}) async {
    _sonidoHabilitado = await _prefs.leerSonidoHabilitado();
    _idioma = await _prefs.leerIdioma() ?? idiomaFallback;
    // AudioServiceImp always starts unmuted (muted = false); apply the saved
    // mute only when the user had disabled sound.
    if (!_sonidoHabilitado && !_audioControl.muted) {
      _audioControl.toggleMute();
    }
    notifyListeners();
  }

  /// Toggles sound on/off, persists the new value, and synchronises the audio
  /// mute flag — without touching any game logic (AC2).
  Future<void> toggleSonido() async {
    _sonidoHabilitado = !_sonidoHabilitado;
    _audioControl.toggleMute();
    await _prefs.guardarSonidoHabilitado(_sonidoHabilitado);
    notifyListeners();
  }

  /// Switches the active language to [idioma], persists the choice, and
  /// notifies listeners so the [LocalizacionesProvider] / [CadenasScope] can
  /// refresh the UI strings live (AC3).
  ///
  /// No-op when [idioma] is already active.
  Future<void> cambiarIdioma(String idioma) async {
    if (_idioma == idioma) return;
    _idioma = idioma;
    await _prefs.guardarIdioma(idioma);
    notifyListeners();
  }
}
